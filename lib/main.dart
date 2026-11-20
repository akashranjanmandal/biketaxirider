import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/theme.dart';
import 'ui/screens/onboarding.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/google_fonts, never fetched at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const AamarCaptainApp());
}

class AamarCaptainApp extends StatelessWidget {
  const AamarCaptainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Aamar Captain',
        debugShowCheckedModeBanner: false,
        themeMode: themeController.mode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        builder: (context, child) {
          final c = context.c;
          // Keep text sizes sane even with very large system font settings.
          final mq = MediaQuery.of(context);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: (c.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
            ),
            child: MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: .9, maxScaleFactor: 1.2)),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
