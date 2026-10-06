import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

class SatislarSayfasi extends StatefulWidget {
  const SatislarSayfasi({super.key});

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
      final veri = await _db
          .from('accessory_sales')
          .select('*, parts(name, brand, model)')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(200);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Satışlar alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SatisFormu()),
    );
    if (s == true) _yukle();
  }

  Future<void> _sil(Map<String, dynamic> s) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Satış silinsin mi?'),
        content: const Text(
            'Ürün stoğa geri döner ve kasadan düşer. Kayıt veritabanında saklanır.'),
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
          .from('accessory_sales')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', s['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  double _kar(Map<String, dynamic> s) =>
      alan(s, 'total') - tam(s, 'qty') * alan(s, 'unit_cost');

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
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _yukle, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }
    final bugun = DateTime.now().toIso8601String().substring(0, 10);
    final bugunku = _liste.where((s) => '${s['sale_date']}' == bugun).toList();
    final ciro = bugunku.fold(0.0, (t, s) => t + alan(s, 'total'));
    final kar = bugunku.fold(0.0, (t, s) => t + _kar(s));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Row(
          children: [
            _kutu('Bugünkü satış', para(ciro)),
            _kutu('Bugünkü kâr', para(kar),
                renk: kar >= 0 ? Colors.green : Colors.red),
          ],
        ),
        if (_liste.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text('Henüz satış yok.', style: TextStyle(fontSize: 18))),
          ),
        ..._liste.map((s) {
          final p = s['parts'] as Map<String, dynamic>?;
          final ad = '${p?['name'] ?? ''} ${p?['brand'] ?? ''} ${p?['model'] ?? ''}'
              .trim();
          return Card(
            child: ListTile(
              title: Text(ad, style: const TextStyle(fontSize: 17)),
              subtitle: Text(
                  '${tam(s, 'qty')} adet × ${para(alan(s, 'unit_price'))} • ${tarih(s['created_at'])}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(para(alan(s, 'total')),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Kâr ${para(_kar(s))}',
                          style: TextStyle(
                              fontSize: 12,
                              color: _kar(s) >= 0 ? Colors.green : Colors.red)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Sil',
                    onPressed: () => _sil(s),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aksesuar Satışı'),
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
    );
  }
}

class SatisFormu extends StatefulWidget {
  const SatisFormu({super.key});

  @override
  State<SatisFormu> createState() => _SatisFormuState();
}

class _SatisFormuState extends State<SatisFormu> {
  String? _parcaId;
  String? _parcaAd;
  int? _stok;
  final _adet = TextEditingController(text: '1');
  final _fiyat = TextEditingController();
  final _not = TextEditingController();
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    _adet.dispose();
    _fiyat.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _urunSec() async {
    try {
      final veri = await _db
          .from('parts')
          .select('id, name, brand, model, sell_price, stock')
          .eq('category', 'aksesuar')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final liste = List<Map<String, dynamic>>.from(veri)
          .map((p) => {
                ...p,
                'etiket': '${p['name']} ${p['brand']} ${p['model']}'.trim(),
                'stokYazi': 'Stok: ${tam(p, 'stock')} adet',
              })
          .toList();
      final p = await secimPenceresi(
        context,
        baslik: 'Aksesuar seç',
        liste: liste,
        ana: 'etiket',
        alt: 'stokYazi',
      );
      if (p != null) {
        setState(() {
          _parcaId = p['id'];
          _parcaAd = p['etiket'];
          _stok = tam(p, 'stock');
          _fiyat.text = sayiYaz(alan(p, 'sell_price'));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Ürünler alınamadı: $e');
    }
  }

  Future<void> _kaydet() async {
    final adet = tamSayi(_adet.text);
    if (_parcaId == null) {
      setState(() =>
          _hata = 'Önce ürün seçin. Ürün yoksa Aksesuar Stoku bölümünden ekleyin.');
      return;
    }
    if (adet <= 0) {
      setState(() => _hata = 'Adet 1 veya daha fazla olmalı.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      await _db.from('accessory_sales').insert({
        'part_id': _parcaId,
        'qty': adet,
        'unit_price': sayi(_fiyat.text),
        'note': _not.text.trim(),
      });
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

  @override
  Widget build(BuildContext context) {
    final adet = tamSayi(_adet.text);
    final toplam = adet * sayi(_fiyat.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni aksesuar satışı')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.headphones),
                  title: Text(_parcaAd ?? 'Ürün seçin'),
                  subtitle: _stok == null ? null : Text('Stokta $_stok adet'),
                  trailing: const Icon(Icons.search),
                  onTap: _urunSec,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adet,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Adet', border: OutlineInputBorder()),
              ),
              if (_stok != null && adet > _stok!)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Dikkat: Stokta $_stok adet var, kaydederseniz stok eksiye düşer.',
                    style: TextStyle(color: Colors.orange.shade900),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _fiyat,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Birim satış fiyatı',
                  suffixText: '₺',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam', style: TextStyle(fontSize: 16)),
                      Text(para(toplam),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
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
                      style: const TextStyle(color: Colors.red, fontSize: 16)),
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
    );
  }
}