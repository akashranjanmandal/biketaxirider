import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app/theme.dart';
import '../data/models.dart';

const kFast = Duration(milliseconds: 180);
const kMedium = Duration(milliseconds: 280);
const kSlow = Duration(milliseconds: 420);
const kEase = Curves.easeOutCubic;

/// Subtle press feedback: slight scale and dim. Used for buttons and cards.
class Tappable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  const Tappable({super.key, required this.child, this.onTap, this.pressedScale = .97, this.haptic = false});

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: kFast,
        curve: kEase,
        child: AnimatedOpacity(opacity: _down ? .85 : 1, duration: kFast, child: widget.child),
      ),
    );
  }
}

/// List row with a pressed highlight instead of a scale.
class RowTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final BorderRadius radius;
  const RowTap({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14), this.radius = BorderRadius.zero});

  @override
  State<RowTap> createState() => _RowTapState();
}

class _RowTapState extends State<RowTap> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: kFast,
        padding: widget.padding,
        decoration: BoxDecoration(color: _down ? c.surfaceAlt : Colors.transparent, borderRadius: widget.radius),
        child: widget.child,
      ),
    );
  }
}

enum ButtonKind { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final ButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;
  const AppButton(this.label, {super.key, this.onTap, this.kind = ButtonKind.primary, this.icon, this.loading = false, this.expand = true, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (kind) {
      ButtonKind.primary => (Brand.primary, Brand.onPrimary, Colors.transparent),
      ButtonKind.secondary => (c.surfaceAlt, c.text, Colors.transparent),
      ButtonKind.ghost => (Colors.transparent, c.text, c.border),
      ButtonKind.danger => (Brand.danger.withValues(alpha: c.dark ? .16 : .1), Brand.danger, Colors.transparent),
    };
    final disabled = onTap == null && !loading;
    return Tappable(
      onTap: loading ? null : onTap,
      haptic: kind == ButtonKind.primary,
      child: AnimatedOpacity(
        duration: kMedium,
        opacity: disabled ? .4 : 1,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: border)),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: kMedium,
            child: loading
                ? SizedBox(key: const ValueKey('l'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                : Row(key: ValueKey(label), mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: fg, weight: 500), const SizedBox(width: 8)],
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.button.copyWith(color: fg))),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Round icon button, used over the map and in headers.
class CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool elevated;
  final Color? color;
  final Color? iconColor;
  const CircleButton(this.icon, {super.key, this.onTap, this.size = 44, this.elevated = false, this.color, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tappable(
      onTap: onTap,
      pressedScale: .92,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color ?? (elevated ? c.surface : c.surfaceAlt),
          shape: BoxShape.circle,
          boxShadow: elevated ? shadow(c) : null,
        ),
        child: Icon(icon, size: size * .48, color: iconColor ?? c.text, weight: 500),
      ),
    );
  }
}

List<BoxShadow> shadow(AppColors c, {double strength = 1}) => [
      BoxShadow(color: Colors.black.withValues(alpha: (c.dark ? .45 : .10) * strength), blurRadius: 18, offset: const Offset(0, 6)),
      BoxShadow(color: Colors.black.withValues(alpha: (c.dark ? .3 : .04) * strength), blurRadius: 3, offset: const Offset(0, 1)),
    ];

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool outlined;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.outlined = true});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: outlined ? Border.all(color: c.border) : null,
      ),
      child: child,
    );
    return onTap == null ? card : Tappable(onTap: onTap, pressedScale: .985, child: card);
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 10)});

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(title, style: context.t.title)),
          if (action != null)
            Tappable(onTap: onAction, child: Text(action!, style: context.t.label.copyWith(color: context.c.accentText))),
        ]),
      );
}

/// Square-ish tile for an icon.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Color? iconColor;
  const IconTile(this.icon, {super.key, this.size = 40, this.color, this.iconColor});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color ?? context.c.surfaceAlt, borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(icon, size: size * .5, color: iconColor ?? context.c.text, weight: 450),
      );
}

/// Standard settings / list row.
class ListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  const ListRow({super.key, this.icon, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.chevron = true});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return RowTap(
      onTap: onTap,
      child: Row(children: [
        if (leading != null) leading! else if (icon != null) IconTile(icon!),
        if (leading != null || icon != null) const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.t.bodyStrong),
            if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: context.t.caption)],
          ]),
        ),
        if (trailing != null) trailing!,
        if (chevron && onTap != null) Icon(Symbols.chevron_right, color: c.text3, size: 22),
      ]),
    );
  }
}

class Hairline extends StatelessWidget {
  final double indent;
  const Hairline({super.key, this.indent = 0});
  @override
  Widget build(BuildContext context) => Container(height: 1, margin: EdgeInsets.only(left: indent), color: context.c.border);
}

/// Vehicle illustration from the brand sheet. In dark mode it sits on a soft
/// light plate so the dark car/rider details stay legible.
class VehicleImage extends StatelessWidget {
  final Service service;
  final double width;
  final bool plate;
  const VehicleImage(this.service, {super.key, this.width = 64, this.plate = false});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(service.artAsset, width: width, height: width * .62, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
    if (!plate) return img;
    final c = context.c;
    return Container(
      width: width + 16,
      height: width * .62 + 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.dark ? const Color(0xFFECEAE4) : c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: img,
    );
  }
}

/// Horizontal position of the pin's centre within logo_mark.png (the speed
/// lines make the image wider on the left). Generated by tool/brand_assets.py.
const kMarkCenterX = .6011;

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Image.asset('assets/brand/logo_mark.png', width: size, filterQuality: FilterQuality.medium);
}

class Wordmark extends StatelessWidget {
  final double height;
  const Wordmark({super.key, this.height = 26});
  @override
  Widget build(BuildContext context) => Image.asset(
        context.c.dark ? 'assets/brand/wordmark_dark.png' : 'assets/brand/wordmark.png',
        height: height,
        filterQuality: FilterQuality.medium,
      );
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  const Avatar(this.initials, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.c.sunken, shape: BoxShape.circle),
        child: Text(initials, style: context.t.subtitle.copyWith(fontSize: size * .36)),
      );
}

class PlateTag extends StatelessWidget {
  final String plate;
  const PlateTag(this.plate, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: context.c.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.c.text, width: 1.2),
        ),
        child: Text(plate, style: context.t.label.copyWith(fontSize: 12, letterSpacing: .4)),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color, this.textColor, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color ?? context.c.surfaceAlt, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: textColor ?? context.c.text2, fill: 1), const SizedBox(width: 3)],
          Text(text, style: context.t.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: textColor ?? context.c.text2)),
        ]),
      );
}

/// Segmented control.
class Segmented extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  const Segmented({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth / items.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: kMedium,
            curve: kEase,
            left: w * index,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(decoration: BoxDecoration(color: c.dark ? c.sunken : c.surface, borderRadius: BorderRadius.circular(9), boxShadow: c.dark ? null : shadow(c, strength: .5))),
          ),
          Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: kMedium,
                      style: context.t.label.copyWith(color: i == index ? c.text : c.text2),
                      child: Text(items[i]),
                    ),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Bottom sheet with consistent chrome.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scrollable = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        Flexible(child: builder(ctx)),
        SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
      ]),
    ),
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(color: context.c.border, borderRadius: BorderRadius.circular(2)),
      );
}

void showToast(BuildContext context, String message, {IconData icon = Symbols.check_circle}) {
  final c = context.c;
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: c.dark ? c.sunken : const Color(0xFF1B1C20),
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    duration: const Duration(milliseconds: 2200),
    content: Row(children: [
      Icon(icon, color: Brand.primary, size: 20, fill: 1),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: context.t.label.copyWith(color: Colors.white))),
    ]),
  ));
}

String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'am' : 'pm'}';
}

String rupees(num v) => '₹${v.round()}';

/// Standard page scaffold with a large title.
class PageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottom;
  const PageScaffold({super.key, required this.title, required this.body, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: Navigator.of(context).canPop() ? Center(child: CircleButton(Symbols.arrow_back, size: 40, onTap: () => Navigator.of(context).maybePop())) : null,
          title: Text(title, style: context.t.title),
          centerTitle: false,
          titleSpacing: 4,
          actions: [...actions, const SizedBox(width: 12)],
        ),
        body: body,
        bottomNavigationBar: bottom,
      );
}
