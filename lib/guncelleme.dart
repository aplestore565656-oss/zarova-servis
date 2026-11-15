import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'alislar.dart' show hataMetni;
import 'ana_menu.dart' show uygulamaSurumu;
import 'ortak.dart';

final _db = Supabase.instance.client;

String get _platform => Platform.isWindows ? 'windows' : 'android';

int _karsilastir(String a, String b) {
  List<int> p(String s) => s
      .split('.')
      .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final xi = i < x.length ? x[i] : 0;
    final yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi.compareTo(yi);
  }
  return 0;
}

Future<String> _imzaliAdres(String yol) =>
    _db.storage.from('releases').createSignedUrl(yol, 1800);

/// Uygulama açılınca çağrılır. Sadece kurulu (release) uygulamada çalışır.
Future<void> guncellemeKontrol(BuildContext context, String mevcut) async {
  if (!kReleaseMode) return;
  if (!(Platform.isWindows || Platform.isAndroid)) return;
  try {
    final r = await _db
        .from('app_release')
        .select()
        .eq('platform', _platform)
        .maybeSingle();
    if (r == null || _karsilastir('${r['version']}', mevcut) <= 0) return;
    if (!context.mounted) return;
    await guncellemeSor(context, r, mevcut);
  } catch (_) {}
}

Future<void> guncellemeSor(
    BuildContext context, Map<String, dynamic> r, String mevcut) async {
  final zorunlu = r['mandatory'] == true;
  final notlar = '${r['notes'] ?? ''}'.trim();
  final evet = await showDialog<bool>(
    context: context,
    barrierDismissible: !zorunlu,
    builder: (ctx) => PopScope(
      canPop: !zorunlu,
      child: AlertDialog(
        title: const Text('Yeni sürüm var'),
        content: Text(
            'Sürüm $mevcut → ${r['version']}${notlar.isEmpty ? '' : '\n\n$notlar'}${Platform.isWindows ? '\n\nGüncelleme birkaç saniye sürer, uygulama kapanıp yeniden açılır.' : '\n\nAPK indirilecek, indirince dokunup kurun.'}'),
        actions: [
          if (!zorunlu)
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Sonra')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Şimdi güncelle')),
        ],
      ),
    ),
  );
  if (evet != true || !context.mounted) return;
  if (Platform.isWindows) {
    await _windowsGuncelle(context, r);
  } else {
    await _androidIndir(context, r);
  }
}

Future<void> _windowsGuncelle(
    BuildContext context, Map<String, dynamic> r) async {
  if (!kReleaseMode) {
    bildir(context,
        'Geliştirme modunda (VS Code) güncelleme yapılmaz. Kurulu uygulamada deneyin.');
    return;
  }
  final ilerleme = ValueNotifier<double?>(null);
  final durum = ValueNotifier<String>('İndiriliyor...');
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Güncelleniyor'),
        content: ValueListenableBuilder<String>(
          valueListenable: durum,
          builder: (_, d, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d),
              const SizedBox(height: 12),
              ValueListenableBuilder<double?>(
                valueListenable: ilerleme,
                builder: (_, p, __) => LinearProgressIndicator(value: p),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final adres = await _imzaliAdres('${r['file_path']}');
    final istemci = http.Client();
    final yanit = await istemci.send(http.Request('GET', Uri.parse(adres)));
    if (yanit.statusCode != 200) {
      throw Exception('İndirme hatası (${yanit.statusCode}).');
    }
    final toplam = yanit.contentLength ?? 0;
    final dosya = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}ZarovaKurulum_${r['version']}.exe');
    final yaz = dosya.openWrite();
    var alinan = 0;
    await for (final parca in yanit.stream) {
      yaz.add(parca);
      alinan += parca.length;
      if (toplam > 0) ilerleme.value = alinan / toplam;
    }
    await yaz.close();
    istemci.close();
    durum.value = 'Dosya doğrulanıyor...';
    final beklenen = '${r['sha256'] ?? ''}'.trim().toLowerCase();
    if (beklenen.isNotEmpty) {
      final hash =
          (await sha256.bind(dosya.openRead()).first).toString().toLowerCase();
      if (hash != beklenen) {
        await dosya.delete();
        throw Exception('İndirilen dosya bozuk, tekrar deneyin.');
      }
    }
    durum.value = 'Kuruluyor, uygulama yeniden açılacak...';
    await Process.start(
      'cmd',
      [
        '/c', 'start', '', dosya.path,
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS',
      ],
      mode: ProcessStartMode.detached,
    );
    await Future.delayed(const Duration(seconds: 2));
    exit(0);
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) bildir(context, 'Güncellenemedi: ${hataMetni(e)}');
  }
}

Future<void> _androidIndir(
    BuildContext context, Map<String, dynamic> r) async {
  try {
    final adres = await _imzaliAdres('${r['file_path']}');
    final ok = await launchUrl(Uri.parse(adres),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) bildir(context, 'İndirme başlatılamadı.');
  } catch (e) {
    if (context.mounted) bildir(context, 'Güncellenemedi: ${hataMetni(e)}');
  }
}

class GuncellemeSayfasi extends StatefulWidget {
  const GuncellemeSayfasi({super.key});

  @override
  State<GuncellemeSayfasi> createState() => _GuncellemeSayfasiState();
}

class _GuncellemeSayfasiState extends State<GuncellemeSayfasi> {
  bool _yuk = false;
  String _mesaj = '';

  bool get _destek => Platform.isWindows || Platform.isAndroid;

  Future<void> _denetle() async {
    setState(() {
      _yuk = true;
      _mesaj = '';
    });
    try {
      final r = await _db
          .from('app_release')
          .select()
          .eq('platform', _platform)
          .maybeSingle();
      if (!mounted) return;
      if (r == null) {
        setState(() {
          _mesaj = 'Henüz yayımlanmış bir sürüm kaydı yok.';
          _yuk = false;
        });
        return;
      }
      final yeni = '${r['version']}';
      if (_karsilastir(yeni, uygulamaSurumu) <= 0) {
        setState(() {
          _mesaj = 'Güncelsiniz. Yayındaki son sürüm: $yeni';
          _yuk = false;
        });
        return;
      }
      setState(() => _yuk = false);
      await guncellemeSor(context, r, uygulamaSurumu);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mesaj = 'Denetlenemedi: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Güncelleme',
      genislik: 560,
      govde: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.system_update, size: 48),
                  const SizedBox(height: 10),
                  Text('Kurulu sürüm: $uygulamaSurumu',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Uygulama her açılışta yeni sürüm olup olmadığına kendiliğinden bakar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: (_yuk || !_destek) ? null : _denetle,
                      icon: _yuk
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: const Text('Güncellemeyi denetle'),
                    ),
                  ),
                  if (!_destek)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('Bu cihazda otomatik güncelleme desteklenmiyor.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  if (_mesaj.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(_mesaj, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}