import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data.dart';

class C {
  static const ink = Color(0xFF161B26);
  static const muted = Color(0xFF5B6270);
  static const subtle = Color(0xFF4A505C);
  static const paper = Color(0xFFF5F3EE);
  static const line = Color(0xFFE3E0D8);
  static const field = Color(0xFFD6D2C8);
  static const brand = Color(0xFF22306A);
  static const brandSoft = Color(0xFFE7EAF5);
  static const brandMuted = Color(0xFFC9CFE6);
  static const recv = Color(0xFF12667F);
  static const recvSoft = Color(0xFFE3F1F5);
  static const pay = Color(0xFFA9461A);
  static const paySoft = Color(0xFFFBEDE5);
  static const amber = Color(0xFFF2B53A);
  static const amberSoft = Color(0xFFFDF1D8);
  static const amberInk = Color(0xFF8A5A00);
  static const grey = Color(0xFFEDEBE6);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.brand,
    primary: C.brand,
    secondary: C.amber,
    surface: Colors.white,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: C.field),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: C.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: C.brand, width: 2)),
      labelStyle: const TextStyle(color: C.muted, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.brand,
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: C.brand),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: C.brandSoft,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? C.brand : C.muted,
          )),
    ),
  );
}

/// Amber pill button used for the main "add" action on a screen.
class AmberFab extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const AmberFab({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: C.amber,
      foregroundColor: C.ink,
      icon: const Icon(Icons.add),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? topBar;
  final Color borderColor;
  final double borderWidth;
  final Color color;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.topBar,
    this.borderColor = C.line,
    this.borderWidth = 1,
    this.color = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBar != null) Container(height: 3, color: topBar),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: body),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const Pill(this.text, {super.key, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class StatusChip extends StatelessWidget {
  final TripStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TripStatus.booked:
        return Pill(status.label, fg: C.subtle, bg: C.grey);
      case TripStatus.loaded:
        return Pill(status.label, fg: C.amberInk, bg: C.amberSoft);
      case TripStatus.inTransit:
        return Pill(status.label, fg: C.brand, bg: C.brandSoft);
      case TripStatus.delivered:
        return Pill(status.label, fg: C.pay, bg: C.paySoft);
      case TripStatus.pod:
      case TripStatus.settled:
        return Pill(status.label, fg: C.recv, bg: C.recvSoft);
    }
  }
}

class Tag extends StatelessWidget {
  final String text;
  const Tag(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Pill(text, fg: C.brand, bg: C.brandSoft);
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class KV extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  final Color? vColor;
  const KV(this.k, this.v, {super.key, this.bold = false, this.vColor});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: vColor ?? C.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(k,
                style: TextStyle(
                    fontSize: bold ? 14 : 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? C.ink : C.muted)),
          ),
          Text(v, style: style),
        ],
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  final String name;
  final String phone;
  const CallButton({super.key, required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: '$name ko call karo',
      style: IconButton.styleFrom(backgroundColor: C.recvSoft, foregroundColor: C.recv),
      onPressed: () => soon(context, 'Call: $name · $phone'),
      icon: const Icon(Icons.call_outlined),
    );
  }
}

void soon(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// Trip tile used in lists.
class TripTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final bool showBalances;
  const TripTile({super.key, required this.trip, required this.onTap, this.showBalances = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('LR ${trip.lr} · ${dm(trip.date)}',
                      style: const TextStyle(fontSize: 12, color: C.muted)),
                ),
                StatusChip(trip.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(trip.route, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('${s.party(trip.partyId).name} · ${trip.truckNo}',
                      style: const TextStyle(fontSize: 13, color: C.muted),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(inr(trip.freight),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            if (showBalances && (trip.partyBalance != 0 || trip.ownerBalance != 0)) ...[
              const Divider(height: 14, color: C.line),
              Row(
                children: [
                  Expanded(
                    child: Text('Party: ${inr(trip.partyBalance)} baaki',
                        style: const TextStyle(
                            fontSize: 12, color: C.recv, fontWeight: FontWeight.w600)),
                  ),
                  Text('Owner: ${inr(trip.ownerBalance)} baaki',
                      style: const TextStyle(
                          fontSize: 12, color: C.pay, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple drawn route map: origin, destination, truck at [progress].
class RouteMap extends StatelessWidget {
  final String from;
  final String to;
  final double progress;
  final String near;
  final double height;
  const RouteMap({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    required this.near,
    this.height = 360,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _RouteMapPainter(from, to, progress, near)),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final String from;
  final String to;
  final double progress;
  final String near;
  _RouteMapPainter(this.from, this.to, this.progress, this.near);

  Offset _bez(Offset a, Offset c1, Offset c2, Offset b, double t) {
    final mt = 1 - t;
    return a * (mt * mt * mt) + c1 * (3 * mt * mt * t) + c2 * (3 * mt * t * t) + b * (t * t * t);
  }

  void _label(Canvas canvas, String text, Offset at, {bool bold = true, Color bg = Colors.transparent}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: C.ink, fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200);
    if (bg != Colors.transparent) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 10, at.dy - 6, tp.width + 20, tp.height + 12), const Radius.circular(14));
      canvas.drawRRect(r, Paint()..color = bg);
    }
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE8EEE6));
    final road = Paint()
      ..color = const Color(0xFFD3DCCF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.28)
          ..quadraticBezierTo(w * 0.3, h * 0.33, w * 0.5, h * 0.21)
          ..quadraticBezierTo(w * 0.75, h * 0.1, w, h * 0.16),
        road);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.08, h)
          ..quadraticBezierTo(w * 0.25, h * 0.75, w * 0.15, h * 0.55)
          ..quadraticBezierTo(w * 0.05, h * 0.3, w * 0.3, 0),
        road);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.62, h)
          ..quadraticBezierTo(w * 0.78, h * 0.7, w, h * 0.65),
        road);

    final a = Offset(w * 0.77, h * 0.1);
    final b = Offset(w * 0.24, h * 0.88);
    final c1 = Offset(w * 0.68, h * 0.4);
    final c2 = Offset(w * 0.4, h * 0.6);
    final p = progress.clamp(0.0, 1.0);

    final done = Path()..moveTo(a.dx, a.dy);
    const steps = 60;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      if (t > p) break;
      final pt = _bez(a, c1, c2, b, t);
      done.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(
        done,
        Paint()
          ..color = C.brand
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6);
    // dashed remainder
    final dash = Paint()
      ..color = C.brand
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    for (var i = 0; i < steps; i += 2) {
      final t0 = i / steps, t1 = math.min(1.0, (i + 0.6) / steps);
      if (t0 < p) continue;
      canvas.drawLine(_bez(a, c1, c2, b, t0), _bez(a, c1, c2, b, t1), dash);
    }

    canvas.drawCircle(a, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
        a,
        9,
        Paint()
          ..color = C.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _label(canvas, from, Offset(a.dx + 16, a.dy - 9));
    canvas.drawCircle(b, 10, Paint()..color = C.recv);
    canvas.drawCircle(
        b,
        10,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    _label(canvas, to, Offset(b.dx + 18, b.dy - 9));

    final truck = _bez(a, c1, c2, b, p);
    canvas.drawCircle(truck, 26, Paint()..color = const Color(0x4DF2B53A));
    canvas.drawCircle(truck, 16, Paint()..color = C.amber);
    canvas.drawCircle(
        truck,
        16,
        Paint()
          ..color = C.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.local_shipping.codePoint),
        style: TextStyle(fontSize: 18, fontFamily: Icons.local_shipping.fontFamily, color: C.ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, truck - Offset(icon.width / 2, icon.height / 2));
    if (near.isNotEmpty && p > 0 && p < 1) {
      _label(canvas, near, Offset(truck.dx + 32, truck.dy - 10), bold: false, bg: Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) =>
      old.progress != progress || old.from != from || old.to != to || old.near != near;
}

/// Horizontal progress strip used on the shipper home.
class TripProgressBar extends StatelessWidget {
  final double progress;
  const TripProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final x = 10 + (w - 20) * progress.clamp(0.0, 1.0);
      return SizedBox(
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 10,
              right: 10,
              top: 15,
              child: Container(
                  height: 6,
                  decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              left: 10,
              top: 15,
              width: x - 10,
              child: Container(
                  height: 6,
                  decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
                left: 3,
                top: 11,
                child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(color: C.brand, shape: BoxShape.circle))),
            Positioned(
                right: 3,
                top: 11,
                child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.recv, width: 3)))),
            Positioned(
              left: x - 14,
              top: 4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: C.amber, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 2)),
                child: const Icon(Icons.local_shipping, size: 15, color: C.ink),
              ),
            ),
          ],
        ),
      );
    });
  }
}
