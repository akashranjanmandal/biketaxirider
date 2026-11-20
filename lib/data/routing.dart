import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'net.dart';

/// A drivable route between two points.
class RouteInfo {
  final List<LatLng> points;
  final double meters;
  final double seconds;
  final List<double> _cumulative; // distance along the route at each point

  RouteInfo(this.points, this.meters, this.seconds) : _cumulative = _cumulate(points);

  double get km => meters / 1000;
  double get minutes => seconds / 60;

  static const _d = Distance();

  static List<double> _cumulate(List<LatLng> pts) {
    final out = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      out.add(out.last + _d.as(LengthUnit.Meter, pts[i - 1], pts[i]));
    }
    return out;
  }

  double get _length => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// Distance (m) along the route at each point.
  List<double> get cumulative => _cumulative;

  /// Length of the drawn line in metres (close to [meters]).
  double get length => _length;

  /// Position and heading (degrees, 0 = north) at fraction [t] (0..1) of the route.
  ({LatLng pos, double heading}) at(double t) {
    if (points.length < 2) return (pos: points.first, heading: 0);
    final target = _length * t.clamp(0.0, 1.0);
    var i = 1;
    while (i < _cumulative.length - 1 && _cumulative[i] < target) {
      i++;
    }
    final a = points[i - 1], b = points[i];
    final seg = _cumulative[i] - _cumulative[i - 1];
    final f = seg <= 0 ? 0.0 : (target - _cumulative[i - 1]) / seg;
    final pos = LatLng(a.latitude + (b.latitude - a.latitude) * f, a.longitude + (b.longitude - a.longitude) * f);
    return (pos: pos, heading: _d.bearing(a, b));
  }

  /// The part of the route from fraction [t] to the end.
  List<LatLng> remaining(double t) {
    if (t <= 0) return points;
    final here = at(t).pos;
    final target = _length * t.clamp(0.0, 1.0);
    final idx = _cumulative.indexWhere((d) => d >= target);
    return [here, if (idx >= 0) ...points.sublist(idx)];
  }

  /// The part of the route from the start to fraction [t].
  List<LatLng> travelled(double t) {
    if (t <= 0) return const [];
    final target = _length * t.clamp(0.0, 1.0);
    final idx = _cumulative.indexWhere((d) => d >= target);
    return [...points.sublist(0, idx < 0 ? points.length : idx), at(t).pos];
  }
}

final _cache = <String, RouteInfo>{};

/// Cached route between two points, if one was fetched already.
RouteInfo? cachedRoute(LatLng a, LatLng b) => _cache['${a.latitude},${a.longitude};${b.latitude},${b.longitude}'];

/// Fetches a real road route from the public OSRM server. Falls back to a gently
/// curved line if the network is unavailable, so the UI always has a route.
Future<RouteInfo> fetchRoute(LatLng a, LatLng b) async {
  final key = '${a.latitude},${a.longitude};${b.latitude},${b.longitude}';
  final cached = _cache[key];
  if (cached != null) return cached;
  try {
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${a.longitude},${a.latitude};${b.longitude},${b.latitude}?overview=full&geometries=geojson');
    final res = await http.get(uri, headers: {'User-Agent': 'AamarCaptain/1.0 (demo)'}).timeout(const Duration(seconds: 7));
    net.report(true);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes != null && routes.isNotEmpty) {
        final r = routes.first as Map<String, dynamic>;
        final coords = (r['geometry']['coordinates'] as List)
            .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
            .toList();
        if (coords.length >= 2) {
          final info = RouteInfo(coords, (r['distance'] as num).toDouble(), (r['duration'] as num).toDouble());
          return _cache[key] = info;
        }
      }
    }
  } catch (e) {
    // offline or rate-limited: fall through to the synthetic route
    if (isNetworkError(e)) net.report(false);
  }
  return _cache[key] = _fallback(a, b);
}

RouteInfo _fallback(LatLng a, LatLng b) {
  const n = 40;
  final dLat = b.latitude - a.latitude, dLng = b.longitude - a.longitude;
  final pts = <LatLng>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n;
    final bend = math.sin(t * math.pi) * .12;
    pts.add(LatLng(a.latitude + dLat * t - dLng * bend, a.longitude + dLng * t + dLat * bend));
  }
  final meters = const Distance().as(LengthUnit.Meter, a, b) * 1.3;
  return RouteInfo(pts, meters, meters / 6.5); // ~23 km/h city average
}
