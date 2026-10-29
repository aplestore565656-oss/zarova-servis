import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yardimci.dart';

class KurBilgisi {
  final double satis;
  final String tarih; // kaynak ve zaman açıklaması
  final bool elle;
  const KurBilgisi(this.satis, this.tarih, {this.elle = false});
}

KurBilgisi? _onbellek;
DateTime? _onbellekZamani;

String _iki(int n) => n.toString().padLeft(2, '0');
String _saat(DateTime d) => '${_iki(d.hour)}:${_iki(d.minute)}';
String _gunSaat(DateTime d) => '${_iki(d.day)}.${_iki(d.month)} ${_saat(d)}';

double? _kurSayi(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  var t = '$v'.trim().replaceAll('%', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}

Future<KurBilgisi?> _elleKur() async {
  try {
    final r = await Supabase.instance.client
        .from('business_settings')
        .select('usd_rate, usd_rate_at')
        .eq('id', 1)
        .maybeSingle();
    if (r == null) return null;
    final v = _kurSayi(r['usd_rate']);
    final at = DateTime.tryParse('${r['usd_rate_at'] ?? ''}')?.toLocal();
    if (v == null || v <= 0 || at == null) return null;
    if (DateTime.now().difference(at).inHours >= 24) return null;
    return KurBilgisi(v, 'elle girildi ${_gunSaat(at)}', elle: true);
  } catch (_) {
    return null;
  }
}

Future<KurBilgisi?> _tcmbKur() async {
  try {
    final r = await http
        .get(Uri.parse('https://www.tcmb.gov.tr/kurlar/today.xml'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final govde = latin1.decode(r.bodyBytes);
    final tarih = RegExp(r'Tarih="([\d.]+)"').firstMatch(govde)?.group(1) ?? '';
    final m = RegExp(r'Kod="USD"[\s\S]*?<ForexSelling>([\d.]+)</ForexSelling>')
        .firstMatch(govde);
    final k = double.tryParse(m?.group(1) ?? '');
    if (k == null || k <= 0) return null;
    return KurBilgisi(k, 'TCMB $tarih');
  } catch (_) {
    return null;
  }
}

Future<KurBilgisi?> _canliKur(double? referans) async {
  try {
    final r = await http
        .get(Uri.parse('https://finans.truncgil.com/today.json'))
        .timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
    if (j is! Map) return null;
    final d = j['ABD DOLARI'] ?? j['USD'];
    if (d is! Map) return null;
    final v = _kurSayi(
        d['Satış'] ?? d['Satis'] ?? d['Selling'] ?? d['selling'] ?? d['sell']);
    if (v == null || v < 1 || v > 1000) return null;
    if (referans != null && (v - referans).abs() / referans > 0.10) return null;
    return KurBilgisi(v, 'canlı piyasa ${_saat(DateTime.now())}');
  } catch (_) {
    return null;
  }
}

/// Sıra: elle girilen kur (24 saat) > canlı piyasa > TCMB.
Future<KurBilgisi?> dolarKuruGetir({bool zorla = false}) async {
  final e = await _elleKur();
  if (e != null) return e;
  final z = _onbellekZamani;
  if (!zorla &&
      _onbellek != null &&
      z != null &&
      DateTime.now().difference(z).inMinutes < 3) {
    return _onbellek;
  }
  final tcmb = await _tcmbKur();
  final canli = await _canliKur(tcmb?.satis);
  final sonuc = canli ?? tcmb;
  if (sonuc != null) {
    _onbellek = sonuc;
    _onbellekZamani = DateTime.now();
  }
  return sonuc ?? _onbellek;
}

/// Kendi kurunuzu kaydeder. null verirseniz canlı kura döner.
Future<void> elleKurKaydet(double? v) async {
  await Supabase.instance.client.from('business_settings').update({
    'usd_rate': v == null ? null : (v * 10000).round() / 10000,
    'usd_rate_at': v == null ? null : DateTime.now().toUtc().toIso8601String(),
  }).eq('id', 1);
  _onbellek = null;
  _onbellekZamani = null;
}

/// Ana menünün üstündeki dolar kuru kutusu.
class KurRozeti extends StatefulWidget {
  const KurRozeti({super.key});

  @override
  State<KurRozeti> createState() => _KurRozetiState();
}

class _KurRozetiState extends State<KurRozeti> {
  KurBilgisi? _kur;
  bool _yuk = true;
  bool _hata = false;
  Timer? _zaman;

  @override
  void initState() {
    super.initState();
    _getir();
    _zaman =
        Timer.periodic(const Duration(minutes: 10), (_) => _getir(zorla: true));
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Future<void> _getir({bool zorla = false}) async {
    if (mounted) setState(() => _yuk = true);
    final k = await dolarKuruGetir(zorla: zorla);
    if (!mounted) return;
    setState(() {
      _yuk = false;
      if (k != null) {
        _kur = k;
        _hata = false;
      } else {
        _hata = true;
      }
    });
  }

  void _hesapla() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dolar hesapla'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: DolarCeviri(
                hedef: TextEditingController(), etiket: 'Dolar tutarı'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _duzenle() async {
    final c = TextEditingController(
        text: _kur == null
            ? ''
            : _kur!.satis.toStringAsFixed(4).replaceAll('.', ','));
    String? hata;
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Dolar kurunu ayarla'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yazdığınız kur tüm ekranlarda ve tüm cihazlarda 24 saat boyunca kullanılır. Canlı kura dönmek için "Canlıya dön" deyin.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '1 dolar kaç TL?',
                      suffixText: '₺',
                      border: OutlineInputBorder()),
                ),
                if (hata != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(hata!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            if (_kur?.elle == true)
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'canli'),
                  child: const Text('Canlıya dön')),
            FilledButton(
              onPressed: () {
                final v = sayi(c.text);
                if (v < 1 || v > 1000) {
                  setS(() => hata = 'Geçerli bir kur yazın.');
                  return;
                }
                Navigator.pop(ctx, 'kaydet');
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (sonuc == null) return;
    try {
      if (sonuc == 'canli') {
        await elleKurKaydet(null);
      } else {
        await elleKurKaydet(sayi(c.text));
      }
      await _getir(zorla: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _kur;
    final kurYazi =
        k == null ? '—' : k.satis.toStringAsFixed(4).replaceAll('.', ',');
    final alt = k == null
        ? (_yuk ? 'Kur alınıyor...' : 'Kur alınamadı, yenile düğmesine basın')
        : 'Kaynak: ${k.tarih}${_hata ? ' • yenilenemedi' : ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (k?.elle == true ? Colors.orangeAccent : Colors.greenAccent)
                .withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_money,
              color: k?.elle == true ? Colors.orangeAccent : Colors.greenAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dolar  $kurYazi ₺',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(alt,
                    style: TextStyle(
                        fontSize: 12,
                        color: k?.elle == true
                            ? Colors.orangeAccent
                            : Colors.grey)),
              ],
            ),
          ),
          IconButton(
            onPressed: _hesapla,
            tooltip: 'Dolar hesapla',
            icon: const Icon(Icons.calculate),
          ),
          IconButton(
            onPressed: _duzenle,
            tooltip: 'Kurumu kendim yazayım',
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: _yuk ? null : () => _getir(zorla: true),
            tooltip: 'Kuru yenile',
            icon: _yuk
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

/// Dolar yazınca TL karşılığını güncel kurla hesaplayıp [hedef] kutusuna yazar.
class DolarCeviri extends StatefulWidget {
  final TextEditingController hedef;
  final String etiket;
  const DolarCeviri(
      {super.key, required this.hedef, this.etiket = 'Dolar olarak girin'});

  @override
  State<DolarCeviri> createState() => _DolarCeviriState();
}

class _DolarCeviriState extends State<DolarCeviri> {
  final _usd = TextEditingController();
  final _kur = TextEditingController();
  bool _yukleniyor = false;
  String? _not;

  @override
  void initState() {
    super.initState();
    _kurGetir();
  }

  @override
  void dispose() {
    _usd.dispose();
    _kur.dispose();
    super.dispose();
  }

  int _d4(String s) => (sayi(s) * 10000).round();

  int get _tlKurus {
    final u = _d4(_usd.text);
    final k = _d4(_kur.text);
    if (u <= 0 || k <= 0) return 0;
    return (u * k + 500000) ~/ 1000000;
  }

  void _hesapla() {
    final k = _tlKurus;
    if (k > 0) {
      widget.hedef.text = '${k ~/ 100},${(k % 100).toString().padLeft(2, '0')}';
    }
    setState(() {});
  }

  Future<void> _kurGetir() async {
    setState(() {
      _yukleniyor = true;
      _not = null;
    });
    final k = await dolarKuruGetir();
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      if (k == null) {
        _not = 'Kur otomatik alınamadı, kuru elle yazın.';
      } else {
        _kur.text = k.satis.toStringAsFixed(4).replaceAll('.', ',');
        _not = 'Kur kaynağı (${k.tarih})';
      }
    });
    _hesapla();
  }

  @override
  Widget build(BuildContext context) {
    final tl = _tlKurus;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.etiket} (\$ → ₺ otomatik)',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usd,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _hesapla(),
                  decoration: const InputDecoration(
                      labelText: 'Dolar',
                      suffixText: '\$',
                      isDense: true,
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _kur,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _hesapla(),
                  decoration: const InputDecoration(
                      labelText: 'Kur',
                      suffixText: '₺',
                      isDense: true,
                      border: OutlineInputBorder()),
                ),
              ),
              IconButton(
                onPressed: _yukleniyor ? null : _kurGetir,
                tooltip: 'Güncel kuru getir',
                icon: _yukleniyor
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          if (tl > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('= ${para(tl / 100)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          if (_not != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_not!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}