import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/models.dart';
import '../captain_kit.dart';
import '../forms.dart';
import '../kit.dart';
import 'contact.dart';
import 'more.dart';
import 'onboarding.dart';

IconData payIcon(Pay p) => switch (p) {
      Pay.upi => Symbols.qr_code_2,
      Pay.cash => Symbols.payments,
      Pay.wallet => Symbols.account_balance_wallet,
    };

String km(double v) => v < 10 ? '${v.toStringAsFixed(1)} km' : '${v.round()} km';

/// Rider avatar, name and rating (used on every trip panel).
class RiderRow extends StatelessWidget {
  final Rider rider;
  final Widget? trailing;
  final double size;
  const RiderRow({super.key, required this.rider, this.trailing, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(children: [
      Avatar(rider.initials, size: size),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rider.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.bodyStrong),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Symbols.star, size: 14, fill: 1, color: Brand.primary),
            const SizedBox(width: 3),
            Flexible(
              child: Text('${rider.rating} · ${rider.rides} rides', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption.copyWith(color: c.text2)),
            ),
          ]),
        ]),
      ),
      ?trailing,
    ]);
  }
}

class PayPill extends StatelessWidget {
  final Pay pay;
  const PayPill(this.pay, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(payIcon(pay), size: 16, color: c.text, weight: 500),
        const SizedBox(width: 5),
        Text(pay.label, style: context.t.label),
      ]),
    );
  }
}

/// Square action with icon + label (rider app's ride actions).
class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? tone;
  const ActionTile(this.icon, this.label, this.onTap, {super.key, this.selected = false, this.tone});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = selected ? Brand.onPrimary : (tone ?? c.text);
    return Tappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kMedium,
        curve: kEase,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: selected ? Brand.primary : c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
        child: Column(children: [
          Icon(icon, size: 22, color: fg, weight: 500, fill: selected ? 1 : 0),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

Widget _scrollable(Widget child) => SingleChildScrollView(physics: const ClampingScrollPhysics(), child: child);

// ───────────────────────── request ─────────────────────────

class RequestPanel extends StatelessWidget {
  final TripSession s;
  const RequestPanel({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final zone = s.zone;
    return _scrollable(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(child: SheetHandle()),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New ${s.service.label.toLowerCase()} request', style: context.t.title),
              const SizedBox(height: 2),
              Text('${km(s.pickupKm)} away · ${s.pickupMinutes} min to pickup', style: context.t.secondary),
            ]),
          ),
          const SizedBox(width: 12),
          CountdownRing(startedAt: s.requestAt ?? clock.now(), total: TripSession.requestSecs),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(inr(s.fare), style: context.t.hero),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                PayPill(s.pay),
                if (zone != null) StatusPill('${zone.multiplier}× demand', Brand.primary, icon: Symbols.trending_up),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        RouteStops(
          from: s.pickup.name,
          fromSub: '${s.pickup.address} · ${km(s.pickupKm)} away',
          to: s.drop.name,
          toSub: '${km(s.tripKm)} trip · about ${s.tripMinutes} min',
        ),
        const SizedBox(height: 14),
        RiderRow(rider: s.rider, trailing: VehicleImage(s.service, width: 60)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: AppButton('Decline', kind: ButtonKind.secondary, onTap: captain.decline)),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: AppButton('Accept', icon: Symbols.check, onTap: captain.accept)),
        ]),
      ]),
    ));
  }
}

// ───────────────────────── going to pickup ─────────────────────────

class ToPickupPanel extends StatelessWidget {
  final TripSession s;
  final bool navigating;
  final VoidCallback onNavigate;
  const ToPickupPanel({super.key, required this.s, required this.navigating, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return _scrollable(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: SheetHandle()),
          const SizedBox(height: 4),
          Text('Picking up ${s.rider.firstName}', style: context.t.title),
          const SizedBox(height: 2),
          Text('${s.pickup.name} · ${km(s.kmLeft)} · ${s.minutesLeft} min', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.secondary),
          const SizedBox(height: 14),
          ProgressLine(value: s.approachProgress),
          const SizedBox(height: 16),
          RiderRow(rider: s.rider, trailing: PayPill(s.pay)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ActionTile(Symbols.call, 'Call', () => showCallSheet(context, s.rider))),
            const SizedBox(width: 8),
            Expanded(child: ActionTile(Symbols.chat_bubble, 'Message', () => showChatSheet(context, s.rider, place: s.pickup.name))),
            const SizedBox(width: 8),
            Expanded(child: ActionTile(Symbols.navigation, 'Navigate', onNavigate, selected: navigating)),
            const SizedBox(width: 8),
            Expanded(child: ActionTile(Symbols.block, 'Cancel', () => confirmCancel(context, s), tone: Brand.danger)),
          ]),
        ]),
      ),
    ));
  }
}

void confirmCancel(BuildContext context, TripSession s) {
  const reasons = ['Rider asked me to cancel', 'Rider isn\'t reachable', 'Pickup is too far', 'Vehicle problem', 'Other'];
  var picked = -1;
  showAppSheet(context, builder: (ctx) {
    return StatefulBuilder(builder: (ctx, set) {
      final c = ctx.c;
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), child: Text('Why are you cancelling?', style: ctx.t.title)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text('${s.rider.firstName} is waiting. Frequent cancellations lower your rating.', style: ctx.t.secondary),
          ),
          for (var i = 0; i < reasons.length; i++)
            RowTap(
              onTap: () => set(() => picked = i),
              child: Row(children: [
                Icon(picked == i ? Symbols.radio_button_checked : Symbols.radio_button_unchecked, color: picked == i ? c.text : c.text3, fill: picked == i ? 1 : 0),
                const SizedBox(width: 12),
                Expanded(child: Text(reasons[i], style: ctx.t.body)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(children: [
              Expanded(child: AppButton('Keep trip', kind: ButtonKind.secondary, onTap: () => Navigator.pop(ctx))),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  'Cancel trip',
                  kind: ButtonKind.danger,
                  onTap: picked >= 0
                      ? () {
                          Navigator.pop(ctx);
                          captain.cancelTrip(reasons[picked]);
                          showToast(context, 'Trip cancelled', icon: Symbols.cancel);
                        }
                      : null,
                ),
              ),
            ]),
          ),
        ]),
      );
    });
  });
}

// ───────────────────────── arrived: waiting + PIN ─────────────────────────

class ArrivedPanel extends StatefulWidget {
  final TripSession s;
  const ArrivedPanel({super.key, required this.s});
  @override
  State<ArrivedPanel> createState() => _ArrivedPanelState();
}

class _ArrivedPanelState extends State<ArrivedPanel> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  CodeState _state = CodeState.typing;
  int _shake = 0;

  TripSession get s => widget.s;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (_state == CodeState.wrong) _state = CodeState.typing;
    setState(() {});
    if (v.length == 4) _verify();
  }

  Future<void> _verify() async {
    setState(() => _state = CodeState.verifying);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    if (_ctrl.text == s.pin) {
      HapticFeedback.mediumImpact();
      setState(() => _state = CodeState.ok);
      _focus.unfocus();
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      captain.verifyPin(_ctrl.text);
    } else {
      setState(() {
        _state = CodeState.wrong;
        _shake++;
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _ctrl.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _scrollable(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(child: SheetHandle()),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waiting for ${s.rider.firstName}', style: context.t.title),
              const SizedBox(height: 2),
              Text('At ${s.pickup.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.secondary),
            ]),
          ),
          const SizedBox(width: 12),
          ListenableBuilder(listenable: s, builder: (context, _) => _WaitChip(s: s)),
        ]),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            final free = s.waitingSecs <= kFreeWaitSecs;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProgressLine(value: (s.waitingSecs / kFreeWaitSecs).clamp(0.0, 1.0), color: free ? Brand.success : Brand.primary),
              const SizedBox(height: 6),
              Text(
                free ? 'Free waiting for 3 min, then ₹1 a minute' : 'Waiting charge ${rupees(s.waitingCharge)} added to the fare',
                style: context.t.caption,
              ),
            ]);
          },
        ),
        const SizedBox(height: 16),
        Text('Enter rider PIN', style: context.t.subtitle),
        const SizedBox(height: 2),
        Text('Ask ${s.rider.firstName} for the 4-digit PIN to start the trip.', style: context.t.caption),
        const SizedBox(height: 12),
        CodeInput(controller: _ctrl, focusNode: _focus, state: _state, shakeKey: _shake, onChanged: _onChanged, autofocus: false, boxHeight: 58),
        AnimatedSize(
          duration: kMedium,
          curve: kEase,
          child: _state == CodeState.wrong
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    const Icon(Symbols.error, size: 18, color: Brand.danger, fill: 1),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Wrong PIN. Check with ${s.rider.firstName}.', style: context.t.secondary.copyWith(color: Brand.danger))),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 12),
        DemoHint(text: 'Demo build: the rider PIN is ${s.pin}', onFill: () {
          _ctrl.text = s.pin;
          _onChanged(s.pin);
        }),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ActionTile(Symbols.call, 'Call', () => showCallSheet(context, s.rider))),
          const SizedBox(width: 8),
          Expanded(child: ActionTile(Symbols.chat_bubble, 'Message', () => showChatSheet(context, s.rider, place: s.pickup.name))),
          const SizedBox(width: 8),
          Expanded(child: ActionTile(Symbols.block, 'Cancel', () => confirmCancel(context, s), tone: Brand.danger)),
        ]),
      ]),
    ));
  }
}

class _WaitChip extends StatelessWidget {
  final TripSession s;
  const _WaitChip({required this.s});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final secs = s.waitingSecs;
    final free = secs <= kFreeWaitSecs;
    final mm = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(color: free ? c.surfaceAlt : c.selectedBg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.timer, size: 16, color: free ? c.text : c.accentText, weight: 500),
        const SizedBox(width: 5),
        Text(mm, style: context.t.label.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

// ───────────────────────── on trip ─────────────────────────

class OnTripPanel extends StatelessWidget {
  final TripSession s;
  final bool navigating;
  final VoidCallback onNavigate;
  const OnTripPanel({super.key, required this.s, required this.navigating, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _scrollable(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final eta = clock.now().add(Duration(minutes: s.minutesLeft));
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dropping ${s.rider.firstName}', style: context.t.title),
                  const SizedBox(height: 2),
                  Text(s.drop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.secondary),
                ]),
              ),
              const SizedBox(width: 10),
              Tappable(
                onTap: () => showSosSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Brand.danger.withValues(alpha: c.dark ? .16 : .1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Symbols.sos, size: 18, color: Brand.danger, weight: 600),
                    const SizedBox(width: 4),
                    Text('SOS', style: context.t.label.copyWith(color: Brand.danger)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Stat(s.reachedDrop ? 'Arrived' : '${s.minutesLeft} min', 'ETA ${formatTime(eta)}')),
              Expanded(child: _Stat(km(s.kmLeft), 'left')),
              Expanded(child: _Stat(inr(s.total), s.pay.label)),
            ]),
            const SizedBox(height: 12),
            ProgressLine(value: s.tripProgress),
            AnimatedSize(
              duration: kMedium,
              curve: kEase,
              child: s.reachedDrop
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        const Icon(Symbols.check_circle, size: 18, color: Brand.success, fill: 1),
                        const SizedBox(width: 8),
                        Expanded(child: Text('You\'ve reached ${s.drop.name}. End the trip to collect payment.', style: context.t.secondary)),
                      ]),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: SlideToConfirm(label: 'Swipe to end trip', icon: Symbols.sports_score, onConfirm: captain.endTrip)),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                height: 60,
                child: Tappable(
                  onTap: onNavigate,
                  child: AnimatedContainer(
                    duration: kMedium,
                    decoration: BoxDecoration(color: navigating ? Brand.primary : c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(Symbols.navigation, color: navigating ? Brand.onPrimary : c.text, fill: navigating ? 1 : 0, weight: 500),
                  ),
                ),
              ),
            ]),
          ]);
        },
      ),
    ));
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.subtitle),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
      ]);
}

// ───────────────────────── collect payment ─────────────────────────

class CollectPanel extends StatelessWidget {
  final TripSession s;
  const CollectPanel({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final cash = s.pay == Pay.cash;
    return _scrollable(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(child: SheetHandle()),
        const SizedBox(height: 4),
        if (cash) ...[
          Text('COLLECT CASH', style: context.t.overline),
          const SizedBox(height: 6),
          CountUp(s.total, format: inr, style: context.t.hero),
          const SizedBox(height: 4),
          Text('from ${s.rider.name}', style: context.t.secondary),
        ] else
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: Brand.success.withValues(alpha: .12), shape: BoxShape.circle),
              child: const Icon(Symbols.check, color: Brand.success, size: 28, weight: 600),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Paid online', style: context.t.title),
                Text('${inr(s.total)} via ${s.pay.label}', style: context.t.secondary),
              ]),
            ),
          ]),
        const SizedBox(height: 14),
        const Hairline(),
        const SizedBox(height: 8),
        KvRow('Ride fare · ${km(s.tripKm * s.tripProgress)}', inr(s.fare)),
        if (s.waitingCharge > 0) KvRow('Waiting charge', inr(s.waitingCharge)),
        KvRow(cash ? 'Collect from rider' : 'Total paid', inr(s.total), strong: true),
        const SizedBox(height: 16),
        AppButton(cash ? 'Cash collected' : 'Continue', icon: cash ? Symbols.payments : null, onTap: captain.paymentReceived),
      ]),
    ));
  }
}
