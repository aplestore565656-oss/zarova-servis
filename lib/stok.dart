import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

class StokSayfasi extends StatefulWidget {
  final String kategori;
  const StokSayfasi({super.key, this.kategori = 'parca'});

  @override
  State<StokSayfasi> createState() => _StokSayfasiState();
}

class _StokSayfasiState extends State<StokSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';
  bool _sadeceAzalan = false;

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
          .from('parts')
          .select('*, suppliers(name)')
          .isFilter('deleted_at', null)
          .eq('category', widget.kategori)
          .order('name');
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Parçalar alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  bool _azaliyor(Map<String, dynamic> p) =>
      tam(p, 'stock') <= tam(p, 'min_stock');

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    return _liste.where((p) {
      if (_sadeceAzalan && !_azaliyor(p)) return false;
      if (a.isEmpty) return true;
      final metin = [
        p['name'],
        p['brand'],
        p['model'],
        p['compatible'],
        p['location'],
        p['serial_no'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return metin.contains(a);
    }).toList();
  }

  Future<void> _ac([Map<String, dynamic>? parca]) async {
    final sonuc = await Navigator.push<bool>(
      context,
MaterialPageRoute(
          builder: (_) =>
              ParcaFormu(parca: parca, kategori: widget.kategori)),
    );
    if (sonuc == true) _yukle();
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
                  style: const TextStyle(color: Colors.red)),
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
        child: Text('Parça bulunamadı.', style: TextStyle(fontSize: 18)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final p = liste[i];
        final azaliyor = _azaliyor(p);
        final ek = [p['brand'], p['model'], p['compatible']]
            .where((e) => '${e ?? ''}'.isNotEmpty)
            .join(' • ');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            onTap: () => _ac(p),
            leading: CircleAvatar(
              backgroundColor:
                  azaliyor ? Colors.red.shade100 : Colors.green.shade100,
              child: Text(
                '${tam(p, 'stock')}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: azaliyor ? Colors.red : Colors.green.shade800,
                ),
              ),
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
    return Scaffold(
      appBar: AppBar(
title: Text(widget.kategori == 'aksesuar'
            ? 'Aksesuar Stoku'
            : 'Stok ve Parçalar'),
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
        label: const Text('Yeni parça'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Parça, marka, model veya raf ara',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Sadece azalan / biten stoklar'),
                    selected: _sadeceAzalan,
                    onSelected: (v) => setState(() => _sadeceAzalan = v),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: _icerik()),
            ],
          ),
        ),
      ),
    );
  }
}

class ParcaFormu extends StatefulWidget {
  final Map<String, dynamic>? parca;
  final String kategori;
  const ParcaFormu({super.key, this.parca, this.kategori = 'parca'});

  @override
  State<ParcaFormu> createState() => _ParcaFormuState();
}

class _ParcaFormuState extends State<ParcaFormu> {
  final _anahtar = GlobalKey<FormState>();

  String _t(String k) => (widget.parca?[k] ?? '').toString();

  late final _ad = TextEditingController(text: _t('name'));
  late final _marka = TextEditingController(text: _t('brand'));
  late final _model = TextEditingController(text: _t('model'));
  late final _uyumlu = TextEditingController(text: _t('compatible'));
  late final _alis = TextEditingController(text: sayiYaz(widget.parca?['buy_price']));
  late final _satis = TextEditingController(text: sayiYaz(widget.parca?['sell_price']));
  late final _stok = TextEditingController(
      text: widget.parca == null ? '0' : '${tam(widget.parca!, 'stock')}');
  late final _minStok = TextEditingController(
      text: widget.parca == null ? '0' : '${tam(widget.parca!, 'min_stock')}');
  late final _raf = TextEditingController(text: _t('location'));
  late final _seri = TextEditingController(text: _t('serial_no'));
  late final _not = TextEditingController(text: _t('note'));

  late String? _tedarikciId = widget.parca?['supplier_id'];
  late String? _tedarikciAd =
      (widget.parca?['suppliers'] as Map<String, dynamic>?)?['name'];
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in [
      _ad, _marka, _model, _uyumlu, _alis, _satis,
      _stok, _minStok, _raf, _seri, _not,
    ]) {
      c.dispose();
    }
    super.dispose();
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
      setState(() => _hata = 'Tedarikçiler alınamadı: $e');
    }
  }

  Future<void> _kaydet() async {
    if (!_anahtar.currentState!.validate()) return;
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    final Map<String, dynamic> veri = {
      'name': _ad.text.trim(),
      'brand': _marka.text.trim(),
      'model': _model.text.trim(),
      'compatible': _uyumlu.text.trim(),
      'supplier_id': _tedarikciId,
      'buy_price': sayi(_alis.text),
      'sell_price': sayi(_satis.text),
      'stock': tamSayi(_stok.text),
      'min_stock': tamSayi(_minStok.text),
      'location': _raf.text.trim(),
      'serial_no': _seri.text.trim(),
      'note': _not.text.trim(),
    };
    try {
      if (widget.parca == null) {
        await _db.from('parts').insert(veri);
      } else {
        await _db.from('parts').update(veri).eq('id', widget.parca!['id']);
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

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parça silinsin mi?'),
        content: const Text(
            'Kayıt listeden kalkar ama veritabanında saklanır, geri getirilebilir.'),
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
          .from('parts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.parca!['id']);
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
    final yeniMi = widget.parca == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(yeniMi ? 'Yeni parça' : 'Parçayı düzenle'),
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
                _girdi(_ad, 'Parça adı (örn. iPhone 13 ekran)', zorunlu: true),
                _girdi(_marka, 'Marka'),
                _girdi(_model, 'Model'),
                _girdi(_uyumlu, 'Uyumlu cihaz'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping),
                    title: Text(_tedarikciAd ?? 'Tedarikçi seçin (isteğe bağlı)'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tedarikciId != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _tedarikciId = null;
                              _tedarikciAd = null;
                            }),
                          ),
                        const Icon(Icons.search),
                      ],
                    ),
                    onTap: _tedarikciSec,
                  ),
                ),
                const SizedBox(height: 12),
                _girdi(_alis, 'Alış fiyatı', sayiMi: true, para: true),
                _girdi(_satis, 'Satış fiyatı', sayiMi: true, para: true),
                _girdi(_stok, 'Stok adedi',
                    tamMi: true,
                    ipucu:
                        'Parça alışı girince otomatik artar. Elinizdeki mevcut adedi buraya yazın.'),
                _girdi(_minStok, 'Minimum stok',
                    tamMi: true,
                    ipucu: 'Stok bu sayıya düşünce parça kırmızı görünür.'),
                _girdi(_raf, 'Raf / lokasyon'),
                _girdi(_seri, 'Seri numarası'),
                _girdi(_not, 'Not'),
                if (_hata != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_hata!,
                        style: const TextStyle(color: Colors.red, fontSize: 16)),
                  ),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _kaydediliyor ? null : _kaydet,
                    child: _kaydediliyor
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3))
                        : const Text('Kaydet', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}