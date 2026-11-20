import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'navigation.dart';
import 'net.dart';
import 'routing.dart';

/// Demo login: any 10-digit number, OTP is always this.
const kDemoOtp = '1234';

/// Every demo rider shares this ride PIN.
const kDemoPin = '4821';

/// Free waiting at the pickup, then ₹1 a minute.
const kFreeWaitSecs = 180;

/// New captains pay no platform fee on their first rides.
const kZeroCommissionRides = 50;

enum CaptainStage { offline, online, request, toPickup, arrived, onTrip, collect, summary }

extension CaptainStageX on CaptainStage {
  /// A request or trip owns the screen (bottom bar hidden, can't go offline).
  bool get busy => index >= CaptainStage.request.index;
}

const _d = Distance();

double _secsSince(DateTime? t) => t == null ? 0 : clock.now().difference(t).inMicroseconds / 1e6;

// ───────────────────────── one request / trip ─────────────────────────

/// A single ride request, from the moment it is offered to the trip summary.
/// Progress is computed from wall-clock time, so the map can interpolate the
/// vehicle every frame while this object only notifies a few times a second.
class TripSession extends ChangeNotifier {
  final int id;
  final Rider rider;
  final Service service;
  final Place pickup, drop;
  final LatLng start; // where the captain was when the request came in
  final Pay pay;
  final DemandZone? zone;
  final double tip; // riders paying online sometimes tip; shown after payment
  final String pin = kDemoPin;

  TripSession({
    required this.id,
    required this.rider,
    required this.service,
    required this.pickup,
    required this.drop,
    required this.start,
    required this.pay,
    this.zone,
    this.tip = 0,
  });

  CaptainStage stage = CaptainStage.request;

  RouteInfo? approach, trip;
  NavGuide? approachGuide, tripGuide;
  bool get ready => approach != null && trip != null;

  DateTime? requestAt, toPickupAt, arrivedAt, onTripAt, endedAt;
  double approachSecs = 18, tripSecs = 28;
  double _endProgress = 1;
  bool reachedDrop = false;
  int? riderStars;
  TripRecord? record;
  String? cancelReason;
  bool _disposed = false;

  static const requestSecs = 15.0;

  Future<void> load() async {
    final r = await Future.wait([fetchRoute(start, pickup.pos), fetchRoute(pickup.pos, drop.pos)]);
    if (_disposed) return;
    approach = r[0];
    trip = r[1];
    approachGuide = NavGuide(r[0], pickup.name);
    tripGuide = NavGuide(r[1], drop.name);
    notifyListeners();
  }

  double get pickupKm => approach?.km ?? _d.as(LengthUnit.Meter, start, pickup.pos) / 1000 * 1.3;
  int get pickupMinutes => math.max(1, ((approach?.minutes ?? pickupKm * 2.6) * service.speedFactor).ceil());
  double get tripKm => trip?.km ?? _d.as(LengthUnit.Meter, pickup.pos, drop.pos) / 1000 * 1.3;
  int get tripMinutes => math.max(1, ((trip?.minutes ?? tripKm * 2.6) * service.speedFactor).ceil());

  /// Upfront ride fare, including any demand multiplier.
  double get fare => (service.fareFor(tripKm) * (zone?.multiplier ?? 1)).roundToDouble();

  /// Seconds left to accept the request.
  double get requestLeft => (requestSecs - _secsSince(requestAt)).clamp(0.0, requestSecs);

  double get approachProgress => switch (stage) {
        CaptainStage.toPickup => (_secsSince(toPickupAt) / approachSecs).clamp(0.0, 1.0),
        CaptainStage.request => 0,
        _ => 1,
      };

  double get tripProgress => switch (stage) {
        CaptainStage.onTrip => (_secsSince(onTripAt) / tripSecs).clamp(0.0, 1.0),
        CaptainStage.collect || CaptainStage.summary => _endProgress,
        _ => 0,
      };

  /// Seconds spent waiting at the pickup.
  int get waitingSecs {
    final a = arrivedAt;
    if (a == null) return 0;
    final end = onTripAt ?? (stage == CaptainStage.arrived ? clock.now() : a);
    return end.difference(a).inSeconds;
  }

  /// ₹1 for every started minute after the free wait.
  double get waitingCharge => waitingSecs <= kFreeWaitSecs ? 0 : ((waitingSecs - kFreeWaitSecs) / 60).ceil().toDouble();

  /// What the rider pays (ride + waiting). Tips come on top for online payments.
  double get total => fare + waitingCharge;

  double get kmLeft => switch (stage) {
        CaptainStage.toPickup => pickupKm * (1 - approachProgress),
        CaptainStage.onTrip => tripKm * (1 - tripProgress),
        _ => 0,
      };

  int get minutesLeft => switch (stage) {
        CaptainStage.toPickup => math.max(1, (pickupMinutes * (1 - approachProgress)).ceil()),
        CaptainStage.onTrip => math.max(1, (tripMinutes * (1 - tripProgress)).ceil()),
        _ => 0,
      };

  /// Turn-by-turn instruction for the current leg.
  NavStep? get navStep => switch (stage) {
        CaptainStage.toPickup => approachGuide?.stepAt(approachProgress),
        CaptainStage.onTrip => tripGuide?.stepAt(tripProgress),
        _ => null,
      };

  /// Where the captain's vehicle is right now, and which way it faces.
  ({LatLng pos, double heading}) vehicle() {
    final a = approach, t = trip;
    switch (stage) {
      case CaptainStage.request:
        return (pos: start, heading: a == null ? 0 : a.at(0).heading);
      case CaptainStage.toPickup:
        return a == null ? (pos: start, heading: 0) : a.at(approachProgress);
      case CaptainStage.arrived:
        return (pos: pickup.pos, heading: a == null ? 0 : a.at(1).heading);
      default:
        return t == null ? (pos: pickup.pos, heading: 0) : t.at(tripProgress);
    }
  }

  void _go(CaptainStage s) {
    stage = s;
    final now = clock.now();
    switch (s) {
      case CaptainStage.request:
        requestAt = now;
      case CaptainStage.toPickup:
        toPickupAt = now;
        approachSecs = (pickupKm * 7).clamp(14.0, 26.0);
      case CaptainStage.arrived:
        arrivedAt = now;
      case CaptainStage.onTrip:
        onTripAt = now;
        tripSecs = (tripKm * 4.5).clamp(22.0, 40.0);
      case CaptainStage.collect:
        _endProgress = (_secsSince(onTripAt) / tripSecs).clamp(0.0, 1.0);
        endedAt = now;
      default:
        break;
    }
    notifyListeners();
  }

  void tick() {
    if (!_disposed) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// ───────────────────────── the captain ─────────────────────────

enum NoticeKind { incentive, document, payout, info }

class CaptainNotice {
  final NoticeKind kind;
  final String title, body;
  final DateTime when;
  const CaptainNotice(this.kind, this.title, this.body, this.when);
}

/// An incentive target and how far along the captain is.
class IncentiveProgress {
  final String key, title, sub;
  final int done, target;
  final double reward;
  const IncentiveProgress(this.key, this.title, this.sub, this.done, this.target, this.reward);
  bool get complete => done >= target;
  double get fraction => (done / target).clamp(0.0, 1.0);
}

enum Period { today, week, month }

/// Earnings for a period, with a breakdown that adds up.
class EarningsReport {
  final double fares, tips, incentives, fees, cash, online, km;
  final int rides;
  final Duration onlineTime;
  final List<({String label, double amount})> bars;
  const EarningsReport({
    required this.fares,
    required this.tips,
    required this.incentives,
    required this.fees,
    required this.cash,
    required this.online,
    required this.km,
    required this.rides,
    required this.onlineTime,
    required this.bars,
  });

  double get total => fares + tips + incentives - fees;
}

/// App-wide captain state: account, duty status, the active request and the
/// earnings ledger. Drives the ride state machine with timers:
/// offline → online → request → toPickup → arrived → onTrip → collect → summary.
class CaptainState extends ChangeNotifier {
  // account
  bool signedIn = false;
  bool registered = false;
  String phone = '';
  String name = '';
  String city = 'Kolkata';
  Set<String> languages = {'Bengali', 'Hindi'};
  Service vehicle = Service.bike;
  String plate = '';
  Map<DocKind, DocStatus> docs = {for (final d in DocKind.values) d: DocStatus.missing};
  String bankAccount = '', ifsc = '', holder = '';

  // duty
  bool online = false;
  DateTime? onlineSince;
  Duration _onlineBefore = Duration.zero; // today, before the current session
  LatLng position = kCaptainStart;
  double heading = 20;
  TripSession? session;
  TripSession? _pending;
  DateTime? missedAt;
  Timer? _next, _tick, _missTimer;
  int _requestNo = 0;

  // ledger
  final List<TripRecord> trips = [];
  final List<Payout> payouts = [];
  final List<IncentiveCredit> credits = [];
  final List<CaptainNotice> notices = [];
  final Set<String> _creditedKeys = {};
  final Map<DateTime, Duration> _onlineByDay = {};
  double wallet = 0;
  int lifetimeRides = 0;
  int offered = 0, accepted = 0;
  double rating = 4.92;
  DateTime joined = clock.now();

  CaptainStage get stage => session?.stage ?? (online ? CaptainStage.online : CaptainStage.offline);

  String get firstName => name.trim().isEmpty ? 'Captain' : name.trim().split(' ').first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    return parts.take(2).map((e) => e[0].toUpperCase()).join();
  }

  String get phoneFormatted => phone.length == 10 ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}' : '+91 $phone';
  String get vehicleModel => captainFor(vehicle).vehicle;
  String get plateOrDefault => plate.trim().isEmpty ? captainFor(vehicle).plate : plate.trim().toUpperCase();
  String get bankName => bankForIfsc(ifsc) ?? 'Bank';
  String get bankMasked => bankAccount.length >= 4 ? '••${bankAccount.substring(bankAccount.length - 4)}' : '••••';

  int get acceptanceRate => offered == 0 ? 100 : (accepted * 100 / offered).round();
  int get cancellationRate {
    final cancelled = trips.where((t) => !t.completed).length;
    return trips.isEmpty ? 0 : (cancelled * 100 / trips.length).round();
  }

  int get zeroCommissionLeft => math.max(0, kZeroCommissionRides - lifetimeRides);
  double feeFor(double fare) => lifetimeRides < kZeroCommissionRides ? 0 : (fare * .1).roundToDouble();

  // ───────── account ─────────

  void signIn(String phoneNumber) {
    phone = phoneNumber;
    signedIn = true;
    notifyListeners();
    _prepare(); // fetch the first request's routes in the background
  }

  void setName(String n) {
    name = n;
    notifyListeners();
  }

  void setDoc(DocKind k, DocStatus s) {
    docs[k] = s;
    notifyListeners();
  }

  bool get docsComplete => kRegistrationDocs.every((d) => docs[d] == DocStatus.verified);

  /// Called when verification finishes: activates the account and fills in a
  /// few weeks of history so every screen has realistic data.
  void completeRegistration() {
    registered = true;
    for (final d in [DocKind.insurance, DocKind.puc]) {
      docs[d] = DocStatus.verified;
    }
    _seed();
    _prepare();
    notifyListeners();
  }

  /// Expiry date of a document (null if it doesn't expire).
  DateTime? expiryOf(DocKind k) {
    final m = k.validMonths;
    if (m == null) return null;
    final base = DateTime(joined.year, joined.month, joined.day);
    return m == 0 ? base.add(const Duration(days: 45)) : DateTime(base.year, base.month + m, base.day);
  }

  bool expiringSoon(DocKind k) {
    final e = expiryOf(k);
    return e != null && e.difference(clock.now()).inDays < 30;
  }

  void signOut() {
    reset();
    notifyListeners();
  }

  /// Clears everything (sign out, tests).
  void reset() {
    _next?.cancel();
    _tick?.cancel();
    _missTimer?.cancel();
    session?.dispose();
    _pending?.dispose();
    session = null;
    _pending = null;
    missedAt = null;
    online = false;
    onlineSince = null;
    signedIn = false;
    registered = false;
    phone = '';
    name = '';
    plate = '';
    vehicle = Service.bike;
    languages = {'Bengali', 'Hindi'};
    docs = {for (final d in DocKind.values) d: DocStatus.missing};
    bankAccount = ifsc = holder = '';
    position = kCaptainStart;
    heading = 20;
    _requestNo = 0;
    trips.clear();
    payouts.clear();
    credits.clear();
    notices.clear();
    _creditedKeys.clear();
    _onlineByDay.clear();
    _onlineBefore = Duration.zero;
    wallet = 0;
    lifetimeRides = 0;
    offered = accepted = 0;
    net.reset();
  }

  // ───────── duty ─────────

  Duration get onlineToday => _onlineBefore + (onlineSince == null ? Duration.zero : clock.now().difference(onlineSince!));

  /// Returns false if there's no connection.
  bool goOnline() {
    if (online) return true;
    if (!net.online) return false;
    online = true;
    onlineSince = clock.now();
    missedAt = null;
    _scheduleRequest(const Duration(seconds: 8));
    notifyListeners();
    return true;
  }

  void goOffline() {
    if (!online || stage.busy) return;
    final since = onlineSince;
    if (since != null) _onlineBefore += clock.now().difference(since);
    online = false;
    onlineSince = null;
    missedAt = null;
    _next?.cancel();
    _missTimer?.cancel();
    notifyListeners();
  }

  void _scheduleRequest(Duration after) {
    _next?.cancel();
    _next = Timer(after, _offer);
    _prepare();
  }

  /// Builds the next request ahead of time and fetches its routes, so the
  /// fare and map are ready the moment it is shown.
  void _prepare() {
    final p = _pending;
    if (p != null && p.service == vehicle) return;
    p?.dispose(); // prepared before the vehicle type was picked
    final s = _makeRequest(p?.id ?? _requestNo++);
    _pending = s;
    s.load();
  }

  void _offer() {
    final s = _pending;
    if (!online || session != null || s == null) return;
    if (!s.ready) {
      _next = Timer(const Duration(milliseconds: 400), _offer);
      return;
    }
    _pending = null;
    missedAt = null;
    _missTimer?.cancel();
    session = s;
    offered++;
    s._go(CaptainStage.request);
    _startTicking();
    notifyListeners();
  }

  TripSession _makeRequest(int n) {
    final rnd = math.Random(n * 7919 + 3);
    if (n == 0) {
      // the first request of a session is always the same (prefetched at sign in)
      return TripSession(
        id: n,
        rider: kRiders[0],
        service: vehicle,
        pickup: kSpots[0],
        drop: kDrops[0],
        start: position,
        pay: Pay.cash,
      );
    }
    final here = position;
    final spots = [...kSpots]..sort((a, b) => _d.as(LengthUnit.Meter, here, a.pos).compareTo(_d.as(LengthUnit.Meter, here, b.pos)));
    final near = spots.where((p) => _d.as(LengthUnit.Meter, here, p.pos) > 300).take(4).toList();
    final pickup = near.isEmpty ? spots.first : near[rnd.nextInt(near.length)];
    final drops = kDrops.where((p) {
      final km = _d.as(LengthUnit.Meter, pickup.pos, p.pos) / 1000;
      return km > 2 && km < 9;
    }).toList();
    final drop = drops.isEmpty ? kDrops[rnd.nextInt(kDrops.length)] : drops[rnd.nextInt(drops.length)];
    final pay = const [Pay.upi, Pay.cash, Pay.upi, Pay.wallet][rnd.nextInt(4)];
    final zone = kDemandZones.where((z) => _d.as(LengthUnit.Meter, z.center, pickup.pos) < z.radius).firstOrNull;
    return TripSession(
      id: n,
      rider: kRiders[1 + rnd.nextInt(kRiders.length - 1)],
      service: vehicle,
      pickup: pickup,
      drop: drop,
      start: here,
      pay: pay,
      zone: zone,
      tip: pay == Pay.cash ? 0 : const [0.0, 0.0, 10.0, 20.0][rnd.nextInt(4)],
    );
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick());
  }

  void _onTick() {
    final s = session;
    if (s == null) {
      _tick?.cancel();
      return;
    }
    switch (s.stage) {
      case CaptainStage.request when s.requestLeft <= 0:
        _missed();
        return;
      case CaptainStage.toPickup when s.approachProgress >= 1:
        position = s.pickup.pos;
        s._go(CaptainStage.arrived);
        notifyListeners();
        return;
      case CaptainStage.onTrip when s.tripProgress >= 1 && !s.reachedDrop:
        s.reachedDrop = true;
      case CaptainStage.collect || CaptainStage.summary:
        _tick?.cancel();
        return;
      default:
        break;
    }
    s.tick();
  }

  void _missed() {
    final s = session;
    if (s == null) return;
    _clearSession();
    missedAt = clock.now();
    _missTimer?.cancel();
    _missTimer = Timer(const Duration(milliseconds: 2600), () {
      missedAt = null;
      notifyListeners();
    });
    _scheduleRequest(const Duration(seconds: 10));
    notifyListeners();
  }

  void _clearSession() {
    final s = session;
    session = null;
    _tick?.cancel();
    // dispose after closing animations have finished
    if (s != null) Future.delayed(const Duration(seconds: 2), s.dispose);
  }

  void accept() {
    final s = session;
    if (s == null || s.stage != CaptainStage.request) return;
    accepted++;
    s._go(CaptainStage.toPickup);
    notifyListeners();
  }

  void decline() {
    final s = session;
    if (s == null || s.stage != CaptainStage.request) return;
    _clearSession();
    _scheduleRequest(const Duration(seconds: 10));
    notifyListeners();
  }

  /// Checks the rider's PIN and starts the trip if it matches.
  bool verifyPin(String code) {
    final s = session;
    if (s == null || s.stage != CaptainStage.arrived || code != s.pin) return false;
    s._go(CaptainStage.onTrip);
    notifyListeners();
    return true;
  }

  void endTrip() {
    final s = session;
    if (s == null || s.stage != CaptainStage.onTrip) return;
    s._go(CaptainStage.collect);
    final v = s.vehicle();
    position = v.pos;
    heading = v.heading;
    notifyListeners();
  }

  /// Cash collected / online payment confirmed: books the trip into the ledger.
  void paymentReceived() {
    final s = session;
    if (s == null || s.stage != CaptainStage.collect) return;
    final fee = feeFor(s.total);
    final rec = TripRecord(
      service: s.service,
      rider: s.rider,
      from: s.pickup.name,
      to: s.drop.name,
      when: clock.now(),
      km: s.tripKm * s.tripProgress,
      minutes: s.tripMinutes,
      fare: s.total,
      waiting: s.waitingCharge,
      tip: s.tip,
      platformFee: fee,
      pay: s.pay,
    );
    s.record = rec;
    trips.insert(0, rec);
    lifetimeRides++;
    wallet += s.pay == Pay.cash ? -fee : rec.earnings;
    _checkIncentives();
    s._go(CaptainStage.summary);
    notifyListeners();
  }

  /// Leaves the summary and goes back to waiting for requests.
  void finishSummary({int stars = 0}) {
    final s = session;
    if (s == null || s.stage != CaptainStage.summary) return;
    final rec = s.record;
    if (rec != null && stars > 0) {
      final i = trips.indexOf(rec);
      if (i >= 0) trips[i] = _withStars(rec, stars);
    }
    _clearSession();
    if (online) _scheduleRequest(const Duration(seconds: 10));
    notifyListeners();
  }

  void cancelTrip(String reason) {
    final s = session;
    if (s == null || !(s.stage == CaptainStage.toPickup || s.stage == CaptainStage.arrived)) return;
    final v = s.vehicle();
    position = v.pos;
    heading = v.heading;
    trips.insert(
      0,
      TripRecord(
        service: s.service,
        rider: s.rider,
        from: s.pickup.name,
        to: s.drop.name,
        when: clock.now(),
        km: 0,
        minutes: 0,
        fare: s.fare,
        pay: s.pay,
        status: TripStatus.cancelled,
        cancelReason: reason,
      ),
    );
    _clearSession();
    if (online) _scheduleRequest(const Duration(seconds: 10));
    notifyListeners();
  }

  TripRecord _withStars(TripRecord r, int stars) => TripRecord(
        service: r.service,
        rider: r.rider,
        from: r.from,
        to: r.to,
        when: r.when,
        km: r.km,
        minutes: r.minutes,
        fare: r.fare,
        waiting: r.waiting,
        tip: r.tip,
        platformFee: r.platformFee,
        pay: r.pay,
        status: r.status,
        cancelReason: r.cancelReason,
        riderStars: stars,
      );

  // ───────── money ─────────

  Future<bool> withdraw(double amount) async {
    if (amount <= 0 || amount > wallet) return false;
    await Future.delayed(const Duration(milliseconds: 1200));
    wallet -= amount;
    payouts.insert(0, Payout(amount, clock.now(), instant: true));
    notices.insert(0, CaptainNotice(NoticeKind.payout, 'Withdrawal on its way', '${_r(amount)} to $bankName $bankMasked. It usually arrives in a few minutes.', clock.now()));
    notifyListeners();
    return true;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
  static DateTime _monday(DateTime t) => _day(t).subtract(Duration(days: t.weekday - 1));

  List<IncentiveProgress> get incentives {
    final now = clock.now();
    final today = _day(now);
    final done = trips.where((t) => t.completed);
    final todayCount = done.where((t) => !t.when.isBefore(today)).length;
    final peak = done.where((t) => !t.when.isBefore(today) && t.when.hour >= 17 && t.when.hour < 21).length;
    final week = done.where((t) => !t.when.isBefore(_monday(now))).length;
    String k(String p) => '$p-${today.toIso8601String()}';
    return [
      IncentiveProgress(k('daily'), 'Complete 10 rides today', 'Daily target', todayCount, 10, 150),
      IncentiveProgress(k('peak'), '5 rides between 5 pm and 9 pm', 'Evening peak', peak, 5, 80),
      IncentiveProgress('weekly-${_monday(now).toIso8601String()}', '40 rides this week', 'Weekly target', week, 40, 500),
    ];
  }

  void _checkIncentives() {
    for (final i in incentives) {
      if (i.complete && _creditedKeys.add(i.key)) {
        final now = clock.now();
        credits.add(IncentiveCredit(i.title, i.reward, now));
        wallet += i.reward;
        notices.insert(0, CaptainNotice(NoticeKind.incentive, 'Bonus unlocked: ${_r(i.reward)}', '${i.title}. The bonus has been added to your balance.', now));
      }
    }
  }

  EarningsReport report(Period p) {
    final now = clock.now();
    final today = _day(now);
    final from = switch (p) {
      Period.today => today,
      Period.week => today.subtract(const Duration(days: 6)),
      Period.month => today.subtract(const Duration(days: 29)),
    };
    final ts = trips.where((t) => t.completed && !t.when.isBefore(from)).toList();
    final cs = credits.where((c) => !c.when.isBefore(from)).toList();
    double sum(Iterable<double> xs) => xs.fold(0.0, (a, b) => a + b);
    final bars = <({String label, double amount})>[];
    if (p == Period.today) {
      for (var h = 6; h < 24; h++) {
        final amt = sum(ts.where((t) => t.when.hour == h).map((t) => t.earnings)) + sum(cs.where((c) => c.when.hour == h).map((c) => c.amount));
        final label = h % 3 == 0 ? '${h % 12 == 0 ? 12 : h % 12}${h < 12 ? 'a' : 'p'}' : '';
        bars.add((label: label, amount: amt));
      }
    } else {
      final days = p == Period.week ? 7 : 30;
      for (var i = days - 1; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        final e = d.add(const Duration(days: 1));
        bool inDay(DateTime t) => !t.isBefore(d) && t.isBefore(e);
        final amt = sum(ts.where((t) => inDay(t.when)).map((t) => t.earnings)) + sum(cs.where((c) => inDay(c.when)).map((c) => c.amount));
        final label = p == Period.week ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday - 1] : (i % 5 == 0 ? '${d.day}' : '');
        bars.add((label: label, amount: amt));
      }
    }
    var online = Duration.zero;
    _onlineByDay.forEach((d, v) {
      if (!d.isBefore(from) && d.isBefore(today)) online += v;
    });
    online += onlineToday;
    return EarningsReport(
      fares: sum(ts.map((t) => t.fare)),
      tips: sum(ts.map((t) => t.tip)),
      incentives: sum(cs.map((c) => c.amount)),
      fees: sum(ts.map((t) => t.platformFee)),
      cash: sum(ts.where((t) => t.pay == Pay.cash).map((t) => t.fare + t.tip)),
      online: sum(ts.where((t) => t.pay != Pay.cash).map((t) => t.fare + t.tip)),
      km: sum(ts.map((t) => t.km)),
      rides: ts.length,
      onlineTime: online,
      bars: bars,
    );
  }

  /// Today's figures for the home top bar.
  double get todayEarnings => report(Period.today).total;
  int get todayRides {
    final today = _day(clock.now());
    return trips.where((t) => t.completed && !t.when.isBefore(today)).length;
  }

  // ───────── seed data ─────────

  /// About three weeks of history for a part-time captain: a few rides a day,
  /// six so far today, daily payouts of online earnings, and some notices.
  void _seed() {
    final now = clock.now();
    final today = _day(now);
    final rnd = math.Random(42);
    joined = today.subtract(const Duration(days: 23));
    trips.clear();
    payouts.clear();
    credits.clear();
    notices.clear();
    _creditedKeys.clear();
    _onlineByDay.clear();
    lifetimeRides = 0;
    var walletCalc = 0.0;
    var paidOut = 0.0;

    TripRecord make(DateTime when, {bool cancelled = false}) {
      final from = kSpots[rnd.nextInt(kSpots.length)];
      final to = kDrops[rnd.nextInt(kDrops.length)];
      final km = (_d.as(LengthUnit.Meter, from.pos, to.pos) / 1000 * 1.3).clamp(1.6, 14.0);
      final pay = const [Pay.upi, Pay.cash, Pay.upi, Pay.wallet, Pay.cash][rnd.nextInt(5)];
      final waiting = rnd.nextInt(6) == 0 ? (1 + rnd.nextInt(3)).toDouble() : 0.0;
      final fare = vehicle.fareFor(km) + waiting;
      return TripRecord(
        service: vehicle,
        rider: kRiders[1 + rnd.nextInt(kRiders.length - 1)],
        from: from.name,
        to: to.name,
        when: when,
        km: double.parse(km.toStringAsFixed(1)),
        minutes: (km * 3.1).ceil(),
        fare: fare,
        waiting: waiting,
        tip: pay != Pay.cash && rnd.nextInt(5) == 0 ? 10 : 0,
        pay: pay,
        status: cancelled ? TripStatus.cancelled : TripStatus.completed,
        cancelReason: cancelled ? 'Rider not reachable' : null,
        riderStars: cancelled ? null : 4 + rnd.nextInt(2),
      );
    }

    final seeded = <TripRecord>[];
    for (var ago = 22; ago >= 1; ago--) {
      final day = today.subtract(Duration(days: ago));
      final n = const [0, 1, 1, 2, 2, 2, 3][rnd.nextInt(7)];
      if (n == 0) continue;
      _onlineByDay[day] = Duration(minutes: 50 * n + rnd.nextInt(40));
      var dayOnline = 0.0;
      for (var i = 0; i < n; i++) {
        final when = day.add(Duration(hours: 9 + i * 3 + rnd.nextInt(2), minutes: rnd.nextInt(60)));
        final r = make(when, cancelled: rnd.nextInt(14) == 0);
        seeded.add(r);
        if (r.completed && r.pay != Pay.cash) dayOnline += r.earnings;
      }
      // payout of the day's online earnings, the next morning
      if (dayOnline > 0) {
        payouts.add(Payout(dayOnline, day.add(const Duration(days: 1, hours: 6))));
        paidOut += dayOnline;
      }
    }
    // today: six rides over the last few hours
    var t = now.subtract(const Duration(minutes: 25));
    final todays = <TripRecord>[];
    for (var i = 0; i < 6 && !t.isBefore(today); i++) {
      todays.add(make(t));
      t = t.subtract(Duration(minutes: 32 + rnd.nextInt(30)));
    }
    _onlineBefore = todays.isEmpty ? Duration.zero : Duration(minutes: 35 * todays.length + 12);
    seeded.addAll(todays);
    seeded.sort((a, b) => b.when.compareTo(a.when));
    trips.addAll(seeded);
    lifetimeRides = trips.where((r) => r.completed).length;
    for (final r in trips.where((r) => r.completed)) {
      walletCalc += r.pay == Pay.cash ? -r.platformFee : r.earnings;
    }
    wallet = walletCalc - paidOut;
    payouts.sort((a, b) => b.when.compareTo(a.when));

    final requested = trips.length + 4; // a few missed / declined requests
    offered = requested;
    accepted = trips.length;

    final daily = incentives.first;
    final lastPayout = payouts.firstOrNull;
    notices.addAll([
      CaptainNotice(NoticeKind.incentive, '${daily.target - daily.done} rides to a ${_r(daily.reward)} bonus', 'Complete ${daily.target} rides today to unlock your daily bonus.', now.subtract(const Duration(minutes: 40))),
      CaptainNotice(NoticeKind.document, 'Pollution certificate expires soon', 'Your PUC expires on ${_date(expiryOf(DocKind.puc) ?? now)}. Upload the new one to keep riding.', now.subtract(const Duration(hours: 3))),
      if (lastPayout != null) CaptainNotice(NoticeKind.payout, 'Payout credited', '${_r(lastPayout.amount)} sent to your bank account.', lastPayout.when),
      CaptainNotice(NoticeKind.incentive, 'Evening peak bonus', 'Do 5 rides between 5 pm and 9 pm today for an extra ₹80.', today.add(const Duration(hours: 8))),
      CaptainNotice(NoticeKind.info, 'Zero commission is on', 'You pay no platform fee on your first $kZeroCommissionRides rides.', joined.add(const Duration(hours: 10))),
    ]);
    notices.sort((a, b) => b.when.compareTo(a.when));
  }

  static String _r(double v) => '₹${v.round()}';
  static String _date(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

final captain = CaptainState();
