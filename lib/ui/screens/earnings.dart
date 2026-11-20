import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../captain_kit.dart';
import '../kit.dart';
import 'shell.dart';

class EarningsTab extends StatefulWidget {
  const EarningsTab({super.key});
  @override
  State<EarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<EarningsTab> {
  Period _period = Period.today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: captain,
          builder: (context, _) {
            final r = captain.report(_period);
            final now = clock.now();
            final label = switch (_period) {
              Period.today => 'Today · ${formatDate(now)}',
              Period.week => 'Last 7 days',
              Period.month => 'Last 30 days',
            };
            return ListView(
              padding: EdgeInsets.only(bottom: tabBottomPadding(context)),
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text('Earnings', style: context.t.display)),
                const OfflineBanner(margin: EdgeInsets.fromLTRB(20, 0, 20, 8)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Segmented(
                    items: const ['Today', 'Week', 'Month'],
                    index: _period.index,
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _period = Period.values[i]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: context.t.secondary),
                    const SizedBox(height: 2),
                    CountUp(r.total, key: ValueKey(_period), format: inr, style: context.t.hero),
                    const SizedBox(height: 4),
                    Text(
                      '${r.rides} ${r.rides == 1 ? 'ride' : 'rides'} · ${formatDuration(r.onlineTime)} online · ${r.km.toStringAsFixed(0)} km',
                      style: context.t.caption,
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: r.total == 0
                      ? AppCard(
                          child: EmptyState(
                            icon: Symbols.bar_chart,
                            title: _period == Period.today ? 'No earnings yet today' : 'No earnings in this period',
                            sub: 'Go online to start getting ride requests.',
                            action: AppButton('Go to home', kind: ButtonKind.secondary, expand: false, height: 44, onTap: () => Shell.of(context)?.select(0)),
                          ),
                        )
                      : EarningsChart(key: ValueKey(_period), bars: r.bars, period: _period),
                ),
                const SizedBox(height: 16),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: BalanceCard()),
                const SectionHeader('Breakdown'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppCard(
                    child: Column(children: [
                      KvRow('Ride fares', inr(r.fares)),
                      KvRow('Tips', inr(r.tips)),
                      KvRow('Incentives', inr(r.incentives)),
                      KvRow('Platform fee', r.fees == 0 ? '₹0' : '−${inr(r.fees)}'),
                      const SizedBox(height: 4),
                      const Hairline(),
                      const SizedBox(height: 4),
                      KvRow('Total earnings', inr(r.total), strong: true),
                    ]),
                  ),
                ),
                const SectionHeader('How you were paid'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Expanded(child: _PaidTile(icon: Symbols.payments, title: 'Cash collected', amount: r.cash, sub: 'Already with you')),
                    const SizedBox(width: 10),
                    Expanded(child: _PaidTile(icon: Symbols.qr_code_2, title: 'Online payments', amount: r.online, sub: 'Added to balance')),
                  ]),
                ),
                const SectionHeader('Incentives'),
                for (final i in captain.incentives)
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: IncentiveCard(i)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bars drawn with plain containers; they grow in when the period changes.
/// Tap a bar to see its amount.
class EarningsChart extends StatefulWidget {
  final List<({String label, double amount})> bars;
  final Period period;
  const EarningsChart({super.key, required this.bars, required this.period});
  @override
  State<EarningsChart> createState() => _EarningsChartState();
}

class _EarningsChartState extends State<EarningsChart> {
  late int _sel = _defaultSel();

  int _defaultSel() {
    if (widget.period != Period.today) return widget.bars.length - 1;
    final h = clock.now().hour - 6;
    return h.clamp(0, widget.bars.length - 1);
  }

  String _title(int i) {
    final now = clock.now();
    switch (widget.period) {
      case Period.today:
        final h = 6 + i;
        String t(int h) => '${h % 12 == 0 ? 12 : h % 12} ${h < 12 || h == 24 ? 'am' : 'pm'}';
        return '${t(h)} – ${t(h + 1)}';
      default:
        final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: widget.bars.length - 1 - i));
        final wd = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
        return i == widget.bars.length - 1 ? 'Today' : '$wd, ${formatDate(d)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bars = widget.bars;
    final max = bars.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    final sel = _sel.clamp(0, bars.length - 1);
    final gap = bars.length > 20 ? 3.0 : (bars.length > 10 ? 5.0 : 10.0);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_title(sel), style: context.t.caption)),
          Text(inr(bars[sel].amount), style: context.t.label),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: kSlow,
            curve: kEase,
            builder: (context, v, _) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _sel = i);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap / 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: kFast,
                          height: max == 0 ? 3 : (3 + 125 * (bars[i].amount / max) * v),
                          decoration: BoxDecoration(
                            color: i == sel ? Brand.primary : (c.dark ? c.sunken : c.border),
                            borderRadius: BorderRadius.circular(bars.length > 20 ? 2 : 4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (final b in bars)
            Expanded(
              child: Text(b.label, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textAlign: TextAlign.center, style: context.t.caption.copyWith(fontSize: 11)),
            ),
        ]),
      ]),
    );
  }
}

class _PaidTile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final double amount;
  const _PaidTile({required this.icon, required this.title, required this.amount, required this.sub});
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon, size: 36),
          const SizedBox(height: 12),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
          Text(inr(amount), style: context.t.title),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption.copyWith(color: context.c.text3)),
        ]),
      );
}

class IncentiveCard extends StatelessWidget {
  final IncentiveProgress i;
  const IncentiveCard(this.i, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(i.complete ? Symbols.check : Symbols.bolt, size: 40, color: i.complete ? Brand.success.withValues(alpha: c.dark ? .18 : .1) : c.selectedBg, iconColor: i.complete ? Brand.success : c.accentText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.sub.toUpperCase(), style: context.t.overline),
              const SizedBox(height: 2),
              Text('${i.title} → ${rupees(i.reward)} bonus', style: context.t.bodyStrong),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ProgressLine(value: i.fraction, color: i.complete ? Brand.success : Brand.primary)),
          const SizedBox(width: 12),
          Text(i.complete ? 'Earned' : '${i.done}/${i.target}', style: context.t.label.copyWith(color: i.complete ? Brand.success : c.text)),
        ]),
      ]),
    );
  }
}

/// Dark balance card (the rider app's wallet card) with withdraw / payouts.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.dark ? c.surfaceAlt : const Color(0xFF15161A), borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Balance', style: context.t.label.copyWith(color: Colors.white70))),
          const BrandMark(size: 30),
        ]),
        const SizedBox(height: 10),
        CountUp(captain.wallet, format: inr, style: context.t.display.copyWith(color: Colors.white)),
        const SizedBox(height: 2),
        Text('Auto payout to ${captain.bankName} ${captain.bankMasked} at 6 am', style: context.t.caption.copyWith(color: Colors.white60)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: AppButton('Withdraw', height: 46, onTap: () => showWithdrawSheet(context))),
          const SizedBox(width: 10),
          Expanded(
            child: Tappable(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayoutsScreen())),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: Colors.white24)),
                child: Text('Payouts', style: context.t.button.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ───────────────────────── payouts ─────────────────────────

class PayoutsScreen extends StatelessWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PageScaffold(
      title: 'Payouts',
      body: ListenableBuilder(
        listenable: captain,
        builder: (context, _) {
          final now = clock.now();
          return ListView(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24), children: [
            const OfflineBanner(margin: EdgeInsets.fromLTRB(20, 0, 20, 8)),
            const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: BalanceCard()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Icon(Symbols.schedule, size: 16, color: c.text3),
                const SizedBox(width: 6),
                Expanded(child: Text('Online earnings are paid out every morning. Cash fares stay with you.', style: context.t.caption)),
              ]),
            ),
            const SectionHeader('Payout history'),
            if (captain.payouts.isEmpty)
              const EmptyState(icon: Symbols.account_balance, title: 'No payouts yet', sub: 'Your first payout arrives the morning after your first online ride.')
            else
              for (final p in captain.payouts) ...[
                ListRow(
                  leading: IconTile(Symbols.south_west, iconColor: Brand.success, color: Brand.success.withValues(alpha: c.dark ? .18 : .12)),
                  title: p.instant ? 'Instant withdrawal' : 'Daily payout',
                  subtitle: '${formatWhen(p.when)} · ${captain.bankName} ${captain.bankMasked}',
                  chevron: false,
                  trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(inr(p.amount), style: context.t.bodyStrong),
                    const SizedBox(height: 4),
                    now.difference(p.when).inMinutes < 10
                        ? const StatusPill('Processing', Brand.primary)
                        : const StatusPill('Credited', Brand.success),
                  ]),
                ),
                const Hairline(indent: 74),
              ],
          ]);
        },
      ),
    );
  }
}

void showWithdrawSheet(BuildContext context) {
  final ctrl = TextEditingController(text: captain.wallet >= 100 ? '${captain.wallet.floor()}' : '');
  var busy = false;
  double? sent;
  showAppSheet(context, builder: (ctx) {
    return StatefulBuilder(builder: (ctx, set) {
      final c = ctx.c;
      final amount = double.tryParse(ctrl.text) ?? 0;
      final balance = captain.wallet;
      final error = amount <= 0
          ? null
          : amount < 100
              ? 'Minimum withdrawal is ₹100'
              : amount > balance
                  ? 'You can withdraw up to ${inr(balance)}'
                  : null;
      final paid = sent;
      if (paid != null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
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
            const SizedBox(height: 14),
            Text('${inr(paid)} is on its way', style: ctx.t.headline),
            const SizedBox(height: 4),
            Text('To ${captain.bankName} ${captain.bankMasked}. It usually arrives within minutes.', textAlign: TextAlign.center, style: ctx.t.secondary),
            const SizedBox(height: 20),
            AppButton('Done', onTap: () => Navigator.pop(ctx)),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Withdraw to bank', style: ctx.t.title),
          const SizedBox(height: 4),
          Text('Balance ${inr(balance)} · ${captain.bankName} ${captain.bankMasked}', style: ctx.t.secondary),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: error != null ? Brand.danger : c.text, width: 1.6)),
            child: Row(children: [
              Text('₹', style: ctx.t.headline),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  onChanged: (_) => set(() {}),
                  style: ctx.t.headline,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ]),
          ),
          AnimatedSize(
            duration: kMedium,
            curve: kEase,
            child: error == null
                ? const SizedBox(width: double.infinity)
                : Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: ctx.t.caption.copyWith(color: Brand.danger))),
          ),
          const SizedBox(height: 12),
          Row(children: [
            for (final (i, v) in [(0, 100.0), (1, 500.0), (2, balance.floorToDouble())].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Tappable(
                  onTap: () => set(() => ctrl.text = '${v.$2.round()}'),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Text(v.$1 == 2 ? 'All' : inr(v.$2), style: ctx.t.label),
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          AppButton(
            amount >= 100 && error == null ? 'Withdraw ${inr(amount)}' : (balance < 100 ? 'Balance below ₹100' : 'Enter an amount'),
            loading: busy,
            onTap: amount >= 100 && error == null
                ? () async {
                    set(() => busy = true);
                    final ok = await captain.withdraw(amount);
                    if (!ctx.mounted) return;
                    HapticFeedback.mediumImpact();
                    set(() {
                      busy = false;
                      if (ok) sent = amount;
                    });
                  }
                : null,
          ),
        ]),
      );
    });
  }).whenComplete(() => Future.delayed(const Duration(milliseconds: 600), ctrl.dispose));
}
