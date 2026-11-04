import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart'
    show AlisDetaySayfasi, bugunTarih, hataMetni, odemeYontemleri;
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

Map<String, dynamic> _poHazirla(Map<String, dynamic> p, String tedarikci) {
  final kalemler =
      List<Map<String, dynamic>>.from(p['purchase_order_items'] ?? const [])
          .where((k) => k['removed_at'] == null)
          .toList();
  final toplam = kalemler.fold<double>(0.0, (t, k) => t + _tutar(k));
  final odenen =
      List<Map<String, dynamic>>.from(p['cash_transactions'] ?? const [])
          .where((c) => c['voided_at'] == null && c['kind'] == 'tedarikci_odeme')
          .fold<double>(0.0, (t, c) => t + alan(c, 'amount'));
  return {
    'purchase_order_id': p['id'],
    'supplier_name': tedarikci,
    'purchase_date': p['purchase_date'],
    'section': p['section'],
    'note': p['note'],
    'total': toplam,
    'paid': odenen,
    'item_count': kalemler.length,
    '_kalemler': kalemler,
  };
}

bool _odendi(Map<String, dynamic> k, Map<String, dynamic> po) {
  if (k['paid_payment_id'] != null) return true;
  final toplam = alan(po, 'total');
  return toplam > 0 && alan(po, 'paid') >= toplam - 0.005;
}

/// Tedarikçi sayfasında malzemeleri listeler, seçilenlerin ödemesini yapar.
class MalzemeListesi extends StatefulWidget {
  final Map<String, dynamic> tedarikci;
  final double bakiye;
  final VoidCallback degisti;
  const MalzemeListesi({
    super.key,
    required this.tedarikci,
    required this.bakiye,
    required this.degisti,
  });

  @override
  State<MalzemeListesi> createState() => _MalzemeListesiState();
}

class _MalzemeListesiState extends State<MalzemeListesi> {
  List<Map<String, dynamic>> _po = [];
  final Set<String> _secili = {};
  bool _yuk = true;
  String? _hata;

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
              'id, purchase_date, note, section, created_at, purchase_order_items(id, qty, unit_cost, currency, unit_cost_fx, fx_rate, paid_payment_id, removed_at, products(name, brand, model)), cash_transactions(amount, voided_at, kind)')
          .eq('supplier_id', widget.tedarikci['id'])
          .isFilter('deleted_at', null)
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false);
      final ad = '${widget.tedarikci['name']}';
      if (!mounted) return;
      setState(() {
        _po = List<Map<String, dynamic>>.from(v)
            .map((p) => _poHazirla(p, ad))
            .toList();
        _secili.clear();
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Malzemeler alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  List<Map<String, dynamic>> _kalemlerOf(Map<String, dynamic> po) =>
      po['_kalemler'] as List<Map<String, dynamic>>;

  List<Map<String, dynamic>> get _tumKalemler =>
      _po.expand((po) => _kalemlerOf(po)).toList();

  List<Map<String, dynamic>> _secilenler() {
    final s = <Map<String, dynamic>>[];
    for (final po in _po) {
      for (final k in _kalemlerOf(po)) {
        if (_secili.contains('${k['id']}')) s.add(k);
      }
    }
    return s;
  }

  double get _seciliToplam =>
      _secilenler().fold<double>(0.0, (t, k) => t + _tutar(k));

  void _bugunSec() {
    final bugun = bugunTarih();
    setState(() {
      _secili.clear();
      for (final po in _po) {
        if ('${po['purchase_date']}' != bugun) continue;
        for (final k in _kalemlerOf(po)) {
          if (!_odendi(k, po)) _secili.add('${k['id']}');
        }
      }
    });
  }

  void _hepsiniSec() {
    setState(() {
      _secili.clear();
      for (final po in _po) {
        for (final k in _kalemlerOf(po)) {
          if (!_odendi(k, po)) _secili.add('${k['id']}');
        }
      }
    });
  }

  Future<void> _ode() async {
    final secilen = _secilenler();
    if (secilen.isEmpty) return;
    final toplam = secilen.fold<double>(0.0, (t, k) => t + _tutar(k));
    if (toplam > widget.bakiye + 0.004) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Seçilenlerin toplamı (${para(toplam)}) kalan borçtan (${para(widget.bakiye)}) fazla. Daha önce genel ödeme yaptıysanız seçimi azaltın.')));
      return;
    }
    String yontem = 'nakit';
    final not = TextEditingController();
    final sonuc = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Seçilen malzemelerin ödemesi'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...secilen.map((k) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${_ad(k)} × ${tam(k, 'qty')}',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(para(_tutar(k)),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOPLAM',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(para(toplam),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: odemeYontemleri.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: yontem == e.key,
                              onSelected: (_) => setS(() => yontem = e.key),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: not,
                    decoration: const InputDecoration(
                        labelText: 'Not (isteğe bağlı)',
                        border: OutlineInputBorder()),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Ödeme kasadan çıkar ve tedarikçi borcundan düşer. Seçilmeyen alışlar borç olarak kalır.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx, {'yontem': yontem, 'not': not.text.trim()}),
              child: const Text('Öde'),
            ),
          ],
        ),
      ),
    );
    if (sonuc == null) return;
    try {
      await _db.rpc('pay_supplier_items', params: {
        'p_supplier': widget.tedarikci['id'],
        'p_items': secilen.map((k) => '${k['id']}').toList(),
        'p_method': sonuc['yontem'],
        'p_note': sonuc['not'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ödeme kaydedildi: ${para(toplam)}')));
      widget.degisti();
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ödenemedi: ${hataMetni(e)}')));
    }
  }

  Widget _odemeCubugu() {
    if (_secili.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Colors.green.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  'Seçilen ${_secili.length} kalem • ${para(_seciliToplam)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              onPressed: _ode,
              icon: const Icon(Icons.payments),
              label: const Text('Seçilenleri öde'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kalemSatiri(Map<String, dynamic> k, Map<String, dynamic> po) {
    final odendi = _odendi(k, po);
    final usd = '${k['currency']}' == 'USD';
    final fiyat = usd
        ? '${_usd(alan(k, 'unit_cost_fx'))} → ${para(alan(k, 'unit_cost'))}'
        : para(alan(k, 'unit_cost'));
    final id = '${k['id']}';
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: odendi ? true : _secili.contains(id),
      onChanged: odendi
          ? null
          : (v) => setState(() {
                if (v == true) {
                  _secili.add(id);
                } else {
                  _secili.remove(id);
                }
              }),
      title: Text(_ad(k),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text('${tam(k, 'qty')} adet × $fiyat',
          style: const TextStyle(color: Colors.white70)),
      secondary: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(para(_tutar(k)),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(odendi ? 'Ödendi' : 'Ödenmedi',
              style: TextStyle(
                  fontSize: 11,
                  color: odendi ? Colors.greenAccent : Colors.orangeAccent)),
        ],
      ),
    );
  }

  Widget _poKarti(Map<String, dynamic> po) {
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            onTap: () async {
              final s = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => AlisDetaySayfasi(alis: po)),
              );
              if (s == true) {
                widget.degisti();
                _yukle();
              }
            },
            title: Text(tarih('${po['purchase_date']}'),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            trailing: Text('Alış toplamı ${para(alan(po, 'total'))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          ..._kalemlerOf(po).map((k) => _kalemSatiri(k, po)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yuk) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hata != null) {
      return Text(_hata!, style: const TextStyle(color: Colors.redAccent));
    }
    if (_po.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: _bugunSec,
              icon: const Icon(Icons.today),
              label: const Text('Bugünkü alışları seç'),
            ),
            OutlinedButton.icon(
              onPressed: _hepsiniSec,
              icon: const Icon(Icons.select_all),
              label: const Text('Ödenmemişlerin hepsi'),
            ),
            if (_secili.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _secili.clear()),
                child: const Text('Seçimi temizle'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _odemeCubugu(),
        ..._po.map(_poKarti),
        _odemeCubugu(),
      ],
    );
  }
}