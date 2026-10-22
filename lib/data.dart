import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum TripStatus { booked, loaded, inTransit, delivered, pod, settled }

extension TripStatusX on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.booked:
        return 'Booked';
      case TripStatus.loaded:
        return 'Loaded';
      case TripStatus.inTransit:
        return 'In transit';
      case TripStatus.delivered:
        return 'POD baaki';
      case TripStatus.pod:
        return 'POD mila';
      case TripStatus.settled:
        return 'Settled';
    }
  }

  String get short {
    switch (this) {
      case TripStatus.booked:
        return 'Booked';
      case TripStatus.loaded:
        return 'Loaded';
      case TripStatus.inTransit:
        return 'Transit';
      case TripStatus.delivered:
        return 'Delivered';
      case TripStatus.pod:
        return 'POD';
      case TripStatus.settled:
        return 'Settled';
    }
  }

  /// Label for the button that moves a trip to this status.
  String get action {
    switch (this) {
      case TripStatus.booked:
        return 'Booked';
      case TripStatus.loaded:
        return 'Loaded mark karo';
      case TripStatus.inTransit:
        return 'In transit mark karo';
      case TripStatus.delivered:
        return 'Delivered mark karo';
      case TripStatus.pod:
        return 'POD mila mark karo';
      case TripStatus.settled:
        return 'Settle karo';
    }
  }

  bool get isActive => index < TripStatus.delivered.index;
}

class Party {
  final String id;
  final String name;
  final String city;
  final String phone;
  Party(this.id, this.name, this.city, this.phone);
}

class TruckOwner {
  final String id;
  final String name;
  final String phone;
  TruckOwner(this.id, this.name, this.phone);
}

class Truck {
  final String number;
  final String type;
  final int capacityTon;
  final String ownerId;
  final String driver;
  final String driverPhone;
  final List<String> routes;
  Truck(this.number, this.type, this.capacityTon, this.ownerId, this.driver,
      this.driverPhone, this.routes);
}

class Payment {
  final DateTime date;
  final int amount;
  final String mode;
  final String note;
  Payment(this.date, this.amount, this.mode, [this.note = '']);
}

class Trip {
  final int lr;
  final DateTime date;
  final String partyId;
  final String consignee;
  final String truckNo;
  final String from;
  final String to;
  final String material;
  final double weightTon;
  final int freight;
  final int hire;
  TripStatus status;
  final List<Payment> partyPayments;
  final List<Payment> ownerPayments;
  int partyDeduction;
  int ownerDeduction;
  DateTime? deductionDate;
  double progress; // 0..1 of the route covered (for tracking)
  final int distanceKm;
  String nearPlace;

  Trip({
    required this.lr,
    required this.date,
    required this.partyId,
    required this.consignee,
    required this.truckNo,
    required this.from,
    required this.to,
    required this.material,
    required this.weightTon,
    required this.freight,
    required this.hire,
    this.status = TripStatus.booked,
    List<Payment>? partyPayments,
    List<Payment>? ownerPayments,
    this.partyDeduction = 0,
    this.ownerDeduction = 0,
    this.deductionDate,
    this.progress = 0,
    this.distanceKm = 300,
    this.nearPlace = '',
  })  : partyPayments = partyPayments ?? <Payment>[],
        ownerPayments = ownerPayments ?? <Payment>[];

  int get commission => freight - hire;
  int get partyReceived => partyPayments.fold(0, (s, p) => s + p.amount);
  int get ownerPaid => ownerPayments.fold(0, (s, p) => s + p.amount);
  int get partyBalance => freight - partyDeduction - partyReceived;
  int get ownerBalance => hire - ownerDeduction - ownerPaid;
  String get route => '$from → $to';
  int get kmDone => (distanceKm * progress).round();
  int get kmLeft => distanceKm - kmDone;
}

class LoadPost {
  final String from;
  final String to;
  final String material;
  final double weightTon;
  final String truckType;
  final String date;
  final int? rate;
  final String postedBy;
  final String ago;
  LoadPost(this.from, this.to, this.material, this.weightTon, this.truckType,
      this.date, this.rate, this.postedBy, this.ago);
}

class TruckPost {
  final String truckNo;
  final String type;
  final int capacityTon;
  final String area;
  final int km;
  final List<String> wantTo;
  final String postedBy;
  final String ago;
  TruckPost(this.truckNo, this.type, this.capacityTon, this.area, this.km,
      this.wantTo, this.postedBy, this.ago);
}

class LedgerEntry {
  final DateTime date;
  final String title;
  final String sub;
  final int amount; // + = party owes more, - = received / deducted
  final int lr;
  int balance = 0;
  final int order;
  LedgerEntry(this.date, this.title, this.sub, this.amount, this.lr, this.order);
}

class PaymentLine {
  final String who;
  final Payment payment;
  final bool incoming;
  final int lr;
  PaymentLine(this.who, this.payment, this.incoming, this.lr);
}

enum Role { agent, owner, driver, shipper }

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

String inr(int v) {
  final neg = v < 0;
  var s = v.abs().toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return '${neg ? '-' : ''}₹$s';
}

String num0(int v) => inr(v).replaceFirst('₹', '');

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';

String fullDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

String ton(double t) => t == t.roundToDouble() ? '${t.round()} ton' : '$t ton';

// ---------------------------------------------------------------------------
// App state (sample data for the prototype; Supabase comes in a later stage)
// ---------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  final String officeName = 'Sharma Roadlines';
  final String agentName = 'Rakesh';
  final String officePhone = '98100 55221';
  Role role = Role.agent;
  bool driverLocationOn = false;

  // Who is "logged in" for the non-agent roles in the demo.
  final String demoOwnerId = 'o1';
  final String demoDriver = 'Mohan';
  final String demoShipperId = 'p1';

  final List<Party> parties = [
    Party('p1', 'Gupta Traders', 'Delhi', '98110 23456'),
    Party('p2', 'Mittal Steels', 'Ghaziabad', '98734 11209'),
    Party('p3', 'Arora Paper', 'Delhi', '99580 66431'),
    Party('p4', 'Jain Plastics', 'Sonipat', '98120 77854'),
  ];

  final List<TruckOwner> owners = [
    TruckOwner('o1', 'Balwinder Singh', '98140 22871'),
    TruckOwner('o2', 'Ramesh Yadav', '94140 55320'),
    TruckOwner('o3', 'Sukhdev Transport', '98126 40018'),
    TruckOwner('o4', 'Harpreet Logistics', '98880 31452'),
    TruckOwner('o5', 'Kailash Gurjar', '94600 18723'),
    TruckOwner('o6', 'Patel Roadways', '98250 44190'),
  ];

  final List<Truck> trucks = [
    Truck('RJ14 GB 4821', 'Open body', 20, 'o1', 'Mohan', '98290 41177',
        ['Delhi–Jaipur', 'Delhi–Ajmer']),
    Truck('RJ14 GB 3317', 'Open body', 20, 'o1', 'Jagdish', '98290 63310',
        ['Jaipur–Delhi', 'Jaipur–Punjab']),
    Truck('RJ14 GD 2207', 'Container', 16, 'o2', 'Suresh', '94140 88213',
        ['Jaipur–Delhi', 'Jaipur–Gurgaon']),
    Truck('HR55 AC 9031', 'Trailer', 28, 'o3', 'Gurmeet', '98126 55102',
        ['Gurgaon–Jaipur', 'Jaipur–Ahmedabad']),
    Truck('HR38 K 7712', 'Open body', 25, 'o4', 'Sukha', '98880 70011',
        ['Ghaziabad–Ludhiana']),
    Truck('MP09 HG 3390', 'Container', 21, 'o5', 'Raju', '94600 31901',
        ['Delhi–Indore']),
    Truck('GJ01 BT 5566', 'Trailer', 30, 'o6', 'Bhavesh', '98250 61200',
        ['Sonipat–Ahmedabad']),
    Truck('RJ20 GA 1189', 'Open body', 18, 'o5', 'Prem', '94600 77345',
        ['Delhi–Kota']),
  ];

  late final List<Trip> trips = [
    Trip(
      lr: 1018,
      date: DateTime(2026, 10, 2),
      partyId: 'p1',
      consignee: 'Ajmer Kirana Bhandar, Ajmer',
      truckNo: 'RJ14 GB 4821',
      from: 'Delhi',
      to: 'Ajmer',
      material: 'Kirana (bags)',
      weightTon: 18,
      freight: 28000,
      hire: 26000,
      status: TripStatus.settled,
      partyPayments: [Payment(DateTime(2026, 10, 5), 28000, 'UPI')],
      ownerPayments: [Payment(DateTime(2026, 10, 4), 26000, 'Bank')],
      progress: 1,
      distanceKm: 400,
    ),
    Trip(
      lr: 1031,
      date: DateTime(2026, 10, 14),
      partyId: 'p1',
      consignee: 'Kota Traders, Kota',
      truckNo: 'RJ20 GA 1189',
      from: 'Delhi',
      to: 'Kota',
      material: 'Kirana (bags)',
      weightTon: 18,
      freight: 36000,
      hire: 33500,
      status: TripStatus.settled,
      partyPayments: [Payment(DateTime(2026, 10, 16), 36000, 'NEFT')],
      ownerPayments: [Payment(DateTime(2026, 10, 16), 33500, 'UPI')],
      progress: 1,
      distanceKm: 500,
    ),
    Trip(
      lr: 1039,
      date: DateTime(2026, 10, 18),
      partyId: 'p4',
      consignee: 'Shah Polymers, Ahmedabad',
      truckNo: 'GJ01 BT 5566',
      from: 'Sonipat',
      to: 'Ahmedabad',
      material: 'Plastic granules',
      weightTon: 28,
      freight: 71000,
      hire: 67000,
      status: TripStatus.delivered,
      partyPayments: [Payment(DateTime(2026, 10, 18), 40000, 'Bank')],
      ownerPayments: [Payment(DateTime(2026, 10, 18), 45000, 'UPI')],
      progress: 1,
      distanceKm: 950,
    ),
    Trip(
      lr: 1042,
      date: DateTime(2026, 10, 20),
      partyId: 'p1',
      consignee: 'Shree Balaji Stores, Jaipur',
      truckNo: 'RJ14 GB 4821',
      from: 'Delhi',
      to: 'Jaipur',
      material: 'Kirana (bags)',
      weightTon: 20,
      freight: 45000,
      hire: 42000,
      status: TripStatus.inTransit,
      partyPayments: [Payment(DateTime(2026, 10, 20), 30000, 'Bank', 'Advance')],
      ownerPayments: [Payment(DateTime(2026, 10, 20), 35000, 'UPI', 'Advance')],
      partyDeduction: 500,
      ownerDeduction: 500,
      deductionDate: DateTime(2026, 10, 22),
      progress: 0.45,
      distanceKm: 275,
      nearPlace: 'Behror ke paas',
    ),
    Trip(
      lr: 1043,
      date: DateTime(2026, 10, 21),
      partyId: 'p2',
      consignee: 'Punjab Steel Works, Ludhiana',
      truckNo: 'HR38 K 7712',
      from: 'Ghaziabad',
      to: 'Ludhiana',
      material: 'Steel coil',
      weightTon: 24,
      freight: 38000,
      hire: 35500,
      status: TripStatus.loaded,
      partyPayments: [Payment(DateTime(2026, 10, 21), 20000, 'Cash', 'Advance')],
      ownerPayments: [Payment(DateTime(2026, 10, 21), 25000, 'Cash', 'Advance')],
      progress: 0.05,
      distanceKm: 330,
      nearPlace: 'Ghaziabad',
    ),
    Trip(
      lr: 1044,
      date: DateTime(2026, 10, 22),
      partyId: 'p3',
      consignee: 'Malwa Paper Mart, Indore',
      truckNo: 'MP09 HG 3390',
      from: 'Delhi',
      to: 'Indore',
      material: 'Paper reels',
      weightTon: 20,
      freight: 62000,
      hire: 58000,
      status: TripStatus.booked,
      distanceKm: 810,
    ),
  ];

  final List<LoadPost> loads = [
    LoadPost('Jaipur', 'Ludhiana', 'Marble', 18, 'Open body', '23 Oct', null,
        'Jai Ambe Transport', '10 min pehle'),
    LoadPost('Jaipur', 'Delhi', 'Kapda (gaanth)', 15, 'Koi bhi', '24 Oct', 32000,
        'Sharma Roadlines', '1 ghanta pehle'),
    LoadPost('Jaipur', 'Ahmedabad', 'Tiles', 26, 'Trailer', '24 Oct', null,
        'Marudhar Carriers', '3 ghante pehle'),
  ];

  final List<TruckPost> truckPosts = [
    TruckPost('RJ14 GD 2207', 'Container', 16, 'Transport Nagar, Jaipur', 6,
        ['Gurgaon'], 'Driver Suresh', '1 ghanta pehle'),
    TruckPost('HR55 AC 9031', 'Trailer', 28, 'Bagru, Jaipur', 30,
        ['Ahmedabad', 'Kahin bhi'], 'Sukhdev Transport', '3 ghante pehle'),
  ];

  int nextLr = 1045;

  // ---- lookups ----
  Party party(String id) => parties.firstWhere((p) => p.id == id);
  TruckOwner owner(String id) => owners.firstWhere((o) => o.id == id);
  Truck truck(String no) => trucks.firstWhere((t) => t.number == no,
      orElse: () => Truck(no, 'Open body', 20, 'o1', 'Driver', '-', []));
  Trip trip(int lr) => trips.firstWhere((t) => t.lr == lr);
  TruckOwner ownerOfTruck(String no) => owner(truck(no).ownerId);

  List<Trip> get tripsNewestFirst =>
      [...trips]..sort((a, b) => b.lr.compareTo(a.lr));
  List<Trip> get activeTrips =>
      tripsNewestFirst.where((t) => t.status.isActive).toList();

  int get totalReceivable => trips.fold(
      0, (s, t) => s + (t.partyBalance > 0 ? t.partyBalance : 0));
  int get totalPayable =>
      trips.fold(0, (s, t) => s + (t.ownerBalance > 0 ? t.ownerBalance : 0));
  int get receivableParties =>
      trips.where((t) => t.partyBalance > 0).map((t) => t.partyId).toSet().length;
  int get payableOwners => trips
      .where((t) => t.ownerBalance > 0)
      .map((t) => truck(t.truckNo).ownerId)
      .toSet()
      .length;
  List<Trip> get monthTrips =>
      trips.where((t) => t.date.year == 2026 && t.date.month == 10).toList();
  int get monthCommission => monthTrips.fold(0, (s, t) => s + t.commission);

  int partyBalance(String partyId) => trips
      .where((t) => t.partyId == partyId)
      .fold(0, (s, t) => s + t.partyBalance);
  int ownerBalance(String ownerId) => trips
      .where((t) => truck(t.truckNo).ownerId == ownerId)
      .fold(0, (s, t) => s + t.ownerBalance);

  List<PaymentLine> get recentPayments {
    final list = <PaymentLine>[];
    for (final t in trips) {
      for (final p in t.partyPayments) {
        list.add(PaymentLine(party(t.partyId).name, p, true, t.lr));
      }
      for (final p in t.ownerPayments) {
        list.add(PaymentLine('${ownerOfTruck(t.truckNo).name} (owner)', p, false, t.lr));
      }
    }
    list.sort((a, b) {
      final c = b.payment.date.compareTo(a.payment.date);
      return c != 0 ? c : b.lr.compareTo(a.lr);
    });
    return list;
  }

  /// Party ledger, newest first, with running balance.
  List<LedgerEntry> partyLedger(String partyId) {
    final entries = <LedgerEntry>[];
    var seq = 0;
    final ts = trips.where((t) => t.partyId == partyId).toList()
      ..sort((a, b) => a.lr.compareTo(b.lr));
    for (final t in ts) {
      entries.add(LedgerEntry(t.date, t.route, 'LR ${t.lr} · freight', t.freight, t.lr, seq++));
      for (final p in t.partyPayments) {
        final title = p.note.isNotEmpty ? '${p.note} mila · ${p.mode}' : 'Payment mila · ${p.mode}';
        entries.add(LedgerEntry(p.date, title, 'LR ${t.lr}', -p.amount, t.lr, seq++));
      }
      if (t.partyDeduction > 0) {
        entries.add(LedgerEntry(t.deductionDate ?? t.date, 'Shortage kata',
            'LR ${t.lr}', -t.partyDeduction, t.lr, seq++));
      }
    }
    entries.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
    var bal = 0;
    for (final e in entries) {
      bal += e.amount;
      e.balance = bal;
    }
    return entries.reversed.toList();
  }

  // ---- mutations ----
  Trip addTrip({
    required String partyId,
    required String consignee,
    required String truckNo,
    required String from,
    required String to,
    required String material,
    required double weightTon,
    required int freight,
    required int hire,
    required int partyAdvance,
    required int ownerAdvance,
  }) {
    final now = DateTime(2026, 10, 22);
    final t = Trip(
      lr: nextLr++,
      date: now,
      partyId: partyId,
      consignee: consignee,
      truckNo: truckNo,
      from: from,
      to: to,
      material: material,
      weightTon: weightTon,
      freight: freight,
      hire: hire,
      partyPayments: [if (partyAdvance > 0) Payment(now, partyAdvance, 'Cash', 'Advance')],
      ownerPayments: [if (ownerAdvance > 0) Payment(now, ownerAdvance, 'Cash', 'Advance')],
      nearPlace: from,
    );
    trips.add(t);
    notifyListeners();
    return t;
  }

  void addPayment(Trip t, {required bool party, required int amount, required String mode}) {
    final p = Payment(DateTime(2026, 10, 22), amount, mode);
    if (party) {
      t.partyPayments.add(p);
    } else {
      t.ownerPayments.add(p);
    }
    notifyListeners();
  }

  void advanceStatus(Trip t) {
    if (t.status == TripStatus.settled) return;
    t.status = TripStatus.values[t.status.index + 1];
    if (t.status == TripStatus.inTransit && t.progress < 0.1) {
      t.progress = 0.1;
    }
    if (t.status.index >= TripStatus.delivered.index) {
      t.progress = 1;
      t.nearPlace = t.to;
    }
    notifyListeners();
  }

  void setStatus(Trip t, TripStatus s) {
    t.status = s;
    if (s.index >= TripStatus.delivered.index) {
      t.progress = 1;
      t.nearPlace = t.to;
    }
    notifyListeners();
  }

  void postLoad(LoadPost l) {
    loads.insert(0, l);
    notifyListeners();
  }

  final Set<String> postedTrucks = {};

  void postTruck(Truck t, List<String> wantTo) {
    postedTrucks.add(t.number);
    truckPosts.insert(
        0,
        TruckPost(t.number, t.type, t.capacityTon, 'Sitapura, Jaipur', 3,
            wantTo.isEmpty ? ['Kahin bhi'] : wantTo, owner(t.ownerId).name, 'Abhi'));
    notifyListeners();
  }

  void setRole(Role r) {
    role = r;
    notifyListeners();
  }

  void allowLocation() {
    driverLocationOn = true;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
