import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/models.dart';
import '../captain_kit.dart';
import '../forms.dart';
import '../kit.dart';
import 'onboarding.dart';
import 'shell.dart';

const kLanguages = ['Bengali', 'Hindi', 'English', 'Urdu', 'Odia'];

IconData docIcon(DocKind k) => switch (k) {
      DocKind.licence => Symbols.id_card,
      DocKind.rc => Symbols.description,
      DocKind.aadhaar => Symbols.fingerprint,
      DocKind.pan => Symbols.credit_card,
      DocKind.vehiclePhoto => Symbols.photo_camera,
      DocKind.selfie => Symbols.face,
      DocKind.insurance => Symbols.verified_user,
      DocKind.puc => Symbols.eco,
    };

/// Vehicle choices on the registration screen (the three cabs are one card).
enum _VehicleChoice { bike, auto, eRickshaw, cab }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _pc = PageController();
  int _step = 0;
  bool _submitting = false;

  final _name = TextEditingController();
  final _plate = TextEditingController();
  final _acc = TextEditingController();
  final _acc2 = TextEditingController();
  final _ifsc = TextEditingController();
  final _holder = TextEditingController();
  bool _showErrors = false;

  static const _titles = ['Personal details', 'Your vehicle', 'Documents', 'Bank account', 'Review & submit'];

  @override
  void initState() {
    super.initState();
    _name.text = captain.name;
    for (final c in [_name, _plate, _acc, _acc2, _ifsc, _holder]) {
      c.addListener(_refresh);
    }
    captain.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    captain.removeListener(_refresh);
    _pc.dispose();
    for (final c in [_name, _plate, _acc, _acc2, _ifsc, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  // ───────── validation ─────────
  String? get _nameError => _name.text.trim().length < 3 ? 'Enter your full name as on your licence' : null;
  String? get _plateError => isValidPlate(_plate.text) ? null : 'Enter a number like WB 02 AK 4821';
  String? get _accError => RegExp(r'^\d{9,18}$').hasMatch(_acc.text) ? null : 'Account numbers have 9 to 18 digits';
  String? get _acc2Error => _acc2.text == _acc.text ? null : 'Account numbers don\'t match';
  String? get _ifscError => isValidIfsc(_ifsc.text) ? null : 'IFSC has 11 characters, like HDFC0001234';
  String? get _holderError => _holder.text.trim().length < 3 ? 'Enter the name on the bank account' : null;

  bool get _stepValid => switch (_step) {
        0 => _nameError == null && captain.languages.isNotEmpty,
        1 => _plateError == null,
        2 => captain.docsComplete,
        3 => _accError == null && _acc2Error == null && _ifscError == null && _holderError == null,
        _ => true,
      };

  void _goTo(int i) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = i;
      _showErrors = false;
    });
    _pc.animateToPage(i, duration: kSlow, curve: kEase);
  }

  void _next() {
    if (!_stepValid) {
      setState(() => _showErrors = true);
      HapticFeedback.lightImpact();
      return;
    }
    switch (_step) {
      case 0:
        captain.name = _name.text.trim();
        if (_holder.text.isEmpty) _holder.text = captain.name;
      case 1:
        captain.plate = _plate.text.trim().toUpperCase();
      case 3:
        captain.bankAccount = _acc.text;
        captain.ifsc = _ifsc.text.trim().toUpperCase();
        captain.holder = _holder.text.trim();
    }
    if (_step < 4) {
      _goTo(_step + 1);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const VerificationScreen()), (_) => false);
  }

  void _back() {
    if (_step > 0) {
      _goTo(_step - 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.of(context).canPop() || _step > 0 ? Center(child: CircleButton(Symbols.arrow_back, size: 40, onTap: _back)) : null,
          automaticallyImplyLeading: false,
          titleSpacing: _step > 0 || Navigator.of(context).canPop() ? 4 : 20,
          title: Text('Step ${_step + 1} of 5', style: context.t.label.copyWith(color: c.text2)),
        ),
        body: SafeArea(
          top: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: StepTracker(count: 5, index: _step)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: AnimatedSwitcher(
                duration: kMedium,
                layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
                child: Text(_titles[_step], key: ValueKey(_step), style: context.t.headline),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                children: [_personal(), _vehicle(), _documents(), _bank(), _review()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AppButton(
                _step == 4 ? 'Submit for verification' : 'Continue',
                loading: _submitting,
                onTap: _step == 2 && !captain.docsComplete ? null : _next,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      );

  // ───────── step 1: personal ─────────
  Widget _personal() {
    final c = context.c;
    return _scroll([
      Text('As printed on your driving licence.', style: context.t.secondary),
      const SizedBox(height: 18),
      AppField(
        controller: _name,
        label: 'Full name',
        capitalization: TextCapitalization.words,
        action: TextInputAction.done,
        error: _showErrors ? _nameError : null,
      ),
      const SectionHeader('City', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
      AppCard(
        color: c.selectedBg,
        outlined: false,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          const IconTile(Symbols.location_city, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(captain.city, style: context.t.bodyStrong),
              Text('More cities are coming soon', style: context.t.caption),
            ]),
          ),
          const Icon(Symbols.check_circle, color: Brand.success, fill: 1),
        ]),
      ),
      const SectionHeader('Languages you speak', padding: EdgeInsets.fromLTRB(0, 24, 0, 10)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in kLanguages)
          ChoiceChipX(
            label: l,
            selected: captain.languages.contains(l),
            onTap: () {
              final set = {...captain.languages};
              set.contains(l) ? set.remove(l) : set.add(l);
              captain.languages = set;
              setState(() {});
            },
          ),
      ]),
      if (_showErrors && captain.languages.isEmpty) ...[
        const SizedBox(height: 8),
        Text('Pick at least one language', style: context.t.caption.copyWith(color: Brand.danger)),
      ],
    ]);
  }

  // ───────── step 2: vehicle ─────────
  _VehicleChoice get _choice => switch (captain.vehicle) {
        Service.bike => _VehicleChoice.bike,
        Service.auto => _VehicleChoice.auto,
        Service.eRickshaw => _VehicleChoice.eRickshaw,
        _ => _VehicleChoice.cab,
      };

  Widget _vehicle() {
    final c = context.c;
    final options = [
      (_VehicleChoice.bike, Service.bike, 'Bike', 'Solo rides and parcels'),
      (_VehicleChoice.auto, Service.auto, 'Auto', 'Up to 3 riders'),
      (_VehicleChoice.eRickshaw, Service.eRickshaw, 'E-Rickshaw', 'Electric, up to 4 riders'),
      (_VehicleChoice.cab, Service.cabEconomy, 'Cab', 'Economy, Premium or XL'),
    ];
    return _scroll([
      Text('Pick the vehicle you\'ll drive.', style: context.t.secondary),
      const SizedBox(height: 14),
      for (final o in options) ...[
        Tappable(
          pressedScale: .985,
          onTap: () {
            HapticFeedback.selectionClick();
            if (_choice != o.$1) captain.vehicle = o.$2;
            setState(() {});
          },
          child: AnimatedContainer(
            duration: kMedium,
            curve: kEase,
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            decoration: BoxDecoration(
              color: _choice == o.$1 ? c.selectedBg : c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: _choice == o.$1 ? Brand.primary : c.border, width: _choice == o.$1 ? 1.6 : 1),
            ),
            child: Row(children: [
              VehicleImage(o.$2, width: 64, plate: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(o.$3, style: context.t.subtitle)),
                    if (o.$2.isElectric) ...[const SizedBox(width: 6), const Pill('EV', color: Brand.success, textColor: Colors.white)],
                  ]),
                  const SizedBox(height: 2),
                  Text(o.$4, style: context.t.caption),
                ]),
              ),
              AnimatedSwitcher(
                duration: kFast,
                child: _choice == o.$1
                    ? const Icon(Symbols.check_circle, key: ValueKey(1), color: Brand.success, fill: 1)
                    : Icon(Symbols.radio_button_unchecked, key: const ValueKey(0), color: c.text3),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
      ],
      AnimatedSize(
        duration: kMedium,
        curve: kEase,
        alignment: Alignment.topCenter,
        child: _choice != _VehicleChoice.cab
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cab category', style: context.t.label.copyWith(color: c.text2)),
                  const SizedBox(height: 8),
                  Segmented(
                    items: const ['Economy', 'Premium', 'XL'],
                    index: switch (captain.vehicle) { Service.cabPremium => 1, Service.cabXl => 2, _ => 0 },
                    onChanged: (i) {
                      captain.vehicle = const [Service.cabEconomy, Service.cabPremium, Service.cabXl][i];
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(captain.vehicle.tagline, style: context.t.caption),
                ]),
              ),
      ),
      const SizedBox(height: 14),
      AppField(
        controller: _plate,
        label: 'Vehicle number',
        capitalization: TextCapitalization.characters,
        formatters: [UpperCaseFormatter(), LengthLimitingTextInputFormatter(13)],
        helper: 'As on your RC, e.g. ${captainFor(captain.vehicle).plate}',
        error: _showErrors ? _plateError : null,
        action: TextInputAction.done,
      ),
    ]);
  }

  // ───────── step 3: documents ─────────
  Widget _documents() {
    final done = kRegistrationDocs.where((d) => captain.docs[d] == DocStatus.verified).length;
    return _scroll([
      Text('Clear photos get verified in seconds. $done of ${kRegistrationDocs.length} done.', style: context.t.secondary),
      const SizedBox(height: 10),
      for (final d in kRegistrationDocs) DocRow(kind: d, onTap: () => showCaptureSheet(context, d)),
    ]);
  }

  // ───────── step 4: bank ─────────
  Widget _bank() {
    final c = context.c;
    final bank = bankForIfsc(_ifsc.text);
    return _scroll([
      Text('Your daily payouts are sent here.', style: context.t.secondary),
      const SizedBox(height: 18),
      AppField(
        controller: _acc,
        label: 'Account number',
        keyboard: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
        error: _showErrors ? _accError : null,
        action: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      AppField(
        controller: _acc2,
        label: 'Confirm account number',
        keyboard: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
        error: _showErrors || (_acc2.text.length >= _acc.text.length && _acc2.text.isNotEmpty) ? _acc2Error : null,
        action: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      AppField(
        controller: _ifsc,
        label: 'IFSC code',
        capitalization: TextCapitalization.characters,
        formatters: [UpperCaseFormatter(), FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(11)],
        error: _showErrors || _ifsc.text.length == 11 ? _ifscError : null,
        helper: bank,
        suffix: bank != null ? const Icon(Symbols.check_circle, color: Brand.success, fill: 1, size: 20) : null,
        action: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      AppField(
        controller: _holder,
        label: 'Account holder name',
        capitalization: TextCapitalization.words,
        error: _showErrors ? _holderError : null,
        action: TextInputAction.done,
      ),
      const SizedBox(height: 16),
      Row(children: [
        Icon(Symbols.lock, size: 16, color: c.text3),
        const SizedBox(width: 6),
        Expanded(child: Text('Bank details are encrypted and only used for payouts.', style: context.t.caption.copyWith(color: c.text3))),
      ]),
    ]);
  }

  // ───────── step 5: review ─────────
  Widget _review() {
    final c = context.c;
    Widget section(String title, int step, List<Widget> rows) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: context.t.subtitle)),
                Tappable(onTap: () => _goTo(step), child: Text('Edit', style: context.t.label.copyWith(color: c.accentText))),
              ]),
              const SizedBox(height: 8),
              ...rows,
            ]),
          ),
        );
    final bank = bankForIfsc(_ifsc.text) ?? 'Bank';
    final acc = _acc.text;
    return _scroll([
      Text('Check everything before you submit.', style: context.t.secondary),
      const SizedBox(height: 14),
      section('Personal', 0, [
        KvRow('Name', _name.text.trim()),
        KvRow('City', captain.city),
        KvRow('Languages', captain.languages.join(', ')),
      ]),
      section('Vehicle', 1, [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(captain.vehicle.label, style: context.t.bodyStrong),
              const SizedBox(height: 6),
              PlateTag(_plate.text.trim().toUpperCase()),
            ]),
          ),
          VehicleImage(captain.vehicle, width: 72),
        ]),
      ]),
      section('Documents', 2, [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final d in kRegistrationDocs) StatusPill(d.shortLabel, Brand.success, icon: Symbols.check_circle),
        ]),
      ]),
      section('Bank account', 3, [
        KvRow('Bank', bank),
        KvRow('Account', acc.length >= 4 ? '•••• ${acc.substring(acc.length - 4)}' : acc),
        KvRow('IFSC', _ifsc.text.toUpperCase()),
        KvRow('Holder', _holder.text.trim()),
      ]),
    ]);
  }
}

/// Selectable chip used for languages and rating tags.
class ChoiceChipX extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceChipX({super.key, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? c.text : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.text : c.border),
        ),
        child: Text(label, style: context.t.label.copyWith(color: selected ? c.bg : c.text)),
      ),
    );
  }
}

/// Document row with its verification status.
class DocRow extends StatelessWidget {
  final DocKind kind;
  final VoidCallback? onTap;
  final String? expiry;
  final bool expiring;
  const DocRow({super.key, required this.kind, this.onTap, this.expiry, this.expiring = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final st = captain.docs[kind] ?? DocStatus.missing;
    final Widget trailing = switch (st) {
      DocStatus.verified when expiring => const StatusPill('Expiring soon', Brand.primary, icon: Symbols.schedule),
      DocStatus.verified => const StatusPill('Verified', Brand.success, icon: Symbols.check_circle),
      DocStatus.verifying => Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.text2)),
          const SizedBox(width: 6),
          Text('Verifying', style: context.t.caption),
        ]),
      DocStatus.missing => Text('Upload', style: context.t.label.copyWith(color: c.accentText)),
    };
    return ListRow(
      leading: IconTile(docIcon(kind), color: st == DocStatus.verified ? Brand.success.withValues(alpha: c.dark ? .18 : .1) : null, iconColor: st == DocStatus.verified ? Brand.success : null),
      title: kind.label,
      subtitle: expiry ?? kind.hint,
      trailing: AnimatedSwitcher(duration: kMedium, child: KeyedSubtree(key: ValueKey('$st$expiring'), child: trailing)),
      chevron: false,
      onTap: onTap,
    );
  }
}

// ───────────────────────── capture sheet ─────────────────────────

Future<void> showCaptureSheet(BuildContext context, DocKind kind) =>
    showAppSheet(context, builder: (ctx) => _CaptureSheet(kind: kind));

enum _Cap { framing, verifying, done }

class _CaptureSheet extends StatefulWidget {
  final DocKind kind;
  const _CaptureSheet({required this.kind});
  @override
  State<_CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<_CaptureSheet> {
  _Cap _state = _Cap.framing;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _capture() {
    HapticFeedback.mediumImpact();
    setState(() => _state = _Cap.verifying);
    captain.setDoc(widget.kind, DocStatus.verifying);
    _t = Timer(const Duration(milliseconds: 1400), () {
      captain.setDoc(widget.kind, DocStatus.verified);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _state = _Cap.done);
      _t = Timer(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    const viewfinder = Color(0xFF0F1013);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k.label, style: context.t.title),
        const SizedBox(height: 2),
        Text(k.hint, style: context.t.secondary),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: k.isSelfie ? 1.1 : 1.45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Container(
              color: viewfinder,
              child: Stack(alignment: Alignment.center, children: [
                // what the camera "sees"
                AnimatedOpacity(
                  duration: kMedium,
                  opacity: _state == _Cap.framing ? .5 : 1,
                  child: k.isSelfie
                      ? Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08), border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2)),
                          child: Icon(Symbols.face, size: 72, color: Colors.white.withValues(alpha: .55), weight: 300),
                        )
                      : FractionallySizedBox(
                          widthFactor: .78,
                          heightFactor: .66,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFFECEAE4).withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              Container(
                                width: 48,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(6)),
                                child: Icon(k.isPhoto ? Symbols.directions_car : Symbols.person, color: Colors.white.withValues(alpha: .6)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  for (final w in const [.9, .6, .75, .45]) ...[
                                    FractionallySizedBox(
                                      widthFactor: w,
                                      child: Container(height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(3))),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ]),
                              ),
                            ]),
                          ),
                        ),
                ),
                if (!k.isSelfie) const Positioned.fill(child: Padding(padding: EdgeInsets.all(18), child: _Corners())),
                AnimatedSwitcher(
                  duration: kMedium,
                  child: switch (_state) {
                    _Cap.framing => Align(
                        key: const ValueKey('f'),
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(k.isSelfie ? 'Keep your face inside the circle' : 'Fit the ${k.shortLabel} inside the frame', style: context.t.caption.copyWith(color: Colors.white70)),
                        ),
                      ),
                    _Cap.verifying => Container(
                        key: const ValueKey('v'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(24)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text('Verifying…', style: context.t.label.copyWith(color: Colors.white)),
                        ]),
                      ),
                    _Cap.done => Container(
                        key: const ValueKey('d'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: Brand.success, borderRadius: BorderRadius.circular(24)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Symbols.check, color: Colors.white, size: 18, weight: 600),
                          const SizedBox(width: 6),
                          Text('Verified', style: context.t.label.copyWith(color: Colors.white)),
                        ]),
                      ),
                  },
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: AppButton(
              'Gallery',
              kind: ButtonKind.secondary,
              icon: Symbols.photo_library,
              onTap: _state == _Cap.framing ? _capture : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              _state == _Cap.framing ? 'Capture' : (_state == _Cap.done ? 'Done' : 'Verifying'),
              icon: _state == _Cap.done ? Symbols.check : Symbols.photo_camera,
              loading: _state == _Cap.verifying,
              onTap: _state == _Cap.framing ? _capture : null,
            ),
          ),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }
}

/// Corner guides of a document viewfinder.
class _Corners extends StatelessWidget {
  const _Corners();
  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: Brand.primary, width: 3);
    Widget corner(Alignment a, Border b) => Align(alignment: a, child: Container(width: 26, height: 26, decoration: BoxDecoration(border: b)));
    return Stack(children: [
      corner(Alignment.topLeft, const Border(top: side, left: side)),
      corner(Alignment.topRight, const Border(top: side, right: side)),
      corner(Alignment.bottomLeft, const Border(bottom: side, left: side)),
      corner(Alignment.bottomRight, const Border(bottom: side, right: side)),
    ]);
  }
}

// ───────────────────────── under verification ─────────────────────────

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  int _done = 1; // documents received
  final _timers = <Timer>[];

  @override
  void initState() {
    super.initState();
    _timers.add(Timer(const Duration(milliseconds: 1500), () => _set(2)));
    _timers.add(Timer(const Duration(seconds: 3), () {
      captain.completeRegistration();
      HapticFeedback.mediumImpact();
      _set(3);
    }));
  }

  void _set(int v) {
    if (mounted) setState(() => _done = v);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final approved = _done >= 3;
    final steps = ['Documents received', 'Background check', 'Account activated'];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: kSlow,
                    switchInCurve: kEase,
                    transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .85, end: 1.0).animate(a), child: child)),
                    child: Container(
                      key: ValueKey(approved),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(color: approved ? Brand.success.withValues(alpha: .12) : c.selectedBg, shape: BoxShape.circle),
                      child: Icon(approved ? Symbols.verified : Symbols.hourglass_top, size: 38, color: approved ? Brand.success : c.accentText, fill: approved ? 1 : 0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: kMedium,
                  child: Text(
                    approved ? 'You\'re all set, ${captain.firstName}' : 'Under verification',
                    key: ValueKey(approved),
                    textAlign: TextAlign.center,
                    style: context.t.headline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  approved ? 'Your account is active. Go online to start earning.' : 'We\'re checking your documents. This usually takes a few seconds in the demo.',
                  textAlign: TextAlign.center,
                  style: context.t.secondary,
                ),
                const SizedBox(height: 28),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    for (var i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: AnimatedSwitcher(
                              duration: kMedium,
                              child: i < _done
                                  ? const Icon(Symbols.check_circle, key: ValueKey('ok'), color: Brand.success, fill: 1)
                                  : i == _done
                                      ? Padding(key: const ValueKey('l'), padding: const EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2, color: c.text2))
                                      : Icon(Symbols.radio_button_unchecked, key: const ValueKey('n'), color: c.text3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(steps[i], style: i <= _done ? context.t.bodyStrong : context.t.body.copyWith(color: c.text3))),
                        ]),
                      ),
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: AppButton(
              approved ? 'Start earning' : 'Verifying…',
              onTap: approved ? () => Navigator.of(context).pushAndRemoveUntil(fadeRoute(const Shell()), (_) => false) : null,
            ),
          ),
        ]),
      ),
    );
  }
}
