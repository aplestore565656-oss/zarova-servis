import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';

final _db = Supabase.instance.client;

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

const _teknikKategoriler = [
  'Ekran', 'Batarya', 'Kasa', 'Ara film', 'Şarj soketi', 'Diğer'
];
const _aksesuarKategoriler = [
  'Kılıf', 'Cam / koruyucu', 'Şarj aleti', 'Kablo', 'Kulaklık', 'Diğer'
];

class UrunlerSayfasi extends StatefulWidget {
  final String bolum; // 'teknik' veya 'aksesuar'
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
        _hata = 'Ürünler alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  bool _azaliyor(Map<String, dynamic> p) =>
      tam(p, 'stock') <= tam(p, 'min_stock');

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    return _liste.where((p) {
      if (_azalan && !_azaliyor(p)) return false;
      if (a.isEmpty) return true;
      final metin = [
        p['name'], p['brand'], p['model'], p['part_category'],
        p['compatible'], p['location'], p['serial_no'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return metin.contains(a);
    }).toList();
  }

  double get _stokDegeri => _liste.fold(0.0, (t, p) {
        final s = tam(p, 'stock');
        return t + (s > 0 ? s * alan(p, 'buy_price') : 0);
      });

  Future<void> _ac([Map<String, dynamic>? urun]) async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => UrunFormu(bolum: widget.bolum, urun: urun)),
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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            onTap: () => _ac(p),
            leading: CircleAvatar(
              backgroundColor: (az ? Colors.red : Colors.green)
                  .withValues(alpha: 0.2),
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
                Text('Alış ${para(alan(p, 'buy_price'))}',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Azalan / biten'),
                          selected: _azalan,
                          onSelected: (v) => setState(() => _azalan = v),
                        ),
                        const Spacer(),
                        Text(
                          '${_liste.length} çeşit • Stok değeri ${para(_stokDegeri)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
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

  late final _ad = TextEditingController(text: _t('name'));
  late final _marka = TextEditingController(text: _t('brand'));
  late final _model = TextEditingController(text: _t('model'));
  late final _uyumlu = TextEditingController(text: _t('compatible'));
  late final _alis = TextEditingController(text: sayiYaz(widget.urun?['buy_price']));
  late final _satis = TextEditingController(text: sayiYaz(widget.urun?['sell_price']));
  late final _minStok = TextEditingController(text: sayiYaz(widget.urun?['min_stock']));
  late final _baslangic = TextEditingController();
  late final _raf = TextEditingController(text: _t('location'));
  late final _seri = TextEditingController(text: _t('serial_no'));
  late final _not = TextEditingController(text: _t('note'));

  late String _kategori = _t('part_category');
  late int _stok = widget.urun == null ? 0 : tam(widget.urun!, 'stock');
  bool _degisti = false;
  bool _kaydediliyor = false;
  String? _hata;

  bool get _teknik => widget.bolum == 'teknik';
  List<String> get _kategoriler =>
      _teknik ? _teknikKategoriler : _aksesuarKategoriler;

  @override
  void dispose() {
    for (final c in [
      _ad, _marka, _model, _uyumlu, _alis, _satis, _minStok,
      _baslangic, _raf, _seri, _not,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (!_anahtar.currentState!.validate()) return;
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
      'buy_price': sayi(_alis.text),
      'sell_price': sayi(_satis.text),
      'min_stock': tamSayi(_minStok.text),
      'location': _raf.text.trim(),
      'serial_no': _seri.text.trim(),
      'note': _not.text.trim(),
    };
    try {
      if (widget.urun == null) {
        final r = await _db.from('products').insert(veri).select('id').single();
        final bas = tamSayi(_baslangic.text);
        if (bas > 0) {
          await _db.from('stock_movements').insert({
            'product_id': r['id'],
            'qty': bas,
            'reason': 'acilis',
            'note': 'Açılış stoğu',
          });
        }
      } else {
        await _db.from('products').update(veri).eq('id', widget.urun!['id']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kaydedilemedi: $e';
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
                  setS(() => hata = 'Kaydedilemedi: $e');
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
      setState(() => _hata = 'Silinemedi: $e');
    }
  }

  Widget _girdi(TextEditingController c, String etiket,
      {bool sayiMi = false,
      bool tamMi = false,
      bool zorunlu = false,
      bool para = false,
      String? ipucu}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: sayiMi
            ? const TextInputType.numberWithOptions(decimal: true)
            : (tamMi ? TextInputType.number : TextInputType.text),
        decoration: InputDecoration(
          labelText: etiket,
          helperText: ipucu,
          border: const OutlineInputBorder(),
          suffixText: para ? '₺' : null,
        ),
        validator: zorunlu
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bu alanı doldurun' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yeniMi = widget.urun == null;
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
              title: Text(yeniMi ? 'Yeni ürün' : 'Ürünü düzenle'),
              actions: [
                if (!yeniMi)
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
                      _girdi(_ad, 'Ürün adı', zorunlu: true),
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
                      _girdi(_alis, 'Alış fiyatı', sayiMi: true, para: true),
                      _girdi(_satis, 'Satış fiyatı', sayiMi: true, para: true),
                      if (yeniMi)
                        _girdi(_baslangic, 'Başlangıç stoğu (elinizdeki adet)',
                            tamMi: true,
                            ipucu:
                                'Sonrasında stok alış, servis ve satışla otomatik değişir.')
                      else
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
                      const SizedBox(height: 12),
                      _girdi(_minStok, 'Minimum stok',
                          tamMi: true,
                          ipucu: 'Stok bu sayıya düşünce kırmızı görünür.'),
                      _girdi(_raf, 'Raf / lokasyon'),
                      _girdi(_seri, 'Seri numarası / parça kodu'),
                      _girdi(_not, 'Not'),
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