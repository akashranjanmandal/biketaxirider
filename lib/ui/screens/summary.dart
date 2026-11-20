import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/models.dart';
import '../captain_kit.dart';
import '../kit.dart';
import 'registration.dart';
import 'trip_panels.dart';

/// After payment: what the captain earned, and a rating for the rider.
class SummaryScreen extends StatefulWidget {
  final TripSession session;
  const SummaryScreen({super.key, required this.session});
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int _stars = 0;
  final _tags = <String>{};
  bool _closing = false;

  static const _good = ['Polite', 'On time at pickup', 'Clear directions', 'Respectful', 'Easy to find'];
  static const _bad = ['Late to pickup', 'Wrong pickup point', 'Rude behaviour', 'Asked for extra stops', 'Damaged vehicle'];

  TripSession get s => widget.session;

  void _done() {
    if (_closing) return;
    _closing = true;
    captain.finishSummary(stars: _stars);
    Navigator.of(context).pop();
    if (_stars > 0) showToast(context, 'Thanks for rating ${s.rider.firstName}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rec = s.record;
    final earnings = rec?.earnings ?? s.total;
    final fee = rec?.platformFee ?? 0;
    final tags = _stars >= 4 ? _good : _bad;
    final left = captain.zeroCommissionLeft;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: kSlow,
                      curve: kEase,
                      builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .85 + .15 * v, child: child)),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: Brand.success.withValues(alpha: .12), shape: BoxShape.circle),
                        child: const Icon(Symbols.check, color: Brand.success, size: 34, weight: 600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: Text('Trip complete', style: context.t.headline)),
                  const SizedBox(height: 4),
                  Center(child: Text('${s.drop.name} · ${formatTime(s.endedAt ?? clock.now())}', style: context.t.secondary)),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('You earned', style: context.t.secondary),
                            CountUp(earnings, format: inr, duration: const Duration(milliseconds: 900), style: context.t.hero),
                          ]),
                        ),
                        VehicleImage(s.service, width: 76),
                      ]),
                      const SizedBox(height: 14),
                      const Hairline(),
                      const SizedBox(height: 10),
                      KvRow('Ride fare · ${km(rec?.km ?? s.tripKm)}', inr(s.fare)),
                      if (s.waitingCharge > 0) KvRow('Waiting charge', inr(s.waitingCharge)),
                      if (s.tip > 0) KvRow('Tip from ${s.rider.firstName}', inr(s.tip), color: Brand.success),
                      KvRow('Platform fee', fee == 0 ? '₹0' : '−${inr(fee)}'),
                      if (fee == 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: StatusPill(left > 0 ? 'Zero commission · $left rides left' : 'Zero commission ride', Brand.success, icon: Symbols.savings),
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Hairline(),
                      const SizedBox(height: 6),
                      KvRow('Your earnings', inr(earnings), strong: true),
                      KvRow(
                        s.pay == Pay.cash ? 'Collected in cash' : 'Paid via ${s.pay.label}',
                        s.pay == Pay.cash ? inr(s.total) : 'Added to balance',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(children: [
                      Row(children: [
                        Avatar(s.rider.initials, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('How was ${s.rider.firstName}?', style: context.t.bodyStrong),
                            Text('Ratings are anonymous', style: context.t.caption),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 1; i <= 5; i++)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if ((_stars >= 4) != (i >= 4)) _tags.clear();
                                _stars = i;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: AnimatedScale(
                                scale: i <= _stars ? 1.08 : 1,
                                duration: kMedium,
                                curve: kEase,
                                child: Icon(Symbols.star, size: 38, fill: i <= _stars ? 1 : 0, weight: 400, color: i <= _stars ? Brand.primary : c.text3),
                              ),
                            ),
                          ),
                      ]),
                      AnimatedSize(
                        duration: kMedium,
                        curve: kEase,
                        child: _stars == 0
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(children: [
                                  Text(_stars >= 4 ? 'What went well?' : 'What went wrong?', style: context.t.label.copyWith(color: c.text2)),
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                                    for (final t in tags)
                                      ChoiceChipX(
                                        label: t,
                                        selected: _tags.contains(t),
                                        onTap: () => setState(() => _tags.contains(t) ? _tags.remove(t) : _tags.add(t)),
                                      ),
                                  ]),
                                ]),
                              ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppButton(_stars == 0 ? 'Done' : 'Submit rating', onTap: _done),
            ),
          ]),
        ),
      ),
    );
  }
}
