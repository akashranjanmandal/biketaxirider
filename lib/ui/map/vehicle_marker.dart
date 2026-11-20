import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

/// Top-down vehicle icon for the map, drawn as vectors so it stays crisp at
/// any size and rotates cleanly with the direction of travel.
/// [heading] is in degrees, 0 = north (vehicle pointing up the screen).
class VehicleMarker extends StatelessWidget {
  final Service service;
  final double heading;
  final double scale;
  final double opacity;
  const VehicleMarker({super.key, required this.service, this.heading = 0, this.scale = 1, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    final spec = _VehicleSpec.of(service);
    final size = Size(spec.width * scale, spec.length * scale);
    final painter = _VehiclePainter(spec);
    return Opacity(
      opacity: opacity,
      child: Center(
        child: Transform.rotate(
          angle: heading * math.pi / 180,
          child: Stack(alignment: Alignment.center, children: [
            // white outline so the vehicle reads on any map background
            ImageFiltered(
              imageFilter: ui.ImageFilter.dilate(radiusX: 1.8 * scale, radiusY: 1.8 * scale),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: CustomPaint(size: size, painter: painter),
              ),
            ),
            CustomPaint(size: size, painter: painter),
          ]),
        ),
      ),
    );
  }
}

enum _Kind { car, bike, threeWheeler }

class _VehicleSpec {
  final _Kind kind;
  final double width, length;
  final Color body, roof;
  final bool parcelBox;
  const _VehicleSpec(this.kind, this.width, this.length, this.body, this.roof, {this.parcelBox = false});

  static _VehicleSpec of(Service s) => switch (s) {
        Service.bike => const _VehicleSpec(_Kind.bike, 17, 38, Color(0xFF1E2026), Brand.primary),
        Service.parcel => const _VehicleSpec(_Kind.bike, 17, 40, Color(0xFF1E2026), Brand.primary, parcelBox: true),
        Service.auto => const _VehicleSpec(_Kind.threeWheeler, 20, 34, Color(0xFF15803D), Color(0xFFFFC414)),
        Service.eRickshaw => const _VehicleSpec(_Kind.threeWheeler, 20, 34, Color(0xFF15803D), Color(0xFF22C55E)),
        Service.cabPremium => const _VehicleSpec(_Kind.car, 20, 42, Color(0xFF1B1C21), Color(0xFF2B2D34)),
        Service.cabXl => const _VehicleSpec(_Kind.car, 22, 46, Color(0xFFB9BDC6), Color(0xFFA9AEB8)),
        _ => const _VehicleSpec(_Kind.car, 20, 42, Color(0xFFF6F6F4), Color(0xFFE6E6E2)),
      };
}

class _VehiclePainter extends CustomPainter {
  final _VehicleSpec spec;
  _VehiclePainter(this.spec);

  static const _glass = Color(0xFF2B313C);
  static const _tyre = Color(0xFF16171B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, l = size.height;
    final k = w / spec.width; // scale factor vs. the spec's base size
    switch (spec.kind) {
      case _Kind.car:
        _car(canvas, w, l, k);
      case _Kind.bike:
        _bike(canvas, w, l, k);
      case _Kind.threeWheeler:
        _threeWheeler(canvas, w, l, k);
    }
  }

  void _shadow(Canvas c, RRect r, double k) {
    c.drawRRect(
      r.shift(Offset(0, 1.6 * k)).inflate(.6 * k),
      Paint()
        ..color = Colors.black.withValues(alpha: .28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.4 * k),
    );
  }

  void _car(Canvas c, double w, double l, double k) {
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w, l),
      topLeft: Radius.elliptical(w * .42, l * .16),
      topRight: Radius.elliptical(w * .42, l * .16),
      bottomLeft: Radius.elliptical(w * .36, l * .1),
      bottomRight: Radius.elliptical(w * .36, l * .1),
    );
    _shadow(c, body, k);
    // mirrors
    final mirror = Paint()..color = spec.body;
    c.drawOval(Rect.fromCenter(center: Offset(-.6 * k, l * .33), width: 3.2 * k, height: 2.2 * k), mirror);
    c.drawOval(Rect.fromCenter(center: Offset(w + .6 * k, l * .33), width: 3.2 * k, height: 2.2 * k), mirror);
    // body with a soft side-to-side highlight
    c.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(colors: [
          Color.lerp(spec.body, Colors.black, .12)!,
          Color.lerp(spec.body, Colors.white, .18)!,
          Color.lerp(spec.body, Colors.black, .12)!,
        ]).createShader(Rect.fromLTWH(0, 0, w, l)),
    );
    c.drawRRect(body, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 * k
      ..color = Colors.black.withValues(alpha: .28));
    // windscreen
    final ws = Path()
      ..moveTo(w * .14, l * .37)
      ..quadraticBezierTo(w * .5, l * .33, w * .86, l * .37)
      ..lineTo(w * .78, l * .2)
      ..quadraticBezierTo(w * .5, l * .17, w * .22, l * .2)
      ..close();
    c.drawPath(ws, Paint()..color = _glass);
    c.drawPath(
      Path()
        ..moveTo(w * .3, l * .21)
        ..lineTo(w * .45, l * .21)
        ..lineTo(w * .36, l * .3)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .18),
    );
    // roof
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(w * .16, l * .39, w * .84, l * .72), Radius.circular(w * .2)),
      Paint()..color = spec.roof,
    );
    // rear window
    final rw = Path()
      ..moveTo(w * .18, l * .74)
      ..quadraticBezierTo(w * .5, l * .77, w * .82, l * .74)
      ..lineTo(w * .76, l * .84)
      ..quadraticBezierTo(w * .5, l * .86, w * .24, l * .84)
      ..close();
    c.drawPath(rw, Paint()..color = _glass);
    // lights
    final head = Paint()..color = const Color(0xFFFFF4C2);
    c.drawOval(Rect.fromCenter(center: Offset(w * .2, l * .045), width: w * .22, height: 2.2 * k), head);
    c.drawOval(Rect.fromCenter(center: Offset(w * .8, l * .045), width: w * .22, height: 2.2 * k), head);
    final tail = Paint()..color = const Color(0xFFE5484D);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .1, l - 2.4 * k, w * .2, 1.6 * k), Radius.circular(k)), tail);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .7, l - 2.4 * k, w * .2, 1.6 * k), Radius.circular(k)), tail);
  }

  void _bike(Canvas c, double w, double l, double k) {
    final cx = w / 2;
    final frame = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, l * .5), width: w * .36, height: l * .92), Radius.circular(w * .2));
    _shadow(c, RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, l * .5), width: w * .7, height: l * .9), Radius.circular(w * .35)), k);
    // tyres
    final tyre = Paint()..color = _tyre;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, l * .1), width: w * .3, height: l * .2), Radius.circular(w * .15)), tyre);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, l * .88), width: w * .34, height: l * .22), Radius.circular(w * .17)), tyre);
    // body / tank
    c.drawRRect(frame, Paint()..color = spec.body);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, l * .34), width: w * .5, height: l * .16), Radius.circular(w * .25)),
      Paint()..color = Brand.primary,
    );
    // handlebar
    final bar = Paint()
      ..color = _tyre
      ..strokeWidth = 1.8 * k
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(w * .02, l * .24), Offset(w * .98, l * .24), bar);
    // headlight
    c.drawCircle(Offset(cx, l * .02), 1.2 * k, Paint()..color = const Color(0xFFFFF4C2));
    if (spec.parcelBox) {
      final box = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, l * .76), width: w * 1.0, height: l * .26), Radius.circular(1.6 * k));
      c.drawRRect(box, Paint()..color = const Color(0xFFFF9500));
      c.drawRRect(box, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7 * k
        ..color = Colors.black.withValues(alpha: .3));
      c.drawLine(Offset(cx, l * .64), Offset(cx, l * .89), Paint()
        ..color = Colors.black.withValues(alpha: .25)
        ..strokeWidth = .8 * k);
    }
    // rider: shoulders + helmet
    c.drawOval(Rect.fromCenter(center: Offset(cx, l * .52), width: w * .92, height: l * .2), Paint()..color = const Color(0xFF2E3138));
    c.drawCircle(Offset(cx, l * .47), w * .3, Paint()..color = spec.roof);
    c.drawCircle(Offset(cx, l * .47), w * .3, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 * k
      ..color = Colors.black.withValues(alpha: .3));
    c.drawArc(Rect.fromCircle(center: Offset(cx, l * .47), radius: w * .22), math.pi * 1.15, math.pi * .7, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..color = _glass);
  }

  void _threeWheeler(Canvas c, double w, double l, double k) {
    // narrower nose, wide rear, like an auto-rickshaw canopy from above
    final shell = Path()
      ..moveTo(w * .3, 0)
      ..quadraticBezierTo(w * .5, -l * .02, w * .7, 0)
      ..quadraticBezierTo(w * .98, l * .28, w, l * .5)
      ..lineTo(w, l * .9)
      ..quadraticBezierTo(w, l, w * .86, l)
      ..lineTo(w * .14, l)
      ..quadraticBezierTo(0, l, 0, l * .9)
      ..lineTo(0, l * .5)
      ..quadraticBezierTo(w * .02, l * .28, w * .3, 0)
      ..close();
    c.drawPath(
      shell.shift(Offset(0, 1.6 * k)),
      Paint()
        ..color = Colors.black.withValues(alpha: .28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.4 * k),
    );
    c.drawPath(shell, Paint()..color = spec.body);
    // canopy roof
    final roof = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * .1, l * .3, w * .9, l * .95),
      topLeft: Radius.circular(w * .3),
      topRight: Radius.circular(w * .3),
      bottomLeft: Radius.circular(w * .12),
      bottomRight: Radius.circular(w * .12),
    );
    c.drawRRect(
      roof,
      Paint()
        ..shader = LinearGradient(colors: [
          Color.lerp(spec.roof, Colors.black, .1)!,
          Color.lerp(spec.roof, Colors.white, .15)!,
          Color.lerp(spec.roof, Colors.black, .1)!,
        ]).createShader(roof.outerRect),
    );
    // roof ribs
    final rib = Paint()
      ..color = Colors.black.withValues(alpha: .12)
      ..strokeWidth = .8 * k;
    for (final f in [.5, .65, .8]) {
      c.drawLine(Offset(w * .14, l * f), Offset(w * .86, l * f), rib);
    }
    // windscreen
    final ws = Path()
      ..moveTo(w * .26, l * .27)
      ..quadraticBezierTo(w * .5, l * .24, w * .74, l * .27)
      ..lineTo(w * .64, l * .12)
      ..quadraticBezierTo(w * .5, l * .1, w * .36, l * .12)
      ..close();
    c.drawPath(ws, Paint()..color = _glass);
    c.drawCircle(Offset(w * .5, l * .03), 1.3 * k, Paint()..color = const Color(0xFFFFF4C2));
    c.drawPath(shell, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7 * k
      ..color = Colors.black.withValues(alpha: .28));
  }

  @override
  bool shouldRepaint(_VehiclePainter old) => old.spec != spec;
}
