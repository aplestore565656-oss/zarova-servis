import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'yardimci.dart';

class KurBilgisi {
  final double satis;
  final String tarih;
  const KurBilgisi(this.satis, this.tarih);
}

KurBilgisi? _onbellek;
DateTime? _onbellekZamani;

/// TCMB günlük kur dosyasından dolar döviz satış kurunu getirir.
/// Alınamazsa null verir, o zaman kur elle yazılır.
Future<KurBilgisi?> dolarKuruGetir({bool zorla = false}) async {
  final z = _onbellekZamani;
  if (!zorla &&
      _onbellek != null &&
      z != null &&
      DateTime.now().difference(z).inMinutes < 3) {
    return _onbellek;
  }
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
    _onbellek = KurBilgisi(k, tarih);
    _onbellekZamani = DateTime.now();
    return _onbellek;
  } catch (_) {
    return null;
  }
}

/// Ana menünün üstündeki canlı dolar kuru kutusu.
class KurRozeti extends StatefulWidget {
  const KurRozeti({super.key});

  @override
  State<KurRozeti> createState() => _KurRozetiState();
}

class _KurRozetiState extends State<KurRozeti> {
  KurBilgisi? _k;
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
        _k = k;
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

  @override
  Widget build(BuildContext context) {
    final k = _k;
    final kurYazi =
        k == null ? '—' : k.satis.toStringAsFixed(4).replaceAll('.', ',');
    final alt = k == null
        ? (_yuk ? 'Kur alınıyor...' : 'Kur alınamadı, yenile düğmesine basın')
        : 'TCMB döviz satış kuru • ${k.tarih}${_hata ? ' • yenilenemedi' : ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: Colors.greenAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dolar  $kurYazi ₺',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(alt,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            onPressed: _hesapla,
            tooltip: 'Dolar hesapla',
            icon: const Icon(Icons.calculate),
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
        _not = 'TCMB döviz satış kuru (${k.tarih})';
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