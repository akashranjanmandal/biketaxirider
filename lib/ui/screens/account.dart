import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/models.dart';
import '../captain_kit.dart';
import '../forms.dart';
import '../kit.dart';
import 'earnings.dart';
import 'more.dart';
import 'onboarding.dart';
import 'shell.dart';

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  void _go(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([captain, themeController]),
          builder: (context, _) {
            final expiring = DocKind.values.where(captain.expiringSoon).length;
            return ListView(
              padding: EdgeInsets.only(bottom: tabBottomPadding(context)),
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), child: Text('Account', style: context.t.display)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Avatar(captain.initials, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(captain.name.isEmpty ? 'Aamar captain' : captain.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.title),
                        const SizedBox(height: 2),
                        Text(captain.phoneFormatted, style: context.t.secondary),
                        const SizedBox(height: 6),
                        const CaptainBadge(scale: .9),
                      ]),
                    ),
                    AppButton('Edit', kind: ButtonKind.secondary, expand: false, height: 38, onTap: () => _editProfile(context)),
                  ]),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Expanded(child: _StatTile(icon: Symbols.star, value: captain.rating.toStringAsFixed(2), label: 'Rating', iconColor: Brand.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(icon: Symbols.check_circle, value: '${captain.acceptanceRate}%', label: 'Acceptance')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(icon: Symbols.cancel, value: '${captain.cancellationRate}%', label: 'Cancellation')),
                  ]),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppCard(
                    onTap: () => _go(context, const DocumentsScreen()),
                    child: Row(children: [
                      VehicleImage(captain.vehicle, width: 64, plate: true),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(captain.vehicle.label, style: context.t.subtitle),
                          Text(captain.vehicleModel, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
                          const SizedBox(height: 6),
                          PlateTag(captain.plateOrDefault),
                        ]),
                      ),
                      Icon(Symbols.chevron_right, color: c.text3),
                    ]),
                  ),
                ),
                const SectionHeader('Account'),
                ListRow(
                  icon: Symbols.folder_shared,
                  title: 'Vehicle & documents',
                  subtitle: expiring > 0 ? '$expiring expiring soon' : 'All verified',
                  trailing: expiring > 0 ? const Padding(padding: EdgeInsets.only(right: 4), child: StatusPill('Action needed', Brand.primary)) : null,
                  onTap: () => _go(context, const DocumentsScreen()),
                ),
                ListRow(icon: Symbols.account_balance, title: 'Bank details', subtitle: '${captain.bankName} ${captain.bankMasked}', onTap: () => _go(context, const BankScreen())),
                ListRow(icon: Symbols.payments, title: 'Payouts', subtitle: 'Balance ${inr(captain.wallet)}', onTap: () => _go(context, const PayoutsScreen())),
                ListRow(icon: Symbols.notifications, title: 'Notifications', onTap: () => _go(context, const NotificationsScreen())),
                const SectionHeader('Appearance'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Segmented(
                    items: const ['System', 'Light', 'Dark'],
                    index: switch (themeController.mode) { ThemeMode.system => 0, ThemeMode.light => 1, ThemeMode.dark => 2 },
                    onChanged: (i) => themeController.mode = [ThemeMode.system, ThemeMode.light, ThemeMode.dark][i],
                  ),
                ),
                const SectionHeader('Preferences'),
                ListRow(icon: Symbols.translate, title: 'Language', subtitle: 'English', onTap: () => _language(context)),
                ListRow(icon: Symbols.shield_person, title: 'Safety', subtitle: 'SOS and emergency contacts', onTap: () => _go(context, const SafetyScreen())),
                ListRow(icon: Symbols.support_agent, title: 'Help', subtitle: 'FAQs and captain support', onTap: () => _go(context, const HelpScreen())),
                ListRow(
                  icon: Symbols.info,
                  title: 'About Aamar Captain',
                  subtitle: 'Version 1.0.0',
                  onTap: () => showAboutDialog(context: context, applicationName: 'Aamar Captain', applicationVersion: '1.0.0', applicationIcon: const BrandMark(size: 40)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppButton('Log out', kind: ButtonKind.danger, icon: Symbols.logout, onTap: () => _logout(context)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _editProfile(BuildContext context) {
    final name = TextEditingController(text: captain.name);
    showAppSheet(context, builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit profile', style: ctx.t.title),
            const SizedBox(height: 4),
            Text('Your name must match your driving licence.', style: ctx.t.secondary),
            const SizedBox(height: 16),
            AppField(controller: name, label: 'Full name', capitalization: TextCapitalization.words, autofocus: true),
            const SizedBox(height: 20),
            AppButton('Save', onTap: () {
              if (name.text.trim().length >= 3) captain.setName(name.text.trim());
              Navigator.pop(ctx);
              showToast(context, 'Profile updated');
            }),
          ]),
        )).whenComplete(() => Future.delayed(const Duration(milliseconds: 600), name.dispose));
  }

  void _language(BuildContext context) {
    showAppSheet(context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text('Language', style: ctx.t.title)),
          for (final (i, l) in const ['English', 'বাংলা (Bengali)', 'हिन्दी (Hindi)'].indexed)
            ListRow(
              title: l,
              chevron: false,
              trailing: i == 0 ? const Icon(Symbols.check, color: Brand.success) : null,
              onTap: () {
                Navigator.pop(ctx);
                if (i != 0) showToast(context, 'More languages are coming soon', icon: Symbols.translate);
              },
            ),
        ]));
  }

  void _logout(BuildContext context) {
    showAppSheet(context, builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Log out of Aamar Captain?', style: ctx.t.title),
            const SizedBox(height: 6),
            Text(captain.online ? 'You\'ll go offline and stop getting requests.' : 'You\'ll need to verify your number to sign in again.', style: ctx.t.secondary),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: AppButton('Cancel', kind: ButtonKind.secondary, onTap: () => Navigator.pop(ctx))),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton('Log out', kind: ButtonKind.danger, onTap: () {
                  Navigator.pop(ctx);
                  captain.goOffline();
                  captain.signOut();
                  Navigator.of(context).pushAndRemoveUntil(fadeRoute(const WelcomeScreen()), (_) => false);
                }),
              ),
            ]),
          ]),
        ));
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color? iconColor;
  const _StatTile({required this.icon, required this.value, required this.label, this.iconColor});
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: iconColor ?? context.c.text2, fill: iconColor != null ? 1 : 0, weight: 500),
          const SizedBox(height: 8),
          Text(value, style: context.t.title),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.caption),
        ]),
      );
}
