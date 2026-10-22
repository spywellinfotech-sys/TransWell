import 'package:flutter/material.dart';

import 'data.dart';
import 'main.dart' show goToRoleScreen;
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
  Widget build(BuildContext context) {
    final pages = [
      AgentHome(onOpenTrips: () => setState(() => index = 1)),
      const TripsScreen(),
      const LedgerTab(),
      const DirectoryScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      floatingActionButton: index <= 1
          ? AmberFab(
              label: 'Trip',
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const NewTripScreen())),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Trips'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Ledger'),
          NavigationDestination(
              icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Directory'),
        ],
      ),
    );
  }
}

void openTrip(BuildContext context, int lr) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(lr: lr)));

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class AgentHome extends StatelessWidget {
  final VoidCallback onOpenTrips;
  const AgentHome({super.key, required this.onOpenTrips});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final payments = s.recentPayments.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Namaste, ${s.agentName} ji', style: const TextStyle(fontSize: 13, color: C.muted)),
                  Text(s.officeName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Role badlo',
              onPressed: () => goToRoleScreen(context),
              icon: const Icon(Icons.switch_account_outlined),
            ),
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
                      sub: '${s.receivableParties} parties se',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('Ledger')),
                                  body: const LedgerTab()))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MoneyBox(
                      title: 'DENA HAI',
                      color: C.pay,
                      amount: s.totalPayable,
                      sub: '${s.payableOwners} truck owners ko',
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFF3A4784)),
              Row(
                children: [
                  const Expanded(
                    child: Text('Is mahine commission', style: TextStyle(fontSize: 14, color: C.brandMuted)),
                  ),
                  Text(inr(s.monthCommission),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('  · ${s.monthTrips.length} trips',
                      style: const TextStyle(fontSize: 13, color: C.brandMuted)),
                ],
              ),
            ],
          ),
        ),
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
        if (s.activeTrips.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Abhi koi trip chal nahi raha', style: TextStyle(color: C.muted)),
          ),
        for (final t in s.activeTrips) TripTile(trip: t, onTap: () => openTrip(context, t.lr)),
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
                            Text(payments[i].who,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(
                                '${dm(payments[i].payment.date)} · ${payments[i].payment.mode} · LR ${payments[i].lr}',
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
    );
  }
}

class _MoneyBox extends StatelessWidget {
  final String title;
  final Color color;
  final int amount;
  final String sub;
  final VoidCallback? onTap;
  const _MoneyBox({required this.title, required this.color, required this.amount, required this.sub, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trips list
// ---------------------------------------------------------------------------

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
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
    final list = s.tripsNewestFirst.where((t) {
      final hay = '${t.lr} ${t.route} ${s.party(t.partyId).name} ${t.truckNo}'.toLowerCase();
      if (q.isNotEmpty && !hay.contains(q)) return false;
      switch (filter) {
        case 1:
          return t.partyBalance > 0 || t.ownerBalance > 0;
        case 2:
          return t.status == TripStatus.inTransit;
        case 3:
          return t.status == TripStatus.delivered;
        default:
          return true;
      }
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('Trips', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            Text('Oct 2026 · ${s.monthTrips.length} trips', style: const TextStyle(fontSize: 13, color: C.muted)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'LR no., party, truck no. ya city',
          ),
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
        for (final t in list) TripTile(trip: t, showBalances: true, onTap: () => openTrip(context, t.lr)),
      ],
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
  String? truckNo;
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

  Widget _field(TextEditingController c, String label,
      {bool number = false, bool required = true, Color? color}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
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
                child: Text('LR ${s.nextLr} · 22 Oct', style: const TextStyle(fontSize: 13, color: C.muted))),
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
              decoration: const InputDecoration(labelText: 'Party (consignor)'),
              items: [
                for (final p in s.parties)
                  DropdownMenuItem(value: p.id, child: Text('${p.name}, ${p.city}')),
              ],
              onChanged: (v) => setState(() => partyId = v),
              validator: (v) => v == null ? 'Party chuno' : null,
            ),
            const SizedBox(height: 12),
            _field(consignee, 'Consignee (maal kisko jayega)'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: truckNo,
              decoration: const InputDecoration(labelText: 'Truck no.'),
              items: [
                for (final t in s.trucks)
                  DropdownMenuItem(value: t.number, child: Text('${t.number} · ${t.driver}')),
              ],
              onChanged: (v) => setState(() => truckNo = v),
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
                    child: Text('Commission (apne aap)',
                        style: TextStyle(color: C.brand, fontWeight: FontWeight.w500)),
                  ),
                  Text(inr(commission),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: commission < 0 ? C.pay : C.brand)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row(_field(advIn, 'Party se advance mila', number: true, required: false),
                _field(advOut, 'Owner ko advance diya', number: true, required: false)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                if (_n(freight) <= 0 || _n(hire) <= 0) {
                  soon(context, 'Freight aur lorry hire dono bharo');
                  return;
                }
                final t = s.addTrip(
                  partyId: partyId!,
                  consignee: consignee.text.trim(),
                  truckNo: truckNo!,
                  from: from.text.trim(),
                  to: to.text.trim(),
                  material: material.text.trim(),
                  weightTon: double.tryParse(weight.text.trim()) ?? 0,
                  freight: _n(freight),
                  hire: _n(hire),
                  partyAdvance: _n(advIn),
                  ownerAdvance: _n(advOut),
                );
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => TripDetailScreen(lr: t.lr)));
              },
              child: const Text('Trip save karo'),
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

class TripDetailScreen extends StatelessWidget {
  final int lr;
  const TripDetailScreen({super.key, required this.lr});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.trip(lr);
    final tr = s.truck(t.truckNo);
    final owner = s.owner(tr.ownerId);
    return Scaffold(
      appBar: AppBar(title: Text('LR ${t.lr}')),
      body: ListView(
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
                    onPressed: () => s.advanceStatus(t),
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
                Text('${dm(t.date)} · ${t.material} · ${ton(t.weightTon)}',
                    style: const TextStyle(fontSize: 13, color: C.muted)),
                Text('${s.party(t.partyId).name} → ${t.consignee}',
                    style: const TextStyle(fontSize: 13, color: C.muted)),
                if (t.status == TripStatus.loaded || t.status == TripStatus.inTransit)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: C.recv),
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => TrackingScreen(lr: t.lr))),
                    icon: const Icon(Icons.my_location, size: 18),
                    label: Text('Live: ${t.nearPlace.isEmpty ? t.from : t.nearPlace} · ${t.kmLeft} km bacha'),
                  ),
                const Divider(height: 18, color: C.line),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.truckNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('Driver ${tr.driver} · Owner ${owner.name}',
                              style: const TextStyle(fontSize: 12, color: C.muted)),
                        ],
                      ),
                    ),
                    CallButton(name: 'Driver ${tr.driver}', phone: tr.driverPhone),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Panel(
                  topBar: C.recv,
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => PartyLedgerScreen(partyId: t.partyId))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PARTY SIDE',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.recv)),
                      KV('Freight', num0(t.freight)),
                      KV('Mila', '− ${num0(t.partyReceived)}'),
                      if (t.partyDeduction > 0) KV('Shortage', '− ${num0(t.partyDeduction)}'),
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
                      const Text('OWNER SIDE',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.pay)),
                      KV('Lorry hire', num0(t.hire)),
                      KV('Diya', '− ${num0(t.ownerPaid)}'),
                      if (t.ownerDeduction > 0) KV('Shortage', '− ${num0(t.ownerDeduction)}'),
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
                const Expanded(
                    child: Text('Commission', style: TextStyle(color: C.brand, fontWeight: FontWeight.w500))),
                Text(inr(t.commission),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.brand)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showPaymentSheet(context, t),
                  child: const Text('+ Payment'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BiltyScreen(lr: t.lr))),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Bilty'),
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
                            height: 2,
                            color: i == 0 ? Colors.transparent : (i <= status.index ? C.brand : C.line))),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < status.index
                            ? C.brand
                            : i == status.index
                                ? C.amber
                                : Colors.white,
                        border: Border.all(
                            color: i <= status.index ? C.brand : const Color(0xFFC9C5BB),
                            width: i == status.index ? 3 : 2),
                      ),
                    ),
                    Expanded(
                        child: Container(
                            height: 2,
                            color: i == steps.length - 1
                                ? Colors.transparent
                                : (i < status.index ? C.brand : C.line))),
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
  final s = AppScope.of(context);
  var party = true;
  var mode = 'UPI';
  final amount = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('LR ${t.lr} · Payment', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Party se mila')),
                ButtonSegment(value: false, label: Text('Owner ko diya')),
              ],
              selected: {party},
              onSelectionChanged: (v) => setSt(() => party = v.first),
            ),
            const SizedBox(height: 8),
            Text(
              party
                  ? 'Party ka baaki: ${inr(t.partyBalance)}'
                  : 'Owner ka baaki: ${inr(t.ownerBalance)}',
              style: const TextStyle(color: C.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in ['Cash', 'UPI', 'Bank', 'Cheque'])
                  ChoiceChip(
                    label: Text(m),
                    selected: mode == m,
                    onSelected: (_) => setSt(() => mode = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final a = int.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
                if (a <= 0) return;
                s.addPayment(t, party: party, amount: a, mode: mode);
                Navigator.pop(ctx);
                soon(context, '${inr(a)} ${party ? 'mila' : 'diya'} — hisaab update ho gaya');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
  amount.dispose();
}

// ---------------------------------------------------------------------------
// Ledger tab + party ledger
// ---------------------------------------------------------------------------

class LedgerTab extends StatelessWidget {
  const LedgerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ownerIds = s.trucks.map((t) => t.ownerId).toSet().toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SectionTitle('Parties (lena hai)'),
        for (final p in s.parties)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => PartyLedgerScreen(partyId: p.id))),
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
        for (final id in ownerIds)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.owner(id).name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  Text(inr(s.ownerBalance(id)),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: C.pay)),
                ],
              ),
            ),
          ),
      ],
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
    final entries = s.partyLedger(partyId);
    final ts = s.trips.where((t) => t.partyId == partyId).toList();
    final freight = ts.fold(0, (a, t) => a + t.freight);
    final got = ts.fold(0, (a, t) => a + t.partyReceived);
    final ded = ts.fold(0, (a, t) => a + t.partyDeduction);
    final bal = s.partyBalance(partyId);
    final open = ts.where((t) => t.partyBalance > 0).toList();
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
                    Text(inr(bal),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: C.recv)),
                  ],
                ),
                const Divider(height: 20, color: C.line),
                Row(
                  children: [
                    _mini('Freight (${ts.length} trips)', num0(freight)),
                    _mini('Mila', num0(got)),
                    _mini('Deduction', num0(ded)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: open.isEmpty
                      ? () => soon(context, 'Is party ka koi baaki nahi')
                      : () => showPaymentSheet(context, open.first),
                  child: const Text('+ Payment mila'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => soon(context, 'Statement PDF + WhatsApp share agle stage mein'),
                  child: const Text('Statement PDF'),
                ),
              ),
            ],
          ),
          const SectionTitle('Hisaab · naya upar'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  InkWell(
                    onTap: () => openTrip(context, entries[i].lr),
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
                              child: Text(dm(entries[i].date),
                                  style: const TextStyle(fontSize: 12, color: C.muted))),
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

  Widget _mini(String k, String v) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(fontSize: 12, color: C.muted)),
            Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Bilty
// ---------------------------------------------------------------------------

class BiltyScreen extends StatelessWidget {
  final int lr;
  const BiltyScreen({super.key, required this.lr});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.trip(lr);
    final tr = s.truck(t.truckNo);
    final p = s.party(t.partyId);
    const small = TextStyle(fontSize: 10.5, color: C.subtle);
    const val = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    Widget cell(String k, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(k, style: small), Text(v, style: val)],
        );
    return Scaffold(
      backgroundColor: const Color(0xFFE9E6DF),
      appBar: AppBar(title: const Text('Bilty preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Color(0x26161B26), blurRadius: 4, offset: Offset(0, 1))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.ink, width: 2))),
                  child: Column(
                    children: [
                      Text(s.officeName.toUpperCase(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const Text('Transport commission agent · [Office address]', style: small),
                      Text('Ph ${s.officePhone} · GSTIN [GST no.]', style: small),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                        child: Text('LORRY RECEIPT / बिल्टी',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('LR No. ${t.lr}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(fullDate(t.date), style: const TextStyle(color: C.subtle, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9C5BB))),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CONSIGNOR', style: small),
                                Text(p.name, style: val),
                                Text(p.city, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFFC9C5BB)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CONSIGNEE', style: small),
                                Text(t.consignee, style: val),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: cell('FROM', t.from)), Expanded(child: cell('TO', t.to))]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: cell('TRUCK NO.', t.truckNo)),
                  Expanded(child: cell('DRIVER', '${tr.driver} · ${tr.driverPhone}')),
                ]),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9C5BB))),
                  child: Column(
                    children: [
                      Container(
                        color: const Color(0xFFF3F1EC),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: const Row(children: [
                          Expanded(flex: 2, child: Text('MAAL', style: small)),
                          Expanded(child: Text('WEIGHT', style: small)),
                          Expanded(child: Text('FREIGHT', style: small, textAlign: TextAlign.right)),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(children: [
                          Expanded(flex: 2, child: Text(t.material, style: val)),
                          Expanded(child: Text(ton(t.weightTon), style: val)),
                          Expanded(child: Text(inr(t.freight), style: val, textAlign: TextAlign.right)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        KV('Freight', inr(t.freight)),
                        KV('Advance', inr(t.partyPayments.isEmpty ? 0 : t.partyPayments.first.amount)),
                        const Divider(height: 8, color: C.ink),
                        KV('Balance (to pay)',
                            inr(t.freight - (t.partyPayments.isEmpty ? 0 : t.partyPayments.first.amount)),
                            bold: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: _sign('Driver ke sign')),
                    const SizedBox(width: 16),
                    Expanded(child: _sign('For ${s.officeName}')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => soon(context, 'PDF download agle stage mein judega'),
                  child: const Text('PDF download'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => soon(context, 'WhatsApp share agle stage mein judega'),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sign(String label) => Container(
        padding: const EdgeInsets.only(top: 4),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.subtle))),
        child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: C.subtle)),
      );
}

// ---------------------------------------------------------------------------
// Directory
// ---------------------------------------------------------------------------

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  int tab = 2;
  String q = '';

  bool _match(String s) => q.isEmpty || s.toLowerCase().contains(q.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rows = <Widget>[];
    if (tab == 0) {
      for (final p in s.parties.where((p) => _match('${p.name} ${p.city}'))) {
        rows.add(_row(p.name, '${p.city} · ${p.phone}', CallButton(name: p.name, phone: p.phone)));
      }
    } else if (tab == 1) {
      for (final o in s.owners.where((o) => _match(o.name))) {
        final n = s.trucks.where((t) => t.ownerId == o.id).length;
        rows.add(_row(o.name, '$n gaadi · ${o.phone}', CallButton(name: o.name, phone: o.phone)));
      }
    } else if (tab == 2) {
      for (final t in s.trucks.where((t) => _match('${t.number} ${t.routes.join(' ')} ${t.type}'))) {
        final onTrip = s.activeTrips.any((x) => x.truckNo == t.number);
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(t.number, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        onTrip
                            ? const Pill('On trip', fg: C.subtle, bg: C.grey)
                            : const Pill('Khaali', fg: C.recv, bg: C.recvSoft),
                      ]),
                      const SizedBox(height: 4),
                      Text('${t.type} · ${t.capacityTon} ton · ${s.owner(t.ownerId).name}',
                          style: const TextStyle(fontSize: 13, color: C.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final r in t.routes) Tag(r)]),
                    ],
                  ),
                ),
                CallButton(name: s.owner(t.ownerId).name, phone: s.owner(t.ownerId).phone),
              ],
            ),
          ),
        ));
      }
    } else {
      for (final t in s.trucks.where((t) => _match('${t.driver} ${t.number}'))) {
        rows.add(_row(t.driver, '${t.number} · ${t.driverPhone}', CallButton(name: t.driver, phone: t.driverPhone)));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
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
    );
  }

  Widget _row(String title, String sub, Widget trailing) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
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
}

// ---------------------------------------------------------------------------
// Load board + post load
// ---------------------------------------------------------------------------

class LoadBoardScreen extends StatefulWidget {
  const LoadBoardScreen({super.key});
  @override
  State<LoadBoardScreen> createState() => _LoadBoardScreenState();
}

class _LoadBoardScreenState extends State<LoadBoardScreen> {
  int tab = 0;
  String type = 'Sab type';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final posts = s.truckPosts.where((p) => type == 'Sab type' || p.type == type).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Load board'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(label: const Text('Jaipur · 50 km'), onPressed: () => soon(context, 'City badalna GPS stage mein')),
          ),
        ],
      ),
      floatingActionButton: AmberFab(
        label: 'Load post karo',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostLoadScreen())),
      ),
      body: ListView(
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
          const SizedBox(height: 12),
          if (tab == 0) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final t in ['Sab type', 'Open body', 'Container', 'Trailer'])
                  ChoiceChip(
                    label: Text(t),
                    selected: type == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => type = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in posts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(p.truckNo,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        Text(p.ago, style: const TextStyle(fontSize: 12, color: C.muted)),
                      ]),
                      const SizedBox(height: 4),
                      Text('${p.type} · ${p.capacityTon} ton · ${p.area} · ${p.km} km',
                          style: const TextStyle(fontSize: 14)),
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
                      const Divider(height: 18, color: C.line),
                      Row(children: [
                        Expanded(child: Text(p.postedBy, style: const TextStyle(fontSize: 13, color: C.muted))),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: C.recv, minimumSize: const Size(110, 40)),
                          onPressed: () => soon(context, 'Call: ${p.postedBy}'),
                          child: const Text('Call karo'),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
          ] else
            for (final l in s.loads) LoadCard(load: l, cta: 'Interested', onCta: () => soon(context, '${l.postedBy} ko call / WhatsApp')),
        ],
      ),
    );
  }
}

class LoadCard extends StatelessWidget {
  final LoadPost load;
  final String cta;
  final VoidCallback onCta;
  const LoadCard({super.key, required this.load, required this.cta, required this.onCta});

  @override
  Widget build(BuildContext context) {
    final l = load;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text('${l.from} → ${l.to}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              Text(l.ago, style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
            const SizedBox(height: 4),
            Text('${l.material} · ${ton(l.weightTon)} · ${l.truckType} · ${l.date}',
                style: const TextStyle(fontSize: 14, color: C.subtle)),
            if (l.rate != null)
              Text('Rate ${inr(l.rate!)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Divider(height: 18, color: C.line),
            Row(children: [
              Expanded(child: Text(l.postedBy, style: const TextStyle(fontSize: 13, color: C.muted))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.recv, minimumSize: const Size(110, 42)),
                onPressed: onCta,
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
  final String postedBy;
  const PostLoadScreen({super.key, this.postedBy = 'Sharma Roadlines'});
  @override
  State<PostLoadScreen> createState() => _PostLoadScreenState();
}

class _PostLoadScreenState extends State<PostLoadScreen> {
  final from = TextEditingController(text: 'Jaipur');
  final to = TextEditingController();
  final material = TextEditingController();
  final weight = TextEditingController();
  final date = TextEditingController(text: '24 Oct');
  final rate = TextEditingController();
  String type = 'Koi bhi';
  bool showWa = true;

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
    Widget two(Widget a, Widget b) =>
        Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    return Scaffold(
      appBar: AppBar(title: const Text('Load post karo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          two(TextField(controller: from, decoration: const InputDecoration(labelText: 'Loading kahan')),
              TextField(controller: to, decoration: const InputDecoration(labelText: 'Kahan jaana hai'))),
          const SizedBox(height: 12),
          two(TextField(controller: material, decoration: const InputDecoration(labelText: 'Maal')),
              TextField(
                  controller: weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (ton)'))),
          const SizedBox(height: 14),
          const Text('Gaadi kaisi chahiye', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final t in ['Koi bhi', 'Open body', 'Container', 'Trailer'])
                ChoiceChip(
                    label: Text(t),
                    selected: type == t,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => type = t)),
            ],
          ),
          const SizedBox(height: 14),
          two(TextField(controller: date, decoration: const InputDecoration(labelText: 'Loading date')),
              TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Rate ₹ (optional)'))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.recvSoft, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KISKO DIKHEGA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.recv)),
                const SizedBox(height: 4),
                Text(
                    '${from.text.isEmpty ? 'Loading city' : from.text} ke 50 km mein khaali gaadi wale drivers, truck owners aur transporters ko — turant notification ke saath',
                    style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 4),
                const Text('Load 48 ghante baad, ya "Fixed" mark karne pe hat jaayega',
                    style: TextStyle(fontSize: 13, color: C.subtle)),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: showWa,
            onChanged: (v) => setState(() => showWa = v ?? true),
            title: const Text('Interested logon ko mera WhatsApp number dikhe', style: TextStyle(fontSize: 14)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: C.ink),
            onPressed: () {
              if (from.text.trim().isEmpty || to.text.trim().isEmpty || material.text.trim().isEmpty) {
                soon(context, 'Kahan se, kahan tak aur maal bharo');
                return;
              }
              s.postLoad(LoadPost(
                from.text.trim(),
                to.text.trim(),
                material.text.trim(),
                double.tryParse(weight.text.trim()) ?? 0,
                type,
                date.text.trim(),
                int.tryParse(rate.text.replaceAll(',', '').trim()),
                widget.postedBy,
                'Abhi',
              ));
              Navigator.pop(context);
              soon(context, 'Load post ho gaya — paas ke drivers ko dikhega');
            },
            child: const Text('Load post karo', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live tracking
// ---------------------------------------------------------------------------

class TrackingScreen extends StatelessWidget {
  final int lr;
  final bool forShipper;
  const TrackingScreen({super.key, required this.lr, this.forShipper = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.trip(lr);
    final tr = s.truck(t.truckNo);
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
    final live = t.status == TripStatus.inTransit || t.status == TripStatus.loaded;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.truckNo),
            Text('LR ${t.lr} · ${t.route}', style: const TextStyle(fontSize: 12, color: C.muted)),
          ],
        ),
      ),
      body: ListView(
        children: [
          Stack(
            children: [
              RouteMap(from: t.from, to: t.to, progress: t.progress, near: t.nearPlace),
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
                  child: Text(live ? 'Live · 4 min pehle update' : 'Trip khatam — tracking band',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.recv)),
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
                  stat('Chal chuka', '${t.kmDone} km'),
                  const SizedBox(width: 8),
                  stat('Bacha', '${t.kmLeft} km'),
                  const SizedBox(width: 8),
                  stat('Speed', live ? '48 km/h' : '—'),
                ]),
                const SizedBox(height: 12),
                if (!forShipper)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: C.amberSoft,
                        border: Border.all(color: C.amber),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('30 minute tak location update na aaye toh aapko alert aayega.',
                        style: TextStyle(fontSize: 13, height: 1.4)),
                  ),
                const SizedBox(height: 12),
                Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver ${tr.driver}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(tr.driverPhone, style: const TextStyle(fontSize: 12, color: C.muted)),
                          ],
                        ),
                      ),
                      CallButton(name: 'Driver ${tr.driver}', phone: tr.driverPhone),
                    ],
                  ),
                ),
                if (!forShipper) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => soon(context, 'Party ko location WhatsApp pe — agle stage mein'),
                    child: const Text('Party ko location bhejo (WhatsApp)'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
