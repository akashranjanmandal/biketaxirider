import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand constants (from the Aamar Bike logo).
class Brand {
  static const primary = Color(0xFFFFC414); // logo yellow
  static const onPrimary = Color(0xFF0F1013);
  static const orange = Color(0xFFFF9500); // logo gradient end, used sparingly
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFE5484D);
}

/// Theme-dependent colour tokens.
@immutable
class AppColors {
  final bool dark;
  final Color bg, surface, surfaceAlt, sunken, border, text, text2, text3, accentText, selectedBg, scrim;

  const AppColors._({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.sunken,
    required this.border,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accentText,
    required this.selectedBg,
    required this.scrim,
  });

  static const light = AppColors._(
    dark: false,
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F4F6),
    sunken: Color(0xFFECECEF),
    border: Color(0xFFE6E6EA),
    text: Color(0xFF0F1013),
    text2: Color(0xFF5D606B),
    text3: Color(0xFF9497A1),
    accentText: Color(0xFFB26A00), // readable amber for links on white
    selectedBg: Color(0xFFFFF7DC),
    scrim: Color(0x66000000),
  );

  static const darkTheme = AppColors._(
    dark: true,
    bg: Color(0xFF0D0E11),
    surface: Color(0xFF15161A),
    surfaceAlt: Color(0xFF1D1E23),
    sunken: Color(0xFF24252B),
    border: Color(0xFF2A2B31),
    text: Color(0xFFF4F4F6),
    text2: Color(0xFFA3A5AE),
    text3: Color(0xFF6E707A),
    accentText: Brand.primary,
    selectedBg: Color(0xFF2A2412),
    scrim: Color(0x99000000),
  );
}

/// Type scale — one family (Plus Jakarta Sans), a few deliberate sizes.
class AppType {
  final AppColors c;
  const AppType(this.c);

  static TextStyle _f(double size, FontWeight w, Color color, {double ls = 0, double? h}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: h);

  TextStyle get display => _f(30, FontWeight.w700, c.text, ls: -0.9, h: 1.15);
  TextStyle get headline => _f(22, FontWeight.w700, c.text, ls: -0.5, h: 1.2);
  TextStyle get title => _f(18, FontWeight.w700, c.text, ls: -0.3, h: 1.25);
  TextStyle get subtitle => _f(16, FontWeight.w600, c.text, ls: -0.2, h: 1.3);
  TextStyle get body => _f(15, FontWeight.w500, c.text, ls: -0.1, h: 1.4);
  TextStyle get bodyStrong => _f(15, FontWeight.w600, c.text, ls: -0.1, h: 1.35);
  TextStyle get secondary => _f(14, FontWeight.w500, c.text2, h: 1.4);
  TextStyle get label => _f(13, FontWeight.w600, c.text, h: 1.3);
  TextStyle get caption => _f(12.5, FontWeight.w500, c.text2, h: 1.35);
  TextStyle get overline => _f(11.5, FontWeight.w700, c.text3, ls: 0.6);
  TextStyle get price => _f(17, FontWeight.w700, c.text, ls: -0.3);
  TextStyle get button => _f(16, FontWeight.w700, Brand.onPrimary, ls: -0.1);
}

extension ThemeX on BuildContext {
  AppColors get c => Theme.of(this).brightness == Brightness.dark ? AppColors.darkTheme : AppColors.light;
  AppType get t => AppType(c);
}

class Radii {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  set mode(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
  }
}

final themeController = ThemeController();

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.darkTheme : AppColors.light;
  final family = GoogleFonts.plusJakartaSans().fontFamily;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: family,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.primary,
      brightness: brightness,
      primary: Brand.primary,
      onPrimary: Brand.onPrimary,
      surface: c.surface,
      onSurface: c.text,
    ),
    dividerColor: c.border,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.text,
      selectionColor: Brand.primary.withValues(alpha: .35),
      selectionHandleColor: Brand.primary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: c.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.scrim,
      showDragHandle: false,
    ),
  );
  return base;
}
