import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show AlisDetaySayfasi, AlisFormu, hataMetni;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';

final _db = Supabase.instance.client;

String _usd(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';

String _ad(Map<String, dynamic> k) {
  final p = k['products'] as Map<String, dynamic>?;
  final ad = '${p?['name'] ?? ''}'.trim();
  final bm = '${p?['brand'] ?? ''} ${p?['model'] ?? ''}'.trim();
  return bm.isEmpty ? ad : '$ad ($bm)';
}

double _tutar(Map<String, dynamic> k) => tam(k, 'qty') * alan(k, 'unit_cost');

bool _odendi(Map<String, dynamic> k, double toplam, double odenen) {
  if (k['paid_payment_id'] != null) return true;
  return toplam > 0 && odenen >= toplam - 0.005;
}

class AlisListesi extends StatefulWidget {
  const AlisListesi({super.key});

  @override
  State<AlisListesi> createState() => _AlisListesiState();
}

class _AlisListesiState extends State<AlisListesi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yuk = true;
  String? _hata;
  String _arama = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yuk = true;
      _hata = null;
    });
    try {
      final v = await _db
          .from('purchase_orders')
          .select(
              'id, purchase_date, note, section, created_at, suppliers(name), purchase_order_items(id, qty, unit_cost, currency, unit_cost_fx, paid_payment_id, removed_at, products(name, brand, model)), cash_transactions(amount, voided_at, kind)')
          .eq('section', 'teknik')
          .isFilter('deleted_at', null)
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(300);
      final liste = List<Map<String, dynamic>>.from(v).map((p) {
        final kalemler =
            List<Map<String, dynamic>>.from(p['purchase_order_items'] ?? const [])
                .where((k) => k['removed_at'] == null)
                .toList();
        final toplam = kalemler.fold<double>(0.0, (t, k) => t + _tutar(k));
        final odenen =
            List<Map<String, dynamic>>.from(p['cash_transactions'] ?? const [])
                .where((c) =>
                    c['voided_at'] == null && c['kind'] == 'tedarikci_odeme')
                .fold<double>(0.0, (t, c) => t + alan(c, 'amount'));
        return <String, dynamic>{
          'purchase_order_id': p['id'],
          'supplier_name':
              '${(p['suppliers'] as Map<String, dynamic>?)?['name'] ?? ''}',
          'purchase_date': p['purchase_date'],
          'section': p['section'],
          'note': p['note'],
          'total': toplam,
          'paid': odenen,
          'item_count': kalemler.length,
          '_kalemler': kalemler,
        };
      }).toList();
      if (!mounted) return;
      setState(() {
        _liste = liste;
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Alışlar alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    if (a.isEmpty) return _liste;
    return _liste.where((po) {
      final kalemler = po['_kalemler'] as List<Map<String, dynamic>>;
      final metin =
          '${po['supplier_name']} ${kalemler.map(_ad).join(' ')}'.toLowerCase();
      return metin.contains(a);
    }).toList();
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AlisFormu(bolum: 'teknik')),
    );
    if (s == true) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> po) async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AlisDetaySayfasi(alis: po)),
    );
    if (s == true) _yukle();
  }

  Widget _kart(Map<String, dynamic> po) {
    final kalemler = po['_kalemler'] as List<Map<String, dynamic>>;
    final toplam = alan(po, 'total');
    final odenen = alan(po, 'paid');
    final odenmis =
        kalemler.where((k) => _odendi(k, toplam, odenen)).toList();
    final odenmemisToplam = kalemler
        .where((k) => !_odendi(k, toplam, odenen))
        .fold<double>(0.0, (t, k) => t + _tutar(k));
    final usdToplam = kalemler
        .where((k) => '${k['currency']}' == 'USD')
        .fold<double>(0.0, (t, k) => t + tam(k, 'qty') * alan(k, 'unit_cost_fx'));
    String durum;
    Color renk;
    if (kalemler.isNotEmpty && odenmis.length == kalemler.length) {
      durum = 'Ödendi';
      renk = Colors.greenAccent;
    } else if (odenmis.isEmpty) {
      durum = 'Ödenmedi';
      renk = Colors.redAccent;
    } else {
      durum = 'Kısmen ödendi';
      renk = Colors.orangeAccent;
    }
    final satirlar = kalemler.map((k) {
      final usd = '${k['currency']}' == 'USD';
      final fiyat = usd
          ? '${_usd(alan(k, 'unit_cost_fx'))} → ${para(alan(k, 'unit_cost'))}'
          : para(alan(k, 'unit_cost'));
      final isaret = _odendi(k, toplam, odenen) ? '✓' : '•';
      return '$isaret ${_ad(k)} × ${tam(k, 'qty')} • $fiyat';
    }).toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => _detay(po),
        isThreeLine: satirlar.length > 1,
        title: Text('${tarih('${po['purchase_date']}')}  •  ${po['supplier_name']}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(satirlar.isEmpty ? 'Kalem yok' : satirlar.join('\n'),
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(para(toplam),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (usdToplam > 0)
              Text(_usd(usdToplam),
                  style:
                      const TextStyle(fontSize: 12, color: Colors.greenAccent)),
            Text(durum,
                style: TextStyle(
                    color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
            if (odenmemisToplam > 0.004 && odenmis.isNotEmpty)
              Text('Kalan ${para(odenmemisToplam)}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
          ],
        ),
      ),
    );
  }

  Widget _icerik() {
    if (_yuk) return const Center(child: CircularProgressIndicator());
    if (_hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _yukle, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }
    final liste = _gorunen;
    if (liste.isEmpty) {
      return const Center(
          child: Text('Alış kaydı bulunamadı.', style: TextStyle(fontSize: 18)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) => _kart(liste[i]),
    );
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
            title: const Text('Parça Alışları'),
            actions: [
              IconButton(
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile'),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _yeni,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Yeni alış'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: TextField(
                      onChanged: (v) => setState(() => _arama = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Tedarikçi veya malzeme ara',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(child: _icerik()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}