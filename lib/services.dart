import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<void> callPhone(BuildContext context, String phone) async {
  final p = normPhone(phone);
  if (p.length < 10) {
    toast(context, 'Number nahi hai');
    return;
  }
  final ok = await launchUrl(Uri.parse('tel:+91$p'));
  if (!ok && context.mounted) toast(context, 'Call nahi lag paaya');
}

/// Opens WhatsApp with a ready message. Without a phone it opens the contact picker.
Future<void> whatsApp(BuildContext context, String text, {String? phone}) async {
  final p = phone == null ? '' : normPhone(phone);
  final uri = Uri.parse('https://wa.me/${p.length == 10 ? '91$p' : ''}?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'WhatsApp nahi khula');
}

Future<void> openMapsAt(double lat, double lng) async {
  await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication);
}

Future<Uint8List?> takePodPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera se photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery se chuno'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(source: source, imageQuality: 60, maxWidth: 1600);
  if (file == null) return null;
  return file.readAsBytes();
}

Future<void> showPodPhoto(BuildContext context, String path) async {
  final repo = AppScope.read(context);
  try {
    final url = await repo.podUrl(path);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Band karo')),
          ],
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

// ---------------------------------------------------------------------------
// PDFs (built-in PDF font has no Hindi / ₹ glyphs, so text stays English + "Rs.")
// ---------------------------------------------------------------------------

String rs(int v) => 'Rs. ${num0(v)}';

class BiltyData {
  final String officeName;
  final String officePhone;
  final String officeCity;
  final String gst;
  final int lr;
  final DateTime date;
  final String consignor;
  final String consignorCity;
  final String consignee;
  final String from;
  final String to;
  final String truckNo;
  final String driver;
  final String material;
  final double weight;
  final int freight;
  final int advance;
  BiltyData({
    required this.officeName,
    required this.officePhone,
    required this.officeCity,
    required this.gst,
    required this.lr,
    required this.date,
    required this.consignor,
    required this.consignorCity,
    required this.consignee,
    required this.from,
    required this.to,
    required this.truckNo,
    required this.driver,
    required this.material,
    required this.weight,
    required this.freight,
    required this.advance,
  });
}

Future<Uint8List> biltyPdf(BiltyData b) async {
  final doc = pw.Document(title: 'LR ${b.lr}');
  pw.Widget cell(String k, String v) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(k, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ]);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 2))),
          child: pw.Column(children: [
            pw.Text(b.officeName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Transport commission agent · ${b.officeCity}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Ph ${b.officePhone}${b.gst.isEmpty ? '' : ' · GSTIN ${b.gst}'}',
                style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(
              child: pw.Text('LORRY RECEIPT (BILTY)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('LR No. ${b.lr}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(fullDate(b.date), style: const pw.TextStyle(fontSize: 9)),
          ]),
        ]),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500),
          children: [
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: cell('CONSIGNOR', '${b.consignor}, ${b.consignorCity}')),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: cell('CONSIGNEE', b.consignee)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(children: [pw.Expanded(child: cell('FROM', b.from)), pw.Expanded(child: cell('TO', b.to))]),
        pw.SizedBox(height: 6),
        pw.Row(children: [pw.Expanded(child: cell('TRUCK NO.', b.truckNo)), pw.Expanded(child: cell('DRIVER', b.driver))]),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500),
          columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('MATERIAL', style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('WEIGHT', style: const pw.TextStyle(fontSize: 8))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('FREIGHT', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
            ]),
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(b.material)),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(ton(b.weight))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(6), child: pw.Text(rs(b.freight), textAlign: pw.TextAlign.right)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 170,
            child: pw.Column(children: [
              _kv('Freight', rs(b.freight)),
              _kv('Advance', rs(b.advance)),
              pw.Divider(height: 6),
              _kv('Balance (to pay)', rs(b.freight - b.advance), bold: true),
            ]),
          ),
        ),
        pw.Spacer(),
        pw.Row(children: [
          pw.Expanded(child: _sign('Driver signature')),
          pw.SizedBox(width: 24),
          pw.Expanded(child: _sign('For ${b.officeName}')),
        ]),
      ],
    ),
  ));
  return doc.save();
}

pw.Widget _kv(String k, String v, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(k, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null))),
        pw.Text(v, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : null)),
      ]),
    );

pw.Widget _sign(String label) => pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.8))),
      child: pw.Text(label, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9)),
    );

Future<Uint8List> ledgerPdf({
  required String officeName,
  required String officePhone,
  required String partyName,
  required String partyCity,
  required List<LedgerEntry> entries,
  required int balance,
}) async {
  final doc = pw.Document(title: 'Statement $partyName');
  final rows = entries.reversed.toList();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (ctx) => [
      pw.Text(officeName.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('Ph $officePhone', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 12),
      pw.Text('Account statement: $partyName, $partyCity',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text('As of ${fullDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Detail', 'LR / note', 'Debit', 'Credit', 'Balance'],
        data: [
          for (final e in rows)
            [
              fullDate(e.date),
              e.title.replaceAll('→', 'to'),
              e.sub,
              e.amount > 0 ? num0(e.amount) : '',
              e.amount < 0 ? num0(-e.amount) : '',
              num0(e.balance),
            ]
        ],
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignments: {3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight},
      ),
      pw.SizedBox(height: 12),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Balance due: ${rs(balance)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  ));
  return doc.save();
}

Future<void> sharePdf(BuildContext context, Future<Uint8List> Function() build, String filename) async {
  try {
    final bytes = await build();
    await Printing.sharePdf(bytes: bytes, filename: filename);
  } catch (e) {
    if (context.mounted) toast(context, 'PDF nahi ban paaya: ${friendlyError(e)}');
  }
}
