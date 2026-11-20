import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/models.dart';
import '../forms.dart';
import '../kit.dart';
import 'registration.dart';
import 'shell.dart';

Route<T> fadeRoute<T>(Widget page, {int ms = 450}) => PageRouteBuilder<T>(
  transitionDuration: Duration(milliseconds: ms),
  reverseTransitionDuration: Duration(milliseconds: ms),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: child,
  ),
);

/// Small black "CAPTAIN" badge, as on the app icon (inverted in dark mode).
class CaptainBadge extends StatelessWidget {
  final double scale;
  const CaptainBadge({super.key, this.scale = 1});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9 * scale,
        vertical: 3.5 * scale,
      ),
      decoration: BoxDecoration(
        color: c.dark ? c.text : Brand.onPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'CAPTAIN',
        style: context.t.overline.copyWith(
          color: c.dark ? c.bg : Colors.white,
          fontSize: 10.5 * scale,
          letterSpacing: 1.4 * scale,
        ),
      ),
    );
  }
}

// ───────────────────────── Splash ─────────────────────────
/// Continues the native launch screen: the pin stays exactly where the native
/// splash drew it (pin centred, not the image box) while the wordmark and the
/// captain badge settle in beneath it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  Timer? _go;

  @override
  void initState() {
    super.initState();
    _go = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(fadeRoute(const WelcomeScreen(), ms: 600));
    });
  }

  @override
  void dispose() {
    _go?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final word = Curves.easeOutCubic.transform(
            (_c.value / .75).clamp(0.0, 1.0),
          );
          final badge = Curves.easeOutCubic.transform(
            ((_c.value - .25) / .75).clamp(0.0, 1.0),
          );
          return SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(-(kMarkCenterX - .5) * 128, 0),
                  child: const BrandMark(size: 128),
                ),
                Transform.translate(
                  offset: Offset(0, 84 + 10 * (1 - word)),
                  child: Opacity(
                    opacity: word,
                    child: const Wordmark(height: 28),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 122 + 8 * (1 - badge)),
                  child: Opacity(opacity: badge, child: const CaptainBadge()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Welcome ─────────────────────────
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pc = PageController();
  int _page = 0;
  Timer? _auto;

  static const _slides = [
    (
      Service.bike,
      'Earn on your schedule',
      'Go online whenever it suits you. No shifts, no fixed hours.',
    ),
    (
      Service.cabEconomy,
      'Daily payouts to your bank',
      'Online earnings reach your bank account every morning.',
    ),
    (
      Service.auto,
      'Zero commission on your first 50 rides',
      'Keep the full fare while you get started.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients) return;
      _pc.animateToPage(
        (_page + 1) % _slides.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  BrandMark(size: 34),
                  SizedBox(width: 10),
                  Wordmark(height: 20),
                  SizedBox(width: 8),
                  CaptainBadge(scale: .9),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (n) {
                  if (n.dragDetails != null) _auto?.cancel();
                  return false;
                },
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final s = _slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  margin: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: c.dark
                                        ? const Color(0xFFECEAE4)
                                        : c.surfaceAlt,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: FractionallySizedBox(
                                    widthFactor: .7,
                                    child: Image.asset(
                                      s.$1.artAsset,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(s.$2, style: context.t.display),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              s.$3,
                              style: context.t.secondary.copyWith(
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: kMedium,
                      curve: kEase,
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? c.text : c.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppButton(
                'Continue with phone number',
                icon: Symbols.call,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PhoneScreen())),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'By continuing, you agree to the Captain Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: context.t.caption.copyWith(color: c.text3),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Phone ─────────────────────────
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;

  String get _digits => _ctrl.text.replaceAll(' ', '');
  bool get _valid => _digits.length == 10;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid || _loading) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OtpScreen(phone: _digits)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: CircleButton(
            Symbols.arrow_back,
            size: 40,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Enter your mobile number', style: context.t.headline),
              const SizedBox(height: 8),
              Text(
                'We\'ll send you a 4-digit code to verify it.',
                style: context.t.secondary,
              ),
              const SizedBox(height: 28),
              AnimatedContainer(
                duration: kFast,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: _focus.hasFocus ? c.text : c.border,
                    width: _focus.hasFocus ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      '+91',
                      style: context.t.subtitle.copyWith(fontSize: 17),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: c.border,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [
                          AutofillHints.telephoneNumberNational,
                        ],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                          PhoneFormatter(),
                        ],
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _submit(),
                        style: context.t.subtitle.copyWith(
                          fontSize: 17,
                          letterSpacing: .8,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '98765 43210',
                          hintStyle: context.t.subtitle.copyWith(
                            fontSize: 17,
                            letterSpacing: .8,
                            color: c.text3,
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _valid ? 1 : 0,
                      duration: kMedium,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Icon(
                          Symbols.check_circle,
                          color: Brand.success,
                          fill: 1,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Symbols.info, size: 16, color: c.text3),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Demo build: any 10-digit number works.',
                      style: context.t.caption.copyWith(color: c.text3),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              AppButton(
                'Get OTP',
                loading: _loading,
                onTap: _valid ? _submit : null,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── OTP ─────────────────────────
class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  CodeState _state = CodeState.typing;
  int _shake = 0;
  int _left = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _left = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = math.max(0, _left - 1));
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_ctrl.text == kDemoOtp) {
      HapticFeedback.mediumImpact();
      setState(() => _state = CodeState.ok);
      captain.signIn(widget.phone);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      final next = captain.registered
          ? const Shell()
          : const RegistrationScreen();
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(next), (_) => false);
    } else {
      setState(() {
        _state = CodeState.wrong;
        _shake++;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _ctrl.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final phone =
        '+91 ${widget.phone.substring(0, 5)} ${widget.phone.substring(5)}';
    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: CircleButton(
            Symbols.arrow_back,
            size: 40,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('Enter the code', style: context.t.headline),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: Text('Sent to $phone', style: context.t.secondary),
                  ),
                  const SizedBox(width: 8),
                  Tappable(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Edit',
                      style: context.t.label.copyWith(color: c.accentText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              CodeInput(
                controller: _ctrl,
                focusNode: _focus,
                state: _state,
                shakeKey: _shake,
                onChanged: _onChanged,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 24,
                child: AnimatedSwitcher(
                  duration: kMedium,
                  child: switch (_state) {
                    CodeState.verifying => Row(
                      key: const ValueKey('v'),
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.text2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Verifying…', style: context.t.secondary),
                      ],
                    ),
                    CodeState.wrong => Row(
                      key: const ValueKey('w'),
                      children: [
                        const Icon(
                          Symbols.error,
                          size: 18,
                          color: Brand.danger,
                          fill: 1,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'That code isn\'t right. Try again.',
                            style: context.t.secondary.copyWith(
                              color: Brand.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    CodeState.ok => Row(
                      key: const ValueKey('o'),
                      children: [
                        const Icon(
                          Symbols.check_circle,
                          size: 18,
                          color: Brand.success,
                          fill: 1,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verified',
                          style: context.t.secondary.copyWith(
                            color: Brand.success,
                          ),
                        ),
                      ],
                    ),
                    _ => Row(
                      key: const ValueKey('t'),
                      children: [
                        if (_left > 0)
                          Text(
                            'Resend code in 0:${_left.toString().padLeft(2, '0')}',
                            style: context.t.secondary,
                          )
                        else
                          Tappable(
                            onTap: () {
                              setState(_startTimer);
                              showToast(context, 'Code sent again');
                            },
                            child: Text(
                              'Resend code',
                              style: context.t.label.copyWith(
                                color: c.accentText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  },
                ),
              ),
              const SizedBox(height: 22),
              DemoHint(
                text: 'Demo build: the code is $kDemoOtp',
                onFill: () {
                  _ctrl.text = kDemoOtp;
                  _onChanged(kDemoOtp);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Demo build: …" note with a Fill shortcut (OTP and rider PIN).
class DemoHint extends StatelessWidget {
  final String text;
  final VoidCallback onFill;
  const DemoHint({super.key, required this.text, required this.onFill});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Symbols.info, size: 18, color: c.text2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: context.t.label.copyWith(color: c.text2)),
          ),
          Tappable(
            onTap: onFill,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Fill',
                style: context.t.label.copyWith(color: c.accentText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
