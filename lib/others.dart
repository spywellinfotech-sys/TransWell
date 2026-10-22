import 'package:flutter/material.dart';

import 'agent.dart';
import 'data.dart';
import 'main.dart' show goToRoleScreen;
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Truck owner
// ---------------------------------------------------------------------------

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});
  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  final wantTo = TextEditingController(text: 'Delhi, Punjab');

  @override
  void dispose() {
    wantTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.owner(s.demoOwnerId);
    final myTrucks = s.trucks.where((t) => t.ownerId == me.id).toList();
    final myTrips = s.tripsNewestFirst.where((t) => s.truck(t.truckNo).ownerId == me.id).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Namaste, ${me.name.split(' ').first} ji',
                          style: const TextStyle(fontSize: 13, color: C.muted)),
                      const Text('Meri gaadiyan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                    tooltip: 'Role badlo',
                    onPressed: () => goToRoleScreen(context),
                    icon: const Icon(Icons.switch_account_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            Panel(
              topBar: C.recv,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AGENTS SE LENA HAI',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.recv)),
                  const SizedBox(height: 6),
                  KV(s.officeName, inr(s.ownerBalance(me.id)), bold: true),
                  KV('Jai Ambe Transport', inr(0)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final t in myTrucks) ...[
              _truckCard(context, s, t, myTrips),
              const SizedBox(height: 12),
            ],
            const SectionTitle('Mere trips'),
            for (final t in myTrips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BiltyScreen(lr: t.lr))),
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
                          'Hire ${num0(t.hire)} · Mila ${num0(t.ownerPaid)}${t.ownerDeduction > 0 ? ' · Shortage ${num0(t.ownerDeduction)}' : ''}',
                          style: const TextStyle(fontSize: 13, color: C.muted)),
                      Text('Baaki ${inr(t.ownerBalance)} · bilty dekhne ke liye tap karo',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Jaipur se loads'),
            for (final l in s.loads.take(2))
              LoadCard(load: l, cta: 'Interested', onCta: () => soon(context, '${l.postedBy} ko bata diya')),
          ],
        ),
      ),
    );
  }

  Widget _truckCard(BuildContext context, AppState s, Truck t, List<Trip> myTrips) {
    final active = myTrips.where((x) => x.truckNo == t.number && x.status.isActive).toList();
    if (active.isNotEmpty) {
      final trip = active.first;
      return Panel(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(lr: trip.lr, forShipper: true))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(t.number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              const Pill('On trip', fg: C.brand, bg: C.brandSoft),
            ]),
            const SizedBox(height: 4),
            Text('${trip.route} · LR ${trip.lr} · Driver ${t.driver}', style: const TextStyle(fontSize: 14)),
            Text('Abhi: ${trip.nearPlace.isEmpty ? trip.from : trip.nearPlace} · ${trip.kmLeft} km bacha',
                style: const TextStyle(fontSize: 13, color: C.recv, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    final posted = s.postedTrucks.contains(t.number);
    return Panel(
      borderColor: C.amber,
      borderWidth: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(t.number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            const Pill('Khaali', fg: C.recv, bg: C.recvSoft),
          ]),
          const SizedBox(height: 4),
          Text('${t.type} · ${t.capacityTon} ton · abhi Sitapura, Jaipur', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          if (!posted) ...[
            TextField(controller: wantTo, decoration: const InputDecoration(labelText: 'Kis taraf jaana hai')),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: C.ink),
              onPressed: () {
                final places = wantTo.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                s.postTruck(t, places);
                soon(context, 'Gaadi post ho gayi — Jaipur ke transporters ko dikhegi');
              },
              child: const Text('Gaadi khaali hai — post karo', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            const Text('Jaipur ke 50 km mein sab transporters ko dikhegi, 24 ghante tak',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ] else
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
// Driver (Hindi)
// ---------------------------------------------------------------------------

const _hindiCity = {
  'Delhi': 'दिल्ली',
  'Jaipur': 'जयपुर',
  'Ludhiana': 'लुधियाना',
  'Ahmedabad': 'अहमदाबाद',
  'Ajmer': 'अजमेर',
  'Kota': 'कोटा',
  'Indore': 'इंदौर',
  'Ghaziabad': 'गाज़ियाबाद',
  'Sonipat': 'सोनीपत',
};

String hi(String city) => _hindiCity[city] ?? city;

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  void _next(BuildContext context) => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const DriverHome()));

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
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
                    point('सिर्फ ट्रिप चालू होने पर (लोड से डिलीवरी तक) — ऐप बंद हो तब भी'),
                    point('सिर्फ इन्हें दिखेगी: एजेंट, गाड़ी मालिक, और जिसका माल है'),
                    point('डिलीवरी होते ही बंद — उसके बाद कोई नहीं देख सकता'),
                    point('फायदा: बार-बार "कहाँ पहुँचे" वाले फोन कम, और पास के लोड आपको मिलेंगे'),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 58)),
                onPressed: () {
                  s.allowLocation();
                  _next(context);
                },
                child: const Text('ठीक है, अनुमति दें', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: () => _next(context), child: const Text('अभी नहीं', style: TextStyle(fontSize: 16))),
              const Text('"अभी नहीं" दबाने पर भी ट्रिप चलेगा, बस लाइव मैप नहीं दिखेगा',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final mine = s.activeTrips.where((t) => s.truck(t.truckNo).driver == s.demoDriver).toList();
    final trip = mine.isEmpty ? null : mine.first;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('राम राम, ${s.demoDriver == 'Mohan' ? 'मोहन' : s.demoDriver} जी',
                          style: const TextStyle(fontSize: 14, color: C.muted)),
                      const Text('आज का ट्रिप', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                    tooltip: 'Role badlo',
                    onPressed: () => goToRoleScreen(context),
                    icon: const Icon(Icons.switch_account_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            if (trip == null)
              Panel(
                padding: const EdgeInsets.all(20),
                child: const Text('अभी कोई ट्रिप नहीं है। नीचे पास के लोड देखें।',
                    style: TextStyle(fontSize: 16)),
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
                    Text('${trip.material} · ${trip.weightTon.round()} टन · ${trip.truckNo}',
                        style: const TextStyle(fontSize: 15, color: Color(0xFFDDE1F0))),
                    Text('माल देना है: ${trip.consignee}',
                        style: const TextStyle(fontSize: 15, color: Color(0xFFDDE1F0))),
                    if (s.driverLocationOn)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('● लोकेशन चालू है', style: TextStyle(fontSize: 13, color: C.amber)),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: C.amber, foregroundColor: C.ink, minimumSize: const Size(48, 56)),
                      onPressed: () {
                        if (trip.status == TripStatus.booked) {
                          s.setStatus(trip, TripStatus.loaded);
                          soon(context, 'एजेंट को बता दिया: लोड हो गया');
                        } else {
                          s.setStatus(trip, TripStatus.delivered);
                          soon(context, 'एजेंट और मालिक को बता दिया: पहुँच गया');
                        }
                      },
                      child: Text(trip.status == TripStatus.booked ? 'लोड हो गया' : 'पहुँच गया',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF8F9AC8)),
                          minimumSize: const Size(48, 48)),
                      onPressed: () => soon(context, 'कैमरा से बिल्टी फोटो — अगले स्टेज में'),
                      child: const Text('बिल्टी की फोटो भेजो', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: C.recv, side: const BorderSide(color: C.field)),
                    onPressed: () => soon(context, 'कॉल: ${s.officeName} · ${s.officePhone}'),
                    child: const Text('एजेंट को कॉल'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: C.recv, side: const BorderSide(color: C.field)),
                    onPressed: () => soon(context, 'कॉल: ${s.owner(s.demoOwnerId).name}'),
                    child: const Text('मालिक को कॉल'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                    child: Text('जयपुर से लोड', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                Text('50 km में · ${s.loads.length}', style: const TextStyle(fontSize: 13, color: C.muted)),
              ],
            ),
            const SizedBox(height: 8),
            for (final l in s.loads)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${hi(l.from)} → ${hi(l.to)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${l.material} · ${l.weightTon.round()} टन · ${l.truckType} · ${l.date}',
                          style: const TextStyle(fontSize: 14, color: C.subtle)),
                      const Divider(height: 18, color: C.line),
                      Row(
                        children: [
                          Expanded(child: Text(l.postedBy, style: const TextStyle(fontSize: 14, color: C.subtle))),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: C.recv, minimumSize: const Size(110, 44)),
                            onPressed: () => soon(context, 'मालिक को खबर भेज दी — वो बात करेंगे'),
                            child: const Text('मुझे चाहिए', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shipper
// ---------------------------------------------------------------------------

class ShipperHome extends StatelessWidget {
  const ShipperHome({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final me = s.party(s.demoShipperId);
    final mine = s.tripsNewestFirst.where((t) => t.partyId == me.id).toList();
    final active = mine.where((t) => t.status.isActive).toList();
    final done = mine.where((t) => !t.status.isActive).toList();
    final bal = s.partyBalance(me.id);
    return Scaffold(
      floatingActionButton: AmberFab(
        label: 'Load post karo',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => PostLoadScreen(postedBy: me.name))),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${me.name}, ${me.city}', style: const TextStyle(fontSize: 13, color: C.muted)),
                      const Text('Mera maal kahan hai',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                    tooltip: 'Role badlo',
                    onPressed: () => goToRoleScreen(context),
                    icon: const Icon(Icons.switch_account_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            if (active.isEmpty)
              const Panel(child: Text('Abhi koi maal raste mein nahi hai')),
            for (final t in active)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  borderColor: C.brand,
                  borderWidth: 2,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('LR ${t.lr} · ${t.material} · ${ton(t.weightTon)}',
                              style: const TextStyle(fontSize: 12, color: C.muted)),
                        ),
                        t.status == TripStatus.booked
                            ? const Pill('Booked', fg: C.subtle, bg: C.grey)
                            : const Pill('Live · 4 min', fg: C.recv, bg: C.recvSoft),
                      ]),
                      const SizedBox(height: 4),
                      Text(t.route, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TripProgressBar(progress: t.progress),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Abhi', style: TextStyle(fontSize: 12, color: C.muted)),
                              Text(t.nearPlace.isEmpty ? t.from : t.nearPlace,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Bacha · andaazan', style: TextStyle(fontSize: 12, color: C.muted)),
                              Text('${t.kmLeft} km · ~${(t.kmLeft / 45).toStringAsFixed(1)} ghante',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => TrackingScreen(lr: t.lr, forShipper: true))),
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
                            onPressed: () => soon(context, 'Call: Driver ${s.truck(t.truckNo).driver}'),
                            child: const Text('Driver ko call'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            const SectionTitle('Pahunch gaye'),
            for (final t in done)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.route, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('LR ${t.lr} · ${dm(t.date)}', style: const TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => BiltyScreen(lr: t.lr))),
                        child: const Text('Bilty / POD'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Panel(
              topBar: C.pay,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => PartyLedgerScreen(partyId: me.id))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.officeName.toUpperCase()} KO DENA HAI',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.pay)),
                        Text(inr(bal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Text('Hisaab', style: TextStyle(fontWeight: FontWeight.w700, color: C.brand)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
