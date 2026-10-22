import 'dart:async';

import 'package:flutter/material.dart';

import 'admin.dart' show VerifiedTick;
import 'bilty.dart' show confirm;
import 'data.dart';
import 'services.dart';
import 'widgets.dart';

String _asRole(Role? r) => switch (r) { Role.owner => 'owner', Role.driver => 'driver', _ => 'shipper' };

/// Owner / driver / shipper: the transporters they work with.
class MyTransportersScreen extends StatefulWidget {
  const MyTransportersScreen({super.key});
  @override
  State<MyTransportersScreen> createState() => _MyTransportersScreenState();
}

class _MyTransportersScreenState extends State<MyTransportersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final r = AppScope.read(context);
    try {
      await r.refreshMyConnections();
      await r.refreshLinked();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    // Offices that already have trips with me, even without a request.
    final fromTrips = <String, (String, String)>{};
    for (final t in r.linked) {
      fromTrips[t.officeName] = (t.officeName, t.officePhone);
    }
    for (final c in r.linkedBilties) {
      fromTrips[c.officeName] = (c.officeName, c.officePhone);
    }
    for (final c in r.myConnections) {
      fromTrips.remove(c.officeName);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mere transporter')),
      floatingActionButton: AmberFab(
        label: 'Transporter jodo',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransporterScreen())),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Text(
              'Jis transporter ke saath kaam karte ho, use yahan jodo. Woh accept karega toh aap uski directory mein '
              'jud jaoge aur uske trips / hisaab aapko apne aap dikhenge.',
              style: TextStyle(color: C.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (r.myConnections.isEmpty && fromTrips.isEmpty)
              EmptyNote('Abhi koi transporter nahi juda',
                  action: 'Transporter dhoondho',
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransporterScreen()))),
            for (final c in r.myConnections)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                              child: Text(c.officeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                          if (c.verified) const Padding(padding: EdgeInsets.only(left: 4), child: VerifiedTick()),
                        ]),
                        Text('${c.officeCity}${c.truckNumber.isEmpty ? '' : ' · ${c.truckNumber}'}',
                            style: const TextStyle(fontSize: 13, color: C.muted)),
                        const SizedBox(height: 4),
                        switch (c.status) {
                          'accepted' => const Pill('Jude hue', fg: C.recv, bg: C.recvSoft),
                          'rejected' => const Pill('Mana kiya', fg: C.pay, bg: C.paySoft),
                          _ => const Pill('Request bheji', fg: C.amberInk, bg: C.amberSoft),
                        },
                      ]),
                    ),
                    if (c.officePhone.isNotEmpty) CallButton(name: c.officeName, phone: c.officePhone),
                    if (c.status != 'accepted')
                      IconButton(
                        tooltip: 'Request hatao',
                        onPressed: () async {
                          final ok = await confirm(context, 'Request hatani hai?', c.officeName);
                          if (ok) await r.cancelConnection(c.id);
                        },
                        icon: const Icon(Icons.close, color: C.muted),
                      ),
                  ]),
                ),
              ),
            if (fromTrips.isNotEmpty) ...[
              const SectionTitle('Trips se jude'),
              for (final e in fromTrips.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    child: Row(children: [
                      Expanded(child: Text(e.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                      if (e.$2.isNotEmpty) CallButton(name: e.$1, phone: e.$2),
                    ]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddTransporterScreen extends StatefulWidget {
  const AddTransporterScreen({super.key});
  @override
  State<AddTransporterScreen> createState() => _AddTransporterScreenState();
}

class _AddTransporterScreenState extends State<AddTransporterScreen> {
  List<OfficeHit> hits = [];
  bool searching = false;
  Timer? _debounce;
  String q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String v) {
    q = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (v.trim().length < 2) {
        setState(() => hits = []);
        return;
      }
      setState(() => searching = true);
      try {
        final res = await AppScope.read(context).searchOffices(v);
        if (mounted && q == v) setState(() => hits = res);
      } catch (e) {
        if (mounted) toast(context, friendlyError(e));
      } finally {
        if (mounted) setState(() => searching = false);
      }
    });
  }

  Future<void> _request(OfficeHit o) async {
    final r = AppScope.read(context);
    final role = _asRole(r.role);
    final name = TextEditingController(text: r.profile?.name ?? '');
    final city = TextEditingController();
    final truck = TextEditingController();
    final cap = TextEditingController();
    final msg = TextEditingController();
    var type = 'Open body';
    var sent = false;
    await showFormSheet(
      context,
      title: '${o.name} se judo',
      fields: (setSt) => [
        Text(
          switch (role) {
            'owner' => 'Aap gaadi malik ke roop mein judoge. Apni gaadi bhi likho — accept hote hi transporter ki directory mein aa jaayegi.',
            'driver' => 'Aap driver ke roop mein judoge. Jo gaadi chalate ho uska number likho.',
            _ => 'Aap party / shipper ke roop mein judoge. Aapka maal aur hisaab transporter ke paas aapke naam se chalega.',
          },
          style: const TextStyle(color: C.muted, height: 1.4),
        ),
        Field(name, role == 'shipper' ? 'Firm / aapka naam' : 'Aapka naam'),
        Field(city, 'City'),
        if (role != 'shipper') ...[
          Field(truck, 'Gaadi number', hint: 'RJ14 GB 4821'),
          if (role == 'owner') ...[
            Wrap(spacing: 8, children: [
              for (final t in ['Open body', 'Container', 'Trailer', 'Tanker'])
                ChoiceChip(label: Text(t), selected: type == t, showCheckmark: false, onSelected: (_) => setSt(() => type = t)),
            ]),
            Field(cap, 'Capacity (ton)', number: true),
          ],
        ],
        Field(msg, 'Kuch kehna hai? (optional)'),
      ],
      onSave: () async {
        if (name.text.trim().isEmpty) return 'Naam likho';
        await r.sendConnection(
          officeId: o.id,
          asRole: role,
          name: name.text.trim(),
          city: city.text.trim(),
          truckNumber: truck.text.trim(),
          truckType: role == 'owner' ? type : '',
          capacity: double.tryParse(cap.text.trim()),
          message: msg.text.trim(),
        );
        sent = true;
        return null;
      },
    );
    if (sent && mounted) {
      toast(context, 'Request bhej di — ${o.name} accept karega');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transporter dhoondho')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Naam, city ya mobile number'),
            onChanged: _search,
          ),
          const SizedBox(height: 8),
          if (searching) const LinearProgressIndicator(),
          if (!searching && q.trim().length >= 2 && hits.isEmpty)
            const EmptyNote('Koi transporter nahi mila. Unse kaho TransWell pe apna office banayein, ya unka mobile number se dhoondho.'),
          for (final o in hits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                onTap: () => _request(o),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(o.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        if (o.verified) const Padding(padding: EdgeInsets.only(left: 4), child: VerifiedTick()),
                      ]),
                      Text(
                          '${o.city}${o.city.isEmpty ? '' : ' · '}${switch (o.kind) { 'transport' => 'Goods transport', 'parcel' => 'Parcel service', _ => 'Commission agent' }}',
                          style: const TextStyle(fontSize: 13, color: C.muted)),
                    ]),
                  ),
                  const Text('Judo', style: TextStyle(fontWeight: FontWeight.w700, color: C.brand)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Transporter side: people asking to join (shown on home and directory).
class ConnRequestsSection extends StatefulWidget {
  const ConnRequestsSection({super.key});
  @override
  State<ConnRequestsSection> createState() => _ConnRequestsSectionState();
}

class _ConnRequestsSectionState extends State<ConnRequestsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => AppScope.read(context).refreshConnRequests().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    if (r.connRequests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        borderColor: C.amber,
        color: C.amberSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${r.connRequests.length} log aapse judna chahte hain',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            for (final c in r.connRequests)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text('${c.name} · ${c.roleLabel}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (c.phone.isNotEmpty) CallButton(name: c.name, phone: c.phone),
                    ]),
                    Text(
                      [
                        if (c.phone.isNotEmpty) c.phone,
                        if (c.city.isNotEmpty) c.city,
                        if (c.truckNumber.isNotEmpty)
                          '${c.truckNumber}${c.truckType.isEmpty ? '' : ' (${c.truckType}${c.capacity == null ? '' : ', ${c.capacity!.round()} ton'})'}',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 13, color: C.muted),
                    ),
                    if (c.message.isNotEmpty) Text('"${c.message}"', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
                          onPressed: () => r.decideConnection(c.id, false).catchError((Object e) => toast(context, friendlyError(e))),
                          child: const Text('Mana karo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(48, 40)),
                          onPressed: () async {
                            try {
                              await r.decideConnection(c.id, true);
                              if (context.mounted) toast(context, '${c.name} directory mein jud gaye');
                            } catch (e) {
                              if (context.mounted) toast(context, friendlyError(e));
                            }
                          },
                          child: const Text('Accept'),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
