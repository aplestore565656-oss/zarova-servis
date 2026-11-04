import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri;
import 'ayarlar.dart' show isletmeAyarlari;
import 'ortak.dart' show bildir;
import 'yardimci.dart';
import 'yedek.dart' show yedekKlasoru;

String _usd(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';

String _malzeme(Map<String, dynamic> k) {
  final p = k['products'] as Map<String, dynamic>?;
  final ad = '${p?['name'] ?? ''}'.trim();
  final bm = '${p?['brand'] ?? ''} ${p?['model'] ?? ''}'.trim();
  return bm.isEmpty ? ad : '$ad ($bm)';
}

/// Tedarikçi hesap ekstresini PDF olarak kaydeder ve açar (yazdırmak için).
/// [gun] 0 ise tüm hareketler, değilse son [gun] gün listelenir (devreden bakiye hesaplanır).
Future<void> tedarikciEkstresiYazdir(
    BuildContext context, Map<String, dynamic> t, int gun) async {
  try {
    final db = Supabase.instance.client;
    final id = t['id'];
    final alislar = List<Map<String, dynamic>>.from(await db
        .from('purchase_orders')
        .select(
            'purchase_date, purchase_order_items(qty, unit_cost, currency, unit_cost_fx, fx_rate, removed_at, products(name, brand, model))')
        .eq('supplier_id', id)
        .isFilter('deleted_at', null)
        .order('purchase_date')
        .order('created_at'));
    final nakit = List<Map<String, dynamic>>.from(await db
        .from('cash_transactions')
        .select('tx_date, kind, amount, method, description')
        .eq('supplier_id', id)
        .inFilter('kind', ['tedarikci_odeme', 'tedarikci_iade'])
        .isFilter('voided_at', null)
        .order('tx_date')
        .order('created_at'));
    final iadeler = List<Map<String, dynamic>>.from(await db
        .from('return_list')
        .select()
        .eq('supplier_id', id)
        .order('return_date'));
    final hesap = await db
        .from('supplier_accounts')
        .select()
        .eq('supplier_id', id)
        .maybeSingle();
    final ayar = await isletmeAyarlari();

    final bas = gun > 0 ? DateTime.now().subtract(Duration(days: gun)) : null;
    final basYazi = bas?.toIso8601String().substring(0, 10);
    bool donemde(String d) => basYazi == null || d.compareTo(basYazi) >= 0;

    double alisOnce = 0, iadeOnce = 0, odemeOnce = 0, geriOnce = 0;
    double alis = 0, alisUsd = 0, iade = 0, odeme = 0, geri = 0;

    final alisSatirlari = <List<String>>[];
    for (final po in alislar) {
      final d = '${po['purchase_date']}';
      for (final k in List<Map<String, dynamic>>.from(
          po['purchase_order_items'] ?? const [])) {
        if (k['removed_at'] != null) continue;
        final q = tam(k, 'qty');
        final birim = alan(k, 'unit_cost');
        final tutar = q * birim;
        if (!donemde(d)) {
          alisOnce += tutar;
          continue;
        }
        alis += tutar;
        final usd = '${k['currency']}' == 'USD';
        final fx = alan(k, 'unit_cost_fx');
        if (usd) alisUsd += q * fx;
        final kur =
            alan(k, 'fx_rate').toStringAsFixed(4).replaceAll('.', ',');
        alisSatirlari.add([
          tarih(d),
          _malzeme(k),
          '$q',
          usd ? '${_usd(fx)} (kur $kur)\n${para(birim)}' : para(birim),
          usd ? '${_usd(q * fx)}\n${para(tutar)}' : para(tutar),
          '',
        ]);
      }
    }

    final iadeSatirlari = <List<String>>[];
    for (final r in iadeler) {
      final d = '${r['return_date']}';
      final tutar = alan(r, 'amount');
      final sonuc = '${r['outcome']}';
      final sayilir = sonuc == 'para' || sonuc == 'cari';
      if (!donemde(d)) {
        if (sayilir) iadeOnce += tutar;
        continue;
      }
      if (sayilir) iade += tutar;
      iadeSatirlari.add([
        tarih(d),
        '${r['product_name'] ?? ''}',
        '${tam(r, 'qty')}',
        sonuc == 'degisim'
            ? 'Değişim'
            : (sonuc == 'cari' ? 'Borçtan düşüldü' : 'Para geri geldi'),
        sonuc == 'degisim' ? '—' : para(tutar),
        '',
      ]);
    }

    final odemeSatirlari = <List<String>>[];
    for (final c in nakit) {
      final d = '${c['tx_date']}';
      final tutar = alan(c, 'amount');
      final odemeMi = c['kind'] == 'tedarikci_odeme';
      if (!donemde(d)) {
        if (odemeMi) {
          odemeOnce += tutar;
        } else {
          geriOnce += tutar;
        }
        continue;
      }
      if (odemeMi) {
        odeme += tutar;
      } else {
        geri += tutar;
      }
      odemeSatirlari.add([
        tarih(d),
        odemeMi ? 'Ödeme' : 'İade parası geldi',
        odemeYontemleri['${c['method']}'] ?? '',
        '${c['description'] ?? ''}'.trim(),
        para(tutar),
        '',
      ]);
    }

    final devreden = alisOnce - iadeOnce - odemeOnce + geriOnce;
    final kalan = devreden + alis - iade - odeme + geri;
    final uygBakiye = hesap == null ? null : alan(hesap, 'balance');

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

    pw.Widget hucre(String s,
            {bool kalin = false, pw.TextAlign hiza = pw.TextAlign.left}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(3.5),
          child: pw.Text(s,
              textAlign: hiza,
              style: pw.TextStyle(
                  fontSize: 8.6,
                  fontWeight: kalin ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

    pw.Widget tablo(List<String> baslik, List<double> w,
        List<List<String>> satirlar, Set<int> sag) {
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
        columnWidths: {
          for (var i = 0; i < w.length; i++) i: pw.FlexColumnWidth(w[i])
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            children: [
              for (var i = 0; i < baslik.length; i++)
                hucre(baslik[i],
                    kalin: true,
                    hiza: sag.contains(i) ? pw.TextAlign.right : pw.TextAlign.left)
            ],
          ),
          ...satirlar.map((r) => pw.TableRow(children: [
                for (var i = 0; i < r.length; i++)
                  hucre(r[i],
                      hiza: sag.contains(i)
                          ? pw.TextAlign.right
                          : pw.TextAlign.left)
              ])),
        ],
      );
    }

    pw.Widget baslik(String s) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
          child: pw.Text(s,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        );

    pw.Widget bos() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text('Bu dönemde kayıt yok.',
              style: const pw.TextStyle(fontSize: 9)),
        );

    pw.Widget ozetSatir(String a, String b, {bool kalin = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(a,
                  style: pw.TextStyle(
                      fontSize: kalin ? 11 : 9.5,
                      fontWeight:
                          kalin ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(b,
                  style: pw.TextStyle(
                      fontSize: kalin ? 11 : 9.5,
                      fontWeight:
                          kalin ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );

    final iletisim = [t['phone'], t['address']]
        .where((e) => '${e ?? ''}'.trim().isNotEmpty)
        .join(' • ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Sayfa ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (ctx) => [
          pw.Text('${ayar['name']}',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('TEDARİKÇİ HESAP EKSTRESİ',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Tedarikçi: ${t['name']}',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          if (iletisim.isNotEmpty)
            pw.Text(iletisim, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
              'Dönem: ${gun == 0 ? 'Tüm hareketler' : 'Son $gun gün (${tarih(basYazi)} - bugün)'}   •   Çıktı tarihi: ${tarih(DateTime.now().toIso8601String())}',
              style: const pw.TextStyle(fontSize: 9)),
          baslik('ALIŞLAR (aldığımız malzemeler)'),
          if (alisSatirlari.isEmpty)
            bos()
          else
            tablo(['Tarih', 'Malzeme (marka model)', 'Adet', 'Birim', 'Tutar', 'Kontrol'],
                [1.5, 4.3, 0.8, 2.4, 2.4, 1.0], alisSatirlari, {2, 3, 4}),
          baslik('İADELER'),
          if (iadeSatirlari.isEmpty)
            bos()
          else
            tablo(['Tarih', 'Malzeme', 'Adet', 'Sonuç', 'Tutar', 'Kontrol'],
                [1.5, 4.3, 0.8, 2.4, 2.4, 1.0], iadeSatirlari, {2, 4}),
          baslik('ÖDEMELER'),
          if (odemeSatirlari.isEmpty)
            bos()
          else
            tablo(['Tarih', 'Tür', 'Yöntem', 'Not', 'Tutar', 'Kontrol'],
                [1.5, 2.2, 1.6, 3.0, 2.4, 1.0], odemeSatirlari, {4}),
          baslik('ÖZET'),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700, width: 0.8)),
            child: pw.Column(
              children: [
                if (gun > 0) ozetSatir('Devreden bakiye', para(devreden)),
                ozetSatir('Toplam alış', para(alis)),
                if (alisUsd > 0)
                  ozetSatir('   dolar alışların toplamı', _usd(alisUsd)),
                ozetSatir('İade (borçtan düşen)', '- ${para(iade)}'),
                ozetSatir('Yapılan ödemeler', '- ${para(odeme)}'),
                if (geri > 0) ozetSatir('İade olarak gelen para', '+ ${para(geri)}'),
                pw.Divider(color: PdfColors.grey600),
                ozetSatir('KALAN BORÇ', para(kalan), kalin: true),
              ],
            ),
          ),
          if (gun == 0 &&
              uygBakiye != null &&
              (uygBakiye - kalan).abs() > 0.01)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                  'Not: Uygulamadaki güncel bakiye ${para(uygBakiye)} görünüyor.',
                  style: const pw.TextStyle(fontSize: 8.5)),
            ),
          pw.SizedBox(height: 16),
          pw.Text('TOPTANCIYLA KARŞILAŞTIRMA',
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Toptancının defterindeki bakiye: ____________________',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Text('Fark: ____________________',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
          pw.Text('Eksik / fazla kalemler:',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
          pw.Container(height: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 16),
          pw.Container(height: 0.5, color: PdfColors.grey600),
          pw.SizedBox(height: 16),
          pw.Container(height: 0.5, color: PdfColors.grey600),
        ],
      ),
    );

    final bytes = await doc.save();
    final klasor = await yedekKlasoru();
    final adGuvenli =
        '${t['name']}'.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final f = File(
        '${klasor.path}${Platform.pathSeparator}ekstre_${adGuvenli}_${DateTime.now().toIso8601String().substring(0, 10)}.pdf');
    await f.writeAsBytes(bytes);
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', f.path]);
    }
    if (context.mounted) bildir(context, 'Kaydedildi: ${f.path}');
  } catch (e) {
    if (context.mounted) bildir(context, 'Ekstre oluşturulamadı: ${hataMetni(e)}');
  }
}