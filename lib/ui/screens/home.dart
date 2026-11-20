import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/navigation.dart';
import '../captain_kit.dart';
import '../kit.dart';
import '../map/ride_map.dart';
import 'more.dart';
import 'shell.dart';
import 'summary.dart';
import 'trip_panels.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  double? _panelH;
  Timer? _debounce;
  bool _navigate = false;
  CaptainStage _last = captain.stage;
  bool _summaryOpen = false;

  @override
  void initState() {
    super.initState();
    captain.addListener(_onState);
  }

  @override
  void dispose() {
    captain.removeListener(_onState);
    _debounce?.cancel();
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    final st = captain.stage;
    if (st != _last) {
      switch (st) {
        case CaptainStage.request:
          HapticFeedback.heavyImpact();
        case CaptainStage.arrived || CaptainStage.collect:
          HapticFeedback.mediumImpact();
        default:
          break;
      }
      if (!st.busy || st == CaptainStage.arrived) _navigate = false;
      _last = st;
    }
    setState(() {});
    final s = captain.session;
    if (st == CaptainStage.summary && s != null && !_summaryOpen) {
      _summaryOpen = true;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SummaryScreen(session: s))).whenComplete(() => _summaryOpen = false);
    }
  }

  void _onPanelSize(Size size) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      final h = _panelH;
      if (mounted && (h == null || (h - size.height).abs() > 4)) setState(() => _panelH = size.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mq = MediaQuery.of(context);
    final chrome = ShellChrome.of(context);
    final barVisible = chrome?.barVisible ?? false;
    final sysBottom = chrome?.systemBottom ?? mq.padding.bottom;
    final barSpace = barVisible ? kNavBarHeight + sysBottom : 0.0;
    final panelH = _panelH ?? mq.size.height * .32;
    final stage = captain.stage;
    final navStage = stage == CaptainStage.toPickup || stage == CaptainStage.onTrip;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: CaptainMap(
            navigate: _navigate,
            padding: EdgeInsets.only(top: mq.padding.top + (navStage ? 96 : 76), bottom: panelH + barSpace - 24),
          ),
        ),
        // top: today's stats, or the turn-by-turn banner on a trip
        Positioned(
          left: 16,
          right: 16,
          top: mq.padding.top + 10,
          child: Column(children: [
            AnimatedSwitcher(
              duration: kMedium,
              switchInCurve: kEase,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, -.15), end: Offset.zero).animate(a), child: child),
              ),
              layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
              child: switch (stage) {
                CaptainStage.toPickup || CaptainStage.onTrip => _NavBanner(key: const ValueKey('nav')),
                CaptainStage.arrived || CaptainStage.collect || CaptainStage.summary => const SizedBox(key: ValueKey('none'), width: double.infinity),
                _ => const _StatsBar(key: ValueKey('stats')),
              },
            ),
            const OfflineBanner(margin: EdgeInsets.only(top: 8)),
          ]),
        ),
        AnimatedPositioned(
          duration: kMedium,
          curve: kEase,
          left: 0,
          right: 0,
          bottom: barSpace,
          child: _SizeReporter(
            onSize: _onPanelSize,
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                boxShadow: shadow(c, strength: 1.2),
              ),
              child: AnimatedPadding(
                duration: kMedium,
                curve: kEase,
                padding: EdgeInsets.only(bottom: barVisible || mq.viewInsets.bottom > 0 ? 0 : sysBottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: mq.size.height * .72 - mq.viewInsets.bottom * .5),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 340),
                    curve: kEase,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: kMedium,
                      switchInCurve: kEase,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: child),
                      ),
                      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                      child: _panel(stage),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _panel(CaptainStage stage) {
    final s = captain.session;
    if (s == null) {
      if (captain.missedAt != null) return const MissedPanel(key: ValueKey('missed'));
      return IdlePanel(key: ValueKey(stage));
    }
    return switch (stage) {
      CaptainStage.request => RequestPanel(key: ValueKey('req${s.id}'), s: s),
      CaptainStage.toPickup => ToPickupPanel(
          key: ValueKey('pick${s.id}'),
          s: s,
          navigating: _navigate,
          onNavigate: () => setState(() => _navigate = !_navigate),
        ),
      CaptainStage.arrived => ArrivedPanel(key: ValueKey('arr${s.id}'), s: s),
      CaptainStage.onTrip => OnTripPanel(
          key: ValueKey('trip${s.id}'),
          s: s,
          navigating: _navigate,
          onNavigate: () => setState(() => _navigate = !_navigate),
        ),
      _ => CollectPanel(key: ValueKey('collect${s.id}'), s: s),
    };
  }
}

// ───────────────────────── top bar ─────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget stat(String label, Widget value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption.copyWith(fontSize: 11)),
            const SizedBox(height: 1),
            value,
          ]),
        );
    final divider = Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 10), color: c.border);
    return Row(children: [
      Expanded(
        child: Tappable(
          pressedScale: .985,
          onTap: () => Shell.of(context)?.select(1),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), boxShadow: shadow(c)),
            child: ListenableBuilder(
              listenable: captain,
              builder: (context, _) => Row(children: [
                stat('Today', CountUp(captain.todayEarnings, format: inr, style: context.t.subtitle)),
                divider,
                stat('Rides', Text('${captain.todayRides}', style: context.t.subtitle)),
                divider,
                stat('Online', _OnlineTime(style: context.t.subtitle)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      CircleButton(Symbols.notifications, elevated: true, size: 48, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
    ]);
  }
}

/// Time online today; refreshes itself while online.
class _OnlineTime extends StatefulWidget {
  final TextStyle style;
  const _OnlineTime({required this.style});
  @override
  State<_OnlineTime> createState() => _OnlineTimeState();
}

class _OnlineTimeState extends State<_OnlineTime> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && captain.online) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(formatDuration(captain.onlineToday), maxLines: 1, style: widget.style);
}

IconData turnIcon(Turn t) => switch (t) {
      Turn.straight => Symbols.straight,
      Turn.slightLeft => Symbols.turn_slight_left,
      Turn.left => Symbols.turn_left,
      Turn.sharpLeft => Symbols.turn_sharp_left,
      Turn.slightRight => Symbols.turn_slight_right,
      Turn.right => Symbols.turn_right,
      Turn.sharpRight => Symbols.turn_sharp_right,
      Turn.uTurn => Symbols.u_turn_left,
      Turn.arrive => Symbols.sports_score,
    };

/// Turn-by-turn instruction for the current leg.
class _NavBanner extends StatelessWidget {
  const _NavBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = captain.session;
    if (s == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final step = s.navStep;
        final text = step?.text ?? 'Finding the best route…';
        final dist = step == null
            ? ''
            : step.turn == Turn.straight || step.turn == Turn.arrive
                ? (step.metersAway < 1000 ? '${(step.metersAway / 10).round() * 10} m' : '${(step.metersAway / 1000).toStringAsFixed(1)} km')
                : step.distance;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: BoxDecoration(
            color: c.dark ? c.surfaceAlt : const Color(0xFF15161A),
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: shadow(c),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(Radii.md)),
              child: AnimatedSwitcher(
                duration: kMedium,
                child: Icon(turnIcon(step?.turn ?? Turn.straight), key: ValueKey(step?.turn), color: Colors.white, size: 32, weight: 500),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(dist, style: context.t.title.copyWith(color: Colors.white)),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: kMedium,
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                  child: Text(text, key: ValueKey(text), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.t.body.copyWith(color: Colors.white.withValues(alpha: .78))),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ───────────────────────── idle panels ─────────────────────────

/// Offline: today's earnings and "go online". Online: what's happening and
/// "go offline".
class IdlePanel extends StatelessWidget {
  const IdlePanel({super.key});

  void _goOnline(BuildContext context) {
    if (!captain.goOnline()) {
      showToast(context, 'No internet. Connect to go online.', icon: Symbols.wifi_off);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final online = captain.online;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(child: SheetHandle()),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: online ? Brand.success : c.text3, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(online ? 'You\'re online' : 'You\'re offline', style: context.t.title)),
          VehicleImage(captain.vehicle, width: 54),
        ]),
        const SizedBox(height: 2),
        Text(
          online ? 'Looking for ride requests near you' : 'Go online to start getting ride requests.',
          style: context.t.secondary,
        ),
        const SizedBox(height: 14),
        if (online) ...[
          const ProgressLine(),
          const SizedBox(height: 14),
          _IncentiveStrip(),
        ] else
          _TodayCard(),
        const SizedBox(height: 14),
        online
            ? SlideToConfirm(label: 'Swipe to go offline', kind: ButtonKind.secondary, icon: Symbols.power_settings_new, onConfirm: captain.goOffline)
            : SlideToConfirm(label: 'Swipe to go online', icon: Symbols.power_settings_new, onConfirm: () => _goOnline(context)),
      ]),
    );
  }
}

class _TodayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = captain.report(Period.today);
    return AppCard(
      color: c.surfaceAlt,
      outlined: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () => Shell.of(context)?.select(1),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Today\'s earnings', style: context.t.caption),
            const SizedBox(height: 2),
            CountUp(r.total, format: inr, style: context.t.headline),
            const SizedBox(height: 2),
            Text('${r.rides} rides · ${formatDuration(r.onlineTime)} online', style: context.t.caption),
          ]),
        ),
        Icon(Symbols.chevron_right, color: c.text3),
      ]),
    );
  }
}

class _IncentiveStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final i = captain.incentives.first;
    return Row(children: [
      IconTile(Symbols.bolt, size: 36, color: c.selectedBg, iconColor: c.accentText),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            i.complete ? 'Daily bonus unlocked · ${rupees(i.reward)}' : '${i.title} → ${rupees(i.reward)} bonus',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.t.label,
          ),
          const SizedBox(height: 6),
          ProgressLine(value: i.fraction, color: i.complete ? Brand.success : Brand.primary),
        ]),
      ),
      const SizedBox(width: 12),
      Text('${i.done.clamp(0, i.target)}/${i.target}', style: context.t.label),
    ]);
  }
}

/// The request card collapses into this when the timer runs out.
class MissedPanel extends StatelessWidget {
  const MissedPanel({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 6),
          Row(children: [
            IconTile(Symbols.timer_off, size: 44, color: Brand.danger.withValues(alpha: context.c.dark ? .18 : .1), iconColor: Brand.danger),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Missed request', style: context.t.subtitle),
                Text('It expired after 15 seconds. Stay online for the next one.', style: context.t.caption),
              ]),
            ),
          ]),
        ]),
      );
}

/// Reports its child's size after layout (used to frame the map above the panel).
class _SizeReporter extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSize;
  const _SizeReporter({required this.onSize, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onSize);
  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  ValueChanged<Size> onSize;
  Size? _last;
  _RenderSizeReporter(this.onSize);

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final s = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(s));
    }
  }
}
