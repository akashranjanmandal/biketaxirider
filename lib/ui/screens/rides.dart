import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/models.dart';
import '../captain_kit.dart';
import '../kit.dart';
import 'more.dart';
import 'shell.dart';
import 'trip_panels.dart';

class RidesTab extends StatefulWidget {
  const RidesTab({super.key});
  @override
  State<RidesTab> createState() => _RidesTabState();
}

class _RidesTabState extends State<RidesTab> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: captain,
          builder: (context, _) {
            final list = captain.trips.where((r) => _filter == 0 || (_filter == 1 ? r.completed : !r.completed)).toList();
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text('Your rides', style: context.t.display)),
              ),
              const SliverToBoxAdapter(child: OfflineBanner(margin: EdgeInsets.fromLTRB(20, 0, 20, 8))),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Segmented(items: const ['All', 'Completed', 'Cancelled'], index: _filter, onChanged: (i) => setState(() => _filter = i)),
                ),
              ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyState(
                      icon: Symbols.receipt_long,
                      title: _filter == 2 ? 'No cancelled rides' : 'No rides here yet',
                      sub: _filter == 2 ? 'Nice. Keep it that way.' : 'Rides you complete will show up here.',
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Hairline(indent: 20),
                  itemBuilder: (context, i) => _RideRow(ride: list[i]),
                ),
              SliverToBoxAdapter(child: SizedBox(height: tabBottomPadding(context))),
            ]);
          },
        ),
      ),
    );
  }
}

class _RideRow extends StatelessWidget {
  final TripRecord ride;
  const _RideRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return RowTap(
      onTap: () => showTripDetails(context, ride),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        VehicleImage(ride.service, width: 52, plate: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ride.from} → ${ride.to}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.bodyStrong),
            const SizedBox(height: 2),
            Text('${formatWhen(ride.when)} · ${ride.rider.firstName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            ride.completed ? inr(ride.earnings) : inr(ride.fare),
            style: context.t.bodyStrong.copyWith(color: ride.completed ? c.text : c.text3, decoration: ride.completed ? null : TextDecoration.lineThrough),
          ),
          const SizedBox(height: 4),
          if (!ride.completed)
            const StatusPill('Cancelled', Brand.danger)
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(payIcon(ride.pay), size: 14, color: c.text3),
              const SizedBox(width: 3),
              Text(ride.pay.label, style: context.t.caption.copyWith(fontSize: 11.5, color: c.text3)),
            ]),
        ]),
      ]),
    );
  }
}

void showTripDetails(BuildContext context, TripRecord r) {
  showAppSheet(context, builder: (ctx) {
    final stars = r.riderStars;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.completed ? 'You earned ${inr(r.earnings)}' : 'Trip cancelled', style: ctx.t.title),
              Text('${formatWhen(r.when)} · ${r.service.label}', style: ctx.t.secondary),
            ]),
          ),
          VehicleImage(r.service, width: 72),
        ]),
        const SizedBox(height: 16),
        RouteStops(from: r.from, to: r.to),
        const SizedBox(height: 14),
        RiderRow(
          rider: r.rider,
          size: 40,
          trailing: stars == null
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('You rated ', style: ctx.t.caption),
                  const Icon(Symbols.star, size: 14, fill: 1, color: Brand.primary),
                  Text(' $stars', style: ctx.t.label),
                ]),
        ),
        const SizedBox(height: 10),
        const Hairline(),
        const SizedBox(height: 8),
        if (r.completed) ...[
          KvRow('Ride fare · ${km(r.km)}', inr(r.fare - r.waiting)),
          if (r.waiting > 0) KvRow('Waiting charge', inr(r.waiting)),
          if (r.tip > 0) KvRow('Tip', inr(r.tip)),
          KvRow('Platform fee', r.platformFee == 0 ? '₹0' : '−${inr(r.platformFee)}'),
          KvRow('Your earnings', inr(r.earnings), strong: true),
          KvRow('Payment', r.pay == Pay.cash ? 'Cash collected' : 'Paid via ${r.pay.label}'),
        ] else ...[
          KvRow('Fare', '${inr(r.fare)} (not charged)'),
          KvRow('Reason', r.cancelReason ?? 'Cancelled'),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: AppButton('Get help', kind: ButtonKind.secondary, icon: Symbols.support_agent, onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen()));
            }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton('Report issue', kind: ButtonKind.ghost, onTap: () {
              Navigator.pop(ctx);
              showToast(context, 'Thanks. Our team will look into this trip.', icon: Symbols.flag);
            }),
          ),
        ]),
      ]),
    );
  });
}
