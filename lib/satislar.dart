import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri, bugunTarih;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';

final _db = Supabase.instance.client;

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

int _kurus(String s) => (sayi(s) * 100).round();

List<Map<String, dynamic>> _kalemler(Map<String, dynamic> s) =>
    List<Map<String, dynamic>>.from(s['sale_items'] ?? const []);

int _tutarKurus(Map<String, dynamic> s, String k) => _kalemler(s).fold<int>(
    0, (t, i) => t + tam(i, 'qty') * (alan(i, k) * 100).round());

class SatislarSayfasi extends StatefulWidget {
  final String bolum;
  const SatislarSayfasi({super.key, this.bolum = 'aksesuar'});

  @override
  State<SatislarSayfasi> createState() => _SatislarSayfasiState();
}

class _SatislarSayfasiState extends State<SatislarSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final v = await _db
          .from('sales')
          .select('*, sale_items(qty, unit_price, unit_cost, products(name))')
          .eq('section', widget.bolum)
          .isFilter('voided_at', null)
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(v);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Satışlar alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => SatisFormu(bolum: widget.bolum)));
    if (s == true) _yukle();
  }

  Future<void> _iptal(Map<String, dynamic> s) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Satış iptal edilsin mi?'),
        content: const Text(
            'Ürünler stoğa geri döner ve kasadaki tahsilat iptal edilir. Kayıt silinmez, saklanır.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Satışı iptal et')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await _db.rpc('void_sale', params: {'p_id': s['id']});
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İptal edilemedi: ${hataMetni(e)}')));
    }
  }

  void _detay(Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Satış • ${tarih('${s['sale_date']}')}'),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: _kalemler(s).map((i) {
              final ad = (i['products'] as Map<String, dynamic>?)?['name'] ?? '';
              return ListTile(
                dense: true,
                title: Text('$ad'),
                subtitle: Text(
                    '${tam(i, 'qty')} adet × ${para(alan(i, 'unit_price'))}'),
                trailing: Text(
                    para(tam(i, 'qty') * alan(i, 'unit_price')),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _kutu(String baslik, String deger, {Color? renk}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(baslik, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Text(deger,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: renk)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icerik() {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());
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
    final bugun = bugunTarih();
    final bugunku = _liste.where((s) => '${s['sale_date']}' == bugun).toList();
    final ciro = bugunku.fold<int>(0, (t, s) => t + _tutarKurus(s, 'unit_price'));
    final maliyet =
        bugunku.fold<int>(0, (t, s) => t + _tutarKurus(s, 'unit_cost'));
    final kar = ciro - maliyet;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
      children: [
        Row(
          children: [
            _kutu('Bugünkü satış', para(ciro / 100)),
            _kutu('Bugünkü kâr', para(kar / 100),
                renk: kar >= 0 ? Colors.greenAccent : Colors.redAccent),
          ],
        ),
        if (_liste.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text('Henüz satış yok.', style: TextStyle(fontSize: 18))),
          ),
        ..._liste.map((s) {
          final kalemler = _kalemler(s);
          final ilk = kalemler.isEmpty
              ? ''
              : '${(kalemler.first['products'] as Map<String, dynamic>?)?['name'] ?? ''}';
          final ek = kalemler.length > 1 ? ' +${kalemler.length - 1} ürün' : '';
          final toplam = _tutarKurus(s, 'unit_price');
          final k = toplam - _tutarKurus(s, 'unit_cost');
          return Card(
            child: ListTile(
              onTap: () => _detay(s),
              title: Text('$ilk$ek', style: const TextStyle(fontSize: 16)),
              subtitle: Text(tarih('${s['created_at']}')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(para(toplam / 100),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Kâr ${para(k / 100)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: k >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Satışı iptal et',
                    onPressed: () => _iptal(s),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(widget.bolum == 'aksesuar'
                ? 'Aksesuar Satışı'
                : 'Satışlar'),
            actions: [
              IconButton(
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile'),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _yeni,
            icon: const Icon(Icons.add),
            label: const Text('Yeni satış'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _icerik(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sepet {
  final String urunId;
  final String ad;
  final int stok;
  final TextEditingController adet;
  final TextEditingController fiyat;
  _Sepet(this.urunId, this.ad, this.stok, double fiyatDeger)
      : adet = TextEditingController(text: '1'),
        fiyat = TextEditingController(text: sayiYaz(fiyatDeger));

  void dispose() {
    adet.dispose();
    fiyat.dispose();
  }
}

class SatisFormu extends StatefulWidget {
  final String bolum;
  const SatisFormu({super.key, required this.bolum});

  @override
  State<SatisFormu> createState() => _SatisFormuState();
}

class _SatisFormuState extends State<SatisFormu> {
  final List<_Sepet> _sepet = [];
  final _not = TextEditingController();
  String _yontem = 'nakit';
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    for (final s in _sepet) {
      s.dispose();
    }
    _not.dispose();
    super.dispose();
  }

  int get _toplamKurus => _sepet.fold<int>(
      0, (t, s) => t + tamSayi(s.adet.text) * _kurus(s.fiyat.text));

  Future<void> _urunEkle() async {
    try {
      final veri = await _db
          .from('products')
          .select('id, name, brand, model, sell_price, stock')
          .eq('section', widget.bolum)
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final liste = List<Map<String, dynamic>>.from(veri)
          .map((p) => {
                ...p,
                'etiket': '${p['name']} ${p['brand']} ${p['model']}'.trim(),
                'stokYazi':
                    'Stok: ${tam(p, 'stock')} • Satış ${para(alan(p, 'sell_price'))}',
              })
          .toList();
      final p = await secimPenceresi(context,
          baslik: 'Ürün seç', liste: liste, ana: 'etiket', alt: 'stokYazi');
      if (p == null) return;
      final var_ = _sepet.where((s) => s.urunId == p['id']);
      setState(() {
        if (var_.isNotEmpty) {
          final s = var_.first;
          s.adet.text = '${tamSayi(s.adet.text) + 1}';
        } else {
          _sepet.add(_Sepet(
              p['id'], '${p['etiket']}', tam(p, 'stock'), alan(p, 'sell_price')));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Ürünler alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _kaydet() async {
    if (_sepet.isEmpty) {
      setState(() => _hata = 'En az bir ürün ekleyin.');
      return;
    }
    for (final s in _sepet) {
      if (tamSayi(s.adet.text) <= 0) {
        setState(() => _hata = '"${s.ad}" için adet 1 veya daha fazla olmalı.');
        return;
      }
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      await _db.rpc('create_sale', params: {
        'p_section': widget.bolum,
        'p_date': bugunTarih(),
        'p_note': _not.text.trim(),
        'p_items': _sepet
            .map((s) => {
                  'product_id': s.urunId,
                  'qty': tamSayi(s.adet.text),
                  'unit_price': _kurus(s.fiyat.text) / 100,
                })
            .toList(),
        'p_method': _yontem,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kaydedilemedi: ${hataMetni(e)}';
        _kaydediliyor = false;
      });
    }
  }

  Widget _satirKarti(_Sepet s) {
    final q = tamSayi(s.adet.text);
    return Card(
      key: ObjectKey(s),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.ad,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Kaldır',
                  onPressed: () => setState(() {
                    _sepet.remove(s);
                    s.dispose();
                  }),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: s.adet,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Adet', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: s.fiyat,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'Birim fiyat',
                        suffixText: '₺',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            if (q > s.stok)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Dikkat: Stokta ${s.stok} adet var, stok eksiye düşer.',
                    style: TextStyle(color: Colors.orange.shade300)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Yeni satış'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._sepet.map(_satirKarti),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _urunEkle,
                      icon: const Icon(Icons.add),
                      label: const Text('Ürün ekle'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: odemeYontemleri.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: _yontem == e.key,
                              onSelected: (_) =>
                                  setState(() => _yontem = e.key),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.indigo.withValues(alpha: 0.25),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Toplam (peşin)',
                              style: TextStyle(fontSize: 16)),
                          Text(para(_toplamKurus / 100),
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _not,
                    decoration: const InputDecoration(
                        labelText: 'Not', border: OutlineInputBorder()),
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_hata!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 16)),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _kaydediliyor ? null : _kaydet,
                      child: _kaydediliyor
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 3))
                          : const Text('Satışı kaydet',
                              style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}