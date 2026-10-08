import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'ayarlar.dart' show isletmeAyarlari;
import 'ortak.dart';
import 'yardimci.dart';
import 'yedek.dart' show yedekKlasoru;

String _zaman(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  String i(int n) => n.toString().padLeft(2, '0');
  return '${i(d.day)}.${i(d.month)}.${d.year} ${i(d.hour)}:${i(d.minute)}';
}

/// Servis formunu PDF olarak Belgelerim\ZarovaYedek içine kaydeder ve açar.
/// Açılan PDF görüntüleyiciden yazdırabilirsiniz.
Future<void> servisFormuYazdir(
  BuildContext context,
  Map<String, dynamic> o,
  List<Map<String, dynamic>> kalemler,
  Map<String, dynamic>? ozet,
) async {
  try {
    final ayar = await isletmeAyarlari();
    pw.ThemeData tema;
    try {
      final r = File(r'C:\Windows\Fonts\arial.ttf').readAsBytesSync();
      final b = File(r'C:\Windows\Fonts\arialbd.ttf').readAsBytesSync();
      tema = pw.ThemeData.withFont(
        base: pw.Font.ttf(ByteData.sublistView(r)),
        bold: pw.Font.ttf(ByteData.sublistView(b)),
      );
    } catch (_) {
      tema = pw.ThemeData.base();
    }
    final doc = pw.Document(theme: tema);
    final m = o['customers'] as Map<String, dynamic>?;

    pw.Widget satir(String a, String b) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 120,
                child: pw.Text(a,
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(
                  child: pw.Text(b, style: const pw.TextStyle(fontSize: 10))),
            ],
          ),
        );

    pw.Widget hucre(String t, {bool kalin = false}) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      kalin ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    final tablo = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [
          hucre('Parça / işlem', kalin: true),
          hucre('Adet', kalin: true),
          hucre('Birim', kalin: true),
          hucre('Tutar', kalin: true),
        ]),
        ...kalemler.map((k) => pw.TableRow(children: [
              hucre('${k['description']}'),
              hucre('${tam(k, 'qty')}'),
              hucre(para(alan(k, 'unit_price'))),
              hucre(para(tam(k, 'qty') * alan(k, 'unit_price'))),
            ])),
        pw.TableRow(children: [
          hucre('İşçilik'),
          hucre('1'),
          hucre(para(alan(o, 'labor'))),
          hucre(para(alan(o, 'labor'))),
        ]),
      ],
    );

    final toplam = ozet == null ? 0.0 : alan(ozet, 'total');
    final odenen = ozet == null ? 0.0 : alan(ozet, 'paid');
    final kalan = ozet == null ? 0.0 : alan(ozet, 'remaining');
    final garanti = tam(o, 'warranty_days');
    final iletisim = [ayar['phone'], ayar['address']]
        .where((e) => '${e ?? ''}'.trim().isNotEmpty)
        .join(' • ');

    pw.Widget imza(String baslik) => pw.Expanded(
          child: pw.Column(children: [
            pw.Text(baslik, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 36),
            pw.Container(height: 0.5, color: PdfColors.grey700),
          ]),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text('${ayar['name']}',
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (iletisim.isNotEmpty)
            pw.Text(iletisim, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
          pw.Text('SERVİS FORMU  •  ${o['order_no']}',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Tarih: ${_zaman('${o['received_at']}')}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          satir('Müşteri', '${m?['full_name'] ?? ''}'),
          satir('Telefon', '${m?['phone'] ?? ''}'),
          satir('Cihaz', '${o['brand']} ${o['model']}'.trim()),
          satir('IMEI', '${o['imei'] ?? ''}'),
          satir('Cihazın durumu', '${o['device_condition'] ?? ''}'),
          satir('Bildirilen arıza', '${o['problem'] ?? ''}'),
          satir('Yapılacak işlem', '${o['planned_work'] ?? ''}'),
          satir('Yapılan işlem', '${o['work_done'] ?? ''}'),
          satir('Teslim notları', '${o['device_notes'] ?? ''}'),
          satir('Usta', '${o['technician'] ?? ''}'),
          pw.SizedBox(height: 10),
          tablo,
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Toplam: ${para(toplam)}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('Ödenen: ${para(odenen)}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Kalan: ${para(kalan < 0 ? 0 : kalan)}',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          if (garanti > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text('Garanti süresi: $garanti gün (tesliminden itibaren)',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
          if ('${ayar['form_note'] ?? ''}'.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text('${ayar['form_note']}',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          pw.SizedBox(height: 24),
          pw.Row(children: [
            imza('Teslim eden (müşteri)'),
            pw.SizedBox(width: 40),
            imza('Teslim alan'),
          ]),
        ],
      ),
    );

    final bytes = await doc.save();
    final k = await yedekKlasoru();
    final f = File(
        '${k.path}${Platform.pathSeparator}servis_formu_${o['order_no']}.pdf');
    await f.writeAsBytes(bytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', f.path]);
    }
    if (context.mounted) bildir(context, 'Kaydedildi: ${f.path}');
  } catch (e) {
    if (context.mounted) bildir(context, 'Form oluşturulamadı: $e');
  }
}