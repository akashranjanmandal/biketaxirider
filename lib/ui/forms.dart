import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import 'kit.dart';

/// Outlined text field with a floating label (from the rider app's name screen).
class AppField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final TextInputType? keyboard;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final String? prefix;
  final String? error;
  final String? helper;
  final List<TextInputFormatter>? formatters;
  final TextInputAction? action;
  final Widget? suffix;
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.keyboard,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    this.prefix,
    this.error,
    this.helper,
    this.formatters,
    this.action,
    this.suffix,
  });

  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: color, width: w));
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboard,
      textCapitalization: widget.capitalization,
      textInputAction: widget.action,
      inputFormatters: widget.formatters,
      onChanged: widget.onChanged,
      style: context.t.body,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: widget.prefix,
        prefixStyle: context.t.body,
        labelStyle: context.t.secondary,
        floatingLabelStyle: context.t.label.copyWith(color: widget.error != null ? Brand.danger : c.text2),
        errorText: widget.error,
        errorStyle: context.t.caption.copyWith(color: Brand.danger),
        helperText: widget.helper,
        helperStyle: context.t.caption,
        suffixIcon: widget.suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: border(c.border),
        focusedBorder: border(c.text, 1.6),
        errorBorder: border(Brand.danger),
        focusedErrorBorder: border(Brand.danger, 1.6),
      ),
    );
  }
}

enum CodeState { typing, verifying, wrong, ok }

/// Four code boxes over an invisible text field: the rider app's OTP input,
/// shared by the OTP screen and the rider PIN. Bump [shakeKey] to shake.
class CodeInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final CodeState state;
  final int shakeKey;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  final double boxHeight;
  final int length;
  const CodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.state = CodeState.typing,
    this.shakeKey = 0,
    this.autofocus = true,
    this.boxHeight = 64,
    this.length = 4,
  });

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CodeInput old) {
    super.didUpdateWidget(old);
    if (old.shakeKey != widget.shakeKey) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 5) * 8 * (1 - _shake.value), 0), child: child),
      child: GestureDetector(
        onTap: () => widget.focusNode.requestFocus(),
        child: Stack(children: [
          Row(children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _box(context, i, code)),
            ],
          ]),
          // the real input, invisible, on top of the boxes
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                enabled: widget.state != CodeState.verifying && widget.state != CodeState.ok,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
                onChanged: widget.onChanged,
                showCursor: false,
                enableInteractiveSelection: false,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _box(BuildContext context, int i, String code) {
    final c = context.c;
    final st = widget.state;
    final filled = i < code.length;
    final active = i == code.length && widget.focusNode.hasFocus && st == CodeState.typing;
    final Color border = switch (st) {
      CodeState.wrong => Brand.danger,
      CodeState.ok => Brand.success,
      _ => active ? c.text : (filled ? c.text2 : c.border),
    };
    return AnimatedContainer(
      duration: kFast,
      height: widget.boxHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: border, width: active || st == CodeState.wrong || st == CodeState.ok ? 1.6 : 1),
      ),
      child: AnimatedSwitcher(
        duration: kFast,
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .8, end: 1.0).animate(a), child: child)),
        child: filled
            ? Text(code[i], key: ValueKey('$i${code[i]}'), style: context.t.headline)
            : active
                ? _Caret(key: const ValueKey('caret'), color: c.text)
                : const SizedBox.shrink(),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  final Color color;
  const _Caret({super.key, required this.color});
  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _c, child: Container(width: 2, height: 26, color: widget.color));
}

/// Formats as "98765 43210" while typing (digits-only input).
class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(' ', '');
    final f = d.length > 5 ? '${d.substring(0, 5)} ${d.substring(5)}' : d;
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}

/// Upper-cases as you type (IFSC, vehicle numbers).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
