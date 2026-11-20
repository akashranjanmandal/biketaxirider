import 'package:latlong2/latlong.dart';

/// Every service offered, Rapido-style.
enum Service { bike, auto, eRickshaw, cabEconomy, cabPremium, cabXl, parcel, rental, intercity }

enum VehicleArt { bike, car, rickshaw }

extension ServiceInfo on Service {
  String get label => switch (this) {
        Service.bike => 'Bike',
        Service.auto => 'Auto',
        Service.eRickshaw => 'E-Rickshaw',
        Service.cabEconomy => 'Cab Economy',
        Service.cabPremium => 'Cab Premium',
        Service.cabXl => 'Cab XL',
        Service.parcel => 'Parcel',
        Service.rental => 'Rentals',
        Service.intercity => 'Intercity',
      };

  /// Short label for the home services grid.
  String get shortLabel => switch (this) {
        Service.cabEconomy => 'Cab',
        _ => label,
      };

  String get tagline => switch (this) {
        Service.bike => 'Beat the traffic',
        Service.auto => 'Doorstep pickup, no haggling',
        Service.eRickshaw => 'Zero emission, lowest fares',
        Service.cabEconomy => 'Affordable AC rides',
        Service.cabPremium => 'Top-rated drivers, newer cars',
        Service.cabXl => 'SUVs for up to 6',
        Service.parcel => 'Send items across the city',
        Service.rental => 'Keep a car by the hour',
        Service.intercity => 'Outstation, one way',
      };

  VehicleArt get art => switch (this) {
        Service.bike || Service.parcel => VehicleArt.bike,
        Service.auto || Service.eRickshaw => VehicleArt.rickshaw,
        _ => VehicleArt.car,
      };

  String get artAsset => switch (art) {
        VehicleArt.bike => 'assets/brand/v_bike.png',
        VehicleArt.car => 'assets/brand/v_car.png',
        VehicleArt.rickshaw => 'assets/brand/v_rickshaw.png',
      };

  int get seats => switch (this) {
        Service.bike => 1,
        Service.auto => 3,
        Service.eRickshaw => 4,
        Service.cabXl => 6,
        Service.parcel => 0,
        _ => 4,
      };

  double get baseFare => switch (this) {
        Service.bike => 15,
        Service.auto => 25,
        Service.eRickshaw => 12,
        Service.cabEconomy => 45,
        Service.cabPremium => 70,
        Service.cabXl => 95,
        Service.parcel => 30,
        Service.rental => 0,
        Service.intercity => 250,
      };

  double get perKm => switch (this) {
        Service.bike => 5.5,
        Service.auto => 11,
        Service.eRickshaw => 7,
        Service.cabEconomy => 14,
        Service.cabPremium => 18,
        Service.cabXl => 22,
        Service.parcel => 7,
        Service.rental => 0,
        Service.intercity => 11,
      };

  /// Minutes until a captain could reach the rider.
  int get pickupEta => switch (this) {
        Service.bike || Service.parcel => 2,
        Service.auto || Service.eRickshaw => 3,
        Service.cabEconomy => 4,
        Service.cabPremium => 6,
        _ => 8,
      };

  /// Relative speed vs. a car (bikes weave through traffic).
  double get speedFactor => switch (this) {
        Service.bike || Service.parcel => .8,
        Service.eRickshaw => 1.35,
        Service.auto => 1.1,
        _ => 1,
      };

  bool get isElectric => this == Service.eRickshaw;

  String get vehicleNoun => switch (art) {
        VehicleArt.bike => 'bike',
        VehicleArt.car => 'cab',
        VehicleArt.rickshaw => this == Service.auto ? 'auto' : 'e-rickshaw',
      };
}

const kRideOptions = [Service.bike, Service.auto, Service.eRickshaw, Service.cabEconomy, Service.cabPremium, Service.cabXl];
const kHomeServices = [Service.bike, Service.auto, Service.eRickshaw, Service.cabEconomy, Service.parcel, Service.rental, Service.intercity];

enum PlaceKind { home, work, saved, recent, landmark, city }

class Place {
  final String name;
  final String address;
  final LatLng pos;
  final PlaceKind kind;
  const Place(this.name, this.address, this.pos, [this.kind = PlaceKind.landmark]);
}

/// The rider's current location (Gariahat crossing, Kolkata).
const kPickup = Place('Gariahat', 'Gariahat Rd, Ballygunge, Kolkata', LatLng(22.51870, 88.36547));

const kPlaces = <Place>[
  Place('Home', 'Jodhpur Park, Kolkata 700068', LatLng(22.50790, 88.36190), PlaceKind.home),
  Place('Work', 'Salt Lake Sector V, Kolkata', LatLng(22.57260, 88.43390), PlaceKind.work),
  Place('Victoria Memorial', 'Queens Way, Maidan, Kolkata', LatLng(22.54480, 88.34260), PlaceKind.recent),
  Place('South City Mall', 'Prince Anwar Shah Rd, Jadavpur', LatLng(22.50160, 88.36160), PlaceKind.recent),
  Place('Park Street', 'Park Street area, Kolkata 700016', LatLng(22.55300, 88.35200)),
  Place('Howrah Station', 'Howrah, West Bengal 711101', LatLng(22.58390, 88.34260)),
  Place('Netaji Subhas Chandra Bose Airport', 'Dum Dum, Kolkata 700052', LatLng(22.65470, 88.44670)),
  Place('Eco Park', 'Major Arterial Rd, New Town', LatLng(22.60060, 88.46750)),
  Place('Esplanade', 'Dharmatala, Kolkata 700013', LatLng(22.56450, 88.35100)),
  Place('Dakshineswar Kali Temple', 'Dakshineswar, Kolkata 700076', LatLng(22.65500, 88.35760)),
  Place('Science City', 'JBS Haldane Ave, Kolkata 700046', LatLng(22.54000, 88.39600)),
];

const kCities = <Place>[
  Place('Digha', 'Purba Medinipur · beach town', LatLng(21.62660, 87.50740), PlaceKind.city),
  Place('Durgapur', 'Paschim Bardhaman', LatLng(23.52040, 87.31190), PlaceKind.city),
  Place('Shantiniketan', 'Birbhum · Visva-Bharati', LatLng(23.67970, 87.68580), PlaceKind.city),
  Place('Mandarmani', 'Purba Medinipur · beach', LatLng(21.66070, 87.70320), PlaceKind.city),
];

class RentalPackage {
  final int hours, km;
  final double price;
  const RentalPackage(this.hours, this.km, this.price);
  String get label => '$hours hr · $km km';
}

const kRentalPackages = [
  RentalPackage(1, 10, 299),
  RentalPackage(2, 20, 549),
  RentalPackage(4, 40, 999),
  RentalPackage(8, 80, 1849),
];

class Captain {
  final String name;
  final double rating;
  final int trips;
  final String vehicle;
  final String plate;
  const Captain(this.name, this.rating, this.trips, this.vehicle, this.plate);
  String get initials => name.split(' ').map((e) => e[0]).take(2).join();
  String get firstName => name.split(' ').first;
}

Captain captainFor(Service s) => switch (s) {
      Service.bike => const Captain('Rahul Das', 4.9, 3820, 'Honda Shine · Black', 'WB 02 AK 4821'),
      Service.parcel => const Captain('Tanmoy Paul', 4.9, 2890, 'TVS Jupiter · Grey', 'WB 01 PC 1204'),
      Service.auto => const Captain('Biswajit Roy', 4.8, 4411, 'Bajaj RE · Green', 'WB 04 AU 7712'),
      Service.eRickshaw => const Captain('Imran Sheikh', 4.8, 1560, 'Mahindra Treo · Green', 'WB 12 ER 3350'),
      Service.cabPremium => const Captain('Arindam Sen', 4.95, 2210, 'Honda City · White', 'WB 06 CP 2207'),
      Service.cabXl => const Captain('Sanjay Mondal', 4.85, 1904, 'Toyota Innova · Silver', 'WB 20 XL 5519'),
      _ => const Captain('Sourav Ghosh', 4.88, 2104, 'Maruti Dzire · White', 'WB 06 BF 9017'),
    };

enum Pay { upi, cash, wallet }

extension PayInfo on Pay {
  String get label => switch (this) { Pay.upi => 'UPI', Pay.cash => 'Cash', Pay.wallet => 'Aamar Wallet' };
}

class RideRecord {
  final Service service;
  final String from, to, when;
  final double fare;
  final bool cancelled;
  final double? km;
  final Captain? captain;
  const RideRecord(this.service, this.from, this.to, this.when, this.fare, {this.cancelled = false, this.km, this.captain});
}

class WalletTxn {
  final String title, when;
  final double amount;
  const WalletTxn(this.title, this.when, this.amount);
}

class Coupon {
  final String code, title, detail;
  final double percent;
  final double maxOff;
  const Coupon(this.code, this.title, this.detail, this.percent, this.maxOff);
}

const kCoupons = [
  Coupon('AAMAR15', '15% off your ride', 'Up to ₹50 off on any ride', 15, 50),
  Coupon('GOGREEN', '25% off E-Rickshaw', 'Up to ₹40 off · e-rickshaw only', 25, 40),
  Coupon('FIRSTCAB', '₹75 off your first cab', 'Cab Economy & Premium', 100, 75),
];

// ───────────────────────── Captain side ─────────────────────────

/// Vehicle types a captain can register (rides only; parcel uses a bike).
const kCaptainVehicles = [Service.bike, Service.auto, Service.eRickshaw, Service.cabEconomy, Service.cabPremium, Service.cabXl];

extension CaptainServiceInfo on Service {
  bool get isCab => this == Service.cabEconomy || this == Service.cabPremium || this == Service.cabXl;

  /// Upfront fare for a trip of [km] road kilometres (same formula as the rider app).
  double fareFor(double km) {
    final raw = baseFare + perKm * km;
    final minimum = baseFare + perKm * 1.5;
    return raw < minimum ? minimum.roundToDouble() : raw.roundToDouble();
  }
}

class Rider {
  final String name;
  final double rating;
  final int rides;
  const Rider(this.name, this.rating, this.rides);
  String get initials => name.split(' ').map((e) => e[0]).take(2).join();
  String get firstName => name.split(' ').first;
}

const kRiders = [
  Rider('Koustav Das', 4.9, 212),
  Rider('Ananya Bose', 4.8, 96),
  Rider('Arjun Mukherjee', 4.7, 341),
  Rider('Riya Sen', 4.95, 58),
  Rider('Sayan Dutta', 4.6, 127),
  Rider('Moumita Saha', 4.85, 203),
  Rider('Farhan Ahmed', 4.75, 88),
  Rider('Priya Ghosh', 4.9, 164),
  Rider('Rohit Banerjee', 4.65, 39),
  Rider('Tanvi Agarwal', 4.8, 271),
];

/// Where the captain starts the day (Gariahat crossing).
const kCaptainStart = LatLng(22.51870, 88.36547);

/// Busy pickup points across south and central Kolkata.
const kSpots = <Place>[
  Place('Ballygunge Phari', 'Ballygunge Circular Rd, Ballygunge', LatLng(22.52760, 88.36500)),
  Place('Golpark', 'Gariahat Rd South, Golpark', LatLng(22.51480, 88.36690)),
  Place('Deshapriya Park', 'Sarat Bose Rd, Kalighat', LatLng(22.51390, 88.35340)),
  Place('Rashbehari Crossing', 'Rashbehari Ave, Kalighat', LatLng(22.51800, 88.34970)),
  Place('Kalighat Temple', 'Kalighat Rd, Kalighat', LatLng(22.52030, 88.34260)),
  Place('Hazra Crossing', 'Hazra Rd, Bhowanipore', LatLng(22.52650, 88.34660)),
  Place('Dhakuria Bridge', 'Gariahat Rd South, Dhakuria', LatLng(22.51060, 88.37110)),
  Place('Jadavpur 8B', '8B Bus Stand, Jadavpur', LatLng(22.49680, 88.37120)),
  Place('Park Circus', 'Seven Point Crossing, Park Circus', LatLng(22.53940, 88.36830)),
  Place('Exide More', 'Chowringhee Rd, Exide crossing', LatLng(22.54040, 88.35190)),
  Place('Kasba', 'Rajdanga Main Rd, Kasba', LatLng(22.51500, 88.39000)),
  Place('Ruby Crossing', 'EM Bypass, Ruby', LatLng(22.51330, 88.40110)),
  Place('Hindustan Park', 'Hindustan Park, Gariahat', LatLng(22.51640, 88.36230)),
];

/// Where riders are headed.
const kDrops = <Place>[
  Place('Victoria Memorial', 'Queens Way, Maidan', LatLng(22.54480, 88.34260)),
  Place('Park Street', 'Park Street area, Kolkata 700016', LatLng(22.55300, 88.35200)),
  Place('Esplanade', 'Dharmatala, Kolkata 700013', LatLng(22.56450, 88.35100)),
  Place('Science City', 'JBS Haldane Ave, Kolkata 700046', LatLng(22.54000, 88.39600)),
  Place('South City Mall', 'Prince Anwar Shah Rd, Jadavpur', LatLng(22.50160, 88.36160)),
  Place('Salt Lake Sector V', 'Salt Lake, Kolkata 700091', LatLng(22.57260, 88.43390)),
  Place('Howrah Station', 'Howrah, West Bengal 711101', LatLng(22.58390, 88.34260)),
  Place('Quest Mall', 'Syed Amir Ali Ave, Ballygunge', LatLng(22.53920, 88.36550)),
  Place('SSKM Hospital', 'AJC Bose Rd, Bhowanipore', LatLng(22.53940, 88.34370)),
  Place('Tollygunge Metro', 'Deshapran Sasmal Rd, Tollygunge', LatLng(22.49900, 88.34530)),
];

/// Areas with more requests than captains right now.
class DemandZone {
  final String name;
  final LatLng center;
  final double radius; // metres
  final double multiplier;
  const DemandZone(this.name, this.center, this.radius, this.multiplier);
  String get label => 'High demand · ${multiplier.toStringAsFixed(1)}×';
}

const kDemandZones = [
  DemandZone('Park Street', LatLng(22.55250, 88.35350), 1300, 1.3),
  DemandZone('Salt Lake Sector V', LatLng(22.57400, 88.43200), 1600, 1.3),
  DemandZone('Howrah Station', LatLng(22.58350, 88.34200), 1400, 1.2),
];

enum TripStatus { completed, cancelled }

/// One request the captain accepted (finished or cancelled).
class TripRecord {
  final Service service;
  final Rider rider;
  final String from, to;
  final DateTime when;
  final double km;
  final int minutes;
  final double fare; // what the rider paid for the ride, waiting included
  final double waiting;
  final double tip;
  final double platformFee;
  final Pay pay;
  final TripStatus status;
  final String? cancelReason;
  final int? riderStars;
  const TripRecord({
    required this.service,
    required this.rider,
    required this.from,
    required this.to,
    required this.when,
    required this.km,
    required this.minutes,
    required this.fare,
    this.waiting = 0,
    this.tip = 0,
    this.platformFee = 0,
    required this.pay,
    this.status = TripStatus.completed,
    this.cancelReason,
    this.riderStars,
  });

  bool get completed => status == TripStatus.completed;

  /// What the captain keeps from this trip.
  double get earnings => completed ? fare + tip - platformFee : 0;
}

/// Money paid out to the captain's bank account.
class Payout {
  final double amount;
  final DateTime when;
  final bool instant;
  const Payout(this.amount, this.when, {this.instant = false});
}

/// A bonus credited for hitting an incentive target.
class IncentiveCredit {
  final String title;
  final double amount;
  final DateTime when;
  const IncentiveCredit(this.title, this.amount, this.when);
}

enum DocKind { licence, rc, aadhaar, pan, vehiclePhoto, selfie, insurance, puc }

/// Documents asked for during registration (the rest are added later).
const kRegistrationDocs = [DocKind.licence, DocKind.rc, DocKind.aadhaar, DocKind.pan, DocKind.vehiclePhoto, DocKind.selfie];

extension DocInfo on DocKind {
  String get label => switch (this) {
        DocKind.licence => 'Driving licence',
        DocKind.rc => 'Registration certificate (RC)',
        DocKind.aadhaar => 'Aadhaar card',
        DocKind.pan => 'PAN card',
        DocKind.vehiclePhoto => 'Vehicle photo',
        DocKind.selfie => 'Profile selfie',
        DocKind.insurance => 'Vehicle insurance',
        DocKind.puc => 'Pollution certificate (PUC)',
      };

  String get shortLabel => switch (this) {
        DocKind.licence => 'Driving licence',
        DocKind.rc => 'RC',
        DocKind.aadhaar => 'Aadhaar',
        DocKind.pan => 'PAN',
        DocKind.vehiclePhoto => 'Vehicle photo',
        DocKind.selfie => 'Selfie',
        DocKind.insurance => 'Insurance',
        DocKind.puc => 'PUC',
      };

  String get hint => switch (this) {
        DocKind.licence => 'Front side, all four corners visible',
        DocKind.rc => 'Smart card or paper RC',
        DocKind.aadhaar => 'Front side with your photo',
        DocKind.pan => 'Name and PAN number clearly visible',
        DocKind.vehiclePhoto => 'Front of the vehicle with the number plate',
        DocKind.selfie => 'Face the camera in good light',
        DocKind.insurance => 'First page of the policy',
        DocKind.puc => 'Valid pollution certificate',
      };

  /// Months until expiry for documents that expire; null for ones that don't.
  int? get validMonths => switch (this) {
        DocKind.licence => 62,
        DocKind.rc => 118,
        DocKind.insurance => 9,
        DocKind.puc => 0,
        _ => null,
      };

  bool get isSelfie => this == DocKind.selfie;
  bool get isPhoto => this == DocKind.vehiclePhoto || this == DocKind.selfie;
}

enum DocStatus { missing, verifying, verified }

/// Two-letter India-style vehicle number, e.g. "WB 02 AK 4821".
bool isValidPlate(String s) => RegExp(r'^[A-Z]{2} ?\d{1,2} ?[A-Z]{1,3} ?\d{3,4}$').hasMatch(s.trim().toUpperCase());

bool isValidIfsc(String s) => RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(s.trim().toUpperCase());

/// Bank name from the IFSC prefix (a handful of common ones for the demo).
String? bankForIfsc(String s) => switch (s.trim().toUpperCase().padRight(4).substring(0, 4)) {
      'HDFC' => 'HDFC Bank',
      'SBIN' => 'State Bank of India',
      'ICIC' => 'ICICI Bank',
      'UTIB' => 'Axis Bank',
      'PUNB' => 'Punjab National Bank',
      'KKBK' => 'Kotak Mahindra Bank',
      'BARB' => 'Bank of Baroda',
      'UCBA' => 'UCO Bank',
      'IDIB' => 'Indian Bank',
      _ => isValidIfsc(s) ? 'Bank verified' : null,
    };
