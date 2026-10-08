import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ana_menu.dart' show YildizArkaplan;

final _db = Supabase.instance.client;

String csvHucre(dynamic v) {
  if (v == null) return '';
  final s = (v is Map || v is List) ? jsonEncode(v) : '$v';
  if (s.contains(';') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Excel'de Türkçe karakterler ve sütunlar düzgün açılsın diye ; ayracı ve BOM kullanır.
String csvOlustur(List<Map<String, dynamic>> satirlar, [List<String>? sutunlar]) {
  final kolonlar =
      sutunlar ?? (satirlar.isEmpty ? <String>[] : satirlar.first.keys.toList());
  final sb = StringBuffer('\uFEFF');
  sb.writeln(kolonlar.map(csvHucre).join(';'));
  for (final r in satirlar) {
    sb.writeln(kolonlar.map((k) => csvHucre(r[k])).join(';'));
  }
  return sb.toString();
}

Future<Directory> yedekKlasoru() async {
  final env = Platform.environment;
  final ev = env['USERPROFILE'] ?? env['HOME'] ?? Directory.current.path;
  final s = Platform.pathSeparator;
  final d = Directory('$ev${s}Documents${s}ZarovaYedek');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

Future<String> dosyaKaydet(String ad, String icerik) async {
  final k = await yedekKlasoru();
  final f = File('${k.path}${Platform.pathSeparator}$ad');
  await f.writeAsString(icerik);
  return f.path;
}

Future<List<Map<String, dynamic>>> hepsiniGetir(String tablo) async {
  final sonuc = <Map<String, dynamic>>[];
  var bas = 0;
  while (true) {
    final v = await _db.from(tablo).select().order('id').range(bas, bas + 999);
    final liste = List<Map<String, dynamic>>.from(v);
    sonuc.addAll(liste);
    if (liste.length < 1000) break;
    bas += 1000;
  }
  return sonuc;
}

String _iki(int n) => n.toString().padLeft(2, '0');

String _damga() {
  final d = DateTime.now();
  return '${d.year}-${_iki(d.month)}-${_iki(d.day)}_${_iki(d.hour)}${_iki(d.minute)}';
}

const _tablolar = <String, String>{
  'customers': 'Müşteriler',
  'suppliers': 'Tedarikçiler',
  'products': 'Ürünler',
  'stock_movements': 'Stok hareketleri',
  'purchase_orders': 'Alışlar',
  'purchase_order_items': 'Alış kalemleri',
  'service_orders': 'Servisler',
  'service_items': 'Servis kalemleri',
  'service_status_history': 'Durum geçmişi',
  'cash_transactions': 'Kasa hareketleri',
  'sales': 'Satışlar',
  'sale_items': 'Satış kalemleri',
};

class YedekSayfasi extends StatefulWidget {
  const YedekSayfasi({super.key});

  @override
  State<YedekSayfasi> createState() => _YedekSayfasiState();
}

class _YedekSayfasiState extends State<YedekSayfasi> {
  bool _calisiyor = false;
  String _mesaj = '';
  String? _klasor;
  String? _hata;
  int _kayit = 0;

  Future<void> _yedekAl() async {
    setState(() {
      _calisiyor = true;
      _hata = null;
      _klasor = null;
      _mesaj = 'Başlıyor...';
    });
    try {
      final ana = await yedekKlasoru();
      final s = Platform.pathSeparator;
      final k = Directory('${ana.path}${s}yedek_${_damga()}');
      await k.create(recursive: true);
      final hepsi = <String, dynamic>{};
      var adet = 0;
      for (final e in _tablolar.entries) {
        if (mounted) setState(() => _mesaj = '${e.value} alınıyor...');
        final satirlar = await hepsiniGetir(e.key);
        hepsi[e.key] = satirlar;
        adet += satirlar.length;
        await File('${k.path}$s${e.key}.csv').writeAsString(csvOlustur(satirlar));
      }
      await File('${k.path}${s}hepsi.json').writeAsString(jsonEncode({
        'olusturma': DateTime.now().toIso8601String(),
        'tablolar': hepsi,
      }));
      if (!mounted) return;
      setState(() {
        _klasor = k.path;
        _kayit = adet;
        _mesaj = 'Yedek tamamlandı.';
        _calisiyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Yedek alınamadı: ${hataMetni(e)}';
        _calisiyor = false;
      });
    }
  }

  Future<void> _klasoruAc() async {
    if (_klasor == null) return;
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [_klasor!]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.cyan,
          useMaterial3: true),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Yedekleme')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Verileriniz zaten bulutta (Supabase) saklanıyor. Bu ekran ek güvenlik içindir: tüm kayıtları bilgisayarınıza Excel (CSV) ve tek bir JSON dosyası olarak indirir. Haftada en az bir kez almanızı, dosyaları Google Drive gibi başka bir yere de kopyalamanızı öneririm.\n\nNot: Dosya kaydetme şu an Windows içindir.',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _calisiyor ? null : _yedekAl,
                      icon: _calisiyor
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 3))
                          : const Icon(Icons.cloud_download),
                      label: const Text('Yedek al',
                          style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_mesaj.isNotEmpty)
                    Text(_mesaj, style: const TextStyle(fontSize: 16)),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_hata!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  if (_klasor != null)
                    Card(
                      color: Colors.green.withValues(alpha: 0.18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_kayit kayıt yedeklendi. Klasör:',
                                style: const TextStyle(fontSize: 15)),
                            const SizedBox(height: 6),
                            SelectableText(_klasor!),
                            const SizedBox(height: 10),
                            if (Platform.isWindows)
                              OutlinedButton.icon(
                                onPressed: _klasoruAc,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Klasörü aç'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Geri yükleme: Yedek dosyaları (hepsi.json) bir sorun olursa verileri geri yüklemek için yeterlidir. Geri yükleme ekranını şimdilik eklemedim, ihtiyaç olursa birlikte yaparız. Bulut verileriniz bu arada ayrıca Supabase tarafında durur.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}