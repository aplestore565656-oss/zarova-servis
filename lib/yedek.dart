import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
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
  'service_photos': 'Fotoğraf kayıtları',
  'cash_transactions': 'Kasa hareketleri',
  'scrap_devices': 'Hurda cihazlar',
  'scrap_parts': 'Hurda parçaları',
  'return_records': 'İadeler',
  'sales': 'Satışlar',
  'sale_items': 'Satış kalemleri',
  'business_settings': 'Ayarlar',
};

// ---------- Yedek ayarları (bu bilgisayara özel, Belgelerim\ZarovaYedek\ayar.json) ----------
Future<File> _ayarDosyasi() async {
  final k = await yedekKlasoru();
  return File('${k.path}${Platform.pathSeparator}ayar.json');
}

Future<Map<String, dynamic>> yedekAyarOku() async {
  try {
    final f = await _ayarDosyasi();
    if (!await f.exists()) return {};
    final j = jsonDecode(await f.readAsString());
    return j is Map ? Map<String, dynamic>.from(j) : {};
  } catch (_) {
    return {};
  }
}

Future<void> yedekAyarYaz(Map<String, dynamic> a) async {
  final f = await _ayarDosyasi();
  await f.writeAsString(jsonEncode(a));
}

class YedekSonuc {
  final String klasor;
  final int kayit;
  final String? ekKlasor;
  final String? ekHata;
  const YedekSonuc(this.klasor, this.kayit, this.ekKlasor, this.ekHata);
}

Future<void> _eskileriTemizle(Directory d, int tut) async {
  try {
    final dizinler = <Directory>[];
    await for (final e in d.list()) {
      if (e is Directory &&
          e.path.split(Platform.pathSeparator).last.startsWith('yedek_')) {
        dizinler.add(e);
      }
    }
    dizinler.sort((a, b) => a.path.compareTo(b.path));
    final fazla = dizinler.length - tut;
    for (var i = 0; i < fazla; i++) {
      await dizinler[i].delete(recursive: true);
    }
  } catch (_) {}
}

/// Tüm kayıtları bilgisayara yazar, ek klasör seçiliyse oraya da kopyalar.
Future<YedekSonuc> yedekCalistir({void Function(String)? ilerleme}) async {
  final ana = await yedekKlasoru();
  final s = Platform.pathSeparator;
  final ad = 'yedek_${_damga()}';
  final k = Directory('${ana.path}$s$ad');
  await k.create(recursive: true);
  final hepsi = <String, dynamic>{};
  var adet = 0;
  for (final e in _tablolar.entries) {
    ilerleme?.call('${e.value} alınıyor...');
    final satirlar = await hepsiniGetir(e.key);
    hepsi[e.key] = satirlar;
    adet += satirlar.length;
    await File('${k.path}$s${e.key}.csv').writeAsString(csvOlustur(satirlar));
  }
  await File('${k.path}${s}hepsi.json').writeAsString(jsonEncode({
    'olusturma': DateTime.now().toIso8601String(),
    'tablolar': hepsi,
  }));
  await _eskileriTemizle(ana, 30);

  String? ekYol;
  String? ekHata;
  final ayar = await yedekAyarOku();
  final ek = '${ayar['ek_klasor'] ?? ''}'.trim();
  if (ek.isNotEmpty) {
    try {
      ilerleme?.call('Google Drive / ek klasöre kopyalanıyor...');
      final hedefAna = Directory(ek);
      if (!await hedefAna.exists()) {
        throw Exception('Klasör bulunamadı: $ek');
      }
      final zAna = Directory('$ek${s}ZarovaYedek');
      final zk = Directory('${zAna.path}$s$ad');
      await zk.create(recursive: true);
      await for (final f in k.list()) {
        if (f is File) {
          final dosyaAdi = f.path.split(s).last;
          await f.copy('${zk.path}$s$dosyaAdi');
        }
      }
      await _eskileriTemizle(zAna, 30);
      ekYol = zk.path;
    } catch (e) {
      ekHata = '$e';
    }
  }
  return YedekSonuc(k.path, adet, ekYol, ekHata);
}

/// Uygulama açılınca çağrılır. Otomatik yedek açıksa ve son yedekten 20 saat geçtiyse yedek alır.
Future<void> otomatikYedekKontrol() async {
  if (!Platform.isWindows) return;
  try {
    final ayar = await yedekAyarOku();
    if (ayar['otomatik'] != true) return;
    final son = DateTime.tryParse('${ayar['son_otomatik'] ?? ''}');
    if (son != null && DateTime.now().difference(son).inHours < 20) return;
    await yedekCalistir();
    final yeni = await yedekAyarOku();
    yeni['son_otomatik'] = DateTime.now().toIso8601String();
    await yedekAyarYaz(yeni);
  } catch (_) {}
}

class YedekSayfasi extends StatefulWidget {
  const YedekSayfasi({super.key});

  @override
  State<YedekSayfasi> createState() => _YedekSayfasiState();
}

class _YedekSayfasiState extends State<YedekSayfasi> {
  bool _calisiyor = false;
  String _mesaj = '';
  YedekSonuc? _sonuc;
  String? _hata;
  Map<String, dynamic> _ayar = {};

  bool get _win => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _ayarYukle();
  }

  Future<void> _ayarYukle() async {
    if (!_win) return;
    final a = await yedekAyarOku();
    if (!mounted) return;
    setState(() => _ayar = a);
  }

  Future<void> _yedekAl() async {
    setState(() {
      _calisiyor = true;
      _hata = null;
      _sonuc = null;
      _mesaj = 'Başlıyor...';
    });
    try {
      final s = await yedekCalistir(ilerleme: (m) {
        if (mounted) setState(() => _mesaj = m);
      });
      if (!mounted) return;
      setState(() {
        _sonuc = s;
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

  Future<void> _klasoruAc(String yol) async {
    try {
      if (_win) await Process.run('explorer.exe', [yol]);
    } catch (_) {}
  }

  Future<void> _ekKlasorSec() async {
    final c = TextEditingController(text: '${_ayar['ek_klasor'] ?? ''}');
    final yol = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Google Drive / ek yedek klasörü'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Drive for desktop kuruluysa, Drive klasörünüzün içinden bir klasör seçin. Yedekler oraya da kopyalanır ve Google hesabınıza kendiliğinden yüklenir. Flash bellek veya başka bir disk de seçebilirsiniz.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: c,
                  decoration: const InputDecoration(
                      labelText: 'Klasör yolu', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await getDirectoryPath();
                    if (p != null) setS(() => c.text = p);
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Gözat'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (yol == null) return;
    if (yol.isNotEmpty && !await Directory(yol).exists()) {
      setState(() => _hata = 'Bu klasör bulunamadı: $yol');
      return;
    }
    _ayar['ek_klasor'] = yol;
    await yedekAyarYaz(_ayar);
    if (mounted) setState(() => _hata = null);
  }

  String _sonOtomatik() {
    final d = DateTime.tryParse('${_ayar['son_otomatik'] ?? ''}');
    if (d == null) return 'henüz yok';
    return '${_iki(d.day)}.${_iki(d.month)}.${d.year} ${_iki(d.hour)}:${_iki(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final ek = '${_ayar['ek_klasor'] ?? ''}'.trim();
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
                        'Verileriniz zaten bulutta (Supabase) saklanıyor. Bu ekran ek güvenlik içindir: tüm kayıtları bilgisayarınıza Excel (CSV) ve tek bir JSON dosyası olarak indirir. İsterseniz aynı kopya Google Drive klasörünüze de yazılır.\n\nNot: Yedekleme şimdilik Windows içindir.',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: (_calisiyor || !_win) ? null : _yedekAl,
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
                  if (_sonuc != null)
                    Card(
                      color: Colors.green.withValues(alpha: 0.18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_sonuc!.kayit} kayıt yedeklendi.',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text('Bilgisayar:',
                                style: TextStyle(fontSize: 13)),
                            SelectableText(_sonuc!.klasor),
                            if (_sonuc!.ekKlasor != null) ...[
                              const SizedBox(height: 8),
                              const Text('Google Drive / ek klasör:',
                                  style: TextStyle(fontSize: 13)),
                              SelectableText(_sonuc!.ekKlasor!),
                            ],
                            if (_sonuc!.ekHata != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                  'Ek klasöre kopyalanamadı: ${_sonuc!.ekHata}',
                                  style: const TextStyle(
                                      color: Colors.orangeAccent)),
                            ],
                            const SizedBox(height: 10),
                            if (_win)
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _klasoruAc(_sonuc!.klasor),
                                    icon: const Icon(Icons.folder_open),
                                    label: const Text('Klasörü aç'),
                                  ),
                                  if (_sonuc!.ekKlasor != null)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _klasoruAc(_sonuc!.ekKlasor!),
                                      icon: const Icon(Icons.cloud_done),
                                      label: const Text('Drive klasörünü aç'),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_win) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Google Drive / ek yedek klasörü',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                              ek.isEmpty ? 'Seçilmedi' : ek,
                              style: TextStyle(
                                  color: ek.isEmpty
                                      ? Colors.grey
                                      : Colors.greenAccent),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _ekKlasorSec,
                                  icon: const Icon(Icons.folder_open),
                                  label: Text(
                                      ek.isEmpty ? 'Klasör seç' : 'Değiştir'),
                                ),
                                if (ek.isNotEmpty)
                                  TextButton(
                                    onPressed: () async {
                                      _ayar['ek_klasor'] = '';
                                      await yedekAyarYaz(_ayar);
                                      if (mounted) setState(() {});
                                    },
                                    child: const Text('Kaldır'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Google hesabına yedek için bilgisayara "Google Drive for desktop" kurup hesabınızla giriş yapın (drive.google.com/drive/download). Sonra buradan Drive klasörünüzün içinden bir klasör seçin.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: SwitchListTile(
                        title: const Text('Her gün otomatik yedek al'),
                        subtitle: Text(
                            'Uygulamayı bu bilgisayarda açtığınızda, son yedekten 20 saat geçmişse arka planda yedek alınır. Son otomatik yedek: ${_sonOtomatik()}'),
                        value: _ayar['otomatik'] == true,
                        onChanged: (v) async {
                          _ayar['otomatik'] = v;
                          await yedekAyarYaz(_ayar);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Her klasörde en son 30 yedek tutulur, daha eskileri otomatik silinir. Geri yükleme ekranı şimdilik yok: bir sorun olursa hepsi.json dosyası geri yükleme için yeterlidir, birlikte yaparız.',
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