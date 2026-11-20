import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app/theme.dart';
import '../data/net.dart';
import 'kit.dart';

/// Swipe-to-confirm button (go online / offline, end trip). The thumb has to
/// be dragged most of the way; releasing early springs it back.
class SlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback? onConfirm;
  final IconData icon;
  final ButtonKind kind;
  const SlideToConfirm({super.key, required this.label, this.onConfirm, this.icon = Symbols.arrow_forward, this.kind = ButtonKind.primary});

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> with SingleTickerProviderStateMixin {
  late final AnimationController _pos = AnimationController(vsync: this, duration: kMedium);
  bool _done = false;
  static const _h = 60.0, _pad = 4.0;

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _release() {
    if (_done) return;
    if (_pos.value > .78) {
      _done = true;
      HapticFeedback.mediumImpact();
      _pos.animateTo(1, duration: kFast, curve: kEase).whenComplete(() {
        widget.onConfirm?.call();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _done = false;
          _pos.value = 0;
        });
      });
    } else {
      _pos.animateBack(0, duration: kMedium, curve: kEase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final enabled = widget.onConfirm != null;
    final (thumb, onThumb) = switch (widget.kind) {
      ButtonKind.danger => (Brand.danger, Colors.white),
      ButtonKind.secondary => (c.text, c.bg),
      _ => (Brand.primary, Brand.onPrimary),
    };
    return Semantics(
      button: true,
      label: widget.label,
      onTap: enabled ? widget.onConfirm : null,
      child: AnimatedOpacity(
        duration: kMedium,
        opacity: enabled ? 1 : .4,
        child: LayoutBuilder(builder: (context, box) {
          final travel = box.maxWidth - _h;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: enabled && !_done ? (d) => _pos.value = (_pos.value + d.delta.dx / travel).clamp(0.0, 1.0) : null,
            onHorizontalDragEnd: enabled ? (_) => _release() : null,
            onHorizontalDragCancel: enabled ? _release : null,
            onTap: enabled && !_done
                ? () async {
                    // a tap nudges the thumb to show it needs a swipe
                    await _pos.animateTo(.14, duration: kFast, curve: kEase);
                    if (mounted && !_done) _pos.animateBack(0, duration: kMedium, curve: kEase);
                  }
                : null,
            child: Container(
              height: _h,
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
              child: AnimatedBuilder(
                animation: _pos,
                builder: (context, _) {
                  final v = _pos.value;
                  return Stack(alignment: Alignment.centerLeft, children: [
                    // filled track behind the thumb
                    Container(
                      width: _h + travel * v,
                      decoration: BoxDecoration(color: thumb.withValues(alpha: c.dark ? .22 : .18), borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                    Positioned.fill(
                      left: _h - 8,
                      right: 12,
                      child: Center(
                        child: Opacity(
                          opacity: (1 - v * 1.6).clamp(0.0, 1.0),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.button.copyWith(color: c.text))),
                            const SizedBox(width: 6),
                            Icon(Symbols.keyboard_double_arrow_right, size: 20, color: c.text3),
                          ]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _pad + travel * v,
                      child: Container(
                        width: _h - _pad * 2,
                        height: _h - _pad * 2,
                        decoration: BoxDecoration(color: thumb, borderRadius: BorderRadius.circular(Radii.md - 3)),
                        child: Icon(v >= 1 ? Symbols.check : widget.icon, color: onThumb, size: 24, weight: 600),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Ring that empties over [total] seconds from [startedAt], with the seconds left.
class CountdownRing extends StatefulWidget {
  final DateTime startedAt;
  final double total;
  final double size;
  const CountdownRing({super.key, required this.startedAt, required this.total, this.size = 58});

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.total * 1000).round()));

  @override
  void initState() {
    super.initState();
    final elapsed = clock.now().difference(widget.startedAt).inMilliseconds / 1000 / widget.total;
    _c.forward(from: elapsed.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final left = 1 - _c.value;
          final secs = (left * widget.total).ceil();
          final urgent = secs <= 5;
          return CustomPaint(
            painter: _RingPainter(left, urgent ? Brand.danger : Brand.primary, c.surfaceAlt),
            child: Center(child: Text('$secs', style: context.t.title.copyWith(color: urgent ? Brand.danger : c.text))),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color, track;
  _RingPainter(this.value, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    const w = 4.0;
    final r = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

/// Segmented progress for multi-step flows.
class StepTracker extends StatelessWidget {
  final int count, index;
  const StepTracker({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(children: [
      for (var i = 0; i < count; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: kSlow,
            curve: kEase,
            height: 4,
            decoration: BoxDecoration(color: i <= index ? Brand.primary : c.sunken, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    ]);
  }
}

/// Thin rounded progress bar (as used on the rider app's ride panels).
class ProgressLine extends StatelessWidget {
  final double? value;
  final Color color;
  const ProgressLine({super.key, this.value, this.color = Brand.primary});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: value, minHeight: 4, color: color, backgroundColor: context.c.surfaceAlt),
      );
}

/// Centered icon + message for empty lists.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.sub, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: c.text3),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: context.t.bodyStrong.copyWith(color: c.text2)),
        if (sub != null) ...[const SizedBox(height: 4), Text(sub!, textAlign: TextAlign.center, style: context.t.caption)],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

/// Strip shown while there's no connection. Collapses to nothing when online.
class OfflineBanner extends StatelessWidget {
  final EdgeInsets margin;
  const OfflineBanner({super.key, this.margin = const EdgeInsets.fromLTRB(20, 8, 20, 0)});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: net,
      builder: (context, _) => AnimatedSize(
        duration: kMedium,
        curve: kEase,
        alignment: Alignment.topCenter,
        child: net.online
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: margin,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(color: c.dark ? c.sunken : const Color(0xFF1B1C20), borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(children: [
                    const Icon(Symbols.wifi_off, size: 20, color: Brand.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('You\'re offline. Showing saved data.', style: context.t.label.copyWith(color: Colors.white)),
                    ),
                    Tappable(
                      onTap: net.retry,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('Retry', style: context.t.label.copyWith(color: Brand.primary)),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }
}

/// Number that counts up to [value] when shown (and animates on change).
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle style;
  final Duration duration;
  final String Function(double) format;
  const CountUp(this.value, {super.key, required this.style, this.duration = const Duration(milliseconds: 700), this.format = rupees});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: kEase,
        builder: (_, v, _) => Text(format(v), style: style),
      );
}

/// Pickup → drop with the rider app's dot-and-square markers.
class RouteStops extends StatelessWidget {
  final String from, to;
  final String? fromSub, toSub;
  final bool boxed;
  const RouteStops({super.key, required this.from, required this.to, this.fromSub, this.toSub, this.boxed = true});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget stop(String title, String? sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.bodyStrong),
          if (sub != null) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
        ]);
    final body = IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: Brand.success, shape: BoxShape.circle)),
            Expanded(child: Container(width: 1.5, margin: const EdgeInsets.symmetric(vertical: 3), color: c.border)),
            Container(width: 9, height: 9, decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(1.5))),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            stop(from, fromSub),
            const SizedBox(height: 12),
            stop(to, toSub),
          ]),
        ),
      ]),
    );
    if (!boxed) return body;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.border)),
      child: body,
    );
  }
}

/// Label / value row for receipts and details.
class KvRow extends StatelessWidget {
  final String k, v;
  final bool strong;
  final Color? color;
  const KvRow(this.k, this.v, {super.key, this.strong = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: (strong ? context.t.bodyStrong : context.t.secondary).copyWith(color: color))),
          const SizedBox(width: 12),
          Text(v, style: (strong ? context.t.bodyStrong : context.t.body).copyWith(color: color)),
        ]),
      );
}

/// Small status pill: green for good, amber for attention, red for problems.
class StatusPill extends StatelessWidget {
  final String text;
  final Color tone;
  final IconData? icon;
  const StatusPill(this.text, this.tone, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Pill(text, color: tone.withValues(alpha: context.c.dark ? .2 : .12), textColor: tone == Brand.primary ? context.c.accentText : tone, icon: icon);
}

String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}m';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDate(DateTime d, {bool year = false}) => '${d.day} ${_months[d.month - 1]}${year ? ' ${d.year}' : ''}';

/// "Today · 9:12 am", "Yesterday · 7:40 pm" or "3 Oct · 5:05 pm".
String formatWhen(DateTime t) {
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  final d = diff == 0 ? 'Today' : (diff == 1 ? 'Yesterday' : formatDate(t));
  return '$d · ${formatTime(t)}';
}

/// "₹1,240" with Indian digit grouping.
String inr(num v) {
  final n = v.round().abs();
  final s = n.toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '${v < 0 ? '−' : ''}₹$out';
}

/// One extra step on the type scale for hero numbers (amount to collect,
/// earnings totals). Defined once here; screens never set sizes themselves.
extension CaptainType on AppType {
  TextStyle get hero => display.copyWith(fontSize: 44, letterSpacing: -1.6, height: 1.05);
}
