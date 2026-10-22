import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agent.dart';
import 'bilty.dart' show confirm;
import 'data.dart';
import 'register.dart' show pickDate;
import 'services.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Google users: add a mobile number (all linking in the app is by mobile)
// ---------------------------------------------------------------------------

class PhoneScreen extends StatefulWidget {
  final Widget Function() next;
  const PhoneScreen({super.key, required this.next});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final phone = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          children: [
            Center(child: Image.asset('assets/icon/logo.png', width: 120, height: 120)),
            const SizedBox(height: 20),
            Text('Namaste${r.myName == 'Ji' ? '' : ', ${r.myName}'}!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Apna mobile number jodo. Transporter, gaadi malik, driver aur party — sab ek doosre ko isi number se '
              'pehchaante hain, isliye ye zaroori hai.',
              style: TextStyle(color: C.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: const TextStyle(fontSize: 18, letterSpacing: 1),
              decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91  ', counterText: ''),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        await r.setMyPhone(phone.text);
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => widget.next()), (_) => false);
                      } catch (e) {
                        if (context.mounted) toast(context, friendlyError(e));
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Aage badho'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Verified" badge: user applies with documents
// ---------------------------------------------------------------------------

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  late String kind;
  final business = TextEditingController();
  final person = TextEditingController();
  final city = TextEditingController();
  final gst = TextEditingController();
  final pan = TextEditingController();
  final vehicles = TextEditingController();
  final docs = <Uint8List>[];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    kind = switch (r.role) { Role.owner => 'owner', Role.driver => 'driver', Role.shipper => 'shipper', _ => 'transport' };
    business.text = r.office?.name ?? '';
    person.text = r.profile?.name ?? '';
    city.text = r.office?.city ?? '';
    gst.text = r.office?.gst ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => r.refreshMyRequests().catchError((_) {}));
  }

  @override
  void dispose() {
    for (final c in [business, person, city, gst, pan, vehicles]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addDoc() async {
    final bytes = await takePodPhoto(context);
    if (bytes != null) setState(() => docs.add(bytes));
  }

  Future<void> _submit() async {
    if (business.text.trim().isEmpty || docs.isEmpty) {
      toast(context, 'Naam aur kam se kam ek document ki photo chahiye');
      return;
    }
    setState(() => busy = true);
    final r = AppScope.read(context);
    try {
      await r.submitVerification(
        kind: kind,
        businessName: business.text.trim(),
        personName: person.text.trim(),
        city: city.text.trim(),
        gst: gst.text.trim().toUpperCase(),
        pan: pan.text.trim().toUpperCase(),
        vehicles: vehicles.text.trim().toUpperCase(),
        docs: docs,
      );
      if (mounted) {
        setState(() {
          busy = false;
          docs.clear();
        });
        toast(context, 'Request bhej di — admin check karke badge dega');
      }
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final verified = r.profile?.verified ?? false;
    final pending = r.myRequests.where((x) => x.status == 'pending').toList();
    final lastRejected = r.myRequests.where((x) => x.status == 'rejected').toList();
    final docHint = switch (kind) {
      'owner' => 'RC (har gaadi ki), Aadhaar / PAN',
      'driver' => 'Driving licence, Aadhaar',
      'shipper' => 'GST certificate ya dukaan / firm ka proof',
      _ => 'GST certificate, office ka board / visiting card, PAN',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Verified badge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            color: verified ? C.recvSoft : C.brandSoft,
            borderColor: verified ? C.recv : C.brandSoft,
            child: Row(children: [
              Icon(verified ? Icons.verified : Icons.verified_outlined, color: verified ? C.recv : C.brand, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  verified
                      ? 'Aap verified ho ✓ — load board aur search mein aapke naam ke saath badge dikhta hai.'
                      : 'Verified badge se log aap pe zyada bharosa karte hain, aur load board / search mein aap upar dikhte ho.',
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (pending.isNotEmpty)
            EmptyNote('Aapki request (${dm(pending.first.createdAt)}) admin ke paas hai. Check hone pe badge apne aap lag jaayega.')
          else if (!verified) ...[
            if (lastRejected.isNotEmpty && lastRejected.first.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  color: C.paySoft,
                  borderColor: C.pay,
                  child: Text('Pichli request wapas aayi: ${lastRejected.first.note}', style: const TextStyle(color: C.pay)),
                ),
              ),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'transport', label: Text('Transport')),
                ButtonSegment(value: 'owner', label: Text('Malik')),
                ButtonSegment(value: 'driver', label: Text('Driver')),
                ButtonSegment(value: 'shipper', label: Text('Shipper')),
              ],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
            const SizedBox(height: 12),
            Field(business, kind == 'driver' ? 'Poora naam' : 'Firm / business ka naam'),
            const SizedBox(height: 10),
            Field(person, 'Aapka naam'),
            const SizedBox(height: 10),
            Field(city, 'City'),
            if (kind != 'driver') ...[
              const SizedBox(height: 10),
              Field(gst, 'GST no. (agar hai)'),
            ],
            const SizedBox(height: 10),
            Field(pan, kind == 'driver' ? 'Licence no.' : 'PAN no.'),
            if (kind == 'owner' || kind == 'driver') ...[
              const SizedBox(height: 10),
              Field(vehicles, 'Gaadi number (comma se)'),
            ],
            const SizedBox(height: 14),
            Text('Documents ki photo: $docHint', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < docs.length; i++)
                Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(docs[i], width: 90, height: 90, fit: BoxFit.cover)),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: () => setState(() => docs.removeAt(i)),
                      child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                ]),
              InkWell(
                onTap: _addDoc,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(border: Border.all(color: C.field), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_a_photo_outlined, color: C.muted),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('Documents sirf TransWell admin dekh sakta hai, kisi aur user ko nahi dikhte.',
                style: TextStyle(fontSize: 12, color: C.muted)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Verification ke liye bhejo'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small blue tick shown next to verified names.
class VerifiedTick extends StatelessWidget {
  final double size;
  const VerifiedTick({super.key, this.size = 16});
  @override
  Widget build(BuildContext context) =>
      Tooltip(message: 'Verified', child: Icon(Icons.verified, size: size, color: const Color(0xFF1D7BE0)));
}

// ---------------------------------------------------------------------------
// Promotions shown to users
// ---------------------------------------------------------------------------

class PromoStrip extends StatefulWidget {
  final String audience; // agent | owner | driver | shipper
  const PromoStrip({super.key, required this.audience});
  @override
  State<PromoStrip> createState() => _PromoStripState();
}

class _PromoStripState extends State<PromoStrip> {
  final _seen = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => AppScope.read(context).refreshPromotions());
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final list = r.promotionsFor(widget.audience);
    if (list.isEmpty) return const SizedBox.shrink();
    for (final p in list) {
      if (_seen.add(p.id)) r.promotionHit(p, tap: false);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 150,
        child: PageView.builder(
          controller: PageController(viewportFraction: list.length > 1 ? 0.92 : 1),
          itemCount: list.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(right: list.length > 1 ? 8 : 0),
            child: PromoCard(p: list[i]),
          ),
        ),
      ),
    );
  }
}

class PromoCard extends StatelessWidget {
  final Promotion p;
  final bool preview;
  const PromoCard({super.key, required this.p, this.preview = false});

  Future<void> _open(BuildContext context) async {
    final r = AppScope.read(context);
    if (!preview) r.promotionHit(p, tap: true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (p.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(r.promoImageUrl(p.imagePath!), fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              if (p.subtitle.isNotEmpty) Text(p.subtitle, style: const TextStyle(color: C.muted)),
              if (p.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.body, style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (p.phone.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => callPhone(ctx, p.phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call karo'),
                  ),
                if (p.whatsapp.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.recv),
                    onPressed: () => whatsApp(ctx, 'Namaste, TransWell pe aapka "${p.title}" dekha.', phone: p.whatsapp),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                if (p.link.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(p.link), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Aur jaano'),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return Material(
      color: C.brand,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (p.imagePath != null)
              Image.network(r.promoImageUrl(p.imagePath!), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            if (p.imagePath != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Promoted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.ink)),
                  ),
                  const SizedBox(height: 6),
                  Text(p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  if (p.subtitle.isNotEmpty)
                    Text(p.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFE4EBF8), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Super admin panel: Promote · Verification · Users · Stats
// ---------------------------------------------------------------------------

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  String query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final r = AppScope.read(context);
    try {
      await Future.wait([r.refreshAdmin(query: query), r.refreshPromotions(), r.refreshBoard()]);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    if (!r.isAdmin) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ye hissa sirf super admin ke liye hai')));
    }
    final pending = r.adminRequests.where((x) => x.status == 'pending').length;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Super admin'),
          actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(icon: Icon(Icons.campaign_outlined), text: 'Promote'),
              Tab(icon: const Icon(Icons.verified_outlined), text: 'Verify${pending > 0 ? ' ($pending)' : ''}'),
              const Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              const Tab(icon: Icon(Icons.insights_outlined), text: 'Stats'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PromoteTab(onRefresh: _refresh),
            _VerifyTab(onRefresh: _refresh),
            _UsersTab(
              onSearch: (q) {
                query = q;
                _refresh();
              },
            ),
            _StatsTab(onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

class _PromoteTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _PromoteTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final featuredLoads = r.loads.where((l) => l.isFeatured).toList();
    final featuredTrucks = r.truckPosts.where((p) => p.isFeatured).toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionEditor())),
            icon: const Icon(Icons.add),
            label: const Text('Nayi promotion listing'),
          ),
          const SizedBox(height: 6),
          const Text('Ye cards users ki home aur load board pe "Promoted" ke saath dikhte hain.',
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SectionTitle('Promotions'),
          if (r.promotions.isEmpty) const EmptyNote('Abhi koi promotion nahi'),
          for (final p in r.promotions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PromotionEditor(edit: p))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      p.isLive
                          ? const Pill('Live', fg: C.recv, bg: C.recvSoft)
                          : Pill(p.active ? 'Schedule' : 'Band', fg: C.subtle, bg: C.grey),
                    ]),
                    if (p.subtitle.isNotEmpty) Text(p.subtitle, style: const TextStyle(color: C.muted)),
                    const SizedBox(height: 4),
                    Text(
                      '${_aud(p.audience)}${p.city.isEmpty ? '' : ' · ${p.city}'} · ${dm(p.startsOn)}'
                      '${p.endsOn == null ? ' se' : ' – ${dm(p.endsOn!)}'} · ${p.views} views · ${p.taps} taps',
                      style: const TextStyle(fontSize: 12, color: C.subtle),
                    ),
                  ],
                ),
              ),
            ),
          const SectionTitle('Load board pe featured ⭐'),
          const Text('Load board kholke kisi bhi post pe "⭐ Feature" dabao — woh sabse upar pin ho jaayegi.',
              style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoadBoardScreen())),
            icon: const Icon(Icons.view_list_outlined),
            label: const Text('Load board kholo'),
          ),
          const SizedBox(height: 8),
          for (final l in featuredLoads)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star, color: C.amber),
              title: Text('Load: ${l.from} → ${l.to}'),
              subtitle: Text('${l.posterName} · ${dm(l.featuredUntil!)} tak'),
              trailing: TextButton(onPressed: () => r.setFeatured(load: l, days: 0), child: const Text('Hatao')),
            ),
          for (final t in featuredTrucks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star, color: C.amber),
              title: Text('Gaadi: ${t.truckNo} · ${t.area}'),
              subtitle: Text('${t.posterName} · ${dm(t.featuredUntil!)} tak'),
              trailing: TextButton(onPressed: () => r.setFeatured(truck: t, days: 0), child: const Text('Hatao')),
            ),
        ],
      ),
    );
  }
}

String _aud(String a) => switch (a) {
      'agent' => 'Transporters',
      'owner' => 'Gaadi malik',
      'driver' => 'Drivers',
      'shipper' => 'Shippers',
      _ => 'Sabko',
    };

class PromotionEditor extends StatefulWidget {
  final Promotion? edit;
  const PromotionEditor({super.key, this.edit});
  @override
  State<PromotionEditor> createState() => _PromotionEditorState();
}

class _PromotionEditorState extends State<PromotionEditor> {
  final title = TextEditingController();
  final subtitle = TextEditingController();
  final body = TextEditingController();
  final phone = TextEditingController();
  final wa = TextEditingController();
  final link = TextEditingController();
  final city = TextEditingController();
  final order = TextEditingController(text: '0');
  String audience = 'all';
  DateTime starts = DateTime.now();
  DateTime? ends;
  bool active = true;
  Uint8List? image;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.edit;
    if (p != null) {
      title.text = p.title;
      subtitle.text = p.subtitle;
      body.text = p.body;
      phone.text = p.phone;
      wa.text = p.whatsapp;
      link.text = p.link;
      city.text = p.city;
      order.text = p.sortOrder.toString();
      audience = p.audience;
      starts = p.startsOn;
      ends = p.endsOn;
      active = p.active;
    }
  }

  @override
  void dispose() {
    for (final c in [title, subtitle, body, phone, wa, link, city, order]) {
      c.dispose();
    }
    super.dispose();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (title.text.trim().isEmpty) {
      toast(context, 'Heading likho');
      return;
    }
    setState(() => busy = true);
    final r = AppScope.read(context);
    try {
      await r.savePromotion({
        'title': title.text.trim(),
        'subtitle': subtitle.text.trim(),
        'body': body.text.trim(),
        'phone': normPhone(phone.text),
        'whatsapp': normPhone(wa.text),
        'link': link.text.trim(),
        'city': city.text.trim(),
        'audience': audience,
        'starts_on': _ymd(starts),
        'ends_on': ends == null ? null : _ymd(ends!),
        'active': active,
        'sort_order': int.tryParse(order.text.trim()) ?? 0,
      }, id: widget.edit?.id, image: image);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? 'Nayi promotion' : 'Promotion badlo'),
        actions: [
          if (widget.edit != null)
            IconButton(
              tooltip: 'Hatao',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(context, 'Promotion hatani hai?', 'Ye users ko dikhna band ho jaayegi.');
                if (!ok || !context.mounted) return;
                await r.deletePromotion(widget.edit!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            onTap: () async {
              final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1600);
              if (f != null) {
                final b = await f.readAsBytes();
                setState(() => image = b);
              }
            },
            child: Container(
              height: 160,
              decoration: BoxDecoration(border: Border.all(color: C.field), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: image != null
                  ? Image.memory(image!, fit: BoxFit.cover)
                  : widget.edit?.imagePath != null
                      ? Image.network(r.promoImageUrl(widget.edit!.imagePath!), fit: BoxFit.cover)
                      : const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined, color: C.muted, size: 36),
                            Text('Photo / banner (optional)', style: TextStyle(color: C.muted)),
                          ]),
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Field(title, 'Heading (jaise: Sharma Roadlines — Delhi se Jaipur roz)'),
          const SizedBox(height: 10),
          Field(subtitle, 'Chhoti line'),
          const SizedBox(height: 10),
          TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Poori jaankari')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Field(phone, 'Call number', phone: true)),
            const SizedBox(width: 10),
            Expanded(child: Field(wa, 'WhatsApp number', phone: true)),
          ]),
          const SizedBox(height: 10),
          Field(link, 'Link (optional)'),
          const SizedBox(height: 14),
          const Text('Kisko dikhe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in ['all', 'agent', 'owner', 'driver', 'shipper'])
              ChoiceChip(
                  label: Text(_aud(a)), selected: audience == a, showCheckmark: false, onSelected: (_) => setState(() => audience = a)),
          ]),
          const SizedBox(height: 10),
          Field(city, 'Sirf is city ke office ko (khaali = sab jagah)'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await pickDate(context, starts);
                  if (d != null) setState(() => starts = d);
                },
                child: Text('Shuru: ${dm(starts)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: ends ?? starts.add(const Duration(days: 30)),
                    firstDate: starts,
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  setState(() => ends = d);
                },
                child: Text(ends == null ? 'Khatam: kabhi nahi' : 'Khatam: ${dm(ends!)}'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Field(order, 'Kram (chhota = pehle)', number: true)),
            const SizedBox(width: 10),
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chalu'),
                value: active,
                onChanged: (v) => setState(() => active = v),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _save,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Save karo'),
          ),
        ],
      ),
    );
  }
}

class _VerifyTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _VerifyTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final list = [...r.adminRequests]..sort((a, b) {
        if ((a.status == 'pending') != (b.status == 'pending')) return a.status == 'pending' ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (list.isEmpty) const EmptyNote('Koi verification request nahi'),
          for (final q in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                borderColor: q.status == 'pending' ? C.amber : C.line,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _RequestScreen(req: q))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(q.businessName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      Pill(
                        switch (q.status) { 'approved' => 'Approved', 'rejected' => 'Wapas', _ => 'Pending' },
                        fg: q.status == 'approved' ? C.recv : (q.status == 'rejected' ? C.pay : C.amberInk),
                        bg: q.status == 'approved' ? C.recvSoft : (q.status == 'rejected' ? C.paySoft : C.amberSoft),
                      ),
                    ]),
                    Text('${_kind(q.kind)} · ${q.personName} · ${q.city} · ${dm(q.createdAt)} · ${q.docs.length} docs',
                        style: const TextStyle(fontSize: 13, color: C.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _kind(String k) => switch (k) { 'owner' => 'Gaadi malik', 'driver' => 'Driver', 'shipper' => 'Shipper', _ => 'Transporter' };

class _RequestScreen extends StatelessWidget {
  final VerificationRequest req;
  const _RequestScreen({required this.req});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final note = TextEditingController(text: req.note);
    return Scaffold(
      appBar: AppBar(title: Text(req.businessName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              KV('Type', _kind(req.kind)),
              KV('Naam', req.personName),
              KV('City', req.city),
              if (req.gst.isNotEmpty) KV('GST', req.gst),
              if (req.pan.isNotEmpty) KV(req.kind == 'driver' ? 'Licence' : 'PAN', req.pan),
              if (req.vehicles.isNotEmpty) KV('Gaadiyan', req.vehicles),
              KV('Bheja', dm(req.createdAt)),
            ]),
          ),
          const SectionTitle('Documents'),
          for (final d in req.docs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FutureBuilder<String>(
                future: r.kycUrl(d),
                builder: (_, snap) => snap.hasData
                    ? InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (ctx) => Dialog(child: InteractiveViewer(child: Image.network(snap.data!))),
                        ),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(snap.data!)),
                      )
                    : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              ),
            ),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (wapas bhejne pe zaroori)')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: C.pay, side: const BorderSide(color: C.pay)),
                onPressed: () async {
                  if (note.text.trim().isEmpty) {
                    toast(context, 'Wajah likho, user ko dikhegi');
                    return;
                  }
                  await r.adminReview(req.id, false, note.text.trim());
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Wapas bhejo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: C.recv),
                onPressed: () async {
                  await r.adminReview(req.id, true, note.text.trim());
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.verified),
                label: const Text('Verify karo'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final ValueChanged<String> onSearch;
  const _UsersTab({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Mobile, naam, office ya email'),
          onSubmitted: onSearch,
        ),
        const SizedBox(height: 10),
        for (final u in r.adminUsers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(u.name.isEmpty ? (u.phone.isEmpty ? u.email : u.phone) : u.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    if (u.verified) const VerifiedTick(),
                    if (u.isAdmin) const Padding(padding: EdgeInsets.only(left: 6), child: Pill('Admin', fg: C.brand, bg: C.brandSoft)),
                  ]),
                  Text(
                    [
                      if (u.phone.isNotEmpty) u.phone,
                      if (u.email.isNotEmpty) u.email,
                      if (u.role.isNotEmpty) u.role,
                      if (u.office.isNotEmpty) '${u.office} (${u.officeKind})',
                      '${u.trips} trips',
                      'joined ${dm(u.createdAt)}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: C.muted),
                  ),
                  Row(children: [
                    TextButton(
                      onPressed: () => r.adminSetFlags(u.id, verified: !u.verified, admin: u.isAdmin)
                          .catchError((Object e) => toast(context, friendlyError(e))),
                      child: Text(u.verified ? 'Badge hatao' : 'Verify karo'),
                    ),
                    TextButton(
                      onPressed: () => r.adminSetFlags(u.id, verified: u.verified, admin: !u.isAdmin)
                          .catchError((Object e) => toast(context, friendlyError(e))),
                      child: Text(u.isAdmin ? 'Admin hatao' : 'Admin banao'),
                    ),
                    if (u.phone.isNotEmpty)
                      IconButton(onPressed: () => callPhone(context, u.phone), icon: const Icon(Icons.call_outlined, size: 20)),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _StatsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    final s = r.adminStats;
    Widget tile(String k, String key, Color c) => Expanded(
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: const TextStyle(fontSize: 12, color: C.muted)),
              Text('${s[key] ?? 0}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c)),
            ]),
          ),
        );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [tile('Users', 'users', C.brand), const SizedBox(width: 10), tile('Offices', 'offices', C.brand)]),
          const SizedBox(height: 10),
          Row(children: [tile('Verified', 'verified', C.recv), const SizedBox(width: 10), tile('Pending verify', 'pending', C.amberInk)]),
          const SizedBox(height: 10),
          Row(children: [tile('Trips', 'trips', C.ink), const SizedBox(width: 10), tile('Bilty / parcel', 'bilties', C.ink)]),
          const SizedBox(height: 10),
          Row(children: [tile('Khule loads', 'open_loads', C.pay), const SizedBox(width: 10), tile('Khaali gaadiyan', 'open_trucks', C.recv)]),
        ],
      ),
    );
  }
}
