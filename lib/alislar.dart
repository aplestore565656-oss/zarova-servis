import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

/// Alış kaydını onay sorarak siler (stok geri düşer). Silindiyse true verir.
Future<bool> alisSilOnayli(
    BuildContext context, Map<String, dynamic> alis) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Alış kaydı silinsin mi?'),
      content: const Text(
          'Stoktaki adet geri düşer ve tedarikçi borcu yeniden hesaplanır. Kayıt veritabanında saklanır.'),
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
  if (onay != true) return false;
  try {
    await _db
        .from('purchases')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', alis['id']);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
    return false;
  }
}

class AlislarSayfasi extends StatefulWidget {
  const AlislarSayfasi({super.key});

  @override
  State<AlislarSayfasi> createState() => _AlislarSayfasiState();
}

class _AlislarSayfasiState extends State<AlislarSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';

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
          .from('purchases')
          .select('*, suppliers(name), parts(name)')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Alışlar alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    if (a.isEmpty) return _liste;
    return _liste.where((s) {
      final t = (s['suppliers'] as Map<String, dynamic>?)?['name'] ?? '';
      final p = (s['parts'] as Map<String, dynamic>?)?['name'] ?? '';
      return '$t $p'.toLowerCase().contains(a);
    }).toList();
  }

  Future<void> _yeni() async {
    final sonuc = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AlisFormu()),
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
        child: Text('Alış kaydı bulunamadı.', style: TextStyle(fontSize: 18)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final s = liste[i];
        final tedarikci =
            (s['suppliers'] as Map<String, dynamic>?)?['name'] ?? '';
        final parca = (s['parts'] as Map<String, dynamic>?)?['name'] ?? '';
        final kalan = alan(s, 'remaining');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            isThreeLine: true,
            title: Text('$parca',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            subtitle: Text(
                '$tedarikci • ${tarih(s['created_at'])}\n${s['qty']} adet × ${para(alan(s, 'unit_price'))} = ${para(alan(s, 'total'))}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kalan > 0 ? 'Kalan ${para(kalan)}' : 'Ödendi',
                  style: TextStyle(color: kalan > 0 ? Colors.red : Colors.green),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await alisSilOnayli(context, s)) _yukle();
                  },
                ),
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
      appBar: AppBar(title: const Text('Parça Alışları')),
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
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tedarikçi veya parça ara',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(child: _icerik()),
            ],
          ),
        ),
      ),
    );
  }
}

class AlisFormu extends StatefulWidget {
  final Map<String, dynamic>? tedarikci;
  const AlisFormu({super.key, this.tedarikci});

  @override
  State<AlisFormu> createState() => _AlisFormuState();
}

class _AlisFormuState extends State<AlisFormu> {
  late String? _tedarikciId = widget.tedarikci?['id'];
  late String? _tedarikciAd = widget.tedarikci?['name'];
  String? _parcaId;
  String? _parcaAd;
  final _adet = TextEditingController(text: '1');
  final _fiyat = TextEditingController();
  final _odenen = TextEditingController();
  final _not = TextEditingController();
  String _odeyen = 'kasa';
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    _adet.dispose();
    _fiyat.dispose();
    _odenen.dispose();
    _not.dispose();
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

  Future<void> _parcaSec() async {
    try {
      final veri = await _db
          .from('parts')
          .select('id, name, brand, model, buy_price')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final liste = List<Map<String, dynamic>>.from(veri)
          .map((p) => {
                ...p,
                'etiket': '${p['name']} ${p['brand']} ${p['model']}'.trim(),
              })
          .toList();
      final p = await secimPenceresi(
        context,
        baslik: 'Parça seç',
        liste: liste,
        ana: 'etiket',
      );
      if (p != null) {
        setState(() {
          _parcaId = p['id'];
          _parcaAd = p['etiket'];
          final f = alan(p, 'buy_price');
          if (f > 0) _fiyat.text = sayiYaz(f);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Parçalar alınamadı: $e');
    }
  }

  Future<void> _kaydet() async {
    final adet = tamSayi(_adet.text);
    final fiyat = sayi(_fiyat.text);
    final odenen = sayi(_odenen.text);
    if (_tedarikciId == null) {
      setState(() => _hata = 'Önce tedarikçi seçin.');
      return;
    }
    if (_parcaId == null) {
      setState(() => _hata = 'Önce parça seçin. Parça yoksa Stok bölümünden ekleyin.');
      return;
    }
    if (adet <= 0) {
      setState(() => _hata = 'Adet 1 veya daha fazla olmalı.');
      return;
    }
    if (odenen > adet * fiyat) {
      setState(() => _hata = 'Ödenen tutar toplamdan fazla olamaz.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      await _db.from('purchases').insert({
        'supplier_id': _tedarikciId,
        'part_id': _parcaId,
        'qty': adet,
        'unit_price': fiyat,
        'paid': odenen,
        'paid_by': _odeyen,
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

  Widget _girdi(TextEditingController c, String etiket,
      {bool sayiMi = false, bool para = false, bool hesapla = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: sayiMi
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: hesapla ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: etiket,
          border: const OutlineInputBorder(),
          suffixText: para ? '₺' : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adet = tamSayi(_adet.text);
    final toplam = adet * sayi(_fiyat.text);
    final kalan = toplam - sayi(_odenen.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni parça alışı')),
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
                  leading: const Icon(Icons.memory),
                  title: Text(_parcaAd ?? 'Parça seçin'),
                  trailing: const Icon(Icons.search),
                  onTap: _parcaSec,
                ),
              ),
              const SizedBox(height: 12),
              _girdi(_adet, 'Adet', sayiMi: true, hesapla: true),
              _girdi(_fiyat, 'Birim fiyat',
                  sayiMi: true, para: true, hesapla: true),
              _girdi(_odenen, 'Şimdi ödenen',
                  sayiMi: true, para: true, hesapla: true),
              const Text('Kim ödedi?', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: odeyenler.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _odeyen == e.key,
                          onSelected: (_) => setState(() => _odeyen = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Card(
                color: kalan > 0 ? Colors.red.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Toplam', style: TextStyle(fontSize: 16)),
                          Text(para(toplam),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tedarikçiye kalan borç',
                              style: TextStyle(fontSize: 16)),
                          Text(para(kalan < 0 ? 0 : kalan),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kalan > 0 ? Colors.red : Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
    );
  }
}