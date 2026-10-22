import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'agent.dart';
import 'bilty.dart';
import 'cities.dart';
import 'config.dart';
import 'data.dart';
import 'services.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Text field with suggestions (cities, parties, trucks, materials)
// ---------------------------------------------------------------------------

class SuggestField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final Iterable<String> Function() options;
  final String? hint;
  final bool caps;
  final ValueChanged<String>? onPicked;
  final ValueChanged<String>? onChanged;
  const SuggestField(this.controller, this.label,
      {super.key, required this.options, this.hint, this.caps = false, this.onPicked, this.onChanged});

  @override
  State<SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<SuggestField> {
  final focus = FocusNode();

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => RawAutocomplete<String>(
        textEditingController: widget.controller,
        focusNode: focus,
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          if (q.isEmpty) return const Iterable<String>.empty();
          final seen = <String>{};
          return widget.options()
              .where((o) => o.toLowerCase().contains(q) && o.toLowerCase() != q && seen.add(o.toLowerCase()))
              .take(6);
        },
        onSelected: (o) => widget.onPicked?.call(o),
        fieldViewBuilder: (context, c, f, onSubmit) => TextField(
          controller: c,
          focusNode: f,
          textCapitalization: widget.caps ? TextCapitalization.characters : TextCapitalization.words,
          decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
          onChanged: widget.onChanged,
        ),
        optionsViewBuilder: (context, onSel, opts) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 240, maxWidth: box.maxWidth),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final o in opts) ListTile(dense: true, title: Text(o), onTap: () => onSel(o)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Iterable<String> allCities(Repo r) sync* {
  yield* r.usedCities;
  for (final k in cityCoords.keys) {
    yield k.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Entry ki tarikh',
    );

// ---------------------------------------------------------------------------
// Register-style trip entry (full load). Party and truck are created on the fly.
// ---------------------------------------------------------------------------

class QuickEntryScreen extends StatefulWidget {
  final Trip? edit;
  final Trip? copyFrom;
  const QuickEntryScreen({super.key, this.edit, this.copyFrom});
  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
  DateTime date = DateTime.now();
  final truck = TextEditingController();
  final driver = TextEditingController();
  final driverPhone = TextEditingController();
  final ownerName = TextEditingController();
  final from = TextEditingController();
  final to = TextEditingController();
  final party = TextEditingController();
  final partyPhone = TextEditingController();
  final consignee = TextEditingController();
  final material = TextEditingController();
  final weight = TextEditingController();
  final freight = TextEditingController();
  final hire = TextEditingController();
  final advIn = TextEditingController();
  final advOut = TextEditingController();
  bool saving = false;
  int savedCount = 0;

  List<TextEditingController> get _all => [
        truck, driver, driverPhone, ownerName, from, to, party, partyPhone, consignee, material, weight, freight,
        hire, advIn, advOut
      ];

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    final src = widget.edit ?? widget.copyFrom;
    if (src != null) {
      final tr = r.truck(src.truckId);
      truck.text = tr?.number ?? '';
      driver.text = tr?.driver ?? '';
      driverPhone.text = tr?.driverPhone ?? '';
      from.text = src.from;
      to.text = src.to;
      party.text = r.party(src.partyId)?.name ?? '';
      consignee.text = src.consignee;
      material.text = src.material;
      weight.text = src.weightTon == 0 ? '' : src.weightTon.toString();
      freight.text = src.freight.toString();
      hire.text = src.hire.toString();
      if (widget.edit != null) date = src.date;
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  void _partyPicked(String name) {
    final r = AppScope.read(context);
    final p = r.partyByName(name);
    if (p == null) return;
    final last = r.lastTripOfParty(p.id);
    if (last == null) return;
    setState(() {
      if (from.text.isEmpty) from.text = last.from;
      if (to.text.isEmpty) to.text = last.to;
      if (material.text.isEmpty) material.text = last.material;
      if (consignee.text.isEmpty) consignee.text = last.consignee;
      if (freight.text.isEmpty) freight.text = last.freight.toString();
    });
    toast(context, 'Pichle trip se route aur rate bhar diya — badal sakte ho');
  }

  void _truckPicked(String no) {
    final t = AppScope.read(context).truckByNumber(no);
    if (t == null) return;
    setState(() {
      driver.text = t.driver;
      driverPhone.text = t.driverPhone;
    });
  }

  Future<void> _save({required bool next}) async {
    final missing = <String>[
      if (truck.text.trim().isEmpty) 'gaadi no.',
      if (from.text.trim().isEmpty) 'kahan se',
      if (to.text.trim().isEmpty) 'kahan tak',
      if (party.text.trim().isEmpty) 'party',
      if (_n(freight) <= 0) 'bhada',
    ];
    if (missing.isNotEmpty) {
      toast(context, 'Ye bharo: ${missing.join(', ')}');
      return;
    }
    setState(() => saving = true);
    final r = AppScope.read(context);
    try {
      final pid = await r.partyIdFor(party.text, phone: partyPhone.text);
      final tid = await r.truckIdFor(truck.text,
          driver: driver.text.trim(), driverPhone: driverPhone.text, ownerName: ownerName.text);
      if (widget.edit != null) {
        await r.updateTrip(widget.edit!,
            partyId: pid,
            consignee: consignee.text.trim(),
            truckId: tid,
            from: from.text.trim(),
            to: to.text.trim(),
            material: material.text.trim(),
            weightTon: double.tryParse(weight.text.trim()) ?? 0,
            freight: _n(freight),
            hire: _n(hire),
            date: date);
        if (mounted) {
          toast(context, 'Badlaav save ho gaya');
          Navigator.pop(context);
        }
        return;
      }
      final t = await r.addTrip(
        partyId: pid,
        consignee: consignee.text.trim(),
        truckId: tid,
        from: from.text.trim(),
        to: to.text.trim(),
        material: material.text.trim(),
        weightTon: double.tryParse(weight.text.trim()) ?? 0,
        freight: _n(freight),
        hire: _n(hire),
        partyAdvance: _n(advIn),
        ownerAdvance: _n(advOut),
        date: date,
      );
      if (!mounted) return;
      if (next) {
        setState(() {
          savedCount++;
          for (final c in _all) {
            c.clear();
          }
          saving = false;
        });
        toast(context, 'LR ${t.lr} save ho gaya · agli entry bharo');
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

  Widget _two(Widget a, Widget b) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final newTruck = truck.text.trim().isNotEmpty && r.truckByNumber(truck.text) == null;
    final newParty = party.text.trim().isNotEmpty && r.partyByName(party.text) == null;
    final commission = _n(freight) - _n(hire);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit != null ? 'LR ${widget.edit!.lr} badlo' : 'Register entry'),
        actions: [
          if (savedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Pill('$savedCount save', fg: C.recv, bg: C.recvSoft)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            color: isToday ? Colors.white : C.amberSoft,
            borderColor: isToday ? C.line : C.amber,
            onTap: () async {
              final d = await pickDate(context, date);
              if (d != null) setState(() => date = d);
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: C.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Tarikh: ${fullDate(date)}${isToday ? ' (aaj)' : ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Text(isToday ? 'Purani entry? badlo' : 'Badlo', style: const TextStyle(color: C.brand, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SuggestField(truck, 'Gaadi no.',
              caps: true,
              hint: 'RJ14 GB 4821',
              options: () => r.trucks.map((t) => t.number),
              onPicked: _truckPicked,
              onChanged: (_) => setState(() {})),
          if (newTruck) ...[
            const SizedBox(height: 6),
            const Text('Nayi gaadi — apne aap directory mein jud jaayegi',
                style: TextStyle(fontSize: 12, color: C.recv, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          _two(Field(driver, 'Driver naam'), Field(driverPhone, 'Driver mobile', phone: true)),
          if (newTruck) ...[
            const SizedBox(height: 10),
            SuggestField(ownerName, 'Gaadi malik (optional)', options: () => r.owners.map((o) => o.name)),
          ],
          const SizedBox(height: 12),
          _two(
            SuggestField(from, 'Kahan se', options: () => allCities(r)),
            SuggestField(to, 'Kahan tak', options: () => allCities(r)),
          ),
          const SizedBox(height: 12),
          SuggestField(party, 'Party (maal kiska)',
              options: () => r.parties.map((p) => p.name),
              onPicked: _partyPicked,
              onChanged: (_) => setState(() {})),
          if (newParty) ...[
            const SizedBox(height: 6),
            const Text('Nayi party — apne aap jud jaayegi', style: TextStyle(fontSize: 12, color: C.recv, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Field(partyPhone, 'Party mobile (optional)', phone: true),
          ],
          const SizedBox(height: 12),
          _two(SuggestField(material, 'Maal', options: () => r.usedMaterials), Field(weight, 'Wazan (ton)', number: true)),
          const SizedBox(height: 12),
          Field(consignee, 'Consignee (kisko dena hai) — optional'),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: freight,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Party bhada (₹)', labelStyle: TextStyle(color: C.recv, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: hire,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Gaadi bhada (₹)', labelStyle: TextStyle(color: C.pay, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: C.brandSoft, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Expanded(child: Text('Commission', style: TextStyle(color: C.brand, fontWeight: FontWeight.w500))),
              Text(inr(commission),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: commission < 0 ? C.pay : C.brand)),
            ]),
          ),
          if (widget.edit == null) ...[
            const SizedBox(height: 12),
            _two(Field(advIn, 'Party se advance mila', number: true), Field(advOut, 'Gaadi ko advance diya', number: true)),
          ],
          const SizedBox(height: 20),
          if (widget.edit == null)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : () => _save(next: false),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: saving ? null : () => _save(next: true),
                  child: saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Save + agli entry'),
                ),
              ),
            ])
          else
            FilledButton(
              onPressed: saving ? null : () => _save(next: false),
              child: const Text('Badlaav save karo'),
            ),
          const SizedBox(height: 8),
          const Text('Sirf gaadi, kahan se/tak, party aur bhada zaroori hai. Baaki baad mein bhi bhar sakte ho.',
              style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}

/// "+ Entry" chooser used by the agent / transport home.
Future<void> showEntryMenu(BuildContext context) async {
  final r = AppScope.read(context);
  final kind = r.office?.kind ?? 'agent';
  final choice = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Full load trip'),
            subtitle: const Text('Ek party, poori gaadi — register jaisi entry'),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            leading: const Icon(Icons.view_module_outlined),
            title: const Text('Part load gaadi'),
            subtitle: const Text('Ek gaadi mein kai parties ki bilty'),
            onTap: () => Navigator.pop(ctx, 1),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(kind == 'parcel' ? 'Parcel booking' : 'Bilty booking (godown)'),
            subtitle: const Text('Maal ab book karo, gaadi baad mein'),
            onTap: () => Navigator.pop(ctx, 2),
          ),
          if (kind != 'agent')
            ListTile(
              leading: const Icon(Icons.markunread_mailbox_outlined),
              title: Text(kind == 'parcel' ? 'Goods bilty booking' : 'Parcel booking'),
              onTap: () => Navigator.pop(ctx, 3),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final parcelFirst = kind == 'parcel';
  final Widget screen = switch (choice) {
    0 => const QuickEntryScreen(),
    1 => const PartTripScreen(),
    2 => BiltyFormScreen(service: parcelFirst ? 'parcel' : 'goods'),
    _ => BiltyFormScreen(service: parcelFirst ? 'goods' : 'parcel'),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

// ---------------------------------------------------------------------------
// Opening balances from the old register
// ---------------------------------------------------------------------------

class OpeningBalanceScreen extends StatefulWidget {
  final bool parties;
  const OpeningBalanceScreen({super.key, required this.parties});
  @override
  State<OpeningBalanceScreen> createState() => _OpeningBalanceScreenState();
}

class _OpenRow {
  final name = TextEditingController();
  final phone = TextEditingController();
  final amount = TextEditingController();
  void dispose() {
    name.dispose();
    phone.dispose();
    amount.dispose();
  }
}

class _OpeningBalanceScreenState extends State<OpeningBalanceScreen> {
  final rows = <_OpenRow>[];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    if (widget.parties) {
      for (final p in r.parties) {
        rows.add(_OpenRow()
          ..name.text = p.name
          ..phone.text = p.phone
          ..amount.text = p.opening == 0 ? '' : p.opening.toString());
      }
    } else {
      for (final o in r.owners) {
        rows.add(_OpenRow()
          ..name.text = o.name
          ..phone.text = o.phone
          ..amount.text = o.opening == 0 ? '' : o.opening.toString());
      }
    }
    for (var i = 0; i < 3; i++) {
      rows.add(_OpenRow());
    }
  }

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  int get total => rows.fold(0, (s, r) => s + (int.tryParse(r.amount.text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0));

  Future<void> _save() async {
    setState(() => saving = true);
    final r = AppScope.read(context);
    try {
      await r.saveOpenings(partiesSide: widget.parties, rows: [
        for (final x in rows)
          (x.name.text, x.phone.text, int.tryParse(x.amount.text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0)
      ]);
      if (!mounted) return;
      toast(context, 'Purana hisaab save ho gaya');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.parties ? 'Party' : 'Gaadi malik';
    return Scaffold(
      appBar: AppBar(title: Text(widget.parties ? 'Parties ka purana baaki' : 'Gaadi malikon ka purana baaki')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text(
            widget.parties
                ? 'Register mein jis party se jitna lena baaki hai, wahi likho. Naam likhte hi party ban jaayegi.'
                : 'Register mein jis gaadi malik ko jitna dena baaki hai, wahi likho.',
            style: const TextStyle(color: C.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${i + 1}.', style: const TextStyle(color: C.muted))),
                  Expanded(flex: 5, child: Field(rows[i].name, '$who naam')),
                  const SizedBox(width: 6),
                  Expanded(flex: 4, child: Field(rows[i].phone, 'Mobile', phone: true)),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: rows[i].amount,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Baaki ₹'),
                    ),
                  ),
                ],
              ),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => rows.addAll([_OpenRow(), _OpenRow(), _OpenRow()])),
                icon: const Icon(Icons.add),
                label: const Text('Aur line'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final c = await pickContact(context);
                  if (c == null) return;
                  setState(() => rows.insert(
                      rows.indexWhere((x) => x.name.text.isEmpty).clamp(0, rows.length),
                      _OpenRow()
                        ..name.text = c.$1
                        ..phone.text = c.$2));
                },
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('Contacts se'),
              ),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
          child: Row(children: [
            Expanded(child: Text('Kul: ${inr(total)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Save karo'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register view (month table, like the paper book) + PDF
// ---------------------------------------------------------------------------

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool biltyView = false;

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
    final trips = r.trips.where((t) => inMonth(t.date)).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.lr.compareTo(b.lr);
      });
    final bilties = r.bilties.where((c) => inMonth(c.date)).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.lr.compareTo(b.lr);
      });
    const head = TextStyle(fontWeight: FontWeight.w700, color: C.ink);
    DataCell cell(String s, {bool bold = false, Color? color}) =>
        DataCell(Text(s, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null, color: color)));

    final tripTable = DataTable(
      headingRowColor: const WidgetStatePropertyAll(C.grey),
      columnSpacing: 18,
      headingTextStyle: head,
      columns: const [
        DataColumn(label: Text('Tarikh')),
        DataColumn(label: Text('LR')),
        DataColumn(label: Text('Gaadi')),
        DataColumn(label: Text('Kahan se – tak')),
        DataColumn(label: Text('Party')),
        DataColumn(label: Text('Party bhada'), numeric: true),
        DataColumn(label: Text('Gaadi bhada'), numeric: true),
        DataColumn(label: Text('Comm.'), numeric: true),
        DataColumn(label: Text('Party baaki'), numeric: true),
        DataColumn(label: Text('Gaadi baaki'), numeric: true),
      ],
      rows: [
        for (final t in trips)
          DataRow(
            onSelectChanged: (_) => openTrip(context, t.id),
            cells: [
              cell(dm(t.date)),
              cell('${t.lr}'),
              cell(r.truckNo(t.truckId)),
              cell(t.route),
              cell(t.isPart ? 'Part load (${t.bilties.length})' : r.partyName(t.partyId)),
              cell(num0(t.isPart ? t.biltyFreight : t.freight)),
              cell(num0(t.hire)),
              cell(num0(t.commission), color: C.brand),
              cell(t.isPart ? '—' : num0(t.partyBalance), color: C.recv),
              cell(num0(t.ownerBalance), color: C.pay),
            ],
          ),
        DataRow(color: const WidgetStatePropertyAll(C.brandSoft), cells: [
          cell('Kul', bold: true),
          cell('${trips.length}', bold: true),
          cell(''),
          cell(''),
          cell(''),
          cell(num0(trips.fold(0, (s, t) => s + (t.isPart ? t.biltyFreight : t.freight))), bold: true),
          cell(num0(trips.fold(0, (s, t) => s + t.hire)), bold: true),
          cell(num0(trips.fold(0, (s, t) => s + t.commission)), bold: true, color: C.brand),
          cell(num0(trips.fold(0, (s, t) => s + t.partyBalance)), bold: true, color: C.recv),
          cell(num0(trips.fold(0, (s, t) => s + t.ownerBalance)), bold: true, color: C.pay),
        ]),
      ],
    );

    final biltyTable = DataTable(
      headingRowColor: const WidgetStatePropertyAll(C.grey),
      columnSpacing: 18,
      headingTextStyle: head,
      columns: const [
        DataColumn(label: Text('Tarikh')),
        DataColumn(label: Text('LR')),
        DataColumn(label: Text('Party')),
        DataColumn(label: Text('Consignee')),
        DataColumn(label: Text('Kahan se – tak')),
        DataColumn(label: Text('Nag'), numeric: true),
        DataColumn(label: Text('Wazan')),
        DataColumn(label: Text('Bhada'), numeric: true),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Baaki'), numeric: true),
        DataColumn(label: Text('Haalat')),
      ],
      rows: [
        for (final c in bilties)
          DataRow(
            onSelectChanged: (_) =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => BiltyDetailScreen(id: c.id))),
            cells: [
              cell(dm(c.date)),
              cell('${c.lr}${c.isParcel ? ' P' : ''}'),
              cell(r.partyName(c.partyId)),
              cell(c.consignee),
              cell(c.route),
              cell(c.packages?.toString() ?? ''),
              cell(c.weightLabel),
              cell(num0(c.freight)),
              cell(c.payLabel),
              cell(num0(c.balance), color: c.balance > 0 ? C.pay : C.recv),
              cell(biltyStatusLabel(c.status)),
            ],
          ),
        DataRow(color: const WidgetStatePropertyAll(C.brandSoft), cells: [
          cell('Kul', bold: true),
          cell('${bilties.length}', bold: true),
          cell(''),
          cell(''),
          cell(''),
          cell('${bilties.fold(0, (s, c) => s + (c.packages ?? 0))}', bold: true),
          cell(''),
          cell(num0(bilties.fold(0, (s, c) => s + c.freight)), bold: true),
          cell(''),
          cell(num0(bilties.fold(0, (s, c) => s + c.balance)), bold: true),
          cell(''),
        ]),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        actions: [
          IconButton(
            tooltip: 'PDF / print',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => sharePdf(
              context,
              () => registerPdf(r, month, trips, bilties, biltyView),
              'Register-${monthYear(month).replaceAll(' ', '-')}.pdf',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                    onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(monthYear(month),
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text('Gaadi register (${trips.length})')),
                ButtonSegment(value: true, label: Text('Bilty register (${bilties.length})')),
              ],
              selected: {biltyView},
              onSelectionChanged: (v) => setState(() => biltyView = v.first),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
              child: biltyView ? biltyTable : tripTable,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Kisi line pe tap karo toh poori entry khulegi. Upar PDF se print / WhatsApp karo.',
                style: TextStyle(fontSize: 12, color: C.muted)),
          ),
        ],
      ),
    );
  }
}

String biltyStatusLabel(String s) => switch (s) {
      'loaded' => 'Gaadi mein',
      'delivered' => 'Delivered',
      _ => 'Godown',
    };

Future<Uint8List> registerPdf(Repo r, DateTime month, List<Trip> trips, List<Consignment> bilties, bool biltyView) async {
  final doc = pw.Document(title: 'Register ${monthYear(month)}');
  String clean(String s) => s.replaceAll('→', 'to').replaceAll('–', '-');
  final headers = biltyView
      ? ['Date', 'LR', 'Party', 'Consignee', 'Route', 'Pkgs', 'Weight', 'Freight', 'Type', 'Balance']
      : ['Date', 'LR', 'Truck', 'Route', 'Party', 'Freight', 'Hire', 'Comm.', 'Party bal.', 'Truck bal.'];
  final data = biltyView
      ? [
          for (final c in bilties)
            [
              fullDate(c.date),
              '${c.lr}',
              r.partyName(c.partyId),
              c.consignee,
              clean(c.route),
              c.packages?.toString() ?? '',
              c.weightLabel,
              num0(c.freight),
              c.payLabel,
              num0(c.balance),
            ],
          ['TOTAL', '${bilties.length}', '', '', '', '${bilties.fold(0, (s, c) => s + (c.packages ?? 0))}', '',
            num0(bilties.fold(0, (s, c) => s + c.freight)), '', num0(bilties.fold(0, (s, c) => s + c.balance))],
        ]
      : [
          for (final t in trips)
            [
              fullDate(t.date),
              '${t.lr}',
              r.truckNo(t.truckId),
              clean(t.route),
              t.isPart ? 'Part load (${t.bilties.length})' : r.partyName(t.partyId),
              num0(t.isPart ? t.biltyFreight : t.freight),
              num0(t.hire),
              num0(t.commission),
              t.isPart ? '-' : num0(t.partyBalance),
              num0(t.ownerBalance),
            ],
          ['TOTAL', '${trips.length}', '', '', '',
            num0(trips.fold(0, (s, t) => s + (t.isPart ? t.biltyFreight : t.freight))),
            num0(trips.fold(0, (s, t) => s + t.hire)),
            num0(trips.fold(0, (s, t) => s + t.commission)),
            num0(trips.fold(0, (s, t) => s + t.partyBalance)),
            num0(trips.fold(0, (s, t) => s + t.ownerBalance))],
        ];
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => [
      pw.Text((r.office?.name ?? '').toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.Text('${biltyView ? 'Bilty' : 'Truck'} register · ${monthYear(month)}', style: const pw.TextStyle(fontSize: 11)),
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      ),
    ],
  ));
  return doc.save();
}

// ---------------------------------------------------------------------------
// Phone contacts
// ---------------------------------------------------------------------------

Future<(String, String)?> pickContact(BuildContext context) async {
  try {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (context.mounted) toast(context, 'Contacts ki permission nahi mili');
      return null;
    }
    final all = await FlutterContacts.getContacts(withProperties: true);
    final list = [
      for (final c in all)
        if (c.phones.isNotEmpty) (c.displayName, normPhone(c.phones.first.number))
    ]..sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
    if (!context.mounted) return null;
    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final shown = list
                .where((c) => q.isEmpty || c.$1.toLowerCase().contains(q.toLowerCase()) || c.$2.contains(q))
                .take(200)
                .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Naam ya number'),
                      onChanged: (v) => setSt(() => q = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(shown[i].$1),
                        subtitle: Text(shown[i].$2),
                        onTap: () => Navigator.pop(ctx, shown[i]),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
    return null;
  }
}

/// Fills [name] and [phone] from a phone contact.
Widget contactButton(BuildContext context, TextEditingController name, TextEditingController phone) =>
    TextButton.icon(
      onPressed: () async {
        final c = await pickContact(context);
        if (c == null) return;
        name.text = c.$1;
        phone.text = c.$2;
      },
      icon: const Icon(Icons.contacts_outlined, size: 18),
      label: const Text('Phone contacts se chuno'),
    );

// ---------------------------------------------------------------------------
// Invite people on WhatsApp
// ---------------------------------------------------------------------------

Future<void> inviteOnWhatsApp(BuildContext context, {required String name, required String phone, required String as}) {
  final r = AppScope.read(context);
  final office = r.office?.name ?? '';
  final what = switch (as) {
    'driver' => 'apna trip, loading / delivery update aur paas ke load',
    'owner' => 'apni gaadiyon ke trips aur hisaab',
    _ => 'apna maal kahan hai (live), bilty aur hisaab',
  };
  return whatsApp(
    context,
    'Namaste $name ji,\n$office ab TransWell app pe hisaab rakhta hai. '
    'Aap is mobile number (${normPhone(phone)}) se login karke $what dekh sakte ho.\n'
    'App: $appDownloadLink',
    phone: phone,
  );
}

Future<void> showInviteList(BuildContext context) async {
  final r = AppScope.read(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.75,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Text('App bhejo (WhatsApp)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Jinko bhejoge woh apne number se login karke apna hissa dekh payenge.',
              style: TextStyle(color: C.muted)),
          const SizedBox(height: 8),
          for (final p in r.parties.where((p) => p.phone.isNotEmpty))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text('Party · ${p.phone}'),
              trailing: const Icon(Icons.send_outlined, color: C.recv),
              onTap: () => inviteOnWhatsApp(ctx, name: p.name, phone: p.phone, as: 'party'),
            ),
          for (final o in r.owners.where((o) => o.phone.isNotEmpty))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(o.name),
              subtitle: Text('Gaadi malik · ${o.phone}'),
              trailing: const Icon(Icons.send_outlined, color: C.recv),
              onTap: () => inviteOnWhatsApp(ctx, name: o.name, phone: o.phone, as: 'owner'),
            ),
          for (final t in r.trucks.where((t) => t.driverPhone.isNotEmpty))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.driver.isEmpty ? 'Driver' : t.driver),
              subtitle: Text('Driver · ${t.number} · ${t.driverPhone}'),
              trailing: const Icon(Icons.send_outlined, color: C.recv),
              onTap: () => inviteOnWhatsApp(ctx, name: t.driver, phone: t.driverPhone, as: 'driver'),
            ),
          if (r.parties.every((p) => p.phone.isEmpty) && r.owners.every((o) => o.phone.isEmpty) &&
              r.trucks.every((t) => t.driverPhone.isEmpty))
            const EmptyNote('Abhi kisi ka mobile number nahi daala. Directory mein number jodo.'),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Getting-started checklist on the home screen
// ---------------------------------------------------------------------------

class StartChecklist extends StatelessWidget {
  final VoidCallback onHide;
  const StartChecklist({super.key, required this.onHide});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final openingDone = r.parties.any((p) => p.opening != 0) || r.owners.any((o) => o.opening != 0);
    final entryDone = r.trips.isNotEmpty || r.bilties.isNotEmpty;
    Widget step(int n, String title, String sub, bool done, VoidCallback onTap) => ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: done ? C.recv : C.brandSoft,
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('$n', style: const TextStyle(color: C.brand, fontWeight: FontWeight.w700)),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? C.muted : C.ink)),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
        );
    return Panel(
      borderColor: C.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
                child: Text('Register se app pe — 3 kadam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            TextButton(onPressed: onHide, child: const Text('Chhupao')),
          ]),
          step(1, 'Purana baaki chadhao', 'Register mein jo parties / gaadi malik ka baaki hai', openingDone,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningBalanceScreen(parties: true)))),
          step(2, 'Pehli entry karo', 'Register jaisi line — party, gaadi apne aap ban jaayenge', entryDone,
              () => showEntryMenu(context)),
          step(3, 'Party / driver ko app bhejo', 'WhatsApp pe — woh khud apna hisaab aur maal dekhenge', false,
              () => showInviteList(context)),
          const Divider(height: 8, color: C.line),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen())),
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Excel / CSV hai? Ek saath import karo'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Excel / CSV import
// ---------------------------------------------------------------------------

const _templates = {
  'parties': 'name,city,phone,opening\nGupta Traders,Delhi,9811023456,14500\n',
  'owners': 'name,phone,opening\nBalwinder Singh,9814022871,6500\n',
  'trucks': 'number,type,capacity,owner,driver,driver_phone,routes\nRJ14 GB 4821,Open body,20,Balwinder Singh,Mohan,9829041177,Delhi-Jaipur; Delhi-Ajmer\n',
};

const _synonyms = {
  'parties': {
    'name': ['name', 'naam', 'party', 'party name', 'firm', 'firm name'],
    'city': ['city', 'shahar', 'sheher', 'address', 'place'],
    'phone': ['phone', 'mobile', 'mob', 'mobile no', 'phone no', 'contact', 'number'],
    'opening': ['opening', 'balance', 'baaki', 'baki', 'outstanding', 'opening balance', 'due'],
  },
  'owners': {
    'name': ['name', 'naam', 'owner', 'owner name', 'malik', 'transport'],
    'phone': ['phone', 'mobile', 'mob', 'mobile no', 'phone no', 'contact', 'number'],
    'opening': ['opening', 'balance', 'baaki', 'baki', 'outstanding', 'opening balance', 'due'],
  },
  'trucks': {
    'number': ['number', 'truck', 'truck no', 'truck number', 'vehicle', 'vehicle no', 'gadi', 'gaadi', 'gadi no'],
    'type': ['type', 'body', 'truck type'],
    'capacity': ['capacity', 'ton', 'tonnage', 'capacity ton'],
    'owner': ['owner', 'malik', 'owner name'],
    'driver': ['driver', 'driver name'],
    'driver_phone': ['driver phone', 'driver mobile', 'driver_phone', 'driver no'],
    'routes': ['route', 'routes'],
  },
};

List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',' || ch == '\t') {
      row.add(cell.toString().trim());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString().trim());
      cell.clear();
      if (row.any((c) => c.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString().trim());
  if (row.any((c) => c.isNotEmpty)) rows.add(row);
  return rows;
}

List<List<String>> parseXlsx(Uint8List bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  for (final sheet in book.tables.values) {
    final rows = <List<String>>[];
    for (final r in sheet.rows) {
      final cells = [for (final c in r) (c?.value?.toString() ?? '').trim()];
      if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
    }
    if (rows.isNotEmpty) return rows;
  }
  return [];
}

List<ImportRow> toImportRows(String kind, List<List<String>> table) {
  if (table.isEmpty) return [];
  final syn = _synonyms[kind]!;
  final header = table.first.map((h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z_ ]'), '').trim()).toList();
  final colOf = <String, int>{};
  syn.forEach((key, names) {
    for (var i = 0; i < header.length; i++) {
      if (names.contains(header[i]) && !colOf.values.contains(i)) {
        colOf[key] = i;
        break;
      }
    }
  });
  final hasHeader = colOf.isNotEmpty;
  if (!hasHeader) {
    // No recognisable header: assume the template's column order.
    final keys = syn.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      colOf[keys[i]] = i;
    }
  }
  final out = <ImportRow>[];
  for (final row in hasHeader ? table.skip(1) : table) {
    final v = <String, String>{};
    colOf.forEach((k, i) => v[k] = i < row.length ? row[i] : '');
    final r = ImportRow(v);
    final key = kind == 'trucks' ? 'number' : 'name';
    if (r[key].isEmpty) r.problem = kind == 'trucks' ? 'Truck number khaali' : 'Naam khaali';
    out.add(r);
  }
  return out;
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String kind = 'parties';
  List<ImportRow> rows = [];
  String? fileName;
  bool saving = false;

  Future<void> _pick() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'txt'],
        withData: true,
      );
      final f = res?.files.single;
      if (f == null || f.bytes == null) return;
      final bytes = f.bytes!;
      final table = f.name.toLowerCase().endsWith('.xlsx')
          ? parseXlsx(bytes)
          : parseCsv(utf8.decode(bytes, allowMalformed: true));
      setState(() {
        fileName = f.name;
        rows = toImportRows(kind, table);
      });
    } catch (e) {
      if (mounted) toast(context, 'File padh nahi paaya: ${friendlyError(e)}');
    }
  }

  Future<void> _template() async {
    final text = _templates[kind]!;
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(utf8.encode(text)), mimeType: 'text/csv', name: 'transwell-$kind.csv')],
      text: 'TransWell import template ($kind) — Excel mein khol ke bharo, CSV ya XLSX save karo.',
    );
  }

  Future<void> _import() async {
    setState(() => saving = true);
    final r = AppScope.read(context);
    try {
      final n = switch (kind) {
        'owners' => await r.importOwners(rows),
        'trucks' => await r.importTrucks(rows),
        _ => await r.importParties(rows),
      };
      if (!mounted) return;
      toast(context, '$n naye jod diye (jo pehle se the woh chhod diye)');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = rows.where((r) => r.problem == null).length;
    final cols = _synonyms[kind]!.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Excel / CSV se import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'parties', label: Text('Parties')),
              ButtonSegment(value: 'owners', label: Text('Gaadi malik')),
              ButtonSegment(value: 'trucks', label: Text('Gaadiyan')),
            ],
            selected: {kind},
            onSelectionChanged: (v) => setState(() {
              kind = v.first;
              rows = [];
              fileName = null;
            }),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Columns (pehli line mein heading):', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(cols.join(', '), style: const TextStyle(color: C.subtle)),
                const SizedBox(height: 4),
                const Text('Hindi heading bhi chalegi: naam, mobile, baaki, gaadi no, malik…',
                    style: TextStyle(fontSize: 12, color: C.muted)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _template,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Khaali template bhejo / save karo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(fileName == null ? 'File chuno (.xlsx / .csv)' : 'Doosri file chuno'),
          ),
          if (fileName != null) ...[
            const SizedBox(height: 12),
            Text('$fileName · ${rows.length} line · $ok theek', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final r in rows.take(50))
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: r.problem == null ? Colors.white : C.paySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.line),
                ),
                child: Text(
                  r.problem ?? cols.map((c) => r[c]).where((v) => v.isNotEmpty).join(' · '),
                  style: TextStyle(color: r.problem == null ? C.ink : C.pay),
                ),
              ),
            if (rows.length > 50) Text('…aur ${rows.length - 50}', style: const TextStyle(color: C.muted)),
          ],
        ],
      ),
      bottomNavigationBar: rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: saving || ok == 0 ? null : _import,
                  child: saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text('$ok line import karo'),
                ),
              ),
            ),
    );
  }
}
