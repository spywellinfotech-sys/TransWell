import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'agent.dart';
import 'config.dart';
import 'data.dart';
import 'others.dart';
import 'services.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(TransWellApp(repo: Repo()));
}

class TransWellApp extends StatelessWidget {
  final Repo repo;
  const TransWellApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      child: MaterialApp(
        title: 'TransWell',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const StartGate(),
      ),
    );
  }
}

/// Decides the first screen: login, role setup, or the role's home.
class StartGate extends StatefulWidget {
  const StartGate({super.key});
  @override
  State<StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<StartGate> {
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    final r = AppScope.read(context);
    if (!r.signedIn) {
      _replace(const LoginScreen());
      return;
    }
    try {
      await r.loadProfile();
      if (!mounted) return;
      _replace(homeFor(r));
    } catch (e) {
      setState(() => error = friendlyError(e));
    }
  }

  void _replace(Widget w) =>
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => w), (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.brand,
      body: Center(
        child: error == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: C.amber, foregroundColor: C.ink),
                      onPressed: () {
                        setState(() => error = null);
                        _go();
                      },
                      child: const Text('Phir se try karo'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

Widget homeFor(Repo r) {
  final p = r.profile;
  if (p == null || p.role == null) return const RoleScreen();
  switch (p.role!) {
    case Role.agent:
      return p.officeId == null ? const RoleScreen() : const AgentShell();
    case Role.owner:
      return const OwnerHome();
    case Role.driver:
      return const LocationPermissionScreen();
    case Role.shipper:
      return const ShipperHome();
  }
}

void goHome(BuildContext context) {
  final r = AppScope.read(context);
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => homeFor(r)), (_) => false);
}

/// Top-right menu on every home: switch role, log out.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Account',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (v) async {
        if (v == 1) {
          Navigator.of(context)
              .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RoleScreen()), (_) => false);
        } else if (v == 2) {
          await r.signOut();
          if (context.mounted) {
            Navigator.of(context)
                .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<int>(
          enabled: false,
          child: Text('${r.myName} · ${r.profile?.phone ?? ''}', style: const TextStyle(color: C.muted)),
        ),
        const PopupMenuItem<int>(value: 1, child: Text('Role badlo')),
        const PopupMenuItem<int>(value: 2, child: Text('Logout')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Login: mobile number + 6-digit PIN
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final pin = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    pin.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final p = normPhone(phone.text);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(p)) {
      toast(context, '10 ank ka sahi mobile number daalo');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin.text.trim())) {
      toast(context, 'PIN 6 ank ka hona chahiye');
      return;
    }
    setState(() => busy = true);
    final r = AppScope.read(context);
    try {
      await r.signIn(p, pin.text.trim());
      if (!mounted) return;
      goHome(context);
    } catch (e) {
      if (mounted) {
        toast(context, friendlyError(e));
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.brand,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: C.amber, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.local_shipping_outlined, size: 36, color: C.ink),
                    ),
                    const SizedBox(height: 14),
                    const Text('TransWell',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('Trip, hisaab, bilty aur load board — transport ka poora kaam ek app mein',
                        style: TextStyle(fontSize: 17, height: 1.4, color: Color(0xFFDDE1F0))),
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(fontSize: 18, letterSpacing: 1),
                      decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91  ', counterText: ''),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: pin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      style: const TextStyle(fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(labelText: '6 ank ka PIN', counterText: ''),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 6),
                    const Text('Pehli baar: jo PIN yahan rakhoge, aage wahi lagega. Kisi ko mat batana.',
                        style: TextStyle(fontSize: 12, color: C.muted)),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 54)),
                      onPressed: busy ? null : _login,
                      child: busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Aage badho', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
// Role + office setup
// ---------------------------------------------------------------------------

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});
  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  Role? role;
  bool busy = false;
  final officeName = TextEditingController();
  final person = TextEditingController();
  final city = TextEditingController();
  final startLr = TextEditingController(text: '1001');
  final gst = TextEditingController();

  static const _options = [
    (Role.agent, 'Commission agent', 'Transporter / broker, office chalate hain'),
    (Role.owner, 'Truck owner', 'Meri apni gaadiyan hain'),
    (Role.driver, 'Driver', 'Main gaadi chalata hoon'),
    (Role.shipper, 'Shipper', 'Mera maal bhejna hota hai'),
  ];

  @override
  void initState() {
    super.initState();
    final r = AppScope.read(context);
    role = r.profile?.role;
    person.text = r.profile?.name ?? '';
  }

  @override
  void dispose() {
    for (final c in [officeName, person, city, startLr, gst]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    final r = AppScope.read(context);
    final chosen = role;
    if (chosen == null) {
      toast(context, 'Pehle chuno aap kaun hain');
      return;
    }
    final hasOffice = r.profile?.officeId != null;
    if (person.text.trim().isEmpty) {
      toast(context, 'Apna naam daalo');
      return;
    }
    if (chosen == Role.agent && !hasOffice && officeName.text.trim().isEmpty) {
      toast(context, 'Office / firm ka naam daalo');
      return;
    }
    setState(() => busy = true);
    try {
      if (chosen == Role.agent) {
        if (hasOffice) {
          await r.setRole(Role.agent, person.text.trim());
        } else {
          await r.createOffice(
            name: officeName.text.trim(),
            person: person.text.trim(),
            city: city.text.trim(),
            phone: r.profile?.phone ?? '',
            gst: gst.text.trim(),
            startLr: int.tryParse(startLr.text.trim()) ?? 1001,
          );
        }
      } else {
        await r.setRole(chosen, person.text.trim());
      }
      if (mounted) goHome(context);
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
    final hasOffice = r.profile?.officeId != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          children: [
            const Text('Aap kaun hain?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Isi se app ki home screen tay hogi. Baad mein badal sakte hain.',
                style: TextStyle(fontSize: 14, color: C.muted)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                for (final o in _options)
                  Material(
                    color: role == o.$1 ? C.brandSoft : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: role == o.$1 ? C.brand : C.field, width: role == o.$1 ? 2 : 1),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => role = o.$1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(o.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(o.$3, style: const TextStyle(fontSize: 12, color: C.subtle)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Field(person, 'Aapka naam'),
            if (role == Role.agent && !hasOffice) ...[
              const SizedBox(height: 14),
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Office ki jaankari', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Field(officeName, 'Office / firm ka naam'),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Field(city, 'City')),
                      const SizedBox(width: 10),
                      Expanded(child: Field(startLr, 'Bilty kis no. se', number: true)),
                    ]),
                    const SizedBox(height: 10),
                    Field(gst, 'GST no. (optional)'),
                  ],
                ),
              ),
            ],
            if (role == Role.agent && hasOffice) ...[
              const SizedBox(height: 10),
              Text('Aapka office: ${r.office?.name ?? ''}', style: const TextStyle(color: C.brand)),
            ],
            if (role != null && role != Role.agent) ...[
              const SizedBox(height: 10),
              Panel(
                color: C.brandSoft,
                borderColor: C.brandSoft,
                child: Text(
                  'Aapke number (${r.profile?.phone ?? ''}) se jude trips apne aap dikhenge — '
                  'jab koi agent yahi number ${switch (role!) {
                    Role.owner => 'truck owner',
                    Role.driver => 'driver',
                    _ => 'party',
                  }} mein daalega.',
                  style: const TextStyle(color: C.brand),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 54)),
              onPressed: busy ? null : _start,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Shuru karo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
