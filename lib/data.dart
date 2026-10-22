import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cities.dart';
import 'config.dart';

// ---------------------------------------------------------------------------
// Small parsing helpers
// ---------------------------------------------------------------------------

int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
int? _ni(dynamic v) => v == null ? null : (v as num).toInt();
double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
String _s(dynamic v) => v == null ? '' : v.toString();
DateTime _date(dynamic v) => v == null ? DateTime.now() : DateTime.parse(v.toString()).toLocal();
DateTime? _ndate(dynamic v) => v == null ? null : DateTime.parse(v.toString()).toLocal();
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

T? _first<T>(Iterable<T> it) => it.isEmpty ? null : it.first;

String normPhone(String p) {
  final digits = p.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum TripStatus { booked, loaded, inTransit, delivered, pod, settled }

extension TripStatusX on TripStatus {
  String get db => switch (this) {
        TripStatus.booked => 'booked',
        TripStatus.loaded => 'loaded',
        TripStatus.inTransit => 'in_transit',
        TripStatus.delivered => 'delivered',
        TripStatus.pod => 'pod',
        TripStatus.settled => 'settled',
      };

  static TripStatus fromDb(String s) => switch (s) {
        'loaded' => TripStatus.loaded,
        'in_transit' => TripStatus.inTransit,
        'delivered' => TripStatus.delivered,
        'pod' => TripStatus.pod,
        'settled' => TripStatus.settled,
        _ => TripStatus.booked,
      };

  String get label => switch (this) {
        TripStatus.booked => 'Booked',
        TripStatus.loaded => 'Loaded',
        TripStatus.inTransit => 'In transit',
        TripStatus.delivered => 'POD baaki',
        TripStatus.pod => 'POD mila',
        TripStatus.settled => 'Settled',
      };

  String get short => switch (this) {
        TripStatus.booked => 'Booked',
        TripStatus.loaded => 'Loaded',
        TripStatus.inTransit => 'Transit',
        TripStatus.delivered => 'Delivered',
        TripStatus.pod => 'POD',
        TripStatus.settled => 'Settled',
      };

  String get action => switch (this) {
        TripStatus.booked => 'Booked',
        TripStatus.loaded => 'Loaded mark karo',
        TripStatus.inTransit => 'In transit mark karo',
        TripStatus.delivered => 'Delivered mark karo',
        TripStatus.pod => 'POD mila mark karo',
        TripStatus.settled => 'Settle karo',
      };

  bool get isActive => index < TripStatus.delivered.index;
  bool get isMoving => this == TripStatus.loaded || this == TripStatus.inTransit;
}

enum Role { agent, owner, driver, shipper }

Role? roleFromDb(String? s) => switch (s) {
      'agent' || 'staff' => Role.agent,
      'owner' => Role.owner,
      'driver' => Role.driver,
      'shipper' => Role.shipper,
      _ => null,
    };

class Profile {
  final String id;
  final String phone;
  final String name;
  final Role? role;
  final String? officeId;
  Profile(this.id, this.phone, this.name, this.role, this.officeId);
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
      _s(j['id']), _s(j['phone']), _s(j['name']), roleFromDb(j['role'] as String?), j['office_id'] as String?);
}

class Office {
  final String id;
  final String name;
  final String city;
  final String phone;
  final String gst;
  final int nextLr;
  final String kind; // agent | transport | parcel
  Office(this.id, this.name, this.city, this.phone, this.gst, this.nextLr, this.kind);
  factory Office.fromJson(Map<String, dynamic> j) => Office(_s(j['id']), _s(j['name']), _s(j['city']),
      _s(j['phone']), _s(j['gst_no']), _i(j['next_lr']), j['kind'] == null ? 'agent' : _s(j['kind']));
  bool get isAgent => kind == 'agent';
  String get kindLabel => switch (kind) {
        'transport' => 'Goods transport',
        'parcel' => 'Parcel service',
        _ => 'Commission agent',
      };
}

/// A bilty: one party's goods or parcel. Part-load trucks carry many of these.
class Consignment {
  final String id;
  final String? tripId;
  final int lr;
  final DateTime date;
  final String partyId;
  final String consignee;
  final String consigneePhone;
  final String from;
  final String to;
  final String material;
  final int? packages;
  final double? weightTon;
  final double? weightKg;
  final int freight;
  final String payType; // paid | to_pay | tbb
  final String status; // booked | loaded | delivered
  final String service; // goods | parcel
  final int? declaredValue;
  final String deliveredTo;
  final DateTime? deliveredAt;
  final String? podPath;
  final List<Payment> payments = [];

  Consignment.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        tripId = j['trip_id'] as String?,
        lr = _i(j['lr_no']),
        date = _date(j['booking_date']),
        partyId = _s(j['party_id']),
        consignee = _s(j['consignee']),
        consigneePhone = _s(j['consignee_phone']),
        from = _s(j['from_city']),
        to = _s(j['to_city']),
        material = _s(j['material']),
        packages = _ni(j['packages']),
        weightTon = _d(j['weight_ton']),
        weightKg = _d(j['weight_kg']),
        freight = _i(j['freight']),
        payType = _s(j['pay_type']),
        status = _s(j['status']),
        service = _s(j['service']),
        declaredValue = _ni(j['declared_value']),
        deliveredTo = _s(j['delivered_to']),
        deliveredAt = _ndate(j['delivered_at']),
        podPath = j['pod_path'] as String?;

  bool get isParcel => service == 'parcel';
  bool get isToPay => payType == 'to_pay';
  int get received => payments.fold(0, (s, p) => s + p.amount);
  int get balance => freight - received;
  String get route => '$from → $to';

  /// Weight in tons for space calculations (parcels are stored in kg).
  double get tons => weightTon ?? ((weightKg ?? 0) / 1000);
  String get weightLabel {
    if (weightKg != null && (weightTon == null || isParcel)) return '${_trim(weightKg!)} kg';
    if (weightTon != null) return ton(weightTon!);
    return '';
  }

  String get payLabel => payTypeLabel(payType);
}

String payTypeLabel(String t) => switch (t) {
      'to_pay' => 'To-pay',
      'tbb' => 'TBB (bill)',
      _ => 'Paid',
    };

String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// A bilty seen by its sender or receiver.
class LinkedConsignment {
  final String id;
  final int lr;
  final DateTime date;
  final String service;
  final String status;
  final String relation; // sender | receiver
  final String from;
  final String to;
  final String material;
  final int? packages;
  final double? weightTon;
  final double? weightKg;
  final String consignee;
  final String partyName;
  final String officeName;
  final String officePhone;
  final String payType;
  final int? freight;
  final int? paid;
  final String truckNumber;
  final String driverName;
  final String driverPhone;
  final String deliveredTo;
  final DateTime? deliveredAt;
  final String? podPath;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastAt;

  LinkedConsignment.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        lr = _i(j['lr_no']),
        date = _date(j['booking_date']),
        service = _s(j['service']),
        status = _s(j['status']),
        relation = _s(j['my_relation']),
        from = _s(j['from_city']),
        to = _s(j['to_city']),
        material = _s(j['material']),
        packages = _ni(j['packages']),
        weightTon = _d(j['weight_ton']),
        weightKg = _d(j['weight_kg']),
        consignee = _s(j['consignee']),
        partyName = _s(j['party_name']),
        officeName = _s(j['office_name']),
        officePhone = _s(j['office_phone']),
        payType = _s(j['pay_type']),
        freight = _ni(j['freight']),
        paid = _ni(j['paid']),
        truckNumber = _s(j['truck_number']),
        driverName = _s(j['driver_name']),
        driverPhone = _s(j['driver_phone']),
        deliveredTo = _s(j['delivered_to']),
        deliveredAt = _ndate(j['delivered_at']),
        podPath = j['pod_path'] as String?,
        lastLat = _d(j['last_lat']),
        lastLng = _d(j['last_lng']),
        lastAt = _ndate(j['last_at']);

  bool get isParcel => service == 'parcel';
  int get balance => (freight ?? 0) - (paid ?? 0);
  String get route => '$from → $to';
  String get statusLabel => switch (status) {
        'loaded' => 'Raste mein',
        'delivered' => 'Pahunch gaya',
        _ => 'Godown mein',
      };
}

class Party {
  final String id;
  final String name;
  final String city;
  final String phone;
  final int opening; // purana baaki (party owes the agent)
  Party(this.id, this.name, this.city, this.phone, [this.opening = 0]);
  factory Party.fromJson(Map<String, dynamic> j) =>
      Party(_s(j['id']), _s(j['name']), _s(j['city']), _s(j['phone']), _i(j['opening_balance']));
}

class TruckOwner {
  final String id;
  final String name;
  final String phone;
  final int opening; // purana baaki (agent owes the owner)
  TruckOwner(this.id, this.name, this.phone, [this.opening = 0]);
  factory TruckOwner.fromJson(Map<String, dynamic> j) =>
      TruckOwner(_s(j['id']), _s(j['name']), _s(j['phone']), _i(j['opening_balance']));
}

/// One row read from an Excel / CSV file, before it is saved.
class ImportRow {
  final Map<String, String> v;
  String? problem;
  ImportRow(this.v);
  String operator [](String k) => v[k] ?? '';
}

class Truck {
  final String id;
  final String? ownerId;
  final String number;
  final String type;
  final double? capacityTon;
  final String driver;
  final String driverPhone;
  final List<String> routes;
  Truck(this.id, this.ownerId, this.number, this.type, this.capacityTon, this.driver, this.driverPhone,
      this.routes);
  factory Truck.fromJson(Map<String, dynamic> j) => Truck(
        _s(j['id']),
        j['owner_id'] as String?,
        _s(j['number']),
        _s(j['truck_type']),
        _d(j['capacity_ton']),
        _s(j['driver_name']),
        _s(j['driver_phone']),
        ((j['routes'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

class Payment {
  final String id;
  final String tripId;
  final String side; // party | owner
  final int amount;
  final String mode;
  final String note;
  final DateTime date;
  final String? consignmentId;
  Payment(this.id, this.tripId, this.side, this.amount, this.mode, this.note, this.date, [this.consignmentId]);
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(_s(j['id']), _s(j['trip_id']), _s(j['side']),
      _i(j['amount']), _s(j['mode']), _s(j['note']), _date(j['paid_on']), j['consignment_id'] as String?);
}

class Trip {
  final String id;
  final int lr;
  final DateTime date;
  final String partyId;
  final String consignee;
  final String truckId;
  final String from;
  final String to;
  final String material;
  final double weightTon;
  final int freight;
  final int hire;
  final TripStatus status;
  final int partyDeduction;
  final int ownerDeduction;
  final String? podPath;
  final String loadType; // full | part
  final List<Payment> payments = [];
  final List<Consignment> bilties = [];
  double? lastLat;
  double? lastLng;
  DateTime? lastAt;

  Trip({
    required this.id,
    required this.lr,
    required this.date,
    required this.partyId,
    required this.consignee,
    required this.truckId,
    required this.from,
    required this.to,
    required this.material,
    required this.weightTon,
    required this.freight,
    required this.hire,
    required this.status,
    required this.partyDeduction,
    required this.ownerDeduction,
    required this.podPath,
    this.loadType = 'full',
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: _s(j['id']),
        lr: _i(j['lr_no']),
        date: _date(j['trip_date']),
        partyId: _s(j['party_id']),
        consignee: _s(j['consignee']),
        truckId: _s(j['truck_id']),
        from: _s(j['from_city']),
        to: _s(j['to_city']),
        material: _s(j['material']),
        weightTon: _d(j['weight_ton']) ?? 0,
        freight: _i(j['freight']),
        hire: _i(j['hire']),
        status: TripStatusX.fromDb(_s(j['status'])),
        partyDeduction: _i(j['party_deduction']),
        ownerDeduction: _i(j['owner_deduction']),
        podPath: j['pod_path'] as String?,
        loadType: j['load_type'] == null ? 'full' : _s(j['load_type']),
      );

  bool get isPart => loadType == 'part';
  int get biltyFreight => bilties.fold(0, (s, c) => s + c.freight);
  double get loadedTons => bilties.fold(0.0, (s, c) => s + c.tons);

  List<Payment> get partyPayments => payments.where((p) => p.side == 'party' && p.consignmentId == null).toList();
  List<Payment> get ownerPayments => payments.where((p) => p.side == 'owner').toList();
  int get commission => (isPart ? biltyFreight : freight) - hire;
  int get partyReceived => partyPayments.fold(0, (s, p) => s + p.amount);
  int get ownerPaid => ownerPayments.fold(0, (s, p) => s + p.amount);
  int get partyBalance => isPart ? 0 : freight - partyDeduction - partyReceived;
  int get ownerBalance => hire - ownerDeduction - ownerPaid;
  String get route => '$from → $to';
}

/// A trip seen by a truck owner, driver or shipper (only their side's money).
class LinkedTrip {
  final String id;
  final int lr;
  final DateTime date;
  final TripStatus status;
  final String relation; // party | owner | driver
  final String from;
  final String to;
  final String material;
  final double weightTon;
  final String consignee;
  final String truckNumber;
  final String truckType;
  final String driverName;
  final String driverPhone;
  final String ownerName;
  final String ownerPhone;
  final String partyName;
  final String partyPhone;
  final String officeName;
  final String officePhone;
  final int? amount;
  final int? deduction;
  final int? settled;
  final String? podPath;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastAt;

  LinkedTrip.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        lr = _i(j['lr_no']),
        date = _date(j['trip_date']),
        status = TripStatusX.fromDb(_s(j['status'])),
        relation = _s(j['my_relation']),
        from = _s(j['from_city']),
        to = _s(j['to_city']),
        material = _s(j['material']),
        weightTon = _d(j['weight_ton']) ?? 0,
        consignee = _s(j['consignee']),
        truckNumber = _s(j['truck_number']),
        truckType = _s(j['truck_type']),
        driverName = _s(j['driver_name']),
        driverPhone = _s(j['driver_phone']),
        ownerName = _s(j['owner_name']),
        ownerPhone = _s(j['owner_phone']),
        partyName = _s(j['party_name']),
        partyPhone = _s(j['party_phone']),
        officeName = _s(j['office_name']),
        officePhone = _s(j['office_phone']),
        amount = _ni(j['amount']),
        deduction = _ni(j['deduction']),
        settled = _ni(j['settled']),
        podPath = j['pod_path'] as String?,
        lastLat = _d(j['last_lat']),
        lastLng = _d(j['last_lng']),
        lastAt = _ndate(j['last_at']);

  int get balance => (amount ?? 0) - (deduction ?? 0) - (settled ?? 0);
  String get route => '$from → $to';
}

class LoadPost {
  final String id;
  final String postedBy;
  final String posterName;
  final String posterPhone;
  final String from;
  final String to;
  final String material;
  final double weightTon;
  final String truckType;
  final String date;
  final int? rate;
  final bool isPart;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  LoadPost.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        postedBy = _s(j['posted_by']),
        posterName = _s(j['poster_name']),
        posterPhone = _s(j['poster_phone']),
        from = _s(j['from_city']),
        to = _s(j['to_city']),
        material = _s(j['material']),
        weightTon = _d(j['weight_ton']) ?? 0,
        truckType = _s(j['truck_type']),
        date = _s(j['loading_date']),
        rate = _ni(j['rate']),
        isPart = j['load_type'] == 'part',
        lat = _d(j['lat']),
        lng = _d(j['lng']),
        createdAt = _date(j['created_at']);
}

class TruckPost {
  final String id;
  final String postedBy;
  final String posterName;
  final String posterPhone;
  final String truckNo;
  final String type;
  final double? capacityTon;
  final String area;
  final double? lat;
  final double? lng;
  final List<String> wantTo;
  final double? spaceTon;
  final DateTime createdAt;
  TruckPost.fromJson(Map<String, dynamic> j)
      : id = _s(j['id']),
        postedBy = _s(j['posted_by']),
        posterName = _s(j['poster_name']),
        posterPhone = _s(j['poster_phone']),
        truckNo = _s(j['truck_number']),
        type = _s(j['truck_type']),
        capacityTon = _d(j['capacity_ton']),
        area = _s(j['area']),
        lat = _d(j['lat']),
        lng = _d(j['lng']),
        wantTo = ((j['want_to'] as List?) ?? const []).map((e) => e.toString()).toList(),
        spaceTon = _d(j['space_ton']),
        createdAt = _date(j['created_at']);
}

class LedgerEntry {
  final DateTime date;
  final String title;
  final String sub;
  final int amount;
  final String tripId;
  final int order;
  int balance = 0;
  LedgerEntry(this.date, this.title, this.sub, this.amount, this.tripId, this.order);
}

class PaymentLine {
  final String who;
  final Payment payment;
  final bool incoming;
  final int lr;
  PaymentLine(this.who, this.payment, this.incoming, this.lr);
}

// ---------------------------------------------------------------------------
// Formatting
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

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]}';
String fullDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
String ton(double t) => t == t.roundToDouble() ? '${t.round()} ton' : '$t ton';

String ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'Abhi';
  if (m < 60) return '$m min pehle';
  final h = m ~/ 60;
  if (h < 24) return '$h ghante pehle';
  return '${h ~/ 24} din pehle';
}

String friendlyError(Object e) {
  if (e is AuthException) {
    if (e.message.toLowerCase().contains('invalid')) return 'PIN galat hai';
    return e.message;
  }
  if (e is PostgrestException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return 'Server se jawab nahi aaya';
  }
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return 'Internet nahi hai — connection check karo';
  }
  return s.replaceFirst('Exception: ', '');
}

// ---------------------------------------------------------------------------
// Repository: everything the screens read and write
// ---------------------------------------------------------------------------

class Repo extends ChangeNotifier {
  SupabaseClient get db => Supabase.instance.client;

  Profile? profile;
  Office? office;
  List<Party> parties = [];
  List<TruckOwner> owners = [];
  List<Truck> trucks = [];
  List<Trip> trips = [];
  List<LoadPost> loads = [];
  List<TruckPost> truckPosts = [];
  List<LinkedTrip> linked = [];
  List<Consignment> bilties = [];
  List<LinkedConsignment> linkedBilties = [];
  bool busy = false;

  double? myLat;
  double? myLng;
  bool locationAllowed = false;
  Timer? _trackTimer;

  bool get signedIn => db.auth.currentSession != null;
  Role? get role => profile?.role;
  String get myName => (profile?.name.isNotEmpty ?? false) ? profile!.name : 'Ji';

  // ----- auth -----
  Future<void> signIn(String phone, String pin) async {
    final p = normPhone(phone);
    await db.functions.invoke('pin-auth', body: {'phone': p, 'pin': pin});
    await db.auth.signInWithPassword(email: '$p@$phoneLoginDomain', password: 'tw-$pin-$p');
    await loadProfile();
  }

  Future<void> signOut() async {
    stopTracking();
    await db.auth.signOut();
    profile = null;
    office = null;
    parties = [];
    owners = [];
    trucks = [];
    trips = [];
    linked = [];
    notifyListeners();
  }

  Future<void> loadProfile() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;
    final row = await db.from('profiles').select().eq('id', uid).maybeSingle();
    profile = row == null ? null : Profile.fromJson(row);
    if (profile?.officeId != null) {
      final o = await db.from('offices').select().eq('id', profile!.officeId!).maybeSingle();
      office = o == null ? null : Office.fromJson(o);
    }
    notifyListeners();
  }

  Future<void> createOffice({
    required String name,
    required String person,
    required String city,
    required String phone,
    required String gst,
    required int startLr,
    String kind = 'agent',
  }) async {
    await db.rpc('create_office', params: {
      'p_name': name,
      'p_person': person,
      'p_city': city,
      'p_phone': phone,
      'p_gst': gst,
      'p_start_lr': startLr,
      'p_kind': kind,
    });
    await loadProfile();
  }

  Future<void> setRole(Role r, String name) async {
    await db.rpc('set_my_role', params: {
      'p_role': switch (r) { Role.agent => 'agent', Role.owner => 'owner', Role.driver => 'driver', Role.shipper => 'shipper' },
      'p_name': name,
    });
    await loadProfile();
  }

  // ----- agent office data -----
  Future<void> refreshOffice() async {
    if (profile?.officeId == null) return;
    final results = await Future.wait<dynamic>([
      db.from('parties').select().order('name'),
      db.from('truck_owners').select().order('name'),
      db.from('trucks').select().order('number'),
      db.from('trips').select().order('lr_no', ascending: false).limit(500),
      db.from('payments').select().order('paid_on', ascending: false).limit(2000),
      db.from('offices').select().eq('id', profile!.officeId!).maybeSingle(),
      db.from('consignments').select().order('lr_no', ascending: false).limit(1500),
    ]);
    parties = (results[0] as List).map((e) => Party.fromJson(e)).toList();
    owners = (results[1] as List).map((e) => TruckOwner.fromJson(e)).toList();
    trucks = (results[2] as List).map((e) => Truck.fromJson(e)).toList();
    trips = (results[3] as List).map((e) => Trip.fromJson(e)).toList();
    final pays = (results[4] as List).map((e) => Payment.fromJson(e)).toList();
    final byId = {for (final t in trips) t.id: t};
    bilties = (results[6] as List).map((e) => Consignment.fromJson(e)).toList();
    final consById = {for (final c in bilties) c.id: c};
    for (final p in pays) {
      if (p.consignmentId != null) {
        consById[p.consignmentId]?.payments.add(p);
      } else {
        byId[p.tripId]?.payments.add(p);
      }
    }
    for (final c in bilties) {
      if (c.tripId != null) byId[c.tripId]?.bilties.add(c);
    }
    if (results[5] != null) office = Office.fromJson(results[5] as Map<String, dynamic>);

    final moving = trips.where((t) => t.status.isMoving).map((t) => t.id).toList();
    if (moving.isNotEmpty) {
      final locs = await db
          .from('trip_locations')
          .select('trip_id, lat, lng, recorded_at')
          .inFilter('trip_id', moving)
          .order('recorded_at', ascending: false)
          .limit(300);
      for (final l in (locs as List)) {
        final t = byId[l['trip_id']];
        if (t != null && t.lastLat == null) {
          t.lastLat = _d(l['lat']);
          t.lastLng = _d(l['lng']);
          t.lastAt = _ndate(l['recorded_at']);
        }
      }
    }
    notifyListeners();
  }

  Party? party(String id) => _first(parties.where((p) => p.id == id));
  Truck? truck(String id) => _first(trucks.where((t) => t.id == id));
  TruckOwner? owner(String? id) => _first(owners.where((o) => o.id == id));
  Trip? trip(String id) => _first(trips.where((t) => t.id == id));
  String partyName(String id) => party(id)?.name ?? '—';
  String truckNo(String id) => truck(id)?.number ?? '—';

  List<Trip> get activeTrips => trips.where((t) => t.status.isActive).toList();
  int get totalReceivable => parties.fold(0, (s, p) {
        final b = partyBalance(p.id);
        return s + (b > 0 ? b : 0);
      });
  int get totalPayable => owners.fold(0, (s, o) {
        final b = ownerBalance(o.id);
        return s + (b > 0 ? b : 0);
      });
  int get receivableParties => parties.where((p) => partyBalance(p.id) > 0).length;
  int get payableOwners => owners.where((o) => ownerBalance(o.id) > 0).length;
  List<Trip> get monthTrips {
    final n = DateTime.now();
    return trips.where((t) => t.date.year == n.year && t.date.month == n.month).toList();
  }

  int get monthCommission => monthTrips.fold(0, (s, t) => s + t.commission);
  int partyBalance(String id) =>
      (party(id)?.opening ?? 0) +
      trips.where((t) => t.partyId == id).fold(0, (s, t) => s + t.partyBalance) +
      bilties.where((c) => c.partyId == id && !c.isToPay).fold(0, (s, c) => s + c.balance);

  /// Bilties still in the godown (booked, no truck yet).
  List<Consignment> get godown => bilties.where((c) => c.tripId == null && c.status == 'booked').toList();
  List<Consignment> get toPayPending => bilties.where((c) => c.isToPay && c.balance > 0).toList();
  int get toPayTotal => toPayPending.fold(0, (s, c) => s + c.balance);
  Consignment? bilty(String id) => _first(bilties.where((c) => c.id == id));
  int ownerBalance(String id) =>
      (owner(id)?.opening ?? 0) +
      trips.where((t) => truck(t.truckId)?.ownerId == id).fold(0, (s, t) => s + t.ownerBalance);

  List<PaymentLine> get recentPayments {
    final list = <PaymentLine>[];
    for (final t in trips) {
      for (final p in t.payments) {
        final who = p.side == 'party'
            ? partyName(t.partyId)
            : '${owner(truck(t.truckId)?.ownerId)?.name ?? 'Truck owner'} (owner)';
        list.add(PaymentLine(who, p, p.side == 'party', t.lr));
      }
    }
    list.sort((a, b) => b.payment.date.compareTo(a.payment.date));
    return list;
  }

  List<LedgerEntry> partyLedger(String partyId) {
    final entries = <LedgerEntry>[];
    var seq = 0;
    final open = party(partyId)?.opening ?? 0;
    if (open != 0) entries.add(LedgerEntry(DateTime(2000), 'Purana baaki', 'Diary se', open, '', seq++));
    final ts = trips.where((t) => t.partyId == partyId).toList()..sort((a, b) => a.lr.compareTo(b.lr));
    for (final t in ts) {
      entries.add(LedgerEntry(t.date, t.route, 'LR ${t.lr} · freight', t.freight, t.id, seq++));
      for (final p in t.partyPayments) {
        final title = p.note.isNotEmpty ? '${p.note} mila · ${p.mode}' : 'Payment mila · ${p.mode}';
        entries.add(LedgerEntry(p.date, title, 'LR ${t.lr}', -p.amount, t.id, seq++));
      }
      if (t.partyDeduction > 0) {
        entries.add(LedgerEntry(t.date, 'Shortage / kata', 'LR ${t.lr}', -t.partyDeduction, t.id, seq++));
      }
    }
    for (final c in bilties.where((c) => c.partyId == partyId && !c.isToPay).toList().reversed) {
      entries.add(LedgerEntry(c.date, '${c.isParcel ? 'Parcel' : 'Bilty'} ${c.route}',
          'LR ${c.lr} · ${c.payLabel}', c.freight, c.tripId ?? '', seq++));
      for (final p in c.payments) {
        entries.add(LedgerEntry(p.date, 'Payment mila · ${p.mode}', 'LR ${c.lr}', -p.amount, c.tripId ?? '', seq++));
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

  String get _officeId => profile!.officeId!;

  Future<Party> addParty(String name, String city, String phone, {int opening = 0}) async {
    final row = await db
        .from('parties')
        .insert({'office_id': _officeId, 'name': name, 'city': city, 'phone': normPhone(phone), 'opening_balance': opening})
        .select()
        .single();
    await refreshOffice();
    return Party.fromJson(row);
  }

  Future<TruckOwner> addOwner(String name, String phone, {int opening = 0}) async {
    final row = await db
        .from('truck_owners')
        .insert({'office_id': _officeId, 'name': name, 'phone': normPhone(phone), 'opening_balance': opening})
        .select()
        .single();
    await refreshOffice();
    return TruckOwner.fromJson(row);
  }

  Future<void> updateParty(String id, {required String name, required String city, required String phone, required int opening}) async {
    await db.from('parties').update({'name': name, 'city': city, 'phone': normPhone(phone), 'opening_balance': opening}).eq('id', id);
    await refreshOffice();
  }

  Future<void> updateOwner(String id, {required String name, required String phone, required int opening}) async {
    await db.from('truck_owners').update({'name': name, 'phone': normPhone(phone), 'opening_balance': opening}).eq('id', id);
    await refreshOffice();
  }

  Future<void> updateTruck(String id,
      {required String number,
      required String type,
      required double? capacity,
      required String? ownerId,
      required String driver,
      required String driverPhone,
      required List<String> routes}) async {
    await db.from('trucks').update({
      'number': number.toUpperCase(),
      'truck_type': type,
      'capacity_ton': capacity,
      'owner_id': ownerId,
      'driver_name': driver,
      'driver_phone': normPhone(driverPhone),
      'routes': routes,
    }).eq('id', id);
    await refreshOffice();
  }

  /// Deletes are refused while trips still point at the record.
  Future<String?> deleteParty(String id) async {
    if (trips.any((t) => t.partyId == id)) return 'Is party ke trips hain — pehle woh trips hatao';
    await db.from('parties').delete().eq('id', id);
    await refreshOffice();
    return null;
  }

  Future<String?> deleteOwner(String id) async {
    await db.from('trucks').update({'owner_id': null}).eq('owner_id', id);
    await db.from('truck_owners').delete().eq('id', id);
    await refreshOffice();
    return null;
  }

  Future<String?> deleteTruck(String id) async {
    if (trips.any((t) => t.truckId == id)) return 'Is truck ke trips hain — pehle woh trips hatao';
    await db.from('trucks').delete().eq('id', id);
    await refreshOffice();
    return null;
  }

  Future<void> updateTrip(Trip t,
      {required String partyId,
      required String consignee,
      required String truckId,
      required String from,
      required String to,
      required String material,
      required double weightTon,
      required int freight,
      required int hire,
      DateTime? date}) async {
    await db.from('trips').update({
      if (date != null) 'trip_date': _ymd(date),
      'party_id': partyId,
      'consignee': consignee,
      'truck_id': truckId,
      'from_city': from,
      'to_city': to,
      'material': material,
      'weight_ton': weightTon,
      'freight': freight,
      'hire': hire,
    }).eq('id', t.id);
    await refreshOffice();
  }

  Future<void> deleteTrip(Trip t) async {
    await db.from('trips').delete().eq('id', t.id);
    await refreshOffice();
  }

  Future<void> deletePayment(Payment p) async {
    await db.from('payments').delete().eq('id', p.id);
    await refreshOffice();
  }

  Future<void> clearDeductions(Trip t) async {
    await db.from('trips').update({'party_deduction': 0, 'owner_deduction': 0}).eq('id', t.id);
    await refreshOffice();
  }

  // ----- register-style entry: create party / truck / owner on the fly -----
  Party? partyByName(String name) =>
      _first(parties.where((p) => p.name.trim().toLowerCase() == name.trim().toLowerCase()));
  Truck? truckByNumber(String no) => _first(trucks.where(
      (t) => t.number.replaceAll(' ', '').toUpperCase() == no.replaceAll(' ', '').toUpperCase()));
  TruckOwner? ownerByName(String name) =>
      _first(owners.where((o) => o.name.trim().toLowerCase() == name.trim().toLowerCase()));

  Future<String> partyIdFor(String name, {String phone = '', String city = ''}) async {
    final p = partyByName(name);
    if (p != null) {
      if (phone.isNotEmpty && p.phone.isEmpty) {
        await db.from('parties').update({'phone': normPhone(phone)}).eq('id', p.id);
      }
      return p.id;
    }
    final row = await db
        .from('parties')
        .insert({'office_id': _officeId, 'name': name.trim(), 'city': city, 'phone': normPhone(phone)})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> truckIdFor(String number,
      {String driver = '', String driverPhone = '', String ownerName = '', String ownerPhone = ''}) async {
    String? ownerId;
    if (ownerName.trim().isNotEmpty) {
      final o = ownerByName(ownerName);
      if (o != null) {
        ownerId = o.id;
      } else {
        final row = await db
            .from('truck_owners')
            .insert({'office_id': _officeId, 'name': ownerName.trim(), 'phone': normPhone(ownerPhone)})
            .select('id')
            .single();
        ownerId = row['id'] as String;
      }
    }
    final t = truckByNumber(number);
    if (t != null) {
      final upd = <String, dynamic>{
        if (driver.isNotEmpty && driver != t.driver) 'driver_name': driver,
        if (driverPhone.isNotEmpty && normPhone(driverPhone) != t.driverPhone) 'driver_phone': normPhone(driverPhone),
        if (ownerId != null && t.ownerId == null) 'owner_id': ownerId,
      };
      if (upd.isNotEmpty) await db.from('trucks').update(upd).eq('id', t.id);
      return t.id;
    }
    final row = await db
        .from('trucks')
        .insert({
          'office_id': _officeId,
          'number': number.trim().toUpperCase(),
          'truck_type': 'Open body',
          'owner_id': ownerId,
          'driver_name': driver,
          'driver_phone': normPhone(driverPhone),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Saves the opening balances screen: updates existing names, inserts new ones.
  Future<void> saveOpenings({required bool partiesSide, required List<(String, String, int)> rows}) async {
    final table = partiesSide ? 'parties' : 'truck_owners';
    final inserts = <Map<String, dynamic>>[];
    for (final (name, phone, amount) in rows) {
      if (name.trim().isEmpty) continue;
      final existingId = partiesSide ? partyByName(name)?.id : ownerByName(name)?.id;
      if (existingId != null) {
        await db.from(table).update({
          'opening_balance': amount,
          if (phone.trim().isNotEmpty) 'phone': normPhone(phone),
        }).eq('id', existingId);
      } else {
        inserts.add({'office_id': _officeId, 'name': name.trim(), 'phone': normPhone(phone), 'opening_balance': amount});
      }
    }
    if (inserts.isNotEmpty) await db.from(table).insert(inserts);
    await refreshOffice();
  }

  // ----- bulk import (Excel / CSV / contacts) -----
  Future<int> importParties(List<ImportRow> rows) async {
    final known = parties.map((p) => p.name.toLowerCase()).toSet();
    final data = [
      for (final r in rows)
        if (r.problem == null && !known.contains(r['name'].toLowerCase()))
          {
            'office_id': _officeId,
            'name': r['name'],
            'city': r['city'],
            'phone': normPhone(r['phone']),
            'opening_balance': int.tryParse(r['opening'].replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0,
          }
    ];
    if (data.isNotEmpty) await db.from('parties').insert(data);
    await refreshOffice();
    return data.length;
  }

  Future<int> importOwners(List<ImportRow> rows) async {
    final known = owners.map((o) => o.name.toLowerCase()).toSet();
    final data = [
      for (final r in rows)
        if (r.problem == null && !known.contains(r['name'].toLowerCase()))
          {
            'office_id': _officeId,
            'name': r['name'],
            'phone': normPhone(r['phone']),
            'opening_balance': int.tryParse(r['opening'].replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0,
          }
    ];
    if (data.isNotEmpty) await db.from('truck_owners').insert(data);
    await refreshOffice();
    return data.length;
  }

  Future<int> importTrucks(List<ImportRow> rows) async {
    // Owners named in the sheet are created first if they do not exist yet.
    final newOwners = <String, String>{};
    for (final r in rows) {
      final n = r['owner'].trim();
      if (r.problem == null && n.isNotEmpty && !owners.any((o) => o.name.toLowerCase() == n.toLowerCase())) {
        newOwners[n.toLowerCase()] = n;
      }
    }
    if (newOwners.isNotEmpty) {
      await db.from('truck_owners').insert([
        for (final n in newOwners.values) {'office_id': _officeId, 'name': n, 'phone': ''}
      ]);
      await refreshOffice();
    }
    final known = trucks.map((t) => t.number.replaceAll(' ', '').toUpperCase()).toSet();
    final data = [
      for (final r in rows)
        if (r.problem == null && !known.contains(r['number'].replaceAll(' ', '').toUpperCase()))
          {
            'office_id': _officeId,
            'number': r['number'].toUpperCase(),
            'truck_type': r['type'].isEmpty ? 'Open body' : r['type'],
            'capacity_ton': double.tryParse(r['capacity'].replaceAll(RegExp(r'[^0-9.]'), '')),
            'owner_id': _first(owners.where((o) => o.name.toLowerCase() == r['owner'].trim().toLowerCase()))?.id,
            'driver_name': r['driver'],
            'driver_phone': normPhone(r['driver_phone']),
            'routes': r['routes'].split(RegExp(r'[;,]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          }
    ];
    if (data.isNotEmpty) await db.from('trucks').insert(data);
    await refreshOffice();
    return data.length;
  }

  /// Suggestions for the trip form, most used first.
  List<String> get usedCities {
    final count = <String, int>{};
    for (final t in trips) {
      count[t.from] = (count[t.from] ?? 0) + 1;
      count[t.to] = (count[t.to] ?? 0) + 1;
    }
    final list = count.keys.where((k) => k.isNotEmpty).toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    return list;
  }

  List<String> get usedMaterials {
    final count = <String, int>{};
    for (final t in trips) {
      if (t.material.isNotEmpty) count[t.material] = (count[t.material] ?? 0) + 1;
    }
    return count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
  }

  Trip? lastTripOfParty(String partyId) => _first(trips.where((t) => t.partyId == partyId));

  Future<void> addTruck({
    required String number,
    required String type,
    required double? capacity,
    required String? ownerId,
    required String driver,
    required String driverPhone,
    required List<String> routes,
  }) async {
    await db.from('trucks').insert({
      'office_id': _officeId,
      'number': number.toUpperCase(),
      'truck_type': type,
      'capacity_ton': capacity,
      'owner_id': ownerId,
      'driver_name': driver,
      'driver_phone': normPhone(driverPhone),
      'routes': routes,
    });
    await refreshOffice();
  }

  Future<Trip> addTrip({
    required String partyId,
    required String consignee,
    required String truckId,
    required String from,
    required String to,
    required String material,
    required double weightTon,
    required int freight,
    required int hire,
    required int partyAdvance,
    required int ownerAdvance,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final row = await db
        .from('trips')
        .insert({
          'office_id': _officeId,
          'lr_no': 0,
          'trip_date': _ymd(d),
          'party_id': partyId,
          'consignee': consignee,
          'truck_id': truckId,
          'from_city': from,
          'to_city': to,
          'material': material,
          'weight_ton': weightTon,
          'freight': freight,
          'hire': hire,
        })
        .select()
        .single();
    final t = Trip.fromJson(row);
    final pays = <Map<String, dynamic>>[
      if (partyAdvance > 0)
        {'office_id': _officeId, 'trip_id': t.id, 'side': 'party', 'amount': partyAdvance, 'mode': 'Cash', 'note': 'Advance', 'paid_on': _ymd(d)},
      if (ownerAdvance > 0)
        {'office_id': _officeId, 'trip_id': t.id, 'side': 'owner', 'amount': ownerAdvance, 'mode': 'Cash', 'note': 'Advance', 'paid_on': _ymd(d)},
    ];
    if (pays.isNotEmpty) await db.from('payments').insert(pays);
    await refreshOffice();
    return trip(t.id) ?? t;
  }

  Future<void> addPayment(Trip t, {required bool party, required int amount, required String mode}) async {
    await db.from('payments').insert({
      'office_id': _officeId,
      'trip_id': t.id,
      'side': party ? 'party' : 'owner',
      'amount': amount,
      'mode': mode,
      'paid_on': _ymd(DateTime.now()),
    });
    await refreshOffice();
  }

  Future<void> addDeduction(Trip t, {required int amount, required bool bothSides}) async {
    await db.from('trips').update({
      'party_deduction': t.partyDeduction + amount,
      if (bothSides) 'owner_deduction': t.ownerDeduction + amount,
    }).eq('id', t.id);
    await refreshOffice();
  }

  Future<void> setTripStatus(Trip t, TripStatus s) async {
    await db.from('trips').update({'status': s.db}).eq('id', t.id);
    await refreshOffice();
  }

  // ----- linked roles (owner / driver / shipper) -----
  Future<void> refreshLinked() async {
    final r = await Future.wait<dynamic>([db.rpc('linked_trips'), db.rpc('linked_consignments')]);
    linked = (r[0] as List).map((e) => LinkedTrip.fromJson(e as Map<String, dynamic>)).toList();
    linkedBilties = (r[1] as List).map((e) => LinkedConsignment.fromJson(e as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  // ----- bilty / part load / parcel -----
  Future<Consignment> addBilty({
    required String partyName,
    String partyPhone = '',
    required String consignee,
    String consigneePhone = '',
    required String from,
    required String to,
    required String material,
    int? packages,
    double? weightTon,
    double? weightKg,
    required int freight,
    required String payType,
    required String service,
    int? declaredValue,
    int paidNow = 0,
    String? tripId,
    DateTime? date,
  }) async {
    final pid = await partyIdFor(partyName, phone: partyPhone);
    final d = date ?? DateTime.now();
    final row = await db
        .from('consignments')
        .insert({
          'office_id': _officeId,
          'lr_no': 0,
          'booking_date': _ymd(d),
          'trip_id': tripId,
          'party_id': pid,
          'consignee': consignee,
          'consignee_phone': normPhone(consigneePhone),
          'from_city': from,
          'to_city': to,
          'material': material,
          'packages': packages,
          'weight_ton': weightTon,
          'weight_kg': weightKg,
          'freight': freight,
          'pay_type': payType,
          'service': service,
          'declared_value': declaredValue,
          'status': tripId == null ? 'booked' : 'loaded',
        })
        .select()
        .single();
    final c = Consignment.fromJson(row);
    if (paidNow > 0) {
      await db.from('payments').insert({
        'office_id': _officeId,
        'consignment_id': c.id,
        'trip_id': tripId,
        'side': 'party',
        'amount': paidNow,
        'mode': 'Cash',
        'note': 'Booking pe',
        'paid_on': _ymd(d),
      });
    }
    await refreshOffice();
    return bilty(c.id) ?? c;
  }

  Future<Trip> addPartTrip({
    required String truckId,
    required String from,
    required String to,
    required int hire,
    int ownerAdvance = 0,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final row = await db
        .from('trips')
        .insert({
          'office_id': _officeId,
          'lr_no': 0,
          'load_type': 'part',
          'trip_date': _ymd(d),
          'truck_id': truckId,
          'from_city': from,
          'to_city': to,
          'material': 'Part load',
          'freight': 0,
          'hire': hire,
        })
        .select()
        .single();
    final t = Trip.fromJson(row);
    if (ownerAdvance > 0) {
      await db.from('payments').insert({
        'office_id': _officeId,
        'trip_id': t.id,
        'side': 'owner',
        'amount': ownerAdvance,
        'mode': 'Cash',
        'note': 'Advance',
        'paid_on': _ymd(d),
      });
    }
    await refreshOffice();
    return trip(t.id) ?? t;
  }

  Future<void> loadBilties(List<String> ids, String tripId) async {
    if (ids.isEmpty) return;
    await db.from('consignments').update({'trip_id': tripId, 'status': 'loaded'}).inFilter('id', ids);
    await refreshOffice();
  }

  Future<void> unloadBilty(Consignment c) async {
    await db.from('consignments').update({'trip_id': null, 'status': 'booked'}).eq('id', c.id);
    await refreshOffice();
  }

  Future<void> deliverBilty(Consignment c, {required String receivedBy, int collect = 0, String mode = 'Cash'}) async {
    await db.from('consignments').update({
      'status': 'delivered',
      'delivered_to': receivedBy,
      'delivered_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', c.id);
    if (collect > 0) {
      await db.from('payments').insert({
        'office_id': _officeId,
        'consignment_id': c.id,
        'trip_id': c.tripId,
        'side': 'party',
        'amount': collect,
        'mode': mode,
        'note': c.isToPay ? 'Delivery pe' : '',
        'paid_on': _ymd(DateTime.now()),
      });
    }
    await refreshOffice();
  }

  Future<void> addBiltyPayment(Consignment c, int amount, String mode) async {
    await db.from('payments').insert({
      'office_id': _officeId,
      'consignment_id': c.id,
      'trip_id': c.tripId,
      'side': 'party',
      'amount': amount,
      'mode': mode,
      'paid_on': _ymd(DateTime.now()),
    });
    await refreshOffice();
  }

  Future<void> deleteBilty(Consignment c) async {
    await db.from('consignments').delete().eq('id', c.id);
    await refreshOffice();
  }

  Future<void> uploadBiltyPod(Consignment c, Uint8List bytes) async {
    final folder = c.tripId ?? _officeId;
    final path = '$folder/c-${c.id}-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await db.storage.from('pod').uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    await db.from('consignments').update({'pod_path': path}).eq('id', c.id);
    await refreshOffice();
  }

  List<LinkedTrip> linkedAs(String relation) => linked.where((t) => t.relation == relation).toList();

  Future<void> driverSetStatus(String tripId, TripStatus s) async {
    await db.rpc('driver_update_trip', params: {'p_trip': tripId, 'p_status': s.db, 'p_pod': null});
    await refreshLinked();
    if (s.isMoving) {
      await sendLocationNow();
    }
  }

  Future<void> uploadPod(String tripId, Uint8List bytes, {required bool asOffice}) async {
    final path = '$tripId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await db.storage.from('pod').uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    await db.rpc('driver_update_trip', params: {'p_trip': tripId, 'p_status': null, 'p_pod': path});
    if (asOffice) {
      await refreshOffice();
    } else {
      await refreshLinked();
    }
  }

  Future<String> podUrl(String path) => db.storage.from('pod').createSignedUrl(path, 3600);

  // ----- load board -----
  Future<void> refreshBoard() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final r = await Future.wait<dynamic>([
      db.from('loads').select().eq('status', 'open').gt('expires_at', now).order('created_at', ascending: false).limit(200),
      db
          .from('truck_posts')
          .select()
          .eq('status', 'open')
          .gt('expires_at', now)
          .order('created_at', ascending: false)
          .limit(200),
    ]);
    loads = (r[0] as List).map((e) => LoadPost.fromJson(e)).toList();
    truckPosts = (r[1] as List).map((e) => TruckPost.fromJson(e)).toList();
    if (myLat != null) {
      double dist(double? la, double? ln) => (la == null || ln == null) ? 99999 : kmBetween(myLat!, myLng!, la, ln);
      loads.sort((a, b) => dist(a.lat, a.lng).compareTo(dist(b.lat, b.lng)));
      truckPosts.sort((a, b) => dist(a.lat, a.lng).compareTo(dist(b.lat, b.lng)));
    }
    notifyListeners();
  }

  int? kmFromMe(double? lat, double? lng) {
    if (myLat == null || lat == null || lng == null) return null;
    return roadKm(myLat!, myLng!, lat, lng);
  }

  String get posterName => office?.name ?? (profile?.name.isNotEmpty == true ? profile!.name : 'TransWell user');

  Future<void> postLoad({
    required String from,
    required String to,
    required String material,
    required double weight,
    required String truckType,
    required String date,
    required int? rate,
    required bool showPhone,
    bool part = false,
  }) async {
    final c = coordsOf(from);
    await db.from('loads').insert({
      'posted_by': db.auth.currentUser!.id,
      'poster_name': posterName,
      'poster_phone': showPhone ? profile?.phone : null,
      'from_city': from,
      'to_city': to,
      'material': material,
      'weight_ton': weight,
      'truck_type': truckType,
      'loading_date': date,
      'rate': rate,
      'load_type': part ? 'part' : 'full',
      'lat': c?.$1 ?? myLat,
      'lng': c?.$2 ?? myLng,
    });
    await refreshBoard();
  }

  Future<void> postTruck({
    required String number,
    required String type,
    required double? capacity,
    required List<String> wantTo,
    double? spaceTon,
  }) async {
    await refreshMyPosition();
    final area = myLat != null ? nearLabel(myLat!, myLng!) : (office?.city ?? '');
    await db.from('truck_posts').insert({
      'posted_by': db.auth.currentUser!.id,
      'poster_name': posterName,
      'poster_phone': profile?.phone,
      'truck_number': number.toUpperCase(),
      'truck_type': type,
      'capacity_ton': capacity,
      'area': area,
      'lat': myLat,
      'lng': myLng,
      'want_to': wantTo,
      'space_ton': spaceTon,
    });
    await refreshBoard();
  }

  Future<void> closeLoad(LoadPost l) async {
    await db.from('loads').update({'status': 'fixed'}).eq('id', l.id);
    await refreshBoard();
  }

  Future<void> closeTruckPost(TruckPost p) async {
    await db.from('truck_posts').update({'status': 'booked'}).eq('id', p.id);
    await refreshBoard();
  }

  bool isMine(String postedBy) => postedBy == db.auth.currentUser?.id;

  // ----- location -----
  Future<bool> ensureLocationPermission({bool ask = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      locationAllowed = false;
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied && ask) p = await Geolocator.requestPermission();
    locationAllowed = p == LocationPermission.always || p == LocationPermission.whileInUse;
    notifyListeners();
    return locationAllowed;
  }

  Future<void> refreshMyPosition({bool ask = false}) async {
    try {
      if (!await ensureLocationPermission(ask: ask)) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      myLat = pos.latitude;
      myLng = pos.longitude;
      if (signedIn) {
        await db.rpc('update_my_position', params: {'p_lat': myLat, 'p_lng': myLng});
      }
      notifyListeners();
    } catch (_) {
      // Location is optional; the app works without it.
    }
  }

  /// Sends the driver's position for every moving trip they drive.
  Future<void> sendLocationNow() async {
    try {
      if (!await ensureLocationPermission(ask: false)) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      myLat = pos.latitude;
      myLng = pos.longitude;
      final uid = db.auth.currentUser?.id;
      if (uid == null) return;
      final moving = linked.where((t) => t.relation == 'driver' && t.status.isMoving).toList();
      if (moving.isNotEmpty) {
        await db.from('trip_locations').insert([
          for (final t in moving)
            {
              'trip_id': t.id,
              'user_id': uid,
              'lat': pos.latitude,
              'lng': pos.longitude,
              'speed': pos.speed * 3.6,
            }
        ]);
      }
      await db.rpc('update_my_position', params: {'p_lat': myLat, 'p_lng': myLng});
      notifyListeners();
    } catch (_) {}
  }

  void startTracking() {
    _trackTimer?.cancel();
    sendLocationNow();
    _trackTimer = Timer.periodic(const Duration(minutes: 2), (_) => sendLocationNow());
  }

  void stopTracking() {
    _trackTimer?.cancel();
    _trackTimer = null;
  }

  Future<void> run(Future<void> Function() job) async {
    busy = true;
    notifyListeners();
    try {
      await job();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<Repo> {
  const AppScope({super.key, required Repo repo, required super.child}) : super(notifier: repo);

  static Repo of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing (for callbacks).
  static Repo read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}
