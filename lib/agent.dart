import 'package:flutter/material.dart';

import 'bilty.dart';
import 'cities.dart';
import 'data.dart';
import 'register.dart';
import 'main.dart' show AccountMenu;
import 'services.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Agent / staff shell with 4 bottom tabs
// ---------------------------------------------------------------------------

class AgentShell extends StatefulWidget {
  const AgentShell({super.key});
  @override
  State<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends State<AgentShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final r = AppScope.read(context);
    try {
      await r.refreshOffice();
      await r.refreshBoard();
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AgentHome(onOpenTrips: () => setState(() => index = 1), onRefresh: _refresh),
      TripsScreen(onRefresh: _refresh),
      BiltyTab(onRefresh: _refresh),
      LedgerTab(onRefresh: _refresh),
      DirectoryScreen(onRefresh: _refresh),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: index <= 2
          ? AmberFab(label: 'Entry', onPressed: () => showEntryMenu(context))
          : index == 4
              ? AmberFab(label: 'Jodo', onPressed: () => showAddMenu(context))
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Trips'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Bilty'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Ledger'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Directory'),
        ],
      ),
    );
  }
}

/// Session flag: the agent hid the getting-started checklist.
final hideChecklist = ValueNotifier<bool>(false);

void openTrip(BuildContext context, String id) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(id: id)));

void openNewTrip(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickEntryScreen()));

// ---------------------------------------------------------------------------
// Add party / owner / truck
// ---------------------------------------------------------------------------

Future<void> showAddMenu(BuildContext context) async {
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Party (maal bhejne wala)'),
              onTap: () => Navigator.pop(ctx, 0)),
          ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Truck owner'),
              onTap: () => Navigator.pop(ctx, 1)),
          ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Truck + driver'),
              onTap: () => Navigator.pop(ctx, 2)),
          const Divider(height: 1),
          ListTile(
              leading: const Icon(Icons.history_edu_outlined),
              title: const Text('Register ka purana baaki chadhao'),
              onTap: () => Navigator.pop(ctx, 3)),
          ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Excel / CSV se ek saath'),
              onTap: () => Navigator.pop(ctx, 4)),
          ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Party / driver ko app bhejo'),
              onTap: () => Navigator.pop(ctx, 5)),
        ],
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 0) await addPartySheet(context);
  if (choice == 1) await addOwnerSheet(context);
  if (choice == 2) await addTruckSheet(context);
  if (choice == 3) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningBalanceScreen(parties: true)));
  }
  if (choice == 4) await Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen()));
  if (choice == 5) await showInviteList(context);
}

Future<void> addPartySheet(BuildContext context, {Party? edit}) async {
  final r = AppScope.read(context);
  final name = TextEditingController(text: edit?.name),
      city = TextEditingController(text: edit?.city),
      phone = TextEditingController(text: edit?.phone),
      opening = TextEditingController(text: (edit?.opening ?? 0) == 0 ? '' : edit!.opening.toString());
  await showFormSheet(
    context,
    title: edit == null ? 'Nayi party' : 'Party badlo',
    fields: (_) => [
      Field(name, 'Party / firm ka naam'),
      Field(city, 'City'),
      Field(phone, 'Mobile number', phone: true, hint: 'Isi number se party app mein apna maal track karegi'),
      contactButton(context, name, phone),
      Field(opening, 'Register ka purana baaki ₹ (optional)', number: true),
      if (edit != null)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: C.pay),
          onPressed: () async {
            final err = await r.deleteParty(edit.id);
            if (context.mounted) toast(context, err ?? 'Party hata di');
          },
          child: const Text('Party hatao'),
        ),
    ],
    onSave: () async {
      if (name.text.trim().isEmpty) return 'Naam bharo';
      final o = int.tryParse(opening.text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
      if (edit == null) {
        await r.addParty(name.text.trim(), city.text.trim(), phone.text, opening: o);
      } else {
        await r.updateParty(edit.id, name: name.text.trim(), city: city.text.trim(), phone: phone.text, opening: o);
      }
      return null;
    },
  );
}

Future<void> addOwnerSheet(BuildContext context, {TruckOwner? edit}) async {
  final r = AppScope.read(context);
  final name = TextEditingController(text: edit?.name),
      phone = TextEditingController(text: edit?.phone),
      opening = TextEditingController(text: (edit?.opening ?? 0) == 0 ? '' : edit!.opening.toString());
  await showFormSheet(
    context,
    title: edit == null ? 'Naya gaadi malik' : 'Gaadi malik badlo',
    fields: (_) => [
      Field(name, 'Owner / transport ka naam'),
      Field(phone, 'Mobile number', phone: true, hint: 'Isi number se owner apna hisaab dekhega'),
      contactButton(context, name, phone),
      Field(opening, 'Register ka purana baaki ₹ (optional)', number: true),
      if (edit != null)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: C.pay),
          onPressed: () async {
            final err = await r.deleteOwner(edit.id);
            if (context.mounted) toast(context, err ?? 'Hata diya');
          },
          child: const Text('Gaadi malik hatao'),
        ),
    ],
    onSave: () async {
      if (name.text.trim().isEmpty) return 'Naam bharo';
      final o = int.tryParse(opening.text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
      if (edit == null) {
        await r.addOwner(name.text.trim(), phone.text, opening: o);
      } else {
        await r.updateOwner(edit.id, name: name.text.trim(), phone: phone.text, opening: o);
      }
      return null;
    },
  );
}

Future<void> addTruckSheet(BuildContext context, {Truck? edit}) async {
  final r = AppScope.read(context);
  final number = TextEditingController(text: edit?.number),
      cap = TextEditingController(text: edit?.capacityTon?.toString()),
      driver = TextEditingController(text: edit?.driver),
      dphone = TextEditingController(text: edit?.driverPhone),
      routes = TextEditingController(text: edit?.routes.join(', '));
  var type = edit?.type.isNotEmpty == true ? edit!.type : 'Open body';
  String? ownerId = edit != null ? edit.ownerId : (r.owners.isEmpty ? null : r.owners.first.id);
  await showFormSheet(
    context,
    title: edit == null ? 'Naya truck' : 'Truck badlo',
    fields: (setSt) => [
      Field(number, 'Truck number', hint: 'RJ14 GB 4821'),
      Wrap(spacing: 8, children: [
        for (final t in ['Open body', 'Container', 'Trailer', 'Tanker'])
          ChoiceChip(
              label: Text(t), selected: type == t, showCheckmark: false, onSelected: (_) => setSt(() => type = t)),
      ]),
      Field(cap, 'Capacity (ton)', number: true),
      DropdownButtonFormField<String?>(
        value: ownerId,
        decoration: const InputDecoration(labelText: 'Truck owner'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('— baad mein —')),
          for (final o in r.owners) DropdownMenuItem<String?>(value: o.id, child: Text(o.name)),
        ],
        onChanged: (v) => setSt(() => ownerId = v),
      ),
      Field(driver, 'Driver ka naam'),
      Field(dphone, 'Driver ka mobile', phone: true, hint: 'Isi number se driver app mein trip dekhega'),
      contactButton(context, driver, dphone),
      Field(routes, 'Routes (comma se)', hint: 'Delhi–Jaipur, Delhi–Ajmer'),
      if (edit != null)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: C.pay),
          onPressed: () async {
            final err = await r.deleteTruck(edit.id);
            if (context.mounted) toast(context, err ?? 'Truck hata diya');
          },
          child: const Text('Truck hatao'),
        ),
    ],
    onSave: () async {
      if (number.text.trim().isEmpty) return 'Truck number bharo';
      if (edit != null) {
        await r.updateTruck(edit.id,
            number: number.text.trim(),
            type: type,
            capacity: double.tryParse(cap.text.trim()),
            ownerId: ownerId,
            driver: driver.text.trim(),
            driverPhone: dphone.text,
            routes: routes.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
        return null;
      }
      await r.addTruck(
        number: number.text.trim(),
        type: type,
        capacity: double.tryParse(cap.text.trim()),
        ownerId: ownerId,
        driver: driver.text.trim(),
        driverPhone: dphone.text,
        routes: routes.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      );
      return null;
    },
  );
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class AgentHome extends StatelessWidget {
  final VoidCallback onOpenTrips;
  final Future<void> Function() onRefresh;
  const AgentHome({super.key, required this.onOpenTrips, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final payments = s.recentPayments.take(3).toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Namaste, ${s.myName} ji', style: const TextStyle(fontSize: 13, color: C.muted)),
                    Text(s.office?.name ?? 'Mera office',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    if (s.office != null)
                      Text(s.office!.kindLabel, style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              const AccountMenu(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bahar ka paisa', style: TextStyle(fontSize: 13, color: C.brandMuted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyBox(
                          title: 'LENA HAI',
                          color: C.recv,
                          amount: s.totalReceivable,
                          sub: '${s.receivableParties} parties se'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MoneyBox(
                          title: 'DENA HAI',
                          color: C.pay,
                          amount: s.totalPayable,
                          sub: '${s.payableOwners} truck owners ko'),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFF3A4784)),
                Row(
                  children: [
                    const Expanded(
                        child: Text('Is mahine commission', style: TextStyle(fontSize: 14, color: C.brandMuted))),
                    Text(inr(s.monthCommission),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('  · ${s.monthTrips.length} trips', style: const TextStyle(fontSize: 13, color: C.brandMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: hideChecklist,
            builder: (context, hidden, _) => hidden || s.trips.length + s.bilties.length >= 5
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StartChecklist(onHide: () => hideChecklist.value = true),
                  ),
          ),
          if (s.bilties.isNotEmpty || !(s.office?.isAgent ?? true)) ...[
            Row(children: [
              Expanded(
                child: Panel(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Godown')), body: BiltyTab(onRefresh: s.refreshOffice)))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('GODOWN MEIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.brand)),
                    Text('${s.godown.length} bilty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('${s.godown.fold(0.0, (a, c) => a + c.tons).toStringAsFixed(1)} ton',
                        style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('TO-PAY VASOOLI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.pay)),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(inr(s.toPayTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                    Text('${s.toPayPending.length} bilty', style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
              avatar: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Register'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
            ),
            ActionChip(
              avatar: const Icon(Icons.history_edu_outlined, size: 18),
              label: const Text('Purana baaki'),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningBalanceScreen(parties: true))),
            ),
            ActionChip(
              avatar: const Icon(Icons.send_outlined, size: 18),
              label: const Text('App bhejo'),
              onPressed: () => showInviteList(context),
            ),
          ]),
          const SizedBox(height: 12),
          Panel(
            color: C.amberSoft,
            borderColor: C.amber,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoadBoardScreen())),
            child: Row(
              children: [
                Expanded(
                  child: Text('Load board: ${s.truckPosts.length} khaali gaadiyan, ${s.loads.length} loads',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const Text('Dekho', style: TextStyle(fontWeight: FontWeight.w700, color: C.brand)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionTitle('Chalte trips', action: 'Sab dekho', onAction: onOpenTrips),
          if (s.trips.isEmpty)
            EmptyNote(
              'Abhi koi trip nahi hai. Neeche "+ Entry" dabao aur register jaisi line bharo — party aur gaadi apne aap ban jaayenge.',
              action: 'Pehli entry karo',
              onAction: () => showEntryMenu(context),
            )
          else if (s.activeTrips.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Abhi koi trip chal nahi raha', style: TextStyle(color: C.muted)),
            ),
          for (final t in s.activeTrips) TripTile(trip: t, onTap: () => openTrip(context, t.id)),
          if (payments.isNotEmpty) ...[
            const SectionTitle('Recent payments'),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < payments.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: i == payments.length - 1
                            ? null
                            : const Border(bottom: BorderSide(color: Color(0xFFEFECE6))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(payments[i].who, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                Text('${dm(payments[i].payment.date)} · ${payments[i].payment.mode} · LR ${payments[i].lr}',
                                    style: const TextStyle(fontSize: 12, color: C.muted)),
                              ],
                            ),
                          ),
                          Text(
                            '${payments[i].incoming ? '+' : '−'} ${inr(payments[i].payment.amount)}',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: payments[i].incoming ? C.recv : C.pay),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyBox extends StatelessWidget {
  final String title;
  final Color color;
  final int amount;
  final String sub;
  const _MoneyBox({required this.title, required this.color, required this.amount, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(inr(amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trips list
// ---------------------------------------------------------------------------

class TripsScreen extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const TripsScreen({super.key, required this.onRefresh});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String query = '';
  int filter = 0;
  static const filters = ['Sab', 'Payment baaki', 'In transit', 'POD baaki'];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final q = query.toLowerCase();
    final list = s.trips.where((t) {
      final hay = '${t.lr} ${t.route} ${s.partyName(t.partyId)} ${s.truckNo(t.truckId)} ${t.bilties.map((c) => s.partyName(c.partyId)).join(' ')}'.toLowerCase();
      if (q.isNotEmpty && !hay.contains(q)) return false;
      return switch (filter) {
        1 => t.partyBalance > 0 || t.ownerBalance > 0,
        2 => t.status == TripStatus.inTransit,
        3 => t.status == TripStatus.delivered,
        _ => true,
      };
    }).toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Trips', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: Text('Register · ${s.monthTrips.length}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'LR no., party, truck no. ya city'),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(filters[i]),
                selected: filter == i,
                onSelected: (_) => setState(() => filter = i),
                selectedColor: C.brand,
                labelStyle: TextStyle(color: filter == i ? Colors.white : C.ink, fontWeight: FontWeight.w600),
                showCheckmark: false,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Koi trip nahi mila', style: TextStyle(color: C.muted))),
            ),
          for (final t in list) TripTile(trip: t, showBalances: true, onTap: () => openTrip(context, t.id)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New trip form
// ---------------------------------------------------------------------------

class NewTripScreen extends StatefulWidget {
  const NewTripScreen({super.key});
  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  final _form = GlobalKey<FormState>();
  String? partyId;
  String? truckId;
  bool saving = false;
  final consignee = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  final material = TextEditingController();
  final weight = TextEditingController();
  final freight = TextEditingController();
  final hire = TextEditingController();
  final advIn = TextEditingController();
  final advOut = TextEditingController();

  int _n(TextEditingController c) => int.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [consignee, from, to, material, weight, freight, hire, advIn, advOut]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {bool number = false, bool required = true, Color? color}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      textCapitalization: number ? TextCapitalization.none : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color ?? C.muted, fontWeight: color != null ? FontWeight.w600 : null),
      ),
      onChanged: (_) => setState(() {}),
      validator: (v) => required && (v == null || v.trim().isEmpty) ? 'Bharna zaroori hai' : null,
    );
  }

  Widget _row(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_n(freight) <= 0 || _n(hire) <= 0) {
      toast(context, 'Freight aur lorry hire dono bharo');
      return;
    }
    setState(() => saving = true);
    final r = AppScope.read(context);
    try {
      final t = await r.addTrip(
        partyId: partyId!,
        consignee: consignee.text.trim(),
        truckId: truckId!,
        from: from.text.trim(),
        to: to.text.trim(),
        material: material.text.trim(),
        weightTon: double.tryParse(weight.text.trim()) ?? 0,
        freight: _n(freight),
        hire: _n(hire),
        partyAdvance: _n(advIn),
        ownerAdvance: _n(advOut),
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TripDetailScreen(id: t.id)));
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final commission = _n(freight) - _n(hire);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naya trip'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: Text('LR ${s.office?.nextLr ?? ''} · ${dm(DateTime.now())}',
                    style: const TextStyle(fontSize: 13, color: C.muted))),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: partyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Party (consignor)'),
              items: [
                for (final p in s.parties)
                  DropdownMenuItem(value: p.id, child: Text('${p.name}${p.city.isEmpty ? '' : ', ${p.city}'}')),
              ],
              onChanged: (v) => setState(() => partyId = v),
              validator: (v) => v == null ? 'Party chuno' : null,
            ),
            const SizedBox(height: 12),
            _field(consignee, 'Consignee (maal kisko jayega)'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: truckId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Truck no.'),
              items: [
                for (final t in s.trucks)
                  DropdownMenuItem(
                      value: t.id, child: Text('${t.number}${t.driver.isEmpty ? '' : ' · ${t.driver}'}')),
              ],
              onChanged: (v) => setState(() => truckId = v),
              validator: (v) => v == null ? 'Truck chuno' : null,
            ),
            const SizedBox(height: 12),
            _row(_field(from, 'Kahan se'), _field(to, 'Kahan tak')),
            const SizedBox(height: 12),
            _row(_field(material, 'Maal'), _field(weight, 'Weight (ton)', number: true)),
            const SizedBox(height: 12),
            _row(_field(freight, 'Party freight (₹)', number: true, color: C.recv),
                _field(hire, 'Lorry hire (₹)', number: true, color: C.pay)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: C.brandSoft, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Commission (apne aap)', style: TextStyle(color: C.brand, fontWeight: FontWeight.w500))),
                  Text(inr(commission),
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: commission < 0 ? C.pay : C.brand)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row(_field(advIn, 'Party se advance mila', number: true, required: false),
                _field(advOut, 'Owner ko advance diya', number: true, required: false)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Trip save karo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip detail
// ---------------------------------------------------------------------------

BiltyData biltyFor(Repo s, Trip t) {
  final p = s.party(t.partyId);
  final tr = s.truck(t.truckId);
  final adv = t.partyPayments.where((p) => p.note == 'Advance').fold(0, (a, p) => a + p.amount);
  return BiltyData(
    officeName: s.office?.name ?? '',
    officePhone: s.office?.phone ?? '',
    officeCity: s.office?.city ?? '',
    gst: s.office?.gst ?? '',
    lr: t.lr,
    date: t.date,
    consignor: p?.name ?? '',
    consignorCity: p?.city ?? '',
    consignee: t.consignee,
    from: t.from,
    to: t.to,
    truckNo: tr?.number ?? '',
    driver: tr == null ? '' : '${tr.driver} ${tr.driverPhone}'.trim(),
    material: t.material,
    weight: t.weightTon,
    freight: t.freight,
    advance: adv,
  );
}

class TripDetailScreen extends StatelessWidget {
  final String id;
  const TripDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.trip(id);
    if (t == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Trip nahi mila')));
    }
    final tr = s.truck(t.truckId);
    final owner = s.owner(tr?.ownerId);
    final party = s.party(t.partyId);
    final near = (t.lastLat != null) ? nearLabel(t.lastLat!, t.lastLng!) : null;
    final left = kmLeft(t.to, t.lastLat, t.lastLng);
    return Scaffold(
      appBar: AppBar(
        title: Text('${t.isPart ? 'Part load · ' : ''}LR ${t.lr}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => s.refreshOffice(),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<int>(
            onSelected: (v) async {
              if (v == 1) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuickEntryScreen(edit: t)));
              } else if (v == 2) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => QuickEntryScreen(copyFrom: t)));
              } else if (v == 3) {
                if (t.bilties.isNotEmpty) {
                  toast(context, 'Pehle bilty gaadi se utaaro');
                  return;
                }
                final ok = await confirm(context, 'LR ${t.lr} hatana hai?', 'Iske saare payment bhi hat jaayenge.');
                if (!ok || !context.mounted) return;
                try {
                  await s.deleteTrip(t);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) toast(context, friendlyError(e));
                }
              } else if (v == 4) {
                final ok = await confirm(context, 'Kata hatana hai?', 'Party aur owner dono ka kata 0 ho jaayega.');
                if (ok) await s.clearDeductions(t);
              }
            },
            itemBuilder: (_) => [
              if (!t.isPart) const PopupMenuItem(value: 1, child: Text('Entry badlo')),
              if (!t.isPart) const PopupMenuItem(value: 2, child: Text('Isi jaisa naya trip')),
              if (t.partyDeduction > 0 || t.ownerDeduction > 0) const PopupMenuItem(value: 4, child: Text('Kata hatao')),
              const PopupMenuItem(value: 3, child: Text('Trip hatao')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.refreshOffice,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatusStepper(status: t.status),
                  if (t.status != TripStatus.settled) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: s.busy
                          ? null
                          : () => s
                              .run(() => s.setTripStatus(t, TripStatus.values[t.status.index + 1]))
                              .catchError((Object e) => toast(context, friendlyError(e))),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 42)),
                      child: Text(TripStatus.values[t.status.index + 1].action),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.route, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(t.isPart ? '${dm(t.date)} · Part load' : '${dm(t.date)} · ${t.material} · ${ton(t.weightTon)}',
                      style: const TextStyle(fontSize: 13, color: C.muted)),
                  if (!t.isPart)
                    Text('${party?.name ?? ''} → ${t.consignee}', style: const TextStyle(fontSize: 13, color: C.muted)),
                  if (t.status.isMoving)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: C.recv),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TrackingScreen(
                                    title: tr?.number ?? '',
                                    subtitle: 'LR ${t.lr} · ${t.route}',
                                    from: t.from,
                                    to: t.to,
                                    lat: t.lastLat,
                                    lng: t.lastLng,
                                    at: t.lastAt,
                                    driver: tr?.driver ?? '',
                                    driverPhone: tr?.driverPhone ?? '',
                                    sharePhone: party?.phone,
                                  ))),
                      icon: const Icon(Icons.my_location, size: 18),
                      label: Text(near == null
                          ? 'Live map · abhi location nahi aayi'
                          : 'Live: $near${left == null ? '' : ' · $left km bacha'} · ${ago(t.lastAt!)}'),
                    ),
                  const Divider(height: 18, color: C.line),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr?.number ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('Driver ${tr?.driver ?? '-'} · Owner ${owner?.name ?? '-'}',
                                style: const TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      if (tr != null) CallButton(name: 'Driver ${tr.driver}', phone: tr.driverPhone),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (t.isPart) ...[
              PartLoadSection(t: t),
              const SizedBox(height: 12),
              Panel(
                topBar: C.pay,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GAADI KA HISAAB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.pay)),
                    KV('Gaadi bhada', num0(t.hire)),
                    KV('Diya', '− ${num0(t.ownerPaid)}'),
                    if (t.ownerDeduction > 0) KV('Kata', '− ${num0(t.ownerDeduction)}'),
                    const Divider(height: 10, color: C.line),
                    KV('Dena hai', inr(t.ownerBalance), bold: true, vColor: C.pay),
                  ],
                ),
              ),
            ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Panel(
                    topBar: C.recv,
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PartyLedgerScreen(partyId: t.partyId))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PARTY SIDE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.recv)),
                        KV('Freight', num0(t.freight)),
                        KV('Mila', '− ${num0(t.partyReceived)}'),
                        if (t.partyDeduction > 0) KV('Kata', '− ${num0(t.partyDeduction)}'),
                        const Divider(height: 10, color: C.line),
                        KV('Lena hai', inr(t.partyBalance), bold: true, vColor: C.recv),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Panel(
                    topBar: C.pay,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OWNER SIDE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.pay)),
                        KV('Lorry hire', num0(t.hire)),
                        KV('Diya', '− ${num0(t.ownerPaid)}'),
                        if (t.ownerDeduction > 0) KV('Kata', '− ${num0(t.ownerDeduction)}'),
                        const Divider(height: 10, color: C.line),
                        KV('Dena hai', inr(t.ownerBalance), bold: true, vColor: C.pay),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: C.brandSoft, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Expanded(child: Text('Commission', style: TextStyle(color: C.brand, fontWeight: FontWeight.w500))),
                  Text(inr(t.commission), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.brand)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: t.podPath == null ? null : () => showPodPhoto(context, t.podPath!),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(t.podPath == null ? 'POD abhi nahi aaya' : 'POD photo dekho'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final bytes = await takePodPhoto(context);
                      if (bytes == null || !context.mounted) return;
                      try {
                        await s.uploadPod(t.id, bytes, asOffice: true);
                        if (context.mounted) toast(context, 'POD photo save ho gayi');
                      } catch (e) {
                        if (context.mounted) toast(context, friendlyError(e));
                      }
                    },
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('POD jodo'),
                  ),
                ),
              ],
            ),
            if (t.payments.isNotEmpty) ...[
              const SectionTitle('Payments (galat ho toh daba ke rakho = hatao)'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final pay in t.payments)
                    ListTile(
                      dense: true,
                      title: Text('${pay.side == 'party' ? 'Party se mila' : 'Gaadi ko diya'} · ${pay.mode}'
                          '${pay.note.isEmpty ? '' : ' · ${pay.note}'}'),
                      subtitle: Text(dm(pay.date)),
                      trailing: Text(inr(pay.amount),
                          style: TextStyle(fontWeight: FontWeight.w700, color: pay.side == 'party' ? C.recv : C.pay)),
                      onLongPress: () async {
                        final ok = await confirm(context, '${inr(pay.amount)} ki entry hatani hai?', 'Hisaab se hat jaayegi.');
                        if (ok) await s.deletePayment(pay);
                      },
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => showPaymentSheet(context, t), child: const Text('+ Payment')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: t.isPart
                    ? FilledButton.icon(
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => BiltyFormScreen(tripId: t.id))),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nayi bilty'),
                      )
                    : FilledButton.icon(
                  onPressed: () => sharePdf(context, () => biltyPdf(biltyFor(s, t)), 'Bilty-LR-${t.lr}.pdf'),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Bilty PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusStepper extends StatelessWidget {
  final TripStatus status;
  const StatusStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = TripStatus.values;
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Container(
                            height: 2, color: i == 0 ? Colors.transparent : (i <= status.index ? C.brand : C.line))),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < status.index ? C.brand : (i == status.index ? C.amber : Colors.white),
                        border: Border.all(
                            color: i <= status.index ? C.brand : const Color(0xFFC9C5BB),
                            width: i == status.index ? 3 : 2),
                      ),
                    ),
                    Expanded(
                        child: Container(
                            height: 2,
                            color: i == steps.length - 1 ? Colors.transparent : (i < status.index ? C.brand : C.line))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(steps[i].short,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: i == status.index ? FontWeight.w700 : FontWeight.w400,
                        color: i == status.index ? C.ink : C.muted)),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> showPaymentSheet(BuildContext context, Trip t) async {
  final s = AppScope.read(context);
  var kind = t.isPart ? 1 : 0; // 0 party paid, 1 owner paid, 2 shortage
  var mode = 'UPI';
  var both = true;
  final amount = TextEditingController();
  await showFormSheet(
    context,
    title: 'LR ${t.lr} · Payment / kata',
    fields: (setSt) => [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          if (!t.isPart) const ButtonSegment(value: 0, label: Text('Party se mila')),
          const ButtonSegment(value: 1, label: Text('Gaadi ko diya')),
          const ButtonSegment(value: 2, label: Text('Kata')),
        ],
        selected: {kind},
        onSelectionChanged: (v) => setSt(() => kind = v.first),
      ),
      Text(
        switch (kind) {
          0 => 'Party ka baaki: ${inr(t.partyBalance)}',
          1 => 'Owner ka baaki: ${inr(t.ownerBalance)}',
          _ => 'Shortage / damage / TDS jo party ne kaata',
        },
        style: const TextStyle(color: C.muted),
      ),
      TextField(
        controller: amount,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Amount (₹)'),
      ),
      if (kind < 2)
        Wrap(
          spacing: 8,
          children: [
            for (final m in ['Cash', 'UPI', 'Bank', 'Cheque'])
              ChoiceChip(label: Text(m), selected: mode == m, onSelected: (_) => setSt(() => mode = m)),
          ],
        )
      else
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: both,
          onChanged: (v) => setSt(() => both = v ?? true),
          title: const Text('Owner ke hisaab se bhi kaato'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
    ],
    onSave: () async {
      final a = int.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
      if (a <= 0) return 'Amount daalo';
      if (kind == 2) {
        if (t.isPart) {
          await s.db.from('trips').update({'owner_deduction': t.ownerDeduction + a}).eq('id', t.id);
          await s.refreshOffice();
        } else {
          await s.addDeduction(t, amount: a, bothSides: both);
        }
      } else {
        await s.addPayment(t, party: kind == 0, amount: a, mode: mode);
      }
      return null;
    },
  );
}

// ---------------------------------------------------------------------------
// Ledger tab + party ledger
// ---------------------------------------------------------------------------

class LedgerTab extends StatelessWidget {
  final Future<void> Function()? onRefresh;
  const LedgerTab({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh ?? s.refreshOffice,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text('Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
              avatar: const Icon(Icons.history_edu_outlined, size: 18),
              label: const Text('Parties ka purana baaki'),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningBalanceScreen(parties: true))),
            ),
            ActionChip(
              avatar: const Icon(Icons.history_edu_outlined, size: 18),
              label: const Text('Gaadi malik ka purana baaki'),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningBalanceScreen(parties: false))),
            ),
          ]),
          const SectionTitle('Parties (lena hai)'),
          if (s.parties.isEmpty) const EmptyNote('Abhi koi party nahi. Directory se jodo.'),
          for (final p in s.parties)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PartyLedgerScreen(partyId: p.id))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(p.city, style: const TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                    ),
                    Text(inr(s.partyBalance(p.id)),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.recv)),
                    const Icon(Icons.chevron_right, color: C.muted),
                  ],
                ),
              ),
            ),
          const SectionTitle('Truck owners (dena hai)'),
          if (s.owners.isEmpty) const EmptyNote('Abhi koi truck owner nahi. Directory se jodo.'),
          for (final o in s.owners)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                child: Row(
                  children: [
                    Expanded(
                        child: Text(o.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                    Text(inr(s.ownerBalance(o.id)),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.pay)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PartyLedgerScreen extends StatelessWidget {
  final String partyId;
  const PartyLedgerScreen({super.key, required this.partyId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.party(partyId);
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Party nahi mili')));
    final entries = s.partyLedger(partyId);
    final ts = s.trips.where((t) => t.partyId == partyId).toList();
    final freight = ts.fold(0, (a, t) => a + t.freight);
    final got = ts.fold(0, (a, t) => a + t.partyReceived);
    final ded = ts.fold(0, (a, t) => a + t.partyDeduction);
    final bal = s.partyBalance(partyId);
    final open = ts.where((t) => t.partyBalance > 0).toList();
    Widget mini(String k, String v) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: const TextStyle(fontSize: 12, color: C.muted)),
              Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name),
            Text('Party · ${p.city} · ${p.phone}', style: const TextStyle(fontSize: 12, color: C.muted)),
          ],
        ),
        actions: [CallButton(name: p.name, phone: p.phone), const SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(bal >= 0 ? 'Balance (lena hai)' : 'Advance (party ka)',
                            style: const TextStyle(color: C.muted))),
                    Text(inr(bal), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.recv)),
                  ],
                ),
                const Divider(height: 20, color: C.line),
                Row(children: [
                  mini('Freight (${ts.length} trips)', num0(freight)),
                  mini('Mila', num0(got)),
                  mini('Kata', num0(ded)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: open.isEmpty
                      ? () => toast(context, 'Is party ka koi baaki nahi')
                      : () => showPaymentSheet(context, open.last),
                  child: const Text('+ Payment mila'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => sharePdf(
                    context,
                    () => ledgerPdf(
                      officeName: s.office?.name ?? '',
                      officePhone: s.office?.phone ?? '',
                      partyName: p.name,
                      partyCity: p.city,
                      entries: entries,
                      balance: bal,
                    ),
                    'Statement-${p.name.replaceAll(' ', '-')}.pdf',
                  ),
                  child: const Text('Statement PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: C.recv, side: const BorderSide(color: C.recv)),
            onPressed: () => whatsApp(
              context,
              'Namaste ${p.name} ji,\n${s.office?.name ?? ''} ka aapke khate mein baaki: ${inr(bal)}.\n'
              '(${ts.length} trips, freight ${inr(freight)}, mila ${inr(got)}${ded > 0 ? ', kata ${inr(ded)}' : ''})\nDhanyawad.',
              phone: p.phone,
            ),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('WhatsApp pe yaad dilao'),
          ),
          const SectionTitle('Hisaab · naya upar'),
          if (entries.isEmpty) const EmptyNote('Abhi koi entry nahi'),
          if (entries.isNotEmpty)
            Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    InkWell(
                      onTap: entries[i].tripId.isEmpty ? null : () => openTrip(context, entries[i].tripId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          border: i == entries.length - 1
                              ? null
                              : const Border(bottom: BorderSide(color: Color(0xFFEFECE6))),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 46,
                                child: Text(dm(entries[i].date), style: const TextStyle(fontSize: 12, color: C.muted))),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entries[i].title,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: entries[i].amount > 0 ? FontWeight.w600 : FontWeight.w400)),
                                  Text(entries[i].sub, style: const TextStyle(fontSize: 12, color: C.muted)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  entries[i].amount > 0
                                      ? '+ ${num0(entries[i].amount)}'
                                      : '− ${num0(-entries[i].amount)}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: entries[i].amount > 0 ? C.recv : C.pay),
                                ),
                                Text('bal ${num0(entries[i].balance)}',
                                    style: const TextStyle(fontSize: 12, color: C.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Directory
// ---------------------------------------------------------------------------

class DirectoryScreen extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const DirectoryScreen({super.key, required this.onRefresh});
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  int tab = 2;
  String q = '';

  bool _match(String s) => q.isEmpty || s.toLowerCase().contains(q.toLowerCase());

  Widget _row(String title, String sub, Widget trailing, {VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rows = <Widget>[];
    if (tab == 0) {
      for (final p in s.parties.where((p) => _match('${p.name} ${p.city}'))) {
        rows.add(_row(p.name, '${p.city} · ${p.phone}${p.opening != 0 ? ' · purana ${inr(p.opening)}' : ''}',
            CallButton(name: p.name, phone: p.phone), onTap: () => addPartySheet(context, edit: p)));
      }
      if (s.parties.isEmpty) rows.add(EmptyNote('Koi party nahi', action: 'Party jodo', onAction: () => addPartySheet(context)));
    } else if (tab == 1) {
      for (final o in s.owners.where((o) => _match(o.name))) {
        final n = s.trucks.where((t) => t.ownerId == o.id).length;
        rows.add(_row(o.name, '$n gaadi · ${o.phone}${o.opening != 0 ? ' · purana ${inr(o.opening)}' : ''}',
            CallButton(name: o.name, phone: o.phone), onTap: () => addOwnerSheet(context, edit: o)));
      }
      if (s.owners.isEmpty) rows.add(EmptyNote('Koi truck owner nahi', action: 'Owner jodo', onAction: () => addOwnerSheet(context)));
    } else if (tab == 2) {
      for (final t in s.trucks.where((t) => _match('${t.number} ${t.routes.join(' ')} ${t.type}'))) {
        final onTrip = s.activeTrips.any((x) => x.truckId == t.id);
        final o = s.owner(t.ownerId);
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            onTap: () => addTruckSheet(context, edit: t),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(t.number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        onTrip
                            ? const Pill('On trip', fg: C.subtle, bg: C.grey)
                            : const Pill('Khaali', fg: C.recv, bg: C.recvSoft),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${t.type}${t.capacityTon == null ? '' : ' · ${t.capacityTon!.round()} ton'} · ${o?.name ?? 'Owner nahi'}',
                          style: const TextStyle(fontSize: 13, color: C.muted)),
                      if (t.routes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [for (final r in t.routes) Tag(r)]),
                      ],
                    ],
                  ),
                ),
                if (o != null) CallButton(name: o.name, phone: o.phone),
              ],
            ),
          ),
        ));
      }
      if (s.trucks.isEmpty) rows.add(EmptyNote('Koi truck nahi', action: 'Truck jodo', onAction: () => addTruckSheet(context)));
    } else {
      for (final t in s.trucks.where((t) => t.driver.isNotEmpty && _match('${t.driver} ${t.number}'))) {
        rows.add(_row(t.driver, '${t.number} · ${t.driverPhone}', CallButton(name: t.driver, phone: t.driverPhone)));
      }
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(children: [
            const Expanded(child: Text('Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () => showInviteList(context),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('App bhejo'),
            ),
          ]),
          const Text('Kisi naam pe tap karo toh badal / hata sakte ho', style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Parties')),
              ButtonSegment(value: 1, label: Text('Owners')),
              ButtonSegment(value: 2, label: Text('Trucks')),
              ButtonSegment(value: 3, label: Text('Drivers')),
            ],
            selected: {tab},
            onSelectionChanged: (v) => setState(() => tab = v.first),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Naam, truck no. ya route'),
            onChanged: (v) => setState(() => q = v),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Load board + post load (shared by all roles)
// ---------------------------------------------------------------------------

class LoadBoardScreen extends StatefulWidget {
  final int initialTab;
  const LoadBoardScreen({super.key, this.initialTab = 0});
  @override
  State<LoadBoardScreen> createState() => _LoadBoardScreenState();
}

class _LoadBoardScreenState extends State<LoadBoardScreen> {
  late int tab = widget.initialTab;
  String type = 'Sab type';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final r = AppScope.read(context);
      await r.refreshMyPosition(ask: true);
      try {
        await r.refreshBoard();
      } catch (e) {
        if (mounted) toast(context, friendlyError(e));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final posts = s.truckPosts.where((p) => type == 'Sab type' || p.type == type).toList();
    final here = s.myLat == null ? 'Location band' : nearestCity(s.myLat!, s.myLng!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Load board'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: const Icon(Icons.my_location, size: 16),
              label: Text(here),
              onPressed: () async {
                await s.refreshMyPosition(ask: true);
                await s.refreshBoard();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: AmberFab(
        label: 'Load post karo',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostLoadScreen())),
      ),
      body: RefreshIndicator(
        onRefresh: s.refreshBoard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text('Khaali gaadiyan (${s.truckPosts.length})')),
                ButtonSegment(value: 1, label: Text('Loads (${s.loads.length})')),
              ],
              selected: {tab},
              onSelectionChanged: (v) => setState(() => tab = v.first),
            ),
            const SizedBox(height: 6),
            Text(
              s.myLat == null ? 'Location chalu karo toh paas wale upar dikhenge' : 'Paas wale upar dikh rahe hain',
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
            const SizedBox(height: 8),
            if (tab == 0) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final t in ['Sab type', 'Open body', 'Container', 'Trailer'])
                    ChoiceChip(
                        label: Text(t),
                        selected: type == t,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => type = t)),
                ],
              ),
              const SizedBox(height: 12),
              if (posts.isEmpty) const EmptyNote('Abhi koi khaali gaadi post nahi hui'),
              for (final p in posts) TruckPostCard(post: p),
            ] else ...[
              if (s.loads.isEmpty) const EmptyNote('Abhi koi load post nahi hua'),
              for (final l in s.loads) LoadCard(load: l),
            ],
          ],
        ),
      ),
    );
  }
}

class TruckPostCard extends StatelessWidget {
  final TruckPost post;
  const TruckPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = post;
    final km = s.kmFromMe(p.lat, p.lng);
    final mine = s.isMine(p.postedBy);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(p.truckNo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Text(ago(p.createdAt), style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
            const SizedBox(height: 4),
            Text(
                '${p.type}${p.capacityTon == null ? '' : ' · ${p.capacityTon!.round()} ton'} · ${p.area}${km == null ? '' : ' · $km km'}',
                style: const TextStyle(fontSize: 14)),
            if (p.spaceTon != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Pill('Part load: ${p.spaceTon!.toStringAsFixed(p.spaceTon! % 1 == 0 ? 0 : 1)} ton jagah khaali',
                    fg: C.amberInk, bg: C.amberSoft),
              ),
            if (p.wantTo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Jaana hai:', style: TextStyle(fontSize: 12, color: C.muted)),
                  for (final w in p.wantTo) Tag(w),
                ],
              ),
            ],
            const Divider(height: 18, color: C.line),
            Row(children: [
              Expanded(child: Text(p.posterName, style: const TextStyle(fontSize: 13, color: C.muted))),
              if (mine)
                TextButton(
                    onPressed: () => s.closeTruckPost(p).catchError((Object e) => toast(context, friendlyError(e))),
                    child: const Text('Booked — hatao'))
              else if (p.posterPhone.isNotEmpty)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.recv, minimumSize: const Size(110, 40)),
                  onPressed: () => callPhone(context, p.posterPhone),
                  child: const Text('Call karo'),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class LoadCard extends StatelessWidget {
  final LoadPost load;
  final String cta;
  final VoidCallback? onCta;
  const LoadCard({super.key, required this.load, this.cta = 'Interested', this.onCta});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = load;
    final km = s.kmFromMe(l.lat, l.lng);
    final mine = s.isMine(l.postedBy);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text('${l.from} → ${l.to}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              if (l.isPart) const Padding(padding: EdgeInsets.only(right: 6), child: Pill('Part', fg: C.amberInk, bg: C.amberSoft)),
              Text(ago(l.createdAt), style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
            const SizedBox(height: 4),
            Text(
                '${l.material} · ${ton(l.weightTon)} · ${l.truckType}${l.date.isEmpty ? '' : ' · ${l.date}'}${km == null ? '' : ' · $km km door'}',
                style: const TextStyle(fontSize: 14, color: C.subtle)),
            if (l.rate != null) Text('Rate ${inr(l.rate!)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Divider(height: 18, color: C.line),
            Row(children: [
              Expanded(child: Text(l.posterName, style: const TextStyle(fontSize: 13, color: C.muted))),
              if (mine)
                TextButton(
                    onPressed: () => s.closeLoad(l).catchError((Object e) => toast(context, friendlyError(e))),
                    child: const Text('Fixed — hatao'))
              else
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.recv, minimumSize: const Size(110, 42)),
                  onPressed: onCta ??
                      () {
                        if (l.posterPhone.isEmpty) {
                          toast(context, '${l.posterName} ne number nahi dikhaya');
                          return;
                        }
                        whatsApp(
                          context,
                          'Namaste, TransWell pe aapka load dekha: ${l.from} → ${l.to}, ${l.material} ${ton(l.weightTon)}. '
                          'Meri gaadi available hai, baat karein?',
                          phone: l.posterPhone,
                        );
                      },
                  child: Text(cta),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class PostLoadScreen extends StatefulWidget {
  const PostLoadScreen({super.key});
  @override
  State<PostLoadScreen> createState() => _PostLoadScreenState();
}

class _PostLoadScreenState extends State<PostLoadScreen> {
  final from = TextEditingController();
  final to = TextEditingController();
  final material = TextEditingController();
  final weight = TextEditingController();
  final date = TextEditingController(text: dm(DateTime.now().add(const Duration(days: 1))));
  final rate = TextEditingController();
  String type = 'Koi bhi';
  bool showPhone = true;
  bool part = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    if (r.myLat != null) from.text = nearestCity(r.myLat!, r.myLng!);
  }

  @override
  void dispose() {
    for (final c in [from, to, material, weight, date, rate]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget two(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    return Scaffold(
      appBar: AppBar(title: const Text('Load post karo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          two(Field(from, 'Loading kahan'), Field(to, 'Kahan jaana hai')),
          const SizedBox(height: 12),
          two(Field(material, 'Maal'), Field(weight, 'Weight (ton)', number: true)),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Full load')),
              ButtonSegment(value: true, label: Text('Part load')),
            ],
            selected: {part},
            onSelectionChanged: (v) => setState(() => part = v.first),
          ),
          if (part)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Jin gaadiyon mein thodi jagah khaali hai, unko bhi dikhega',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            ),
          const SizedBox(height: 14),
          const Text('Gaadi kaisi chahiye',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final t in ['Koi bhi', 'Open body', 'Container', 'Trailer'])
                ChoiceChip(
                    label: Text(t), selected: type == t, showCheckmark: false, onSelected: (_) => setState(() => type = t)),
            ],
          ),
          const SizedBox(height: 14),
          two(Field(date, 'Loading date'), Field(rate, 'Rate ₹ (optional)', number: true)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.recvSoft, borderRadius: BorderRadius.circular(12)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KISKO DIKHEGA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.recv)),
                SizedBox(height: 4),
                Text('Load board pe sab drivers, truck owners aur transporters ko — loading city ke paas wale sabse upar.',
                    style: TextStyle(fontSize: 15, height: 1.4)),
                SizedBox(height: 4),
                Text('48 ghante baad, ya "Fixed" dabane pe hat jaayega',
                    style: TextStyle(fontSize: 13, color: C.subtle)),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: showPhone,
            onChanged: (v) => setState(() => showPhone = v ?? true),
            title: const Text('Interested log mujhe call / WhatsApp kar sakein', style: TextStyle(fontSize: 14)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: C.ink),
            onPressed: saving
                ? null
                : () async {
                    if (from.text.trim().isEmpty || to.text.trim().isEmpty || material.text.trim().isEmpty) {
                      toast(context, 'Kahan se, kahan tak aur maal bharo');
                      return;
                    }
                    setState(() => saving = true);
                    try {
                      await s.postLoad(
                        from: from.text.trim(),
                        to: to.text.trim(),
                        material: material.text.trim(),
                        weight: double.tryParse(weight.text.trim()) ?? 0,
                        truckType: type,
                        date: date.text.trim(),
                        rate: int.tryParse(rate.text.replaceAll(',', '').trim()),
                        showPhone: showPhone,
                        part: part,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      toast(context, 'Load post ho gaya');
                    } catch (e) {
                      if (context.mounted) toast(context, friendlyError(e));
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: const Text('Load post karo', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live tracking (agent, owner, shipper)
// ---------------------------------------------------------------------------

class TrackingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String from;
  final String to;
  final double? lat;
  final double? lng;
  final DateTime? at;
  final String driver;
  final String driverPhone;
  final String? sharePhone; // party phone for "send location on WhatsApp"
  const TrackingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.from,
    required this.to,
    this.lat,
    this.lng,
    this.at,
    required this.driver,
    required this.driverPhone,
    this.sharePhone,
  });

  @override
  Widget build(BuildContext context) {
    final total = routeKm(from, to);
    final left = kmLeft(to, lat, lng);
    final stale = at != null && DateTime.now().difference(at!).inMinutes > 30;
    Widget stat(String k, String v) => Expanded(
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: const TextStyle(fontSize: 12, color: C.muted)),
                Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: C.muted)),
          ],
        ),
      ),
      body: ListView(
        children: [
          Stack(
            children: [
              TripMap(from: from, to: to, lat: lat, lng: lng, height: 380),
              if (at != null)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Color(0x26161B26), blurRadius: 4)],
                    ),
                    child: Text('Update: ${ago(at!)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stale ? C.pay : C.recv)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  stat('Abhi', lat == null ? '—' : nearLabel(lat!, lng!)),
                  const SizedBox(width: 8),
                  stat('Bacha', left == null ? '—' : '$left km'),
                  const SizedBox(width: 8),
                  stat('Kul', total == null ? '—' : '$total km'),
                ]),
                const SizedBox(height: 12),
                if (stale)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: C.paySoft, border: Border.all(color: C.pay), borderRadius: BorderRadius.circular(12)),
                    child: const Text('30 minute se zyada se update nahi aaya — driver ko call karke check karo.',
                        style: TextStyle(fontSize: 13, height: 1.4)),
                  ),
                if (stale) const SizedBox(height: 12),
                Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver $driver', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(driverPhone, style: const TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      CallButton(name: 'Driver $driver', phone: driverPhone),
                    ],
                  ),
                ),
                if (lat != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openMapsAt(lat!, lng!),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Google Maps'),
                      ),
                    ),
                    if (sharePhone != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => whatsApp(
                            context,
                            '$title ($subtitle) abhi yahan hai: https://maps.google.com/?q=$lat,$lng'
                            '${left == null ? '' : ' — $to se lagbhag $left km door'}',
                            phone: sharePhone,
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('Party ko bhejo'),
                        ),
                      ),
                    ],
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
