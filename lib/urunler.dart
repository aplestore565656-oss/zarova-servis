import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, bugunTarih;
import 'ana_menu.dart' show YildizArkaplan;
import 'kur.dart' show dolarKuruGetir;
import 'tedarikciler.dart' show tedarikciFormuAc;
import 'yardimci.dart';

final _db = Supabase.instance.client;

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

int _d4(String s) => (sayi(s) * 10000).round();
int _kurus(String s) => (sayi(s) * 100).round();
int _tlKurus(String usd, String kur) =>
    (_d4(usd) * _d4(kur) + 500000) ~/ 1000000;
String _usd(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';

Widget _ozetSatir(String a, String b, {bool kalin = false, Color? renk}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(a,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: kalin ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(b,
              style: TextStyle(
                  fontSize: kalin ? 16 : 14,
                  fontWeight: kalin ? FontWeight.bold : FontWeight.w500,
                  color: renk)),
        ],
      ),
    );

const _teknikKategoriler = [
  'Ekran', 'Batarya', 'Kasa', 'Ara film', 'Şarj soketi', 'Diğer'
];
const _aksesuarKategoriler = [
  'Kılıf', 'Cam / koruyucu', 'Şarj aleti', 'Kablo', 'Kulaklık', 'Diğer'
];

class UrunlerSayfasi extends StatefulWidget {
  final String bolum;
  const UrunlerSayfasi({super.key, required this.bolum});

  @override
  State<UrunlerSayfasi> createState() => _UrunlerSayfasiState();
}

class _UrunlerSayfasiState extends State<UrunlerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';
  bool _azalan = false;

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
          .from('products')
          .select()
          .eq('section', widget.bolum)
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Ürünler alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  bool _azaliyor(Map<String, dynamic> p) =>
      p['one_off'] != true && tam(p, 'stock') <= tam(p, 'min_stock');

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    return _liste.where((p) {
      if (p['one_off'] == true && tam(p, 'stock') <= 0) return false;
      if (_azalan && !_azaliyor(p)) return false;
      if (a.isEmpty) return true;
      final metin = [
        p['name'], p['brand'], p['model'], p['part_category'],
        p['compatible'], p['location'], p['serial_no'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return metin.contains(a);
    }).toList();
  }

  List<Map<String, dynamic>> get _stoklu =>
      _liste.where((p) => tam(p, 'stock') > 0).toList();

  int get _adetToplam => _stoklu.fold(0, (t, p) => t + tam(p, 'stock'));

  double get _usdToplam => _stoklu.fold(0.0, (t, p) {
        final u = alan(p, 'buy_price_usd');
        return t + (u > 0 ? tam(p, 'stock') * u : 0);
      });

  double get _tlDolarsiz => _stoklu.fold(0.0, (t, p) {
        final u = alan(p, 'buy_price_usd');
        return t + (u > 0 ? 0 : tam(p, 'stock') * alan(p, 'buy_price'));
      });

  double get _tlToplam => _stoklu.fold(
      0.0, (t, p) => t + tam(p, 'stock') * alan(p, 'buy_price'));

  Future<void> _ac([Map<String, dynamic>? urun]) async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => UrunFormu(bolum: widget.bolum, urun: urun)),
    );
    if (s == true) _yukle();
  }

  Future<void> _degerPenceresi() async {
    final kur = await dolarKuruGetir();
    if (!mounted) return;
    final k = kur?.satis;
    final tahmin = (k != null && k > 0) ? _tlDolarsiz / k : null;
    final toplamUsd = _usdToplam + (tahmin ?? 0);
    double deger(Map<String, dynamic> p) {
      final u = alan(p, 'buy_price_usd');
      if (u > 0) return tam(p, 'stock') * u;
      return (k != null && k > 0)
          ? tam(p, 'stock') * alan(p, 'buy_price') / k
          : 0;
    }

    final satirlar = List<Map<String, dynamic>>.from(_stoklu)
      ..sort((a, b) => deger(b).compareTo(deger(a)));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimdeki parçaların değeri'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ozetSatir('Parça çeşidi', '${satirlar.length}'),
                _ozetSatir('Toplam adet', '$_adetToplam'),
                const Divider(),
                _ozetSatir('Dolar fiyatı girilen parçalar', _usd(_usdToplam)),
                _ozetSatir('Dolar girilmeyenler (TL maliyet)',
                    para(_tlDolarsiz)),
                if (tahmin != null)
                  _ozetSatir('   ≈ bugünkü kurla dolar', _usd(tahmin)),
                const Divider(),
                _ozetSatir('TOPLAM (dolar)', _usd(toplamUsd),
                    kalin: true, renk: Colors.greenAccent),
                if (k != null)
                  _ozetSatir('Bugünkü kurla TL karşılığı', para(toplamUsd * k),
                      kalin: true),
                _ozetSatir('TL maliyet (alış günü kurlarıyla)',
                    para(_tlToplam)),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Text(
                      k == null
                          ? 'Kur alınamadı, dolar karşılığı hesaplanamadı.'
                          : 'Kur: ${k.toStringAsFixed(4).replaceAll('.', ',')} (TCMB ${kur!.tarih})',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                const Divider(),
                ...satirlar.map((p) {
                  final u = alan(p, 'buy_price_usd');
                  final tl = alan(p, 'buy_price');
                  final s = tam(p, 'stock');
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${p['name']}'),
                    subtitle: Text(
                        '$s adet × ${u > 0 ? _usd(u) : para(tl)}'),
                    trailing: Text(
                        u > 0 ? _usd(s * u) : para(s * tl),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }),
              ],
            ),
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
          child: Text('Ürün bulunamadı.', style: TextStyle(fontSize: 18)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final p = liste[i];
        final az = _azaliyor(p);
        final ek = [p['part_category'], p['brand'], p['model']]
            .where((e) => '${e ?? ''}'.isNotEmpty)
            .join(' • ');
        final u = alan(p, 'buy_price_usd');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            onTap: () => _ac(p),
            leading: CircleAvatar(
              backgroundColor:
                  (az ? Colors.red : Colors.green).withValues(alpha: 0.2),
              child: Text('${tam(p, 'stock')}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: az ? Colors.redAccent : Colors.greenAccent)),
            ),
            title: Text('${p['name']}', style: const TextStyle(fontSize: 17)),
            subtitle: Text(ek.isEmpty ? 'Stokta ${tam(p, 'stock')} adet' : ek),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Satış ${para(alan(p, 'sell_price'))}'),
                Text(
                    u > 0
                        ? 'Alış ${_usd(u)} • ${para(alan(p, 'buy_price'))}'
                        : 'Alış ${para(alan(p, 'buy_price'))}',
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
            title: Text(_teknik ? 'Stok ve Parçalar' : 'Aksesuar Stoku'),
            actions: [
              IconButton(
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile'),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _ac(),
            icon: const Icon(Icons.add),
            label: const Text('Yeni ürün'),
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
                        hintText: 'Ürün, marka, model veya raf ara',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _degerPenceresi,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calculate,
                                color: Colors.cyanAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Elimdeki parçaların değeri',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      '${_stoklu.length} çeşit • $_adetToplam adet • ayrıntı için dokunun',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_usdToplam > 0 ? _usd(_usdToplam) : '—',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent)),
                                Text(para(_tlToplam),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: const Text('Azalan / biten'),
                        selected: _azalan,
                        onSelected: (v) => setState(() => _azalan = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
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

class UrunFormu extends StatefulWidget {
  final String bolum;
  final Map<String, dynamic>? urun;
  const UrunFormu({super.key, required this.bolum, this.urun});

  @override
  State<UrunFormu> createState() => _UrunFormuState();
}

class _UrunFormuState extends State<UrunFormu> {
  final _anahtar = GlobalKey<FormState>();
  String _t(String k) => (widget.urun?[k] ?? '').toString();
  bool get _yeni => widget.urun == null;

  late final _ad = TextEditingController(text: _t('name'));
  late final _marka = TextEditingController(text: _t('brand'));
  late final _model = TextEditingController(text: _t('model'));
  late final _uyumlu = TextEditingController(text: _t('compatible'));
  late final _satis =
      TextEditingController(text: sayiYaz(widget.urun?['sell_price']));
  late final _minStok =
      TextEditingController(text: sayiYaz(widget.urun?['min_stock']));
  late final _raf = TextEditingController(text: _t('location'));
  late final _seri = TextEditingController(text: _t('serial_no'));
  late final _not = TextEditingController(text: _t('note'));
  final _adet = TextEditingController();
  final _fiyat = TextEditingController();
  final _kur = TextEditingController();

  late String _kategori = _t('part_category');
  late int _stok = widget.urun == null ? 0 : tam(widget.urun!, 'stock');
  String? _tedId;
  String? _tedAd;
  bool _dolar = true;
  bool _fiyatDegisti = false;
  bool _degisti = false;
  bool _kaydediliyor = false;
  bool _kurYuk = false;
  bool _digerYuk = true;
  bool _stokGirildi = false;
  String? _kurNotu;
  String? _hata;
  String? _olusanId;
  double _digerUsd = 0;
  double _digerTl = 0;

  bool get _teknik => widget.bolum == 'teknik';
  List<String> get _kategoriler =>
      _teknik ? _teknikKategoriler : _aksesuarKategoriler;

  int get _birimKurus =>
      _dolar ? _tlKurus(_fiyat.text, _kur.text) : _kurus(_fiyat.text);

  @override
  void initState() {
    super.initState();
    final u = widget.urun;
    if (u != null) {
      _tedId = u['supplier_id'];
      final usd = alan(u, 'buy_price_usd');
      final tl = alan(u, 'buy_price');
      if (usd > 0) {
        _dolar = true;
        _fiyat.text = sayiYaz(usd);
      } else if (tl > 0) {
        _dolar = false;
        _fiyat.text = sayiYaz(tl);
      }
      if (_tedId != null) _tedarikciAdiGetir();
    }
    _kurGetir();
    _digerleriYukle();
  }

  @override
  void dispose() {
    for (final c in [
      _ad, _marka, _model, _uyumlu, _satis, _minStok, _raf, _seri, _not,
      _adet, _fiyat, _kur,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tedarikciAdiGetir() async {
    try {
      final r = await _db
          .from('suppliers')
          .select('name')
          .eq('id', _tedId!)
          .maybeSingle();
      if (!mounted) return;
      if (r != null) setState(() => _tedAd = '${r['name']}');
    } catch (_) {}
  }

  Future<void> _digerleriYukle() async {
    try {
      final v = await _db
          .from('products')
          .select('id, stock, buy_price, buy_price_usd')
          .eq('section', widget.bolum)
          .isFilter('deleted_at', null)
          .gt('stock', 0);
      double usd = 0, tl = 0;
      for (final p in List<Map<String, dynamic>>.from(v)) {
        if (!_yeni && p['id'] == widget.urun!['id']) continue;
        final s = tam(p, 'stock');
        final u = alan(p, 'buy_price_usd');
        if (u > 0) {
          usd += s * u;
        } else {
          tl += s * alan(p, 'buy_price');
        }
      }
      if (!mounted) return;
      setState(() {
        _digerUsd = usd;
        _digerTl = tl;
        _digerYuk = false;
      });
    } catch (_) {
      if (mounted) setState(() => _digerYuk = false);
    }
  }

  Future<void> _kurGetir() async {
    setState(() {
      _kurYuk = true;
      _kurNotu = null;
    });
    final k = await dolarKuruGetir();
    if (!mounted) return;
    setState(() {
      _kurYuk = false;
      if (k == null) {
        _kurNotu = 'Kur alınamadı, kuru elle yazın.';
      } else {
        _kur.text = k.satis.toStringAsFixed(4).replaceAll('.', ',');
        _kurNotu = 'TCMB döviz satış kuru (${k.tarih})';
      }
    });
  }

  Future<void> _tedarikciSec() async {
    try {
      final v = await _db
          .from('suppliers')
          .select('id, name, phone')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final s = await secimPenceresi(context,
          baslik: 'Tedarikçi seç',
          liste: List<Map<String, dynamic>>.from(v),
          ana: 'name',
          alt: 'phone');
      if (s != null) {
        setState(() {
          _tedId = s['id'];
          _tedAd = s['name'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Tedarikçiler alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _yeniTedarikci() async {
    final t = await tedarikciFormuAc(context);
    if (t != null) {
      setState(() {
        _tedId = t['id'];
        _tedAd = t['name'];
      });
    }
  }

  Future<String> _urunOlustur(Map<String, dynamic> veri) async {
    final r = await _db.from('products').insert(veri).select('id').single();
    _olusanId = '${r['id']}';
    return _olusanId!;
  }
  Future<void> _kaydet() async {
    if (!_anahtar.currentState!.validate()) return;
    final fiyatYazildi = _fiyat.text.trim().isNotEmpty;
    final fiyatYaz = _yeni || _fiyatDegisti;
    if (fiyatYaz && fiyatYazildi && _dolar && _d4(_kur.text) <= 0) {
      setState(() => _hata = 'Dolar kurunu yazın.');
      return;
    }
    final adet = _yeni ? tamSayi(_adet.text) : 0;
    if (_yeni && _tedId != null && adet > 0 && _birimKurus <= 0) {
      setState(() => _hata = 'Tedarikçiden aldıysanız alış fiyatını yazın.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    final veri = <String, dynamic>{
      'section': widget.bolum,
      'name': _ad.text.trim(),
      'brand': _marka.text.trim(),
      'model': _model.text.trim(),
      'part_category': _kategori,
      'compatible': _uyumlu.text.trim(),
      'supplier_id': _tedId,
      'sell_price': sayi(_satis.text),
      'min_stock': tamSayi(_minStok.text),
      'location': _raf.text.trim(),
      'serial_no': _seri.text.trim(),
      'note': _not.text.trim(),
    };
    if (fiyatYaz) {
      veri['buy_price'] = fiyatYazildi ? _birimKurus / 100 : 0;
      veri['buy_price_usd'] =
          (fiyatYazildi && _dolar) ? _d4(_fiyat.text) / 10000 : null;
    }
    try {
      if (_yeni) {
        final String id = _olusanId ?? await _urunOlustur(veri);
        if (adet > 0 && !_stokGirildi) {
          if (_tedId != null) {
            await _db.rpc('create_purchase', params: {
              'p_supplier': _tedId,
              'p_section': widget.bolum,
              'p_date': bugunTarih(),
              'p_note': 'Stok girişi',
              'p_items': [
                _dolar
                    ? {
                        'product_id': id,
                        'qty': adet,
                        'currency': 'USD',
                        'unit_cost_fx': _d4(_fiyat.text) / 10000,
                        'fx_rate': _d4(_kur.text) / 10000,
                        'unit_cost': _birimKurus / 100,
                      }
                    : {
                        'product_id': id,
                        'qty': adet,
                        'currency': 'TRY',
                        'unit_cost': _birimKurus / 100,
                      },
              ],
              'p_paid': 0,
              'p_method': 'nakit',
            });
          } else {
            await _db.from('stock_movements').insert({
              'product_id': id,
              'qty': adet,
              'reason': 'acilis',
              'note': 'Açılış stoğu',
            });
          }
          _stokGirildi = true;
        }
      } else {
        await _db.from('products').update(veri).eq('id', widget.urun!['id']);
      }
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

  Future<void> _sayim() async {
    final sayilan = TextEditingController(text: '$_stok');
    final neden = TextEditingController();
    String? hata;
    final yeni = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Stok sayımı'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sistemde şu an $_stok adet görünüyor.'),
                const SizedBox(height: 12),
                TextField(
                  controller: sayilan,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Gerçekte sayılan adet',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: neden,
                  decoration: const InputDecoration(
                      labelText: 'Neden? (isteğe bağlı)',
                      border: OutlineInputBorder()),
                ),
                if (hata != null) ...[
                  const SizedBox(height: 10),
                  Text(hata!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () async {
                final s = int.tryParse(sayilan.text.trim());
                if (s == null || s < 0) {
                  setS(() => hata = 'Geçerli bir adet yazın.');
                  return;
                }
                final fark = s - _stok;
                if (fark == 0) {
                  Navigator.pop(ctx);
                  return;
                }
                try {
                  await _db.from('stock_movements').insert({
                    'product_id': widget.urun!['id'],
                    'qty': fark,
                    'reason': 'sayim',
                    'note': neden.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, s);
                } catch (e) {
                  setS(() => hata = 'Kaydedilemedi: ${hataMetni(e)}');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (yeni != null) {
      setState(() {
        _stok = yeni;
        _degisti = true;
      });
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürün silinsin mi?'),
        content: const Text(
            'Ürün listeden kalkar ama veritabanında saklanır. Stok hareketleri korunur.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await _db
          .from('products')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.urun!['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Silinemedi: ${hataMetni(e)}');
    }
  }

  Widget _girdi(TextEditingController c, String etiket,
      {bool sayiMi = false,
      bool tamMi = false,
      bool zorunlu = false,
      bool hesapla = false,
      String? ek,
      String? ipucu}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: sayiMi
            ? const TextInputType.numberWithOptions(decimal: true)
            : (tamMi ? TextInputType.number : TextInputType.text),
        onChanged: hesapla ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: etiket,
          helperText: ipucu,
          suffixText: ek,
          border: const OutlineInputBorder(),
        ),
        validator: zorunlu
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bu alanı doldurun' : null
            : null,
      ),
    );
  }

  Widget _fiyatBlogu() {
    final u = widget.urun;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alış fiyatı (birim)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Dolar (\$)'),
                  selected: _dolar,
                  onSelected: (_) => setState(() {
                    _dolar = true;
                    _fiyatDegisti = true;
                    _fiyat.text = '';
                  }),
                ),
                ChoiceChip(
                  label: const Text('Türk Lirası (₺)'),
                  selected: !_dolar,
                  onSelected: (_) => setState(() {
                    _dolar = false;
                    _fiyatDegisti = true;
                    _fiyat.text = '';
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fiyat,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _fiyatDegisti = true),
              decoration: InputDecoration(
                labelText:
                    _dolar ? 'Birim alış fiyatı (dolar)' : 'Birim alış fiyatı (₺)',
                suffixText: _dolar ? '\$' : '₺',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_dolar) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kur,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() => _fiyatDegisti = true),
                      decoration: const InputDecoration(
                          labelText: '1 dolar kaç TL?',
                          suffixText: '₺',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _kurYuk ? null : _kurGetir,
                    tooltip: 'Güncel kuru getir',
                    icon: _kurYuk
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_kurNotu != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_kurNotu!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _dolar
                    ? 'Birim TL karşılığı: ${para(_birimKurus / 100)}'
                    : 'Birim: ${para(_birimKurus / 100)}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            if (u != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Kayıtlı alış: ${alan(u, 'buy_price_usd') > 0 ? '${_usd(alan(u, 'buy_price_usd'))} • ' : ''}${para(alan(u, 'buy_price'))}. Fiyatı değiştirmezseniz kayıtlı fiyat korunur.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _degerKarti() {
    final adet = _yeni ? tamSayi(_adet.text) : _stok;
    final kurDeger = _d4(_kur.text) / 10000;
    final bu = _dolar
        ? adet * (_d4(_fiyat.text) / 10000)
        : (kurDeger > 0 ? adet * _birimKurus / 100 / kurDeger : 0.0);
    final diger = _digerUsd + (kurDeger > 0 ? _digerTl / kurDeger : 0.0);
    return Card(
      color: Colors.indigo.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Elimdeki parçaların toplam değeri',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _ozetSatir('Bu kalem ($adet adet)', _usd(bu)),
            _ozetSatir('Diğer parçalar',
                _digerYuk ? 'hesaplanıyor...' : _usd(diger)),
            const Divider(),
            _ozetSatir('TOPLAM (dolar)', _usd(bu + diger),
                kalin: true, renk: Colors.greenAccent),
            const Text(
              'Dolar fiyatı girilmemiş parçalar, TL maliyetleri bugünkü kurla dolara çevrilerek hesaba katılır.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _degisti);
      },
      child: Theme(
        data: _koyu(),
        child: YildizArkaplan(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(_yeni ? 'Yeni ürün' : 'Ürünü düzenle'),
              actions: [
                if (!_yeni)
                  IconButton(
                      onPressed: _sil,
                      icon: const Icon(Icons.delete),
                      tooltip: 'Sil'),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _anahtar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _girdi(_ad, 'Ürün adı (örn. iPhone 11 ekran)',
                          zorunlu: true),
                      const Text('Kategori', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kategoriler
                            .map((k) => ChoiceChip(
                                  label: Text(k),
                                  selected: _kategori == k,
                                  onSelected: (_) =>
                                      setState(() => _kategori = k),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      _girdi(_marka, 'Marka'),
                      _girdi(_model, 'Model'),
                      _girdi(_uyumlu, 'Uyumlu cihaz'),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_shipping),
                          title: Text(_tedAd ??
                              'Tedarikçi (kimden aldınız? boşsa elinizde vardı)'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_tedId != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Tedarikçiyi kaldır',
                                  onPressed: () => setState(() {
                                    _tedId = null;
                                    _tedAd = null;
                                  }),
                                ),
                              IconButton(
                                icon: const Icon(Icons.person_add),
                                tooltip: 'Yeni tedarikçi',
                                onPressed: _yeniTedarikci,
                              ),
                              const Icon(Icons.search),
                            ],
                          ),
                          onTap: _tedarikciSec,
                        ),
                      ),
                      if (_yeni) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
                          child: Text(
                            'Tedarikçi seçip adet yazarsanız alış kaydı ve tedarikçi borcu oluşur. Seçmezseniz adet, elinizdeki stok olarak girilir.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        _girdi(_adet, 'Adet (aldığınız / elinizdeki)',
                            tamMi: true, hesapla: true),
                      ] else
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2),
                            title: Text('Stokta $_stok adet'),
                            subtitle: const Text(
                                'Sayım farkı varsa düzeltin, hareket olarak kaydedilir'),
                            trailing: FilledButton.tonal(
                                onPressed: _sayim,
                                child: const Text('Sayım yap')),
                          ),
                        ),
                      _fiyatBlogu(),
                      const SizedBox(height: 12),
                      _girdi(_satis, 'Satış fiyatı', sayiMi: true, ek: '₺'),
                      _girdi(_minStok, 'Minimum stok',
                          tamMi: true,
                          ipucu: 'Stok bu sayıya düşünce kırmızı görünür.'),
                      _girdi(_raf, 'Raf / lokasyon'),
                      _girdi(_seri, 'Seri numarası / parça kodu'),
                      _girdi(_not, 'Not'),
                      _degerKarti(),
                      const SizedBox(height: 12),
                      if (_hata != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_hata!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 16)),
                        ),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _kaydediliyor ? null : _kaydet,
                          child: _kaydediliyor
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 3))
                              : const Text('Kaydet',
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
        ),
      ),
    );
  }
}