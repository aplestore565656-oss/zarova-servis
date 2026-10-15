import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ana_menu.dart' show YildizArkaplan;
import 'kur.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

const bolumAdlari = <String, String>{
  'teknik': 'Teknik',
  'aksesuar': 'Aksesuar',
};

const odemeYontemleri = <String, String>{
  'nakit': 'Nakit',
  'kart': 'Kart',
  'havale': 'Havale',
};

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

String bugunTarih() => DateTime.now().toIso8601String().substring(0, 10);

String hataMetni(Object e) =>
    e is PostgrestException ? e.message : e.toString();

int _kurus(String s) => (sayi(s) * 100).round();
int _d4(String s) => (sayi(s) * 10000).round();

/// Dolar × kur = TL kuruş. Tamsayı hesabı, sunucudaki yuvarlamayla birebir aynı.
int _tlKurus(String usdYazi, String kurYazi) =>
    (_d4(usdYazi) * _d4(kurYazi) + 500000) ~/ 1000000;

String dolarYaz(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';
String kurYaz(num n) => n.toStringAsFixed(4).replaceAll('.', ',');

class AlislarSayfasi extends StatefulWidget {
  final String bolum;
  const AlislarSayfasi({super.key, this.bolum = 'teknik'});

  @override
  State<AlislarSayfasi> createState() => _AlislarSayfasiState();
}

class _AlislarSayfasiState extends State<AlislarSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';

  bool get _teknik => widget.bolum == 'teknik';

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
      final veri = await _db
          .from('purchase_summary')
          .select()
          .eq('section', widget.bolum)
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Alışlar alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    if (a.isEmpty) return _liste;
    return _liste
        .where((s) => '${s['supplier_name']}'.toLowerCase().contains(a))
        .toList();
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AlisFormu(bolum: widget.bolum)),
    );
    if (s == true) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> a) async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AlisDetaySayfasi(alis: a)),
    );
    if (s == true) _yukle();
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
    final liste = _gorunen;
    if (liste.isEmpty) {
      return const Center(
          child: Text('Alış kaydı bulunamadı.', style: TextStyle(fontSize: 18)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final a = liste[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            onTap: () => _detay(a),
            title: Text('${a['supplier_name']}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${tarih('${a['purchase_date']}')} • ${tam(a, 'item_count')} kalem'),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(para(alan(a, 'total')),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Alışta ödenen ${para(alan(a, 'paid'))}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
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
            title: Text(_teknik ? 'Parça Alışları' : 'Aksesuar Alışları'),
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
                        hintText: 'Tedarikçi ara',
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

class _Satir {
  final String urunId;
  final String ad;
  final TextEditingController adet;
  final TextEditingController fiyat;
  _Satir(this.urunId, this.ad, String fiyatYazi)
      : adet = TextEditingController(text: '1'),
        fiyat = TextEditingController(text: fiyatYazi);

  void dispose() {
    adet.dispose();
    fiyat.dispose();
  }
}

class AlisFormu extends StatefulWidget {
  final String bolum;
  final Map<String, dynamic>? tedarikci;
  const AlisFormu({super.key, required this.bolum, this.tedarikci});

  @override
  State<AlisFormu> createState() => _AlisFormuState();
}

class _AlisFormuState extends State<AlisFormu> {
  late String? _tedarikciId = widget.tedarikci?['id'];
  late String? _tedarikciAd = widget.tedarikci?['name'];
  final List<_Satir> _satirlar = [];
  final _odenen = TextEditingController();
  final _not = TextEditingController();
  final _kur = TextEditingController();
  String _yontem = 'nakit';
  DateTime _tarih = DateTime.now();
  bool _dolarMod = false;
  bool _kurYukleniyor = false;
  String? _kurNotu;
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    for (final s in _satirlar) {
      s.dispose();
    }
    _odenen.dispose();
    _not.dispose();
    _kur.dispose();
    super.dispose();
  }

  int _birimKurus(_Satir s) =>
      _dolarMod ? _tlKurus(s.fiyat.text, _kur.text) : _kurus(s.fiyat.text);

  int get _toplamKurus => _satirlar.fold<int>(
      0, (t, s) => t + tamSayi(s.adet.text) * _birimKurus(s));

  int get _toplamUsd4 => _satirlar.fold<int>(
      0, (t, s) => t + tamSayi(s.adet.text) * _d4(s.fiyat.text));

  int get _odenenKurus {
    if (!_dolarMod) return _kurus(_odenen.text);
    final p4 = _d4(_odenen.text);
    if (p4 <= 0) return 0;
    if (p4 >= _toplamUsd4) return _toplamKurus;
    final k = _tlKurus(_odenen.text, _kur.text);
    return k > _toplamKurus ? _toplamKurus : k;
  }

  bool get _fazlaOdeme => _dolarMod
      ? _d4(_odenen.text) > _toplamUsd4
      : _kurus(_odenen.text) > _toplamKurus;

  Future<void> _kurGetir() async {
    setState(() {
      _kurYukleniyor = true;
      _kurNotu = null;
    });
    final k = await dolarKuruGetir();
    if (!mounted) return;
    setState(() {
      _kurYukleniyor = false;
      if (k == null) {
        _kurNotu = 'Kur otomatik alınamadı. Kuru elle yazabilirsiniz.';
      } else {
        _kur.text = k.satis.toStringAsFixed(4).replaceAll('.', ',');
        _kurNotu =
            'Kaynak: TCMB döviz satış kuru (${k.tarih}). Kendi kurunuzu yazarak değiştirebilirsiniz.';
      }
    });
  }

  void _paraBirimi(bool dolar) {
    if (_dolarMod == dolar) return;
    setState(() {
      _dolarMod = dolar;
      for (final s in _satirlar) {
        s.fiyat.text = '';
      }
      _odenen.text = '';
      _hata = null;
    });
    if (dolar && _kur.text.trim().isEmpty) _kurGetir();
  }

  Future<void> _tedarikciSec() async {
    try {
      final veri = await _db
          .from('suppliers')
          .select('id, name, phone')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final s = await secimPenceresi(
        context,
        baslik: 'Tedarikçi seç',
        liste: List<Map<String, dynamic>>.from(veri),
        ana: 'name',
        alt: 'phone',
      );
      if (s != null) {
        setState(() {
          _tedarikciId = s['id'];
          _tedarikciAd = s['name'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Tedarikçiler alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _urunEkle() async {
    try {
      final veri = await _db
          .from('products')
          .select('id, name, brand, model, buy_price, stock')
          .eq('section', widget.bolum)
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final liste = List<Map<String, dynamic>>.from(veri)
          .map((p) => {
                ...p,
                'etiket': '${p['name']} ${p['brand']} ${p['model']}'.trim(),
                'stokYazi':
                    'Stok: ${tam(p, 'stock')} • Son alış ${para(alan(p, 'buy_price'))}',
              })
          .toList();
      final p = await secimPenceresi(
        context,
        baslik: 'Ürün seç',
        liste: liste,
        ana: 'etiket',
        alt: 'stokYazi',
      );
      if (p == null) return;
      final varMi = _satirlar.where((s) => s.urunId == p['id']);
      setState(() {
        if (varMi.isNotEmpty) {
          final s = varMi.first;
          s.adet.text = '${tamSayi(s.adet.text) + 1}';
        } else {
          final fiyatYazi = _dolarMod ? '' : sayiYaz(alan(p, 'buy_price'));
          _satirlar.add(_Satir(p['id'], '${p['etiket']}', fiyatYazi));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Ürünler alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (t != null) setState(() => _tarih = t);
  }

  Future<void> _kaydet() async {
    if (_tedarikciId == null) {
      setState(() => _hata = 'Önce tedarikçi seçin.');
      return;
    }
    if (_satirlar.isEmpty) {
      setState(() => _hata = 'En az bir ürün ekleyin.');
      return;
    }
    for (final s in _satirlar) {
      if (tamSayi(s.adet.text) <= 0) {
        setState(() => _hata = '"${s.ad}" için adet 1 veya daha fazla olmalı.');
        return;
      }
    }
    if (_dolarMod && _d4(_kur.text) <= 0) {
      setState(() => _hata = 'Dolar kurunu yazın.');
      return;
    }
    if (_fazlaOdeme) {
      setState(() => _hata = 'Ödenen tutar toplamdan fazla olamaz.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    final kalemler = _satirlar.map((s) {
      final q = tamSayi(s.adet.text);
      if (_dolarMod) {
        return {
          'product_id': s.urunId,
          'qty': q,
          'currency': 'USD',
          'unit_cost_fx': _d4(s.fiyat.text) / 10000,
          'fx_rate': _d4(_kur.text) / 10000,
          'unit_cost': _birimKurus(s) / 100,
        };
      }
      return {
        'product_id': s.urunId,
        'qty': q,
        'currency': 'TRY',
        'unit_cost': _kurus(s.fiyat.text) / 100,
      };
    }).toList();
    try {
      await _db.rpc('create_purchase', params: {
        'p_supplier': _tedarikciId,
        'p_section': widget.bolum,
        'p_date': _tarih.toIso8601String().substring(0, 10),
        'p_note': _not.text.trim(),
        'p_items': kalemler,
        'p_paid': _odenenKurus / 100,
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

  Widget _ozetSatir(String a, String b, {Color? renk}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a, style: const TextStyle(fontSize: 16)),
            Text(b,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: renk)),
          ],
        ),
      );

  Widget _satirKarti(_Satir s) {
    final q = tamSayi(s.adet.text);
    final birim = _birimKurus(s);
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
                    _satirlar.remove(s);
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
                    decoration: InputDecoration(
                        labelText:
                            _dolarMod ? 'Birim fiyat (dolar)' : 'Birim fiyat',
                        suffixText: _dolarMod ? '\$' : '₺',
                        border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(_dolarMod
                  ? 'Birim ${para(birim / 100)} • Kalem ${para(q * birim / 100)}'
                  : 'Kalem toplamı: ${para(q * birim / 100)}'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toplam = _toplamKurus / 100;
    final odenen = _odenenKurus / 100;
    final kalan = toplam - odenen;
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(widget.bolum == 'teknik'
                ? 'Yeni parça alışı'
                : 'Yeni aksesuar alışı'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: Text(_tedarikciAd ?? 'Tedarikçi seçin'),
                      trailing: const Icon(Icons.search),
                      onTap: _tedarikciSec,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text('Tarih: ${tarih(_tarih.toIso8601String())}'),
                      trailing: const Icon(Icons.edit),
                      onTap: _tarihSec,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Alış para birimi', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Türk Lirası (₺)'),
                        selected: !_dolarMod,
                        onSelected: (_) => _paraBirimi(false),
                      ),
                      ChoiceChip(
                        label: const Text('Dolar (\$)'),
                        selected: _dolarMod,
                        onSelected: (_) => _paraBirimi(true),
                      ),
                    ],
                  ),
                  if (_dolarMod) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _kur,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: '1 dolar kaç TL?',
                              suffixText: '₺',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _kurYukleniyor ? null : _kurGetir,
                            icon: _kurYukleniyor
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.refresh),
                            label: const Text('Güncel kur'),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_kurNotu ?? ''}${_kurNotu == null ? '' : '\n'}Geçmiş tarihli alış giriyorsanız o günün kurunu yazın.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text('Ürünler',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ..._satirlar.map(_satirKarti),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _urunEkle,
                      icon: const Icon(Icons.add),
                      label: const Text('Ürün ekle'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _odenen,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _dolarMod
                          ? 'Şimdi ödenen (dolar)'
                          : 'Şimdi ödenen (ödemediyseniz boş bırakın)',
                      suffixText: _dolarMod ? '\$' : '₺',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_dolarMod)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Ödeme kasadan TL karşılığıyla düşer. Ödemediyseniz boş bırakın.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.indigo.withValues(alpha: 0.25),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          if (_dolarMod)
                            _ozetSatir('Toplam (dolar)',
                                dolarYaz(_toplamUsd4 / 10000)),
                          _ozetSatir(
                              _dolarMod ? 'Toplam (TL karşılığı)' : 'Toplam',
                              para(toplam)),
                          if (_dolarMod && odenen > 0)
                            _ozetSatir('Ödenen (TL karşılığı)', para(odenen)),
                          _ozetSatir('Tedarikçiye kalan borç',
                              para(kalan < 0 ? 0 : kalan),
                              renk: kalan > 0
                                  ? Colors.redAccent
                                  : Colors.greenAccent),
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
                          : const Text('Alışı kaydet',
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

class AlisDetaySayfasi extends StatefulWidget {
  final Map<String, dynamic> alis;
  const AlisDetaySayfasi({super.key, required this.alis});

  @override
  State<AlisDetaySayfasi> createState() => _AlisDetaySayfasiState();
}

class _AlisDetaySayfasiState extends State<AlisDetaySayfasi> {
  List<Map<String, dynamic>> _kalemler = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final veri = await _db
          .from('purchase_order_items')
          .select('*, products(name, brand, model)')
          .eq('purchase_order_id', widget.alis['purchase_order_id'])
          .isFilter('removed_at', null)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _kalemler = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kalemler alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _iptal() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alış iptal edilsin mi?'),
        content: const Text(
            'Ürünler stoktan geri düşer, alışta yapılan ödeme iptal edilir ve tedarikçi borcu yeniden hesaplanır. Kayıt silinmez, saklanır.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Alışı iptal et')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await _db.rpc('void_purchase_order',
          params: {'p_id': widget.alis['purchase_order_id']});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İptal edilemedi: ${hataMetni(e)}')));
    }
  }

  Widget _kutu(String baslik, String deger) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(baslik, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Text(deger,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alis;
    final not = '${a['note'] ?? ''}'.trim();
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Alış detayı'),
            actions: [
              IconButton(
                  onPressed: _iptal,
                  icon: const Icon(Icons.delete),
                  tooltip: 'Alışı iptal et'),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping),
                      title: Text('${a['supplier_name']}'),
                      subtitle: Text(
                          '${tarih('${a['purchase_date']}')} • ${bolumAdlari['${a['section']}'] ?? ''}${not.isEmpty ? '' : '\n$not'}'),
                    ),
                  ),
                  Row(
                    children: [
                      _kutu('Toplam', para(alan(a, 'total'))),
                      _kutu('Alışta ödenen', para(alan(a, 'paid'))),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text('Ürünler',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (_yukleniyor)
                    const Center(child: CircularProgressIndicator())
                  else if (_hata != null)
                    Text(_hata!, style: const TextStyle(color: Colors.redAccent))
                  else
                    ..._kalemler.map((k) {
                      final p = k['products'] as Map<String, dynamic>?;
                      final ad =
                          '${p?['name'] ?? ''} ${p?['brand'] ?? ''} ${p?['model'] ?? ''}'
                              .trim();
                      final usd = '${k['currency']}' == 'USD';
                      return Card(
                        child: ListTile(
                          isThreeLine: usd,
                          title: Text(ad),
                          subtitle: Text(usd
                              ? '${tam(k, 'qty')} adet × ${dolarYaz(alan(k, 'unit_cost_fx'))} • kur ${kurYaz(alan(k, 'fx_rate'))}\nBirim ${para(alan(k, 'unit_cost'))}'
                              : '${tam(k, 'qty')} adet × ${para(alan(k, 'unit_cost'))}'),
                          trailing: Text(
                              para(tam(k, 'qty') * alan(k, 'unit_cost')),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Sonradan yapılan ayrı ödemeler tedarikçi sayfasında görünür.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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