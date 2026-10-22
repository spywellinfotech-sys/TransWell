import 'package:flutter/material.dart';

import 'agent.dart';
import 'data.dart';
import 'others.dart';
import 'widgets.dart';

void main() {
  runApp(TransWellApp(state: AppState()));
}

class TransWellApp extends StatelessWidget {
  final AppState state;
  const TransWellApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'TransWell',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}

void goToRoleScreen(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const RoleScreen()),
    (_) => false,
  );
}

// ---------------------------------------------------------------------------
// Login (demo OTP)
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  bool otpSent = false;

  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    super.dispose();
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
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixText: '+91  ',
                        counterText: '',
                      ),
                    ),
                    if (otpSent) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: otp,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        style: const TextStyle(fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(labelText: 'OTP daalo', counterText: ''),
                      ),
                      const SizedBox(height: 6),
                      const Text('Demo app: koi bhi 6 ank daal do. Asli SMS OTP agle stage mein judega.',
                          style: TextStyle(fontSize: 12, color: C.muted)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 54)),
                      onPressed: () {
                        if (!otpSent) {
                          if (phone.text.trim().length < 10) {
                            soon(context, '10 ank ka mobile number daalo');
                            return;
                          }
                          setState(() => otpSent = true);
                          return;
                        }
                        if (otp.text.trim().length < 6) {
                          soon(context, '6 ank ka OTP daalo');
                          return;
                        }
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (_) => const RoleScreen()));
                      },
                      child: Text(otpSent ? 'Aage badho' : 'OTP bhejo',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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

  static const _options = [
    (Role.agent, 'Commission agent', 'Transporter / broker, office chalate hain'),
    (Role.owner, 'Truck owner', 'Meri apni gaadiyan hain'),
    (Role.driver, 'Driver', 'Main gaadi chalata hoon'),
    (Role.shipper, 'Shipper', 'Mera maal bhejna hota hai'),
  ];

  @override
  void initState() {
    super.initState();
  }

  void _start() {
    final s = AppScope.of(context);
    final r = role;
    if (r == null) {
      soon(context, 'Pehle chuno aap kaun hain');
      return;
    }
    s.setRole(r);
    late final Widget next;
    switch (r) {
      case Role.agent:
        next = const AgentShell();
      case Role.owner:
        next = const OwnerHome();
      case Role.driver:
        next = s.driverLocationOn ? const DriverHome() : const LocationPermissionScreen();
      case Role.shipper:
        next = const ShipperHome();
    }
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => next), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
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
              childAspectRatio: 1.55,
              children: [
                for (final o in _options)
                  Material(
                    color: role == o.$1 ? C.brandSoft : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: role == o.$1 ? C.brand : C.field, width: role == o.$1 ? 2 : 1),
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
            if (role == Role.agent) ...[
              const SizedBox(height: 14),
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Office ki jaankari', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                        controller: TextEditingController(text: s.officeName),
                        decoration: const InputDecoration(labelText: 'Office / firm ka naam')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: TextEditingController(text: 'Rakesh Sharma'),
                        decoration: const InputDecoration(labelText: 'Aapka naam')),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: TextEditingController(text: 'Delhi'),
                              decoration: const InputDecoration(labelText: 'City'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: TextEditingController(text: '1001'),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Bilty kis no. se'))),
                    ]),
                    const SizedBox(height: 10),
                    const TextField(decoration: InputDecoration(labelText: 'GST no. (optional)')),
                  ],
                ),
              ),
            ],
            if (role != null && role != Role.agent) ...[
              const SizedBox(height: 14),
              Panel(
                color: C.brandSoft,
                borderColor: C.brandSoft,
                child: Text(
                  switch (role!) {
                    Role.owner => 'Demo: aap Balwinder Singh ke roop mein dekhoge (2 gaadiyan).',
                    Role.driver => 'Demo: aap driver Mohan ke roop mein dekhoge (Delhi → Jaipur trip).',
                    Role.shipper => 'Demo: aap Gupta Traders ke roop mein dekhoge.',
                    Role.agent => '',
                  },
                  style: const TextStyle(color: C.brand),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 54)),
              onPressed: _start,
              child: const Text('Shuru karo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
