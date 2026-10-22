import 'package:flutter/material.dart';

import 'agent.dart';
import 'cities.dart';
import 'data.dart';
import 'main.dart' show AccountMenu;
import 'services.dart';
import 'widgets.dart';

TrackingScreen trackingFor(LinkedTrip t, {String? sharePhone}) => TrackingScreen(
      title: t.truckNumber,
      subtitle: 'LR ${t.lr} · ${t.route}',
      from: t.from,
      to: t.to,
      lat: t.lastLat,
      lng: t.lastLng,
      at: t.lastAt,
      driver: t.driverName,
      driverPhone: t.driverPhone,
      sharePhone: sharePhone,
    );

String whereNow(LinkedTrip t) {
  if (!t.status.isMoving) return t.status.isActive ? t.from : t.to;
  if (t.lastLat == null) return 'Location abhi nahi aayi';
  return nearLabel(t.lastLat!, t.lastLng!);
}

Future<void> _guard(BuildContext context, Future<void> Function() job) async {
  try {
    await job();
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

/// Header row used on the owner / driver / shipper homes.
class _Header extends StatelessWidget {
  final String small;
  final String big;
  const _Header(this.small, this.big);
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(small, style: const TextStyle(fontSize: 13, color: C.muted)),
                Text(big, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const AccountMenu(),
        ],
      );
}

class _NotLinkedNote extends StatelessWidget {
  final String who;
  const _NotLinkedNote(this.who);
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return EmptyNote(
      'Abhi aapke number (${s.profile?.phone ?? ''}) par koi trip nahi hai. '
      'Jab koi transport agent TransWell mein $who ke roop mein yahi number daal ke trip banayega, '
      'woh yahan apne aap dikh jaayega.',
    );
  }
}

// ---------------------------------------------------------------------------
// Truck owner
// ---------------------------------------------------------------------------

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final r = AppScope.read(context);
    await _guard(context, () async {
      await r.refreshLinked();
      await r.refreshMyPosition(ask: true);
      await r.refreshBoard();
    });
  }

  Future<void> _postTruck(String number, String type) async {
    final r = AppScope.read(context);
    final number0 = TextEditingController(text: number);
    final cap = TextEditingController();
    final want = TextEditingController();
    var t = type.isEmpty ? 'Open body' : type;
    await showFormSheet(
      context,
      title: 'Gaadi khaali hai — post karo',
      fields: (setSt) => [
        Field(number0, 'Truck number'),
        Wrap(spacing: 8, children: [
          for (final x in ['Open body', 'Container', 'Trailer', 'Tanker'])
            ChoiceChip(label: Text(x), selected: t == x, showCheckmark: false, onSelected: (_) => setSt(() => t = x)),
        ]),
        Field(cap, 'Capacity (ton)', number: true),
        Field(want, 'Kis taraf jaana hai (comma se)', hint: 'Delhi, Punjab'),
        Text(
          r.myLat == null
              ? 'Location band hai — gaadi ki jagah nahi dikhegi. Location chalu karke post karna behtar hai.'
              : 'Gaadi ki jagah: ${nearLabel(r.myLat!, r.myLng!)} · 24 ghante tak sabko dikhegi',
          style: const TextStyle(fontSize: 12, color: C.muted),
        ),
      ],
      onSave: () async {
        if (number0.text.trim().isEmpty) return 'Truck number bharo';
        await r.postTruck(
          number: number0.text.trim(),
          type: t,
          capacity: double.tryParse(cap.text.trim()),
          wantTo: want.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        );
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mine = s.linkedAs('owner');
    final trucks = <String, String>{for (final t in mine) t.truckNumber: t.truckType};
    final byOffice = <String, int>{};
    for (final t in mine) {
      byOffice[t.officeName] = (byOffice[t.officeName] ?? 0) + t.balance;
    }
    final myPosts = s.truckPosts.where((p) => s.isMine(p.postedBy)).toList();
    return Scaffold(
      floatingActionButton: AmberFab(label: 'Gaadi khaali hai', onPressed: () => _postTruck('', '')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _Header('Namaste, ${s.myName} ji', 'Meri gaadiyan'),
              const SizedBox(height: 12),
              if (mine.isEmpty) const _NotLinkedNote('truck owner'),
              if (byOffice.isNotEmpty)
                Panel(
                  topBar: C.recv,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AGENTS SE LENA HAI',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.recv)),
                      const SizedBox(height: 6),
                      for (final e in byOffice.entries) KV(e.key, inr(e.value), bold: true),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              for (final entry in trucks.entries) ...[
                _truckCard(context, s, entry.key, entry.value, mine),
                const SizedBox(height: 12),
              ],
              if (myPosts.isNotEmpty) ...[
                const SectionTitle('Load board pe meri gaadiyan'),
                for (final p in myPosts) TruckPostCard(post: p),
              ],
              if (mine.isNotEmpty) ...[
                const SectionTitle('Mere trips'),
                for (final t in mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => LinkedTripScreen(tripId: t.id))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('${t.route} · LR ${t.lr}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                            StatusChip(t.status),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                              '${t.truckNumber} · ${t.officeName} · Hire ${num0(t.amount ?? 0)} · Mila ${num0(t.settled ?? 0)}',
                              style: const TextStyle(fontSize: 13, color: C.muted)),
                          Text('Baaki ${inr(t.balance)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
              const SectionTitle('Paas ke loads'),
              if (s.loads.isEmpty) const EmptyNote('Abhi koi load nahi'),
              for (final l in s.loads.take(5)) LoadCard(load: l),
              TextButton(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const LoadBoardScreen(initialTab: 1))),
                child: const Text('Poora load board dekho'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _truckCard(BuildContext context, Repo s, String number, String type, List<LinkedTrip> mine) {
    final active = mine.where((x) => x.truckNumber == number && x.status.isActive).toList();
    if (active.isNotEmpty) {
      final trip = active.first;
      final left = kmLeft(trip.to, trip.lastLat, trip.lastLng);
      return Panel(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => trackingFor(trip))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              const Pill('On trip', fg: C.brand, bg: C.brandSoft),
            ]),
            const SizedBox(height: 4),
            Text('${trip.route} · LR ${trip.lr} · Driver ${trip.driverName}', style: const TextStyle(fontSize: 14)),
            Text('Abhi: ${whereNow(trip)}${left == null ? '' : ' · $left km bacha'}',
                style: const TextStyle(fontSize: 13, color: C.recv, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    final posted = s.truckPosts.any((p) => s.isMine(p.postedBy) && p.truckNo == number.toUpperCase());
    return Panel(
      borderColor: C.amber,
      borderWidth: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            const Pill('Khaali', fg: C.recv, bg: C.recvSoft),
          ]),
          const SizedBox(height: 4),
          Text(type, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          if (!posted)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: C.ink),
              onPressed: () => _postTruck(number, type),
              child: const Text('Gaadi khaali hai — post karo', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.recvSoft, borderRadius: BorderRadius.circular(10)),
              child: const Text('Load board pe post hai · 24 ghante tak dikhegi',
                  style: TextStyle(color: C.recv, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Linked trip detail (owner / shipper / driver)
// ---------------------------------------------------------------------------

class LinkedTripScreen extends StatelessWidget {
  final String tripId;
  const LinkedTripScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.linked.where((x) => x.id == tripId).toList();
    if (list.isEmpty) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Trip nahi mila')));
    final t = list.first;
    final isParty = t.relation == 'party';
    final isOwner = t.relation == 'owner';
    return Scaffold(
      appBar: AppBar(title: Text('LR ${t.lr} · ${t.officeName}')),
      body: RefreshIndicator(
        onRefresh: s.refreshLinked,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(child: StatusStepper(status: t.status)),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.route, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text('${dm(t.date)} · ${t.material} · ${ton(t.weightTon)}',
                      style: const TextStyle(fontSize: 13, color: C.muted)),
                  Text('${t.partyName} → ${t.consignee}', style: const TextStyle(fontSize: 13, color: C.muted)),
                  const Divider(height: 18, color: C.line),
                  Text('${t.truckNumber} · Driver ${t.driverName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (t.status.isMoving)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: C.recv),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => trackingFor(t))),
                      icon: const Icon(Icons.my_location, size: 18),
                      label: Text('Live: ${whereNow(t)}${t.lastAt == null ? '' : ' · ${ago(t.lastAt!)}'}'),
                    ),
                ],
              ),
            ),
            if (isParty || isOwner) ...[
              const SizedBox(height: 12),
              Panel(
                topBar: isParty ? C.pay : C.recv,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isParty ? 'MERA HISAAB (FREIGHT)' : 'MERA HISAAB (LORRY HIRE)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isParty ? C.pay : C.recv)),
                    KV(isParty ? 'Freight' : 'Lorry hire', num0(t.amount ?? 0)),
                    KV(isParty ? 'Diya' : 'Mila', '− ${num0(t.settled ?? 0)}'),
                    if ((t.deduction ?? 0) > 0) KV('Kata', '− ${num0(t.deduction!)}'),
                    const Divider(height: 10, color: C.line),
                    KV(isParty ? 'Dena hai' : 'Lena hai', inr(t.balance), bold: true),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: t.podPath == null ? null : () => showPodPhoto(context, t.podPath!),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(t.podPath == null ? 'POD abhi nahi' : 'POD photo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => callPhone(context, t.officePhone),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Agent ko call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Driver (Hindi)
// ---------------------------------------------------------------------------

const _hindiCity = {
  'delhi': 'दिल्ली',
  'jaipur': 'जयपुर',
  'ludhiana': 'लुधियाना',
  'ahmedabad': 'अहमदाबाद',
  'ajmer': 'अजमेर',
  'kota': 'कोटा',
  'indore': 'इंदौर',
  'ghaziabad': 'गाज़ियाबाद',
  'sonipat': 'सोनीपत',
  'mumbai': 'मुंबई',
  'agra': 'आगरा',
  'kanpur': 'कानपुर',
  'lucknow': 'लखनऊ',
  'surat': 'सूरत',
  'pune': 'पुणे',
  'bhopal': 'भोपाल',
  'udaipur': 'उदयपुर',
  'jodhpur': 'जोधपुर',
  'chandigarh': 'चंडीगढ़',
  'amritsar': 'अमृतसर',
  'gurgaon': 'गुड़गांव',
  'noida': 'नोएडा',
  'panipat': 'पानीपत',
};

String hi(String city) => _hindiCity[city.trim().toLowerCase()] ?? city;

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  void _next(BuildContext context) =>
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DriverHome()));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget point(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check, color: C.recv, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 16, height: 1.45))),
            ],
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: C.brandSoft, shape: BoxShape.circle),
                child: const Icon(Icons.location_on_outlined, size: 44, color: C.brand),
              ),
            ),
            const SizedBox(height: 20),
            const Text('ट्रिप के दौरान आपकी लोकेशन चाहिए',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 20),
            Panel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                children: [
                  point('सिर्फ ट्रिप चालू होने पर (लोड से डिलीवरी तक), जब तक यह ऐप खुला है'),
                  point('सिर्फ इन्हें दिखेगी: एजेंट, गाड़ी मालिक, और जिसका माल है'),
                  point('डिलीवरी होते ही बंद — उसके बाद कोई नहीं देख सकता'),
                  point('फायदा: बार-बार "कहाँ पहुँचे" वाले फोन कम, और पास के लोड आपको मिलेंगे'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 58)),
              onPressed: () async {
                await s.ensureLocationPermission(ask: true);
                if (context.mounted) _next(context);
              },
              child: const Text('ठीक है, अनुमति दें', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            TextButton(onPressed: () => _next(context), child: const Text('अभी नहीं', style: TextStyle(fontSize: 16))),
            const Text('"अभी नहीं" दबाने पर भी ट्रिप चलेगा, बस लाइव मैप नहीं दिखेगा',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
          ],
        ),
      ),
    );
  }
}

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> with WidgetsBindingObserver {
  bool working = false;
  late final Repo _repo;

  @override
  void initState() {
    super.initState();
    _repo = AppScope.read(context);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(start: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repo.stopTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final r = _repo;
    if (state == AppLifecycleState.resumed) {
      r.startTracking();
    } else if (state == AppLifecycleState.paused) {
      r.stopTracking();
    }
  }

  Future<void> _refresh({bool start = false}) async {
    final r = AppScope.read(context);
    await _guard(context, () async {
      await r.refreshLinked();
      await r.refreshMyPosition();
      await r.refreshBoard();
    });
    if (start) r.startTracking();
  }

  Future<void> _do(Future<void> Function() job, String done) async {
    setState(() => working = true);
    try {
      await job();
      if (mounted) toast(context, done);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mine = s.linkedAs('driver').where((t) => t.status.isActive).toList();
    final trip = mine.isEmpty ? null : mine.first;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header('राम राम, ${s.myName} जी', 'आज का ट्रिप'),
              const SizedBox(height: 12),
              if (trip == null)
                Panel(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'अभी कोई ट्रिप नहीं है। एजेंट आपका नंबर (${s.profile?.phone ?? ''}) गाड़ी में डालकर ट्रिप बनाएगा तो यहाँ दिखेगा। नीचे पास के लोड देखें।',
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${hi(trip.from)} → ${hi(trip.to)}',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('${trip.material} · ${trip.weightTon.round()} टन · ${trip.truckNumber} · LR ${trip.lr}',
                          style: const TextStyle(fontSize: 15, color: Color(0xFFDDE1F0))),
                      Text('माल देना है: ${trip.consignee}', style: const TextStyle(fontSize: 15, color: Color(0xFFDDE1F0))),
                      const SizedBox(height: 6),
                      Text(
                        !s.locationAllowed
                            ? '○ लोकेशन बंद है — ऊपर से चालू करें'
                            : trip.status.isMoving
                                ? '● लोकेशन चालू है (हर 2 मिनट)'
                                : '○ लोड होने के बाद लोकेशन चालू होगी',
                        style: const TextStyle(fontSize: 13, color: C.amber),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: C.amber, foregroundColor: C.ink, minimumSize: const Size(48, 56)),
                        onPressed: working
                            ? null
                            : () => trip.status == TripStatus.booked
                                ? _do(() => s.driverSetStatus(trip.id, TripStatus.loaded), 'एजेंट को बता दिया: लोड हो गया')
                                : _do(() => s.driverSetStatus(trip.id, TripStatus.delivered),
                                    'एजेंट और मालिक को बता दिया: पहुँच गया'),
                        child: Text(trip.status == TripStatus.booked ? 'लोड हो गया' : 'पहुँच गया',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF8F9AC8)),
                            minimumSize: const Size(48, 48)),
                        onPressed: working
                            ? null
                            : () async {
                                final bytes = await takePodPhoto(context);
                                if (bytes == null || !context.mounted) return;
                                await _do(() => s.uploadPod(trip.id, bytes, asOffice: false), 'बिल्टी की फोटो भेज दी');
                              },
                        child: Text(trip.podPath == null ? 'बिल्टी की फोटो भेजो' : 'बिल्टी फोटो भेजी ✓ (फिर से भेजो)',
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              if (trip != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: C.recv, side: const BorderSide(color: C.field)),
                        onPressed: () => callPhone(context, trip.officePhone),
                        child: const Text('एजेंट को कॉल'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: C.recv, side: const BorderSide(color: C.field)),
                        onPressed: () => callPhone(context, trip.ownerPhone),
                        child: const Text('मालिक को कॉल'),
                      ),
                    ),
                  ],
                ),
              ],
              if (!s.locationAllowed) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await s.ensureLocationPermission(ask: true);
                    s.startTracking();
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('लोकेशन चालू करो'),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        s.myLat == null ? 'लोड' : '${hi(nearestCity(s.myLat!, s.myLng!))} के पास लोड',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text('${s.loads.length}', style: const TextStyle(fontSize: 13, color: C.muted)),
                ],
              ),
              const SizedBox(height: 8),
              if (s.loads.isEmpty) const EmptyNote('अभी कोई लोड पोस्ट नहीं हुआ'),
              for (final l in s.loads.take(10))
                LoadCard(
                  load: l,
                  cta: 'मुझे चाहिए',
                  onCta: () {
                    final owner = trip?.ownerPhone ?? '';
                    if (owner.isNotEmpty) {
                      whatsApp(
                        context,
                        'मालिक जी, TransWell पर लोड मिला: ${l.from} → ${l.to}, ${l.material} ${l.weightTon.round()} टन, '
                        '${l.posterName}${l.posterPhone.isEmpty ? '' : ' (${l.posterPhone})'}. बात कर लें?',
                        phone: owner,
                      );
                    } else if (l.posterPhone.isNotEmpty) {
                      callPhone(context, l.posterPhone);
                    } else {
                      toast(context, 'नंबर नहीं दिया गया');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipper
// ---------------------------------------------------------------------------

class ShipperHome extends StatefulWidget {
  const ShipperHome({super.key});
  @override
  State<ShipperHome> createState() => _ShipperHomeState();
}

class _ShipperHomeState extends State<ShipperHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final r = AppScope.read(context);
    await _guard(context, () async {
      await r.refreshLinked();
      await r.refreshBoard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mine = s.linkedAs('party');
    final active = mine.where((t) => t.status.isActive).toList();
    final done = mine.where((t) => !t.status.isActive).toList();
    final byOffice = <String, (int, String)>{};
    for (final t in mine) {
      final cur = byOffice[t.officeName];
      byOffice[t.officeName] = ((cur?.$1 ?? 0) + t.balance, t.officePhone);
    }
    final myLoads = s.loads.where((l) => s.isMine(l.postedBy)).toList();
    return Scaffold(
      floatingActionButton: AmberFab(
        label: 'Load post karo',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostLoadScreen())),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _Header(s.myName, 'Mera maal kahan hai'),
              const SizedBox(height: 12),
              if (mine.isEmpty) const _NotLinkedNote('party'),
              for (final t in active)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    borderColor: C.brand,
                    borderWidth: 2,
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LinkedTripScreen(tripId: t.id))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text('LR ${t.lr} · ${t.material} · ${ton(t.weightTon)} · ${t.officeName}',
                                style: const TextStyle(fontSize: 12, color: C.muted)),
                          ),
                          t.status.isMoving && t.lastAt != null
                              ? Pill('Live · ${ago(t.lastAt!)}', fg: C.recv, bg: C.recvSoft)
                              : StatusChip(t.status),
                        ]),
                        const SizedBox(height: 4),
                        Text(t.route, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TripProgressBar(progress: routeProgress(t.from, t.to, t.lastLat, t.lastLng) ?? 0),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Abhi', style: TextStyle(fontSize: 12, color: C.muted)),
                                Text(whereNow(t), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bacha · andaazan', style: TextStyle(fontSize: 12, color: C.muted)),
                                Builder(builder: (_) {
                                  final left = kmLeft(t.to, t.lastLat, t.lastLng);
                                  return Text(left == null ? '—' : '$left km · ~${(left / 45).toStringAsFixed(1)} ghante',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
                                }),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => trackingFor(t))),
                              child: const Text('Map pe dekho'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: C.recv,
                                  side: const BorderSide(color: C.recv),
                                  minimumSize: const Size(48, 44)),
                              onPressed: () => callPhone(context, t.driverPhone),
                              child: const Text('Driver ko call'),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              if (done.isNotEmpty) const SectionTitle('Pahunch gaye'),
              for (final t in done)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LinkedTripScreen(tripId: t.id))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.route, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text('LR ${t.lr} · ${dm(t.date)} · ${t.officeName}',
                                  style: const TextStyle(fontSize: 12, color: C.muted)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: t.podPath == null ? null : () => showPodPhoto(context, t.podPath!),
                          child: Text(t.podPath == null ? 'POD nahi' : 'POD dekho'),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final e in byOffice.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Panel(
                    topBar: C.pay,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e.key.toUpperCase()} KO DENA HAI',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.pay)),
                              Text(inr(e.value.$1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Agent ko call',
                          onPressed: () => callPhone(context, e.value.$2),
                          icon: const Icon(Icons.call_outlined, color: C.recv),
                        ),
                      ],
                    ),
                  ),
                ),
              if (myLoads.isNotEmpty) ...[
                const SectionTitle('Mere post kiye loads'),
                for (final l in myLoads) LoadCard(load: l),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
