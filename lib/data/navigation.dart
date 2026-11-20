import 'package:latlong2/latlong.dart';

import 'routing.dart';

enum Turn { straight, slightLeft, left, sharpLeft, slightRight, right, sharpRight, uTurn, arrive }

extension TurnInfo on Turn {
  String get verb => switch (this) {
        Turn.straight => 'Continue straight',
        Turn.slightLeft => 'Keep left',
        Turn.left => 'Turn left',
        Turn.sharpLeft => 'Turn sharp left',
        Turn.slightRight => 'Keep right',
        Turn.right => 'Turn right',
        Turn.sharpRight => 'Turn sharp right',
        Turn.uTurn => 'Make a U-turn',
        Turn.arrive => 'Arrive',
      };
}

/// One instruction: what to do [at] metres along the route.
class Maneuver {
  final double at;
  final Turn turn;
  final String street;
  const Maneuver(this.at, this.turn, this.street);
}

/// What the banner shows at a given moment.
class NavStep {
  final Turn turn;
  final String text;
  final double metersAway;
  const NavStep(this.turn, this.text, this.metersAway);

  /// "in 200 m", "in 1.2 km" or "Now".
  String get distance {
    if (metersAway < 25) return 'Now';
    if (metersAway < 1000) return 'in ${(metersAway / 10).round() * 10} m';
    return 'in ${(metersAway / 1000).toStringAsFixed(1)} km';
  }
}

/// Real roads around south and central Kolkata. Maneuvers get one of these
/// (picked from their position, so the same turn always has the same name).
const _streets = [
  'Gariahat Rd',
  'Rashbehari Ave',
  'Southern Ave',
  'Hazra Rd',
  'Sarat Bose Rd',
  'Ballygunge Circular Rd',
  'Syed Amir Ali Ave',
  'AJC Bose Rd',
  'Park Street',
  'Camac St',
  'Shakespeare Sarani',
  'Lake View Rd',
  'Purna Das Rd',
  'Dover Ln',
  'Bondel Rd',
  'Ashutosh Mukherjee Rd',
  'Chowringhee Rd',
  'Prince Anwar Shah Rd',
  'EM Bypass',
  'Jawaharlal Nehru Rd',
];

/// Simulated turn-by-turn guidance, derived from heading changes along a
/// route (the free routing server gives geometry only, not street names).
class NavGuide {
  final RouteInfo route;
  final String destination;
  late final List<Maneuver> maneuvers = _build();

  NavGuide(this.route, this.destination);

  static const _d = Distance();
  static const _window = 28.0; // metres of road to average a heading over
  static const _minGap = 70.0; // ignore wiggles closer than this

  List<Maneuver> _build() {
    final pts = route.points;
    final cum = route.cumulative;
    final out = <Maneuver>[];
    if (pts.length < 3) return out;
    double lastAt = -_minGap;
    for (var i = 1; i < pts.length - 1; i++) {
      final at = cum[i];
      if (at - lastAt < _minGap || route.length - at < 40) continue;
      final before = _pointAt(at - _window), after = _pointAt(at + _window);
      final hIn = _d.bearing(before, pts[i]), hOut = _d.bearing(pts[i], after);
      final delta = ((hOut - hIn + 540) % 360) - 180; // −180..180, negative = left
      final a = delta.abs();
      if (a < 30) continue;
      final turn = switch (a) {
        < 55 => delta < 0 ? Turn.slightLeft : Turn.slightRight,
        < 125 => delta < 0 ? Turn.left : Turn.right,
        < 160 => delta < 0 ? Turn.sharpLeft : Turn.sharpRight,
        _ => Turn.uTurn,
      };
      final key = (pts[i].latitude * 1e4).round() * 31 + (pts[i].longitude * 1e4).round();
      out.add(Maneuver(at, turn, _streets[key.abs() % _streets.length]));
      lastAt = at;
    }
    return out;
  }

  LatLng _pointAt(double meters) => route.at(route.length <= 0 ? 0 : (meters / route.length).clamp(0.0, 1.0)).pos;

  /// The next instruction when [progress] (0..1) of the route is done.
  NavStep stepAt(double progress) {
    final here = route.length * progress.clamp(0.0, 1.0);
    for (final m in maneuvers) {
      if (m.at > here - 8) {
        final text = m.turn == Turn.uTurn ? 'Make a U-turn on ${m.street}' : '${m.turn.verb} onto ${m.street}';
        return NavStep(m.turn, text, m.at - here);
      }
    }
    final left = route.length - here;
    if (left < 60) return NavStep(Turn.arrive, 'Arriving at $destination', left);
    return NavStep(Turn.straight, 'Continue to $destination', left);
  }
}
