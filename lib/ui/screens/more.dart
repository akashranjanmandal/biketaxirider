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

// ───────────────────────── Safety ─────────────────────────

/// SOS during a trip: hold to alert, plus quick safety actions.
void showSosSheet(BuildContext context) {
  showAppSheet(context, builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Emergency', style: ctx.t.title),
          const SizedBox(height: 4),
          Text('Press and hold to alert your emergency contacts and the Aamar safety team with your live location.', textAlign: TextAlign.center, style: ctx.t.secondary),
          const SizedBox(height: 20),
          const SosButton(),
          const SizedBox(height: 20),
          ListRow(icon: Symbols.local_police, title: 'Call police (112)', onTap: () => showToast(ctx, 'Demo build: calls are disabled', icon: Symbols.call)),
          ListRow(icon: Symbols.support_agent, title: 'Aamar safety team', subtitle: 'Available 24×7', onTap: () => showToast(ctx, 'Connecting you to our safety team', icon: Symbols.support_agent)),
          ListRow(icon: Symbols.share_location, title: 'Share live location', subtitle: 'With your emergency contacts', onTap: () => showToast(ctx, 'Live location shared', icon: Symbols.share_location)),
        ]),
      ));
}

/// Press-and-hold SOS with a progress ring.
class SosButton extends StatefulWidget {
  const SosButton({super.key});
  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _sent = true);
      }
    });
  bool _sent = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTapDown: (_) {
        if (!_sent) _c.forward();
      },
      onTapUp: (_) {
        if (!_sent) _c.reverse();
      },
      onTapCancel: () {
        if (!_sent) _c.reverse();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => SizedBox(
          width: 132,
          height: 132,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: _sent ? 1 : _c.value,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                color: _sent ? Brand.success : Brand.danger,
                backgroundColor: c.surfaceAlt,
              ),
            ),
            Transform.scale(
              scale: 1 - _c.value * .05,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _sent ? Brand.success : Brand.danger),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_sent ? Symbols.check : Symbols.sos, color: Colors.white, size: 34, weight: 600),
                  const SizedBox(height: 2),
                  Text(_sent ? 'Alert sent' : 'Hold', style: context.t.label.copyWith(color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});
  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  final _on = <String, bool>{'share': true, 'night': true, 'record': false};

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget toggle(String key, IconData icon, String title, String sub) => ListRow(
          icon: icon,
          title: title,
          subtitle: sub,
          chevron: false,
          trailing: Switch.adaptive(
            value: _on[key] ?? false,
            activeTrackColor: Brand.primary,
            activeThumbColor: Brand.onPrimary,
            onChanged: (v) => setState(() => _on[key] = v),
          ),
          onTap: () => setState(() => _on[key] = !(_on[key] ?? false)),
        );
    return PageScaffold(
      title: 'Safety',
      body: ListView(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24), children: [
        const SizedBox(height: 8),
        const Center(child: SosButton()),
        const SizedBox(height: 12),
        Center(child: Text('Press and hold in an emergency', style: context.t.secondary)),
        const SectionHeader('Emergency contacts'),
        ListRow(leading: const Avatar('M', size: 40), title: 'Maa', subtitle: '+91 98300 •••10', chevron: false, trailing: const Icon(Symbols.verified, color: Brand.success, fill: 1, size: 20)),
        ListRow(leading: const Avatar('S', size: 40), title: 'Suman (brother)', subtitle: '+91 90510 •••81', chevron: false, trailing: const Icon(Symbols.verified, color: Brand.success, fill: 1, size: 20)),
        ListRow(leading: IconTile(Symbols.person_add, color: c.surfaceAlt), title: 'Add a contact', onTap: () => showToast(context, 'Contact picker opens here', icon: Symbols.person_add)),
        const SectionHeader('On every trip'),
        toggle('share', Symbols.share_location, 'Share live trips', 'Your contacts can follow each trip'),
        toggle('night', Symbols.dark_mode, 'Night-time check-ins', 'We check in on trips after 10 pm'),
        toggle('record', Symbols.mic, 'Audio recording', 'Record trips on this phone'),
      ]),
    );
  }
}

// ───────────────────────── Notifications ─────────────────────────

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(NoticeKind k) => switch (k) {
        NoticeKind.incentive => Symbols.bolt,
        NoticeKind.document => Symbols.description,
        NoticeKind.payout => Symbols.account_balance,
        NoticeKind.info => Symbols.info,
      };

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Notifications',
        body: ListenableBuilder(
          listenable: captain,
          builder: (context, _) {
            final items = captain.notices;
            if (items.isEmpty) {
              return const Center(child: EmptyState(icon: Symbols.notifications, title: 'You\'re all caught up', sub: 'Bonus alerts, payouts and document reminders show up here.'));
            }
            return ListView.separated(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Hairline(indent: 74),
              itemBuilder: (context, i) {
                final n = items[i];
                final c = context.c;
                final tone = switch (n.kind) {
                  NoticeKind.incentive => c.selectedBg,
                  NoticeKind.payout => Brand.success.withValues(alpha: c.dark ? .18 : .1),
                  _ => null,
                };
                return RowTap(
                  onTap: () {},
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconTile(_icon(n.kind), color: tone, iconColor: n.kind == NoticeKind.payout ? Brand.success : (n.kind == NoticeKind.incentive ? c.accentText : null)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Text(n.title, style: context.t.bodyStrong)),
                          const SizedBox(width: 8),
                          Text(_ago(n.when), style: context.t.caption.copyWith(color: c.text3)),
                        ]),
                        const SizedBox(height: 3),
                        Text(n.body, style: context.t.secondary),
                      ]),
                    ),
                  ]),
                );
              },
            );
          },
        ),
      );

  String _ago(DateTime t) {
    final d = clock.now().difference(t);
    if (d.inMinutes < 1) return 'Now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays == 1) return 'Yesterday';
    return formatDate(t);
  }
}

// ───────────────────────── Documents ─────────────────────────

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Vehicle & documents',
        body: ListenableBuilder(
          listenable: captain,
          builder: (context, _) => ListView(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AppCard(
                child: Row(children: [
                  VehicleImage(captain.vehicle, width: 72, plate: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(captain.vehicle.label, style: context.t.subtitle),
                      Text(captain.vehicleModel, style: context.t.caption),
                      const SizedBox(height: 6),
                      PlateTag(captain.plateOrDefault),
                    ]),
                  ),
                ]),
              ),
            ),
            const SectionHeader('Documents'),
            for (final d in DocKind.values)
              DocRow(
                kind: d,
                expiring: captain.expiringSoon(d),
                expiry: switch (captain.expiryOf(d)) {
                  null => captain.docs[d] == DocStatus.verified ? 'Verified · no expiry' : d.hint,
                  final e => '${captain.expiringSoon(d) ? 'Expires' : 'Valid till'} ${formatDate(e, year: true)}',
                },
                onTap: () => showCaptureSheet(context, d),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text('Tap a document to upload a new copy. We remind you 30 days before anything expires.', style: context.t.caption),
            ),
          ]),
        ),
      );
}

// ───────────────────────── Bank ─────────────────────────

class BankScreen extends StatelessWidget {
  const BankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageScaffold(
      title: 'Bank details',
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconTile(Symbols.account_balance, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(captain.bankName, style: context.t.subtitle),
                  Text('Savings account ${captain.bankMasked}', style: context.t.caption),
                ]),
              ),
              const StatusPill('Verified', Brand.success, icon: Symbols.check_circle),
            ]),
            const SizedBox(height: 14),
            const Hairline(),
            const SizedBox(height: 8),
            KvRow('Account holder', captain.holder.isEmpty ? captain.name : captain.holder),
            KvRow('Account number', captain.bankMasked),
            KvRow('IFSC', captain.ifsc),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Symbols.schedule, size: 16, color: c.text3),
          const SizedBox(width: 6),
          Expanded(child: Text('Online earnings are paid here every morning at 6 am.', style: context.t.caption)),
        ]),
        const SizedBox(height: 20),
        AppButton('Change bank account', kind: ButtonKind.secondary, onTap: () => showToast(context, 'For your safety, bank changes are done with support', icon: Symbols.support_agent)),
      ]),
    );
  }
}

// ───────────────────────── Help ─────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  static const _faq = [
    ('How are my earnings calculated?', 'You earn the full ride fare plus any waiting charge and tips, minus the platform fee. New captains pay no platform fee on their first $kZeroCommissionRides rides.'),
    ('When do I get paid?', 'Online payments and bonuses are paid to your bank account every morning at 6 am. You can also withdraw your balance any time from the Earnings tab.'),
    ('What is the waiting charge?', 'The first 3 minutes at the pickup are free. After that the rider pays ₹1 for every minute, and it goes to you.'),
    ('How do incentives work?', 'Complete the target number of rides in the time shown on each incentive card. The bonus is added to your balance as soon as you hit the target.'),
    ('Why do I need the rider\'s PIN?', 'The 4-digit PIN makes sure you pick up the right person. A trip can only start once the PIN matches.'),
    ('What happens if I miss or decline requests?', 'Nothing is charged, but a low acceptance rate can mean fewer requests during busy hours.'),
  ];
  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Help',
        body: ListView(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: AppCard(
              onTap: () => showToast(context, 'Connecting you to captain support', icon: Symbols.support_agent),
              child: Row(children: [
                const IconTile(Symbols.support_agent, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Chat with captain support', style: context.t.subtitle),
                    Text('Typically replies in 2 minutes', style: context.t.caption),
                  ]),
                ),
                Icon(Symbols.chevron_right, color: context.c.text3),
              ]),
            ),
          ),
          const SectionHeader('Frequently asked'),
          for (final f in _faq) _Faq(q: f.$1, a: f.$2),
        ]),
      );
}

class _Faq extends StatefulWidget {
  final String q, a;
  const _Faq({required this.q, required this.a});
  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(children: [
      RowTap(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedSize(
          duration: kMedium,
          curve: kEase,
          alignment: Alignment.topCenter,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.q, style: context.t.bodyStrong)),
              AnimatedRotation(turns: _open ? .5 : 0, duration: kMedium, child: Icon(Symbols.keyboard_arrow_down, color: c.text2)),
            ]),
            if (_open) Padding(padding: const EdgeInsets.only(top: 8, right: 24), child: Text(widget.a, style: context.t.secondary)),
          ]),
        ),
      ),
      const Hairline(indent: 20),
    ]);
  }
}
