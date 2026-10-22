import 'package:flutter/material.dart';

import 'agent.dart';
import 'config.dart';
import 'data.dart';
import 'register.dart';
import 'services.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Bilty / parcel booking
// ---------------------------------------------------------------------------

class BiltyFormScreen extends StatefulWidget {
  final String service; // goods | parcel
  final String? tripId; // when adding straight into a part-load truck
  const BiltyFormScreen({super.key, this.service = 'goods', this.tripId});
  @override
  State<BiltyFormScreen> createState() => _BiltyFormScreenState();
}

class _BiltyFormScreenState extends State<BiltyFormScreen> {
  late String service = widget.service;
  DateTime date = DateTime.now();
  final party = TextEditingController();
  final partyPhone = TextEditingController();
  final consignee = TextEditingController();
  final consigneePhone = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  final material = TextEditingController();
  final packages = TextEditingController();
  final weight = TextEditingController();
  final value = TextEditingController();
  final freight = TextEditingController();
  final paidNow = TextEditingController();
  String payType = 'paid';
  bool saving = false;
  int savedCount = 0;

  List<TextEditingController> get _all =>
      [party, partyPhone, consignee, consigneePhone, material, packages, weight, value, freight, paidNow];

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    if (widget.tripId != null) {
      final t = r.trip(widget.tripId!);
      if (t != null) {
        from.text = t.from;
        to.text = t.to;
      }
    } else if (r.office?.city.isNotEmpty == true) {
      from.text = r.office!.city;
    }
    if (service == 'parcel') payType = 'to_pay';
  }

  @override
  void dispose() {
    for (final c in [..._all, from, to]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  bool get isParcel => service == 'parcel';

  Future<void> _save({required bool next}) async {
    final missing = <String>[
      if (party.text.trim().isEmpty) 'bhejne wala',
      if (consignee.text.trim().isEmpty) 'lene wala',
      if (to.text.trim().isEmpty) 'kahan tak',
      if (_n(freight) <= 0) 'bhada',
      if (isParcel && normPhone(consigneePhone.text).length != 10) 'lene wale ka mobile',
    ];
    if (missing.isNotEmpty) {
      toast(context, 'Ye bharo: ${missing.join(', ')}');
      return;
    }
    setState(() => saving = true);
    final r = AppScope.read(context);
    try {
      final w = double.tryParse(weight.text.trim());
      final c = await r.addBilty(
        partyName: party.text.trim(),
        partyPhone: partyPhone.text,
        consignee: consignee.text.trim(),
        consigneePhone: consigneePhone.text,
        from: from.text.trim(),
        to: to.text.trim(),
        material: material.text.trim(),
        packages: _n(packages) == 0 ? null : _n(packages),
        weightTon: isParcel ? null : w,
        weightKg: isParcel ? w : null,
        freight: _n(freight),
        payType: payType,
        service: service,
        declaredValue: _n(value) == 0 ? null : _n(value),
        paidNow: payType == 'paid' ? (_n(paidNow) > 0 ? _n(paidNow) : _n(freight)) : 0,
        tripId: widget.tripId,
        date: date,
      );
      if (!mounted) return;
      if (next) {
        setState(() {
          savedCount++;
          for (final x in _all) {
            x.clear();
          }
          saving = false;
        });
        toast(context, 'LR ${c.lr} book ho gaya · agla bharo');
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BiltyDetailScreen(id: c.id)));
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => saving = false);
      }
    }
  }

  Widget _two(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final truckTrip = widget.tripId == null ? null : r.trip(widget.tripId!);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(truckTrip != null
            ? 'Gaadi ${r.truckNo(truckTrip.truckId)} mein bilty'
            : (isParcel ? 'Parcel booking' : 'Bilty booking')),
        actions: [
          if (savedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Pill('$savedCount book', fg: C.recv, bg: C.recvSoft)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'goods', label: Text('Goods (ton)'), icon: Icon(Icons.inventory_2_outlined)),
              ButtonSegment(value: 'parcel', label: Text('Parcel (nag)'), icon: Icon(Icons.markunread_mailbox_outlined)),
            ],
            selected: {service},
            onSelectionChanged: (v) => setState(() {
              service = v.first;
              if (service == 'parcel' && payType == 'paid' && freight.text.isEmpty) payType = 'to_pay';
            }),
          ),
          const SizedBox(height: 12),
          Panel(
            color: isToday ? Colors.white : C.amberSoft,
            borderColor: isToday ? C.line : C.amber,
            onTap: () async {
              final d = await pickDate(context, date);
              if (d != null) setState(() => date = d);
            },
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: C.muted),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Booking: ${fullDate(date)}${isToday ? ' (aaj)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              const Text('Badlo', style: TextStyle(color: C.brand, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('BHEJNE WALA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.muted)),
          const SizedBox(height: 6),
          SuggestField(party, 'Naam / firm', options: () => r.parties.map((p) => p.name)),
          const SizedBox(height: 8),
          Field(partyPhone, 'Mobile (optional)', phone: true),
          contactButton(context, party, partyPhone),
          const Text('LENE WALA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.muted)),
          const SizedBox(height: 6),
          Field(consignee, 'Naam / firm'),
          const SizedBox(height: 8),
          Field(consigneePhone, isParcel ? 'Mobile (zaroori — isse parcel track hoga)' : 'Mobile (optional)', phone: true),
          contactButton(context, consignee, consigneePhone),
          _two(SuggestField(from, 'Kahan se', options: () => allCities(r)),
              SuggestField(to, 'Kahan tak', options: () => allCities(r))),
          const SizedBox(height: 12),
          SuggestField(material, isParcel ? 'Andar kya hai' : 'Maal', options: () => r.usedMaterials),
          const SizedBox(height: 12),
          _two(Field(packages, 'Nag / packet', number: true), Field(weight, isParcel ? 'Wazan (kg)' : 'Wazan (ton)', number: true)),
          if (isParcel) ...[
            const SizedBox(height: 12),
            Field(value, 'Maal ki keemat ₹ (optional)', number: true),
          ],
          const SizedBox(height: 14),
          const Text('Bhada kaun dega', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'paid', label: Text('Paid')),
              ButtonSegment(value: 'to_pay', label: Text('To-pay')),
              ButtonSegment(value: 'tbb', label: Text('TBB')),
            ],
            selected: {payType},
            onSelectionChanged: (v) => setState(() => payType = v.first),
          ),
          const SizedBox(height: 4),
          Text(
            switch (payType) {
              'to_pay' => 'Lene wala delivery pe dega',
              'tbb' => 'Bhejne wale ke khate mein — mahine ke bill mein',
              _ => 'Bhejne wala abhi de raha hai',
            },
            style: const TextStyle(fontSize: 12, color: C.muted),
          ),
          const SizedBox(height: 10),
          _two(
            TextField(
              controller: freight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bhada (₹)'),
            ),
            payType == 'paid'
                ? Field(paidNow, 'Abhi mila (khaali = poora)', number: true)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: saving ? null : () => _save(next: false), child: const Text('Save'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: saving ? null : () => _save(next: true),
                child: saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Save + agla'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bilty tab: godown, in trucks, to-pay collection
// ---------------------------------------------------------------------------

class BiltyTab extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const BiltyTab({super.key, required this.onRefresh});
  @override
  State<BiltyTab> createState() => _BiltyTabState();
}

class _BiltyTabState extends State<BiltyTab> {
  int view = 0; // 0 godown, 1 raste mein, 2 to-pay baaki, 3 sab
  String q = '';
  final selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final base = switch (view) {
      0 => r.godown,
      1 => r.bilties.where((c) => c.status == 'loaded').toList(),
      2 => r.toPayPending,
      _ => r.bilties,
    };
    final ql = q.toLowerCase();
    final list = base
        .where((c) =>
            ql.isEmpty ||
            '${c.lr} ${r.partyName(c.partyId)} ${c.consignee} ${c.to} ${c.consigneePhone}'.toLowerCase().contains(ql))
        .toList();
    final selTons = r.bilties.where((c) => selected.contains(c.id)).fold(0.0, (s, c) => s + c.tons);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Row(children: [
              const Expanded(child: Text('Bilty / Parcel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              IconButton(
                tooltip: 'Register',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                icon: const Icon(Icons.table_chart_outlined),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (i, label) in [
                    (0, 'Godown (${r.godown.length})'),
                    (1, 'Raste mein'),
                    (2, 'To-pay baaki ${r.toPayTotal > 0 ? inr(r.toPayTotal) : ''}'),
                    (3, 'Sab'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: view == i,
                        showCheckmark: false,
                        selectedColor: C.brand,
                        labelStyle: TextStyle(color: view == i ? Colors.white : C.ink, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() {
                          view = i;
                          selected.clear();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'LR, naam, city ya mobile'),
              onChanged: (v) => setState(() => q = v),
            ),
            const SizedBox(height: 10),
            if (view == 0 && list.isNotEmpty)
              const Text('Gaadi mein chadhane ke liye bilty chuno (tick karo)',
                  style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 6),
            if (list.isEmpty)
              EmptyNote(
                view == 0 ? 'Godown khaali hai. Neeche "+ Entry" se bilty / parcel book karo.' : 'Kuch nahi mila',
              ),
            for (final c in list)
              BiltyTile(
                c: c,
                selected: view == 0 ? selected.contains(c.id) : null,
                onSelect: (v) => setState(() => v ? selected.add(c.id) : selected.remove(c.id)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: selected.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
                child: Row(children: [
                  Expanded(
                    child: Text('${selected.length} bilty · ${selTons.toStringAsFixed(1)} ton',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final ids = selected.toList();
                      final tripId = await chooseTruckForBilties(context, ids);
                      if (tripId != null && mounted) setState(() => selected.clear());
                    },
                    child: const Text('Gaadi mein chadhao'),
                  ),
                ]),
              ),
            ),
    );
  }
}

class BiltyTile extends StatelessWidget {
  final Consignment c;
  final bool? selected;
  final ValueChanged<bool>? onSelect;
  const BiltyTile({super.key, required this.c, this.selected, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        borderColor: selected == true ? C.brand : C.line,
        borderWidth: selected == true ? 2 : 1,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BiltyDetailScreen(id: c.id))),
        child: Row(
          children: [
            if (selected != null)
              Checkbox(value: selected, onChanged: (v) => onSelect?.call(v ?? false)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text('LR ${c.lr} · ${dm(c.date)}${c.isParcel ? ' · Parcel' : ''}',
                          style: const TextStyle(fontSize: 12, color: C.muted)),
                    ),
                    Pill(c.payLabel,
                        fg: c.isToPay ? C.pay : (c.payType == 'tbb' ? C.amberInk : C.recv),
                        bg: c.isToPay ? C.paySoft : (c.payType == 'tbb' ? C.amberSoft : C.recvSoft)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${r.partyName(c.partyId)} → ${c.consignee}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(
                      '${c.route}${c.packages == null ? '' : ' · ${c.packages} nag'}${c.weightLabel.isEmpty ? '' : ' · ${c.weightLabel}'}',
                      style: const TextStyle(fontSize: 13, color: C.muted)),
                  Row(children: [
                    Expanded(
                        child: Text(biltyStatusLabel(c.status), style: const TextStyle(fontSize: 12, color: C.subtle))),
                    Text(c.balance > 0 ? 'Baaki ${inr(c.balance)}' : inr(c.freight),
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.balance > 0 ? C.pay : C.ink)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user pick an open part-load truck (or start one) for the given bilties.
Future<String?> chooseTruckForBilties(BuildContext context, List<String> ids) async {
  final r = AppScope.read(context);
  final open = r.trips.where((t) => t.isPart && t.status.index <= TripStatus.loaded.index).toList();
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text('Kis gaadi mein?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          for (final t in open)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('${r.truckNo(t.truckId)} · ${t.route}'),
              subtitle: Text('${t.bilties.length} bilty · ${t.loadedTons.toStringAsFixed(1)} ton chadha'
                  '${_space(r, t)}'),
              onTap: () => Navigator.pop(ctx, t.id),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_circle_outline, color: C.brand),
            title: const Text('Nayi gaadi (part load) shuru karo', style: TextStyle(color: C.brand, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  try {
    if (choice == 'new') {
      final t = await Navigator.push<Trip>(
          context, MaterialPageRoute(builder: (_) => PartTripScreen(loadBilties: ids)));
      return t?.id;
    }
    await r.loadBilties(ids, choice);
    if (context.mounted) toast(context, '${ids.length} bilty gaadi mein chadh gayi');
    return choice;
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
    return null;
  }
}

String _space(Repo r, Trip t) {
  final cap = r.truck(t.truckId)?.capacityTon;
  if (cap == null) return '';
  final left = cap - t.loadedTons;
  return left > 0 ? ' · ${left.toStringAsFixed(1)} ton jagah' : ' · bhar gayi';
}

// ---------------------------------------------------------------------------
// Part-load truck: start one
// ---------------------------------------------------------------------------

class PartTripScreen extends StatefulWidget {
  final List<String> loadBilties;
  const PartTripScreen({super.key, this.loadBilties = const []});
  @override
  State<PartTripScreen> createState() => _PartTripScreenState();
}

class _PartTripScreenState extends State<PartTripScreen> {
  DateTime date = DateTime.now();
  final truck = TextEditingController();
  final driver = TextEditingController();
  final driverPhone = TextEditingController();
  final ownerName = TextEditingController();
  final capacity = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  final hire = TextEditingController();
  final adv = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    final bs = widget.loadBilties.map((id) => r.bilty(id)).whereType<Consignment>().toList();
    if (bs.isNotEmpty) {
      from.text = bs.first.from;
      to.text = bs.first.to;
    } else if (r.office?.city.isNotEmpty == true) {
      from.text = r.office!.city;
    }
  }

  @override
  void dispose() {
    for (final c in [truck, driver, driverPhone, ownerName, capacity, from, to, hire, adv]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  Future<void> _save() async {
    if (truck.text.trim().isEmpty || to.text.trim().isEmpty) {
      toast(context, 'Gaadi no. aur kahan tak bharo');
      return;
    }
    setState(() => saving = true);
    final r = AppScope.read(context);
    try {
      final tid = await r.truckIdFor(truck.text,
          driver: driver.text.trim(), driverPhone: driverPhone.text, ownerName: ownerName.text);
      final cap = double.tryParse(capacity.text.trim());
      if (cap != null) await r.db.from('trucks').update({'capacity_ton': cap}).eq('id', tid);
      final t = await r.addPartTrip(
        truckId: tid,
        from: from.text.trim(),
        to: to.text.trim(),
        hire: _n(hire),
        ownerAdvance: _n(adv),
        date: date,
      );
      if (widget.loadBilties.isNotEmpty) await r.loadBilties(widget.loadBilties, t.id);
      if (!mounted) return;
      if (widget.loadBilties.isNotEmpty) {
        Navigator.pop(context, t);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TripDetailScreen(id: t.id)));
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final known = r.truckByNumber(truck.text);
    Widget two(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    return Scaffold(
      appBar: AppBar(title: const Text('Part load gaadi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.loadBilties.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Pill('${widget.loadBilties.length} bilty is gaadi mein chadhegi', fg: C.brand, bg: C.brandSoft),
            ),
          Panel(
            onTap: () async {
              final d = await pickDate(context, date);
              if (d != null) setState(() => date = d);
            },
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18, color: C.muted),
              const SizedBox(width: 10),
              Expanded(child: Text('Tarikh: ${fullDate(date)}', style: const TextStyle(fontWeight: FontWeight.w600))),
              const Text('Badlo', style: TextStyle(color: C.brand, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 12),
          SuggestField(truck, 'Gaadi no.',
              caps: true,
              options: () => r.trucks.map((t) => t.number),
              onPicked: (no) {
                final t = r.truckByNumber(no);
                if (t == null) return;
                setState(() {
                  driver.text = t.driver;
                  driverPhone.text = t.driverPhone;
                  capacity.text = t.capacityTon?.toString() ?? '';
                });
              },
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          two(Field(driver, 'Driver naam'), Field(driverPhone, 'Driver mobile', phone: true)),
          const SizedBox(height: 10),
          two(Field(capacity, 'Gaadi capacity (ton)', number: true),
              known == null ? SuggestField(ownerName, 'Gaadi malik', options: () => r.owners.map((o) => o.name)) : const SizedBox.shrink()),
          const SizedBox(height: 12),
          two(SuggestField(from, 'Kahan se', options: () => allCities(r)), SuggestField(to, 'Kahan tak', options: () => allCities(r))),
          const SizedBox(height: 12),
          two(Field(hire, 'Gaadi bhada (₹)', number: true), Field(adv, 'Gaadi ko advance', number: true)),
          const SizedBox(height: 8),
          const Text('Bilty is gaadi ke andar alag-alag jodoge — har party ka apna bhada.',
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Gaadi shuru karo'),
          ),
        ],
      ),
    );
  }
}

/// Part-load section shown inside the trip detail.
class PartLoadSection extends StatelessWidget {
  final Trip t;
  const PartLoadSection({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final cap = r.truck(t.truckId)?.capacityTon;
    final used = t.loadedTons;
    final toPay = t.bilties.where((c) => c.isToPay).fold(0, (s, c) => s + c.balance);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${t.bilties.length} bilty · ${used.toStringAsFixed(1)} ton chadha',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                if (cap != null)
                  Text(cap - used > 0 ? '${(cap - used).toStringAsFixed(1)} ton jagah' : 'Bhar gayi',
                      style: TextStyle(fontWeight: FontWeight.w700, color: cap - used > 0 ? C.recv : C.pay)),
              ]),
              if (cap != null && cap > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (used / cap).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: C.line,
                    color: used > cap ? C.pay : C.brand,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              KV('Kul bhada (bilty)', inr(t.biltyFreight)),
              KV('Delivery pe vasooli (to-pay)', inr(toPay), vColor: C.pay),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => BiltyFormScreen(tripId: t.id, service: 'goods'))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nayi bilty'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: r.godown.isEmpty
                        ? () => toast(context, 'Godown khaali hai')
                        : () => _pickFromGodown(context, t),
                    icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                    label: Text('Godown se (${r.godown.length})'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: t.bilties.isEmpty
                    ? null
                    : () {
                        final tr = r.truck(t.truckId);
                        sharePdf(
                          context,
                          () => challanPdf(
                            officeName: r.office?.name ?? '',
                            officePhone: r.office?.phone ?? '',
                            tripLr: t.lr,
                            date: t.date,
                            truckNo: tr?.number ?? '',
                            driver: '${tr?.driver ?? ''} ${tr?.driverPhone ?? ''}',
                            from: t.from,
                            to: t.to,
                            lines: [
                              for (final c in t.bilties)
                                ChallanLine(c.lr, r.partyName(c.partyId), c.consignee, c.to, c.material,
                                    c.packages?.toString() ?? '', c.weightLabel, c.payLabel, c.isToPay ? c.balance : 0),
                            ],
                          ),
                          'Challan-${t.lr}.pdf',
                        );
                      },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Loading challan PDF'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final c in t.bilties) BiltyTile(c: c),
      ],
    );
  }

  Future<void> _pickFromGodown(BuildContext context, Trip t) async {
    final r = AppScope.read(context);
    final chosen = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              const Text('Godown se bilty chuno', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final c in r.godown)
                      CheckboxListTile(
                        value: chosen.contains(c.id),
                        onChanged: (v) => setSt(() => v == true ? chosen.add(c.id) : chosen.remove(c.id)),
                        title: Text('LR ${c.lr} · ${r.partyName(c.partyId)} → ${c.consignee}'),
                        subtitle: Text('${c.route} · ${c.weightLabel} · ${c.payLabel}'),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                    onPressed: chosen.isEmpty
                        ? null
                        : () async {
                            try {
                              await r.loadBilties(chosen.toList(), t.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) toast(ctx, friendlyError(e));
                            }
                          },
                    child: Text('${chosen.length} bilty chadhao'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bilty detail: payments, delivery, POD, PDF
// ---------------------------------------------------------------------------

class BiltyDetailScreen extends StatelessWidget {
  final String id;
  const BiltyDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final c = r.bilty(id);
    if (c == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Bilty nahi mili')));
    final p = r.party(c.partyId);
    final trip = c.tripId == null ? null : r.trip(c.tripId!);
    final tr = trip == null ? null : r.truck(trip.truckId);
    return Scaffold(
      appBar: AppBar(
        title: Text('${c.isParcel ? 'Parcel' : 'Bilty'} LR ${c.lr}'),
        actions: [
          PopupMenuButton<int>(
            onSelected: (v) async {
              if (v == 1 && trip != null) {
                await r.unloadBilty(c).catchError((Object e) => toast(context, friendlyError(e)));
              } else if (v == 2) {
                final ok = await confirm(context, 'LR ${c.lr} hatana hai?', 'Iska hisaab bhi hat jaayega.');
                if (ok && context.mounted) {
                  await r.deleteBilty(c);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              if (trip != null && c.status != 'delivered')
                const PopupMenuItem(value: 1, child: Text('Gaadi se utaaro (godown mein)')),
              const PopupMenuItem(value: 2, child: Text('Bilty hatao')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(c.route, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  Pill(biltyStatusLabel(c.status), fg: C.brand, bg: C.brandSoft),
                ]),
                const SizedBox(height: 4),
                Text('${dm(c.date)} · ${c.material}${c.packages == null ? '' : ' · ${c.packages} nag'}'
                    '${c.weightLabel.isEmpty ? '' : ' · ${c.weightLabel}'}',
                    style: const TextStyle(color: C.muted)),
                if (c.declaredValue != null)
                  Text('Maal ki keemat: ${inr(c.declaredValue!)}', style: const TextStyle(color: C.muted)),
                const Divider(height: 18, color: C.line),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Bhejne wala', style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(p?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (p != null && p.phone.isNotEmpty) CallButton(name: p.name, phone: p.phone),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Lene wala', style: TextStyle(fontSize: 12, color: C.muted)),
                      Text(c.consignee, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (c.consigneePhone.isNotEmpty) CallButton(name: c.consignee, phone: c.consigneePhone),
                ]),
                if (tr != null) ...[
                  const Divider(height: 18, color: C.line),
                  InkWell(
                    onTap: () => openTrip(context, trip!.id),
                    child: Text('Gaadi ${tr.number} · LR ${trip!.lr} · ${trip.status.label}',
                        style: const TextStyle(color: C.brand, fontWeight: FontWeight.w600)),
                  ),
                ],
                if (c.status == 'delivered')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        'Delivered${c.deliveredTo.isEmpty ? '' : ' · ${c.deliveredTo} ko'}${c.deliveredAt == null ? '' : ' · ${dm(c.deliveredAt!)}'}',
                        style: const TextStyle(color: C.recv, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            topBar: c.isToPay ? C.pay : C.recv,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BHADA · ${c.payLabel.toUpperCase()}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.isToPay ? C.pay : C.recv)),
                KV('Bhada', inr(c.freight)),
                for (final pay in c.payments) KV('${dm(pay.date)} · ${pay.mode}${pay.note.isEmpty ? '' : ' · ${pay.note}'}', '− ${num0(pay.amount)}'),
                const Divider(height: 10, color: C.line),
                KV('Baaki', inr(c.balance), bold: true, vColor: c.balance > 0 ? C.pay : C.recv),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (c.status != 'delivered')
            FilledButton.icon(
              onPressed: () => _deliver(context, c),
              icon: const Icon(Icons.task_alt),
              label: Text(c.isToPay && c.balance > 0 ? 'Delivery + ${inr(c.balance)} vasooli' : 'Delivered mark karo'),
            ),
          if (c.status == 'delivered' && c.balance > 0)
            FilledButton(onPressed: () => _payment(context, c), child: const Text('+ Payment mila')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => sharePdf(context, () => biltyPdf(_biltyData(r, c)), 'Bilty-LR-${c.lr}.pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Bilty PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => whatsApp(
                  context,
                  'Namaste ${c.consignee} ji,\n${r.office?.name ?? ''} se aapke liye ${c.isParcel ? 'parcel' : 'maal'} book hua hai.\n'
                  'LR ${c.lr} · ${c.route} · ${c.material}${c.packages == null ? '' : ' · ${c.packages} nag'}\n'
                  'Bhejne wala: ${p?.name ?? ''}${c.isToPay ? '\nTo-pay bhada: ${inr(c.balance)}' : ''}\n'
                  'Isi number se TransWell app mein login karke live track karo: $appDownloadLink',
                  phone: c.consigneePhone.isEmpty ? null : c.consigneePhone,
                ),
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Lene wale ko'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.podPath == null ? null : () => showPodPhoto(context, c.podPath!),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(c.podPath == null ? 'POD nahi' : 'POD dekho'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bytes = await takePodPhoto(context);
                  if (bytes == null || !context.mounted) return;
                  try {
                    await r.uploadBiltyPod(c, bytes);
                    if (context.mounted) toast(context, 'POD save ho gaya');
                  } catch (e) {
                    if (context.mounted) toast(context, friendlyError(e));
                  }
                },
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('POD jodo'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  BiltyData _biltyData(Repo r, Consignment c) {
    final p = r.party(c.partyId);
    final trip = c.tripId == null ? null : r.trip(c.tripId!);
    final tr = trip == null ? null : r.truck(trip.truckId);
    return BiltyData(
      officeName: r.office?.name ?? '',
      officePhone: r.office?.phone ?? '',
      officeCity: r.office?.city ?? '',
      gst: r.office?.gst ?? '',
      lr: c.lr,
      date: c.date,
      consignor: p?.name ?? '',
      consignorCity: c.from,
      consignee: '${c.consignee}${c.consigneePhone.isEmpty ? '' : ' (${c.consigneePhone})'}',
      from: c.from,
      to: c.to,
      truckNo: tr?.number ?? 'Godown',
      driver: tr == null ? '' : '${tr.driver} ${tr.driverPhone}'.trim(),
      material: '${c.material}${c.packages == null ? '' : ' (${c.packages} pkgs)'}',
      weight: c.weightTon ?? 0,
      weightText: c.weightLabel,
      freight: c.freight,
      advance: c.received,
      payNote: c.payLabel,
      title: c.isParcel ? 'PARCEL RECEIPT' : 'LORRY RECEIPT (BILTY)',
    );
  }

  Future<void> _deliver(BuildContext context, Consignment c) async {
    final r = AppScope.read(context);
    final who = TextEditingController(text: c.consignee);
    final amt = TextEditingController(text: c.isToPay && c.balance > 0 ? c.balance.toString() : '');
    var mode = 'Cash';
    await showFormSheet(
      context,
      title: 'LR ${c.lr} delivery',
      fields: (setSt) => [
        Field(who, 'Kisne liya (naam)'),
        if (c.balance > 0) ...[
          TextField(
            controller: amt,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: c.isToPay ? 'To-pay vasooli (₹)' : 'Abhi mila (₹, optional)'),
          ),
          Wrap(spacing: 8, children: [
            for (final m in ['Cash', 'UPI', 'Bank'])
              ChoiceChip(label: Text(m), selected: mode == m, onSelected: (_) => setSt(() => mode = m)),
          ]),
        ],
      ],
      onSave: () async {
        await r.deliverBilty(c,
            receivedBy: who.text.trim(),
            collect: int.tryParse(amt.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
            mode: mode);
        return null;
      },
    );
  }

  Future<void> _payment(BuildContext context, Consignment c) async {
    final r = AppScope.read(context);
    final amt = TextEditingController(text: c.balance.toString());
    var mode = 'Cash';
    await showFormSheet(
      context,
      title: 'LR ${c.lr} payment',
      fields: (setSt) => [
        TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
        Wrap(spacing: 8, children: [
          for (final m in ['Cash', 'UPI', 'Bank', 'Cheque'])
            ChoiceChip(label: Text(m), selected: mode == m, onSelected: (_) => setSt(() => mode = m)),
        ]),
      ],
      onSave: () async {
        final a = int.tryParse(amt.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (a <= 0) return 'Amount daalo';
        await r.addBiltyPayment(c, a, mode);
        return null;
      },
    );
  }
}



Future<bool> confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.pay),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Haan, hatao'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
