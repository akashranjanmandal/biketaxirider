import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../kit.dart';

// Masked call and in-app chat with the rider: the rider app's sheets, with
// the captain on the other side.

void showCallSheet(BuildContext context, Rider rider) => showAppSheet(context, builder: (ctx) => _CallSheet(rider: rider));

class _CallSheet extends StatefulWidget {
  final Rider rider;
  const _CallSheet({required this.rider});
  @override
  State<_CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends State<_CallSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  Timer? _t;
  int _secs = -3; // rings for 3s, then "connected"
  bool _muted = false, _speaker = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs++);
      if (_secs == 0) _pulse.stop();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final connected = _secs >= 0;
    final time = connected ? '${_secs ~/ 60}:${(_secs % 60).toString().padLeft(2, '0')}' : 'Calling…';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 120,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Stack(alignment: Alignment.center, children: [
              if (!connected)
                Container(
                  width: 76 + _pulse.value * 40,
                  height: 76 + _pulse.value * 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.text.withValues(alpha: .08 * (1 - _pulse.value))),
                ),
              child ?? const SizedBox.shrink(),
            ]),
            child: Avatar(widget.rider.initials, size: 76),
          ),
        ),
        Text(widget.rider.name, style: context.t.headline),
        const SizedBox(height: 4),
        Text(time, style: context.t.secondary),
        const SizedBox(height: 4),
        Text('Masked call · numbers stay private', style: context.t.caption.copyWith(color: c.text3)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _CallAction(_muted ? Symbols.mic_off : Symbols.mic, 'Mute', _muted, () => setState(() => _muted = !_muted)),
          Column(children: [
            CircleButton(Symbols.call_end, size: 64, color: Brand.danger, iconColor: Colors.white, onTap: () => Navigator.pop(context)),
            const SizedBox(height: 8),
            Text('End', style: context.t.caption),
          ]),
          _CallAction(Symbols.volume_up, 'Speaker', _speaker, () => setState(() => _speaker = !_speaker)),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _CallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _CallAction(this.icon, this.label, this.on, this.onTap);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(children: [
      CircleButton(icon, size: 56, color: on ? c.text : c.surfaceAlt, iconColor: on ? c.bg : c.text, onTap: onTap),
      const SizedBox(height: 8),
      Text(label, style: context.t.caption),
    ]);
  }
}

void showChatSheet(BuildContext context, Rider rider, {required String place}) =>
    showAppSheet(context, builder: (ctx) => _ChatSheet(rider: rider, place: place));

class _ChatSheet extends StatefulWidget {
  final Rider rider;
  final String place;
  const _ChatSheet({required this.rider, required this.place});
  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  late final List<(bool, String)> _msgs = [(false, 'Hi, I\'m waiting at ${widget.place}.')];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  static const _quick = ['On my way', 'I\'ve reached the pickup', 'Please come to the main road', 'Okay, thanks!'];
  static const _replies = ['Okay, coming.', 'Sure, I\'m near the gate.', 'Thank you!', 'Got it, see you soon.'];
  final _rnd = math.Random();
  final _pending = <Timer>[];

  @override
  void dispose() {
    for (final t in _pending) {
      t.cancel();
    }
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => _msgs.add((true, t)));
    _ctrl.clear();
    _toEnd();
    _pending.add(Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _msgs.add((false, _replies[_rnd.nextInt(_replies.length)])));
      _toEnd();
    }));
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: kMedium, curve: kEase);
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: MediaQuery.of(context).size.height * .6,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(children: [
            Avatar(widget.rider.initials, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.rider.name, style: context.t.bodyStrong),
                Text('Rider · ${widget.place}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
              ]),
            ),
          ]),
        ),
        const Hairline(),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: _msgs.length,
            itemBuilder: (context, i) {
              final (mine, text) = _msgs[i];
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: kMedium,
                  curve: kEase,
                  builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .72),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: mine ? (c.dark ? Brand.primary : c.text) : c.surfaceAlt,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(mine ? 18 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 18),
                      ),
                    ),
                    child: Text(text, style: context.t.body.copyWith(color: mine ? (c.dark ? Brand.onPrimary : c.bg) : c.text)),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quick.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Tappable(
              onTap: () => _send(_quick[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border)),
                child: Text(_quick[i], style: context.t.label),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: _send,
                  textInputAction: TextInputAction.send,
                  style: context.t.body,
                  decoration: InputDecoration(border: InputBorder.none, hintText: 'Message ${widget.rider.firstName}', hintStyle: context.t.body.copyWith(color: c.text3)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleButton(Symbols.arrow_upward, size: 46, color: Brand.primary, iconColor: Brand.onPrimary, onTap: () => _send(_ctrl.text)),
          ]),
        ),
      ]),
    );
  }
}
