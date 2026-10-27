import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'app_state.dart';

Future<Uint8List> buildReportPdf(NoteData s, ReportView view) async {
  final doc = pw.Document();
  final logo = pw.MemoryImage((await rootBundle.load('assets/logo.png')).buffer.asUint8List());

  const yellow = PdfColor.fromInt(0xFFFFCC00);
  const red = PdfColor.fromInt(0xFFE00000);
  const green = PdfColor.fromInt(0xFF0B7A00);
  const black = PdfColors.black;

  final keys = s.dayKeys;
  final period = keys.isEmpty
      ? '-'
      : (keys.first == keys.last
          ? fmtDate(parseKey(keys.first))
          : '${fmtDate(parseKey(keys.first))} - ${fmtDate(parseKey(keys.last))}');

  final statusColor = switch (s.standing) {
    Standing.rugi => red,
    Standing.balikModal => black,
    Standing.profit => green,
  };
  final statusText = switch (s.standing) {
    Standing.rugi => 'Rugi ${rp(s.result)}',
    Standing.balikModal => 'Balik modal',
    Standing.profit => 'Profit +${rp(s.result)}',
  };

  pw.Widget kv(String k, String v, {PdfColor color = black, bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: const pw.TextStyle(fontSize: 12)),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  final headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Row(
          children: [
            pw.Image(logo, width: 60, height: 60),
            pw.SizedBox(width: 16),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Laporan Penjualan ${viewName(view)}',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('Periode: $period', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: yellow,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(statusText,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: statusColor)),
        ),
        pw.SizedBox(height: 14),
        kv('Modal usaha', rp(s.modal)),
        kv('Pendapatan', rp(s.revenue)),
        kv('Unit terjual', '${s.totalUnits}'),
        kv('Hasil', signedRp(s.result), color: statusColor, bold: true),
        pw.SizedBox(height: 20),
        pw.Text('Per produk', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Produk', 'Harga', 'Terjual', 'Subtotal'],
          data: [
            for (final p in s.products)
              [p.name, rp(p.price), '${s.productUnits(p.id)}', rp(s.productUnits(p.id) * p.price)],
          ],
          headerStyle: headerStyle,
          headerDecoration: const pw.BoxDecoration(color: yellow),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 20),
        pw.Text('Rincian ${viewName(view).toLowerCase()}',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Periode', 'Unit', 'Pendapatan', 'Status'],
          data: [
            for (final row in buildPeriods(s, view))
              [row.label, '${row.units}', rp(row.revenue), standingLabel(row.standing)],
          ],
          headerStyle: headerStyle,
          headerDecoration: const pw.BoxDecoration(color: yellow),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerLeft,
          },
        ),
        pw.SizedBox(height: 24),
        pw.Text('Dibuat dengan ModalKu pada ${fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ),
  );
  return doc.save();
}
