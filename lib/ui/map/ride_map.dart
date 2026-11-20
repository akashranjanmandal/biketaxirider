import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../../data/captain_state.dart';
import '../../data/net.dart';
import '../../data/models.dart';
import '../kit.dart';
import 'vehicle_marker.dart';

const _esri = 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas';
const kMapAttribution = 'Esri, HERE, Garmin · © OpenStreetMap contributors';

/// Minimal grey basemap (Esri canvas) plus its street-name layer, tuned to the
/// app's light and dark palettes. No API key needed for demo use.
List<Widget> baseMapLayers(BuildContext context) {
  final dark = context.c.dark;
  final style = dark ? 'Dark' : 'Light';
  // light: steepen contrast so grey land/buildings separate from white roads
  const light = <double>[1.6, 0, 0, 0, -150, 0, 1.6, 0, 0, -150, 0, 0, 1.6, 0, -146, 0, 0, 0, 1, 0];
  const night = <double>[.62, 0, 0, 0, 0, 0, .63, 0, 0, 0, 0, 0, .68, 0, 0, 0, 0, 0, 1, 0];
  return [
    ColorFiltered(
      colorFilter: ColorFilter.matrix(dark ? night : light),
      child: TileLayer(
        urlTemplate: '$_esri/World_${style}_Gray_Base/MapServer/tile/{z}/{y}/{x}',
        maxNativeZoom: 16,
        userAgentPackageName: 'com.aamarbike.aamar_captain',
        tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 220)),
        errorTileCallback: _tileError,
      ),
    ),
    TileLayer(
      urlTemplate: '$_esri/World_${style}_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
      maxNativeZoom: 16,
      userAgentPackageName: 'com.aamarbike.aamar_captain',
      tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 220)),
      errorTileCallback: _tileError,
    ),
  ];
}

void _tileError(TileImage tile, Object error, StackTrace? stack) {
  if (isNetworkError(error)) net.report(false);
}

/// The captain's map: their vehicle, demand zones while online, and the
/// request / trip routes. The camera glides between views as the stage
/// changes. Only the live marker layer rebuilds every frame, and the frame
/// clock only runs while something on the map is moving.
class CaptainMap extends StatefulWidget {
  /// Screen area covered by UI (top bar, bottom panel); the camera frames the
  /// interesting part of the map inside what is left.
  final EdgeInsets padding;

  /// Close-up camera that follows the vehicle (the "Navigate" action).
  final bool navigate;

  const CaptainMap({super.key, this.padding = EdgeInsets.zero, this.navigate = false});

  @override
  State<CaptainMap> createState() => _CaptainMapState();
}

class _CaptainMapState extends State<CaptainMap> with TickerProviderStateMixin {
  final _map = MapController();
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final AnimationController _cam = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  LatLng _fromC = captain.position, _toC = captain.position;
  double _fromZ = 15.5, _toZ = 15.5;
  bool _ready = false;
  bool _follow = true;
  Timer? _refit;
  CaptainStage? _lastStage;
  TripSession? _session;
  bool _hadRoute = false;
  double _heading = captain.heading;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6);
    _cam.addListener(() {
      if (!_ready) return;
      final t = Curves.easeInOutCubic.transform(_cam.value);
      _map.move(
        LatLng(_fromC.latitude + (_toC.latitude - _fromC.latitude) * t, _fromC.longitude + (_toC.longitude - _fromC.longitude) * t),
        _fromZ + (_toZ - _fromZ) * t,
      );
    });
    captain.addListener(_onState);
    _refit = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      final st = captain.stage;
      if (_follow && (st == CaptainStage.toPickup || st == CaptainStage.onTrip)) _frame();
    });
    _onState();
  }

  @override
  void didUpdateWidget(CaptainMap old) {
    super.didUpdateWidget(old);
    if (old.padding != widget.padding || old.navigate != widget.navigate) {
      if (widget.navigate) _follow = true;
      _frame();
    }
  }

  @override
  void dispose() {
    captain.removeListener(_onState);
    _session?.removeListener(_onSession);
    _refit?.cancel();
    _ticker.dispose();
    _cam.dispose();
    _reveal.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    final s = captain.session;
    if (s != _session) {
      _session?.removeListener(_onSession);
      s?.addListener(_onSession);
      _session = s;
      _hadRoute = false;
    }
    // run the frame clock only while something moves (pulse, vehicle)
    final moving = captain.online || s != null;
    if (moving && !_ticker.isActive) _ticker.start();
    if (!moving && _ticker.isActive) {
      _ticker.stop();
      _clock.value = 0;
    }
    final stage = captain.stage;
    final hasRoute = s?.ready ?? false;
    if (stage != _lastStage || hasRoute != _hadRoute) {
      if (hasRoute && !_hadRoute) _reveal.forward(from: 0);
      _lastStage = stage;
      _hadRoute = hasRoute;
      _follow = true;
      _frame();
    }
    setState(() {}); // static layers (zones, drop) follow the stage
  }

  void _onSession() => _onState();

  /// Points the camera should keep in view right now, and the zoom to use
  /// when that's a single point.
  (List<LatLng>, double) _focus() {
    final s = captain.session;
    final stage = captain.stage;
    if (s == null) {
      if (stage == CaptainStage.online) return ([captain.position, for (final z in kDemandZones) z.center], 15);
      return ([captain.position], 15.5);
    }
    final v = s.vehicle().pos;
    switch (stage) {
      case CaptainStage.request:
        return ([s.start, s.pickup.pos, s.drop.pos, ...?s.approach?.points, ...?s.trip?.points], 15);
      case CaptainStage.toPickup:
        return widget.navigate ? ([v], 16.8) : ([v, s.pickup.pos], 16);
      case CaptainStage.arrived:
        return ([s.pickup.pos], 16.5);
      case CaptainStage.onTrip:
        final t = s.trip;
        if (widget.navigate || t == null) return ([v], 16.8);
        return ([v, t.at(math.min(1, s.tripProgress + .35)).pos], 16);
      default:
        return ([v], 16);
    }
  }

  void _frame({bool animate = true}) {
    if (!_ready || !mounted) return;
    final (pts, zoom) = _focus();
    final pad = widget.padding + const EdgeInsets.fromLTRB(40, 48, 40, 32);
    MapCamera target;
    if (pts.length < 2) {
      target = _map.camera.withPosition(center: pts.first, zoom: zoom);
      // shift so the point sits in the middle of the uncovered area
      final shift = (widget.padding.bottom - widget.padding.top) / 2;
      final px = target.projectAtZoom(pts.first, zoom) + Offset(0, shift);
      target = target.withPosition(center: target.unprojectAtZoom(px, zoom));
    } else {
      target = CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: pad, maxZoom: zoom).fit(_map.camera);
    }
    if (!animate) {
      _map.move(target.center, target.zoom);
      return;
    }
    _fromC = _map.camera.center;
    _fromZ = _map.camera.zoom;
    _toC = target.center;
    _toZ = target.zoom;
    _cam.forward(from: 0);
  }

  void _recenter() {
    setState(() => _follow = true);
    _frame();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stage = captain.stage;
    final s = captain.session;
    final showZones = stage == CaptainStage.online || stage == CaptainStage.request;
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: captain.position,
          initialZoom: 15.5,
          minZoom: 5,
          maxZoom: 17.5,
          backgroundColor: c.dark ? const Color(0xFF1A1B1F) : const Color(0xFFF2EFE9),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: () {
            _ready = true;
            _frame(animate: false);
          },
          onPositionChanged: (cam, gesture) {
            if (gesture && _follow) {
              _cam.stop();
              setState(() => _follow = false);
            }
          },
        ),
        children: [
          ...baseMapLayers(context),
          // offline: mute the map (a flat wash, no blur)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: captain.online ? 0 : 1,
              duration: kSlow,
              curve: kEase,
              child: ColoredBox(color: c.bg.withValues(alpha: c.dark ? .42 : .5), child: const SizedBox.expand()),
            ),
          ),
          AnimatedOpacity(opacity: showZones ? 1 : 0, duration: kSlow, curve: kEase, child: const _DemandZones()),
          if (s != null) _RouteLayer(session: s, reveal: _reveal),
          MarkerLayer(markers: [
            if (showZones)
              for (final z in kDemandZones) Marker(point: z.center, width: 200, height: 40, child: _ZoneChip(z)),
            if (s != null && stage != CaptainStage.arrived)
              Marker(point: s.drop.pos, width: 240, height: 100, child: DropMarker(name: s.drop.name)),
          ]),
          ValueListenableBuilder<double>(
            valueListenable: _clock,
            builder: (context, t, _) => MarkerLayer(markers: _live(context, t)),
          ),
        ],
      ),
      // attribution (required by OpenStreetMap / Esri)
      Positioned(
        left: 10,
        bottom: widget.padding.bottom + 6,
        child: IgnorePointer(child: Text(kMapAttribution, style: context.t.caption.copyWith(fontSize: 9.5, color: c.text3))),
      ),
      Positioned(
        right: 16,
        bottom: widget.padding.bottom + 16,
        child: AnimatedScale(
          scale: _follow ? 0 : 1,
          duration: kMedium,
          curve: kEase,
          child: CircleButton(Symbols.my_location, elevated: true, onTap: _recenter),
        ),
      ),
    ]);
  }

  /// Markers that move or pulse: rebuilt every frame.
  List<Marker> _live(BuildContext context, double t) {
    final s = captain.session;
    final stage = captain.stage;
    final out = <Marker>[];

    if (s != null && (stage == CaptainStage.request || stage == CaptainStage.toPickup || stage == CaptainStage.arrived)) {
      final label = switch (stage) {
        CaptainStage.request => 'Pickup · ${s.pickupMinutes} min',
        CaptainStage.toPickup => '${s.pickup.name} · ${s.minutesLeft} min',
        _ => s.rider.firstName,
      };
      out.add(Marker(point: s.pickup.pos, width: 240, height: 120, child: PickupMarker(t: t, label: label, pulse: true)));
    }

    final v = s?.vehicle() ?? (pos: captain.position, heading: captain.heading);
    // ease the rotation so the vehicle turns smoothly at corners
    final diff = ((v.heading - _heading + 540) % 360) - 180;
    _heading = (_heading + diff * .12) % 360;
    if (stage == CaptainStage.online) {
      final ph = (t * .5) % 1;
      out.add(Marker(
        point: v.pos,
        width: 120,
        height: 120,
        child: Center(
          child: Container(
            width: 30 + ph * 80,
            height: 30 + ph * 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Brand.primary.withValues(alpha: .26 * (1 - ph))),
          ),
        ),
      ));
    }
    out.add(Marker(
      point: v.pos,
      width: 76,
      height: 76,
      child: RepaintBoundary(child: VehicleMarker(service: s?.service ?? captain.vehicle, heading: _heading, scale: 1.3)),
    ));
    return out;
  }
}

/// Soft translucent circles where demand is high (static).
class _DemandZones extends StatelessWidget {
  const _DemandZones();
  @override
  Widget build(BuildContext context) {
    final dark = context.c.dark;
    final tone = dark ? Brand.primary : Brand.orange;
    return CircleLayer(circles: [
      for (final z in kDemandZones) ...[
        CircleMarker(point: z.center, radius: z.radius, useRadiusInMeter: true, color: tone.withValues(alpha: .08)),
        CircleMarker(point: z.center, radius: z.radius * .7, useRadiusInMeter: true, color: tone.withValues(alpha: .09)),
        CircleMarker(point: z.center, radius: z.radius * .4, useRadiusInMeter: true, color: tone.withValues(alpha: .11)),
      ],
    ]);
  }
}

class _ZoneChip extends StatelessWidget {
  final DemandZone zone;
  const _ZoneChip(this.zone);
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), boxShadow: shadow(c)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Symbols.trending_up, size: 15, color: c.accentText, weight: 600),
          const SizedBox(width: 5),
          Text(zone.label, style: context.t.label.copyWith(fontSize: 12)),
        ]),
      ),
    );
  }
}

class _RouteLayer extends StatelessWidget {
  final TripSession session;
  final Animation<double> reveal;
  const _RouteLayer({required this.session, required this.reveal});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([session, reveal]),
      builder: (context, _) {
        final lines = <Polyline>[];
        final ink = c.dark ? const Color(0xFFF4F4F6) : const Color(0xFF15161A);
        final casing = c.dark ? const Color(0xFF0D0E11) : Colors.white;
        final approach = session.approach, trip = session.trip;
        final r = Curves.easeInOutCubic.transform(reveal.value);
        Polyline solid(List<LatLng> pts) => Polyline(points: pts, strokeWidth: 5.5, color: ink, borderStrokeWidth: 2, borderColor: casing);
        switch (session.stage) {
          case CaptainStage.request:
            // preview: dashed way to the pickup, then the trip itself
            if (approach != null) {
              final pts = r >= 1 ? approach.points : approach.travelled(r);
              if (pts.length >= 2) lines.add(Polyline(points: pts, strokeWidth: 4, color: c.text2, pattern: StrokePattern.dashed(segments: const [10, 8])));
            }
            if (trip != null) {
              final pts = r >= 1 ? trip.points : trip.travelled(r);
              if (pts.length >= 2) lines.add(solid(pts));
            }
          case CaptainStage.toPickup:
            if (approach != null) {
              final rem = approach.remaining(session.approachProgress);
              if (rem.length >= 2) lines.add(solid(rem));
            }
          case CaptainStage.arrived:
            break;
          default:
            if (trip != null) {
              final p = session.tripProgress;
              final done = trip.travelled(p);
              if (done.length >= 2) lines.add(Polyline(points: done, strokeWidth: 5, color: c.text3.withValues(alpha: .6)));
              final rem = trip.remaining(p);
              if (rem.length >= 2) lines.add(solid(rem));
            }
        }
        return PolylineLayer(polylines: lines);
      },
    );
  }
}

class PickupMarker extends StatelessWidget {
  final double t;
  final String? label;
  final bool pulse;
  const PickupMarker({super.key, required this.t, this.label, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ph = (t * .6) % 1;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      if (pulse)
        Container(
          width: 22 + ph * 70,
          height: 22 + ph * 70,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Brand.primary.withValues(alpha: .28 * (1 - ph))),
        ),
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Brand.primary,
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: shadow(c),
        ),
      ),
      if (label != null) Positioned(top: 8, child: MapChip(label!)),
    ]);
  }
}

class DropMarker extends StatelessWidget {
  final String name;
  final String? sub;
  const DropMarker({super.key, required this.name, this.sub});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(3), boxShadow: shadow(c)),
        child: Center(child: Container(width: 6, height: 6, color: c.bg)),
      ),
      Positioned(top: 2, child: MapChip(name, sub: sub)),
    ]);
  }
}

class MapChip extends StatelessWidget {
  final String text;
  final String? sub;
  const MapChip(this.text, {super.key, this.sub});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), boxShadow: shadow(c)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.t.label.copyWith(fontSize: 12.5))),
        if (sub != null) ...[
          const SizedBox(width: 6),
          Text(sub!, style: context.t.caption.copyWith(fontSize: 12)),
        ],
      ]),
    );
  }
}
