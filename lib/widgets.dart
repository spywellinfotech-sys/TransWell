import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'cities.dart';
import 'data.dart';
import 'services.dart';

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
      onPressed: () => callPhone(context, phone),
      icon: const Icon(Icons.call_outlined),
    );
  }
}

void soon(BuildContext context, String msg) => toast(context, msg);


class EmptyNote extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyNote(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: const TextStyle(color: C.muted, height: 1.4)),
          if (action != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Trip tile used in agent lists.
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
                  child: Text('LR ${trip.lr} · ${dm(trip.date)}', style: const TextStyle(fontSize: 12, color: C.muted)),
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
                  child: Text('${s.partyName(trip.partyId)} · ${s.truckNo(trip.truckId)}',
                      style: const TextStyle(fontSize: 13, color: C.muted), overflow: TextOverflow.ellipsis),
                ),
                Text(inr(trip.freight), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            if (showBalances && (trip.partyBalance != 0 || trip.ownerBalance != 0)) ...[
              const Divider(height: 14, color: C.line),
              Row(
                children: [
                  Expanded(
                    child: Text('Party: ${inr(trip.partyBalance)} baaki',
                        style: const TextStyle(fontSize: 12, color: C.recv, fontWeight: FontWeight.w600)),
                  ),
                  Text('Owner: ${inr(trip.ownerBalance)} baaki',
                      style: const TextStyle(fontSize: 12, color: C.pay, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Live map of a trip on OpenStreetMap: origin, destination and the truck's last point.
class TripMap extends StatelessWidget {
  final String from;
  final String to;
  final double? lat;
  final double? lng;
  final double height;
  const TripMap({super.key, required this.from, required this.to, this.lat, this.lng, this.height = 360});

  @override
  Widget build(BuildContext context) {
    final a = coordsOf(from);
    final b = coordsOf(to);
    final pts = <LatLng>[
      if (a != null) LatLng(a.$1, a.$2),
      if (b != null) LatLng(b.$1, b.$2),
      if (lat != null && lng != null) LatLng(lat!, lng!),
    ];
    if (pts.isEmpty) {
      return Container(
        height: height,
        color: const Color(0xFFE8EEE6),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text('Abhi location nahi aayi. Driver ke app se trip "Loaded" hote hi truck yahan dikhega.',
            textAlign: TextAlign.center, style: TextStyle(color: C.subtle)),
      );
    }
    final camera = pts.length == 1
        ? MapOptions(initialCenter: pts.first, initialZoom: 11)
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(pts),
              padding: const EdgeInsets.all(48),
            ),
          );
    Widget dot(Color fill, Color ring) => Container(
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: Border.all(color: ring, width: 3)),
        );
    return SizedBox(
      height: height,
      child: FlutterMap(
        options: camera,
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.spywell.transwell',
          ),
          if (a != null && b != null)
            PolylineLayer(polylines: [
              Polyline(points: [LatLng(a.$1, a.$2), LatLng(b.$1, b.$2)], color: C.brand, strokeWidth: 4),
            ]),
          MarkerLayer(markers: [
            if (a != null) Marker(point: LatLng(a.$1, a.$2), width: 20, height: 20, child: dot(Colors.white, C.brand)),
            if (b != null) Marker(point: LatLng(b.$1, b.$2), width: 22, height: 22, child: dot(C.recv, Colors.white)),
            if (lat != null && lng != null)
              Marker(
                point: LatLng(lat!, lng!),
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                      color: C.amber, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 2)),
                  child: const Icon(Icons.local_shipping, size: 20, color: C.ink),
                ),
              ),
          ]),
          const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
        ],
      ),
    );
  }
}

/// Horizontal progress strip (shipper home).
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
                  height: 6, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              left: 10,
              top: 15,
              width: x - 10,
              child: Container(
                  height: 6, decoration: BoxDecoration(color: C.brand, borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
                left: 3,
                top: 11,
                child: Container(
                    width: 14, height: 14, decoration: const BoxDecoration(color: C.brand, shape: BoxShape.circle))),
            Positioned(
                right: 3,
                top: 11,
                child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.recv, width: 3)))),
            Positioned(
              left: x - 14,
              top: 4,
              child: Container(
                width: 28,
                height: 28,
                decoration:
                    BoxDecoration(color: C.amber, shape: BoxShape.circle, border: Border.all(color: C.ink, width: 2)),
                child: const Icon(Icons.local_shipping, size: 15, color: C.ink),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Simple labelled form field used in add-sheets.
class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool number;
  final bool phone;
  final String? hint;
  const Field(this.controller, this.label, {super.key, this.number = false, this.phone = false, this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: phone ? TextInputType.phone : (number ? TextInputType.number : TextInputType.text),
      textCapitalization: (number || phone) ? TextCapitalization.none : TextCapitalization.words,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

/// Shows a bottom sheet with a form and a save button that runs [onSave].
Future<void> showFormSheet(
  BuildContext context, {
  required String title,
  required List<Widget> Function(StateSetter setSt) fields,
  required Future<String?> Function() onSave,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      var saving = false;
      return StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final f in fields(setSt)) ...[f, const SizedBox(height: 10)],
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setSt(() => saving = true);
                          try {
                            final err = await onSave();
                            if (err != null) {
                              if (ctx.mounted) toast(ctx, err);
                              setSt(() => saving = false);
                              return;
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) toast(ctx, friendlyError(e));
                            setSt(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
