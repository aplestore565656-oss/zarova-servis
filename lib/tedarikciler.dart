import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

Future<Map<String, dynamic>?> tedarikciFormuAc(BuildContext context,
    {Map<String, dynamic>? mevcut}) async {
  final ad = TextEditingController(text: mevcut?['name'] ?? '');
  final tel = TextEditingController(text: mevcut?['phone'] ?? '');
  final not = TextEditingController(text: mevcut?['note'] ?? '');
  String? hata;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(mevcut == null ? 'Yeni tedarikçi' : 'Tedarikçiyi düzenle'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                TextField(
                  controller: ad,
                  decoration: const InputDecoration(
                      labelText: 'Tedarikçi adı', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Telefon', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: not,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Not', border: OutlineInputBorder()),
                ),
                if (hata != null) ...[
                  const SizedBox(height: 12),
                  Text(hata!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              if (ad.text.trim().isEmpty) {
                setS(() => hata = 'Tedarikçi adını yazın.');
                return;
              }
              final veri = {
                'name': ad.text.trim(),
                'phone': tel.text.trim(),
                'note': not.text.trim(),
              };
              try {
                final Map<String, dynamic> satir = mevcut == null
                    ? await _db.from('suppliers').insert(veri).select().single()
                    : await _db
                        .from('suppliers')
                        .update(veri)
                        .eq('id', mevcut['id'])
                        .select()
                        .single();
                if (ctx.mounted) Navigator.pop(ctx, satir);
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
}

class TedarikcilerSayfasi extends StatefulWidget {
  const TedarikcilerSayfasi({super.key});

  @override
  State<TedarikcilerSayfasi> createState() => _TedarikcilerSayfasiState();
}

class _TedarikcilerSayfasiState extends State<TedarikcilerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  Map<dynamic, Map<String, dynamic>> _bakiye = {};
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
          .from('suppliers')
          .select()
          .isFilter('deleted_at', null)
          .order('name');
      final b = await _db.from('supplier_balances').select();
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _bakiye = {
          for (final x in List<Map<String, dynamic>>.from(b)) x['supplier_id']: x
        };
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Tedarikçiler alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    if (a.isEmpty) return _liste;
    return _liste
        .where((m) => '${m['name']} ${m['phone']}'.toLowerCase().contains(a))
        .toList();
  }

  Future<void> _yeni() async {
    final yeni = await tedarikciFormuAc(context);
    if (yeni != null) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TedarikciDetaySayfasi(tedarikci: t)),
    );
    _yukle();
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
        child: Text('Tedarikçi bulunamadı.', style: TextStyle(fontSize: 18)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final t = liste[i];
        final b = _bakiye[t['id']];
        final borc = b == null ? 0.0 : alan(b, 'balance');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
            title: Text('${t['name']}', style: const TextStyle(fontSize: 18)),
            subtitle: Text('${t['phone']}'),
            trailing: Text(
              borc > 0 ? 'Borç ${para(borc)}' : 'Borç yok',
              style: TextStyle(
                color: borc > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _detay(t),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tedarikçiler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yeni,
        icon: const Icon(Icons.add),
        label: const Text('Yeni tedarikçi'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tedarikçi adı veya telefon ara',
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

class TedarikciDetaySayfasi extends StatefulWidget {
  final Map<String, dynamic> tedarikci;
  const TedarikciDetaySayfasi({super.key, required this.tedarikci});

  @override
  State<TedarikciDetaySayfasi> createState() => _TedarikciDetaySayfasiState();
}

class _TedarikciDetaySayfasiState extends State<TedarikciDetaySayfasi> {
  late Map<String, dynamic> _t = widget.tedarikci;
  List<Map<String, dynamic>> _alislar = [];
  List<Map<String, dynamic>> _odemeler = [];
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
      final a = await _db
          .from('purchases')
          .select('*, parts(name)')
          .eq('supplier_id', _t['id'])
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      final o = await _db
          .from('supplier_payments')
          .select()
          .eq('supplier_id', _t['id'])
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _alislar = List<Map<String, dynamic>>.from(a);
        _odemeler = List<Map<String, dynamic>>.from(o);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kayıtlar alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  double get _toplamAlis =>
      _alislar.fold(0.0, (t, a) => t + alan(a, 'total'));

  double get _toplamOdeme =>
      _alislar.fold(0.0, (t, a) => t + alan(a, 'paid')) +
      _odemeler.fold(0.0, (t, o) => t + alan(o, 'amount'));

  Future<void> _duzenle() async {
    final guncel = await tedarikciFormuAc(context, mevcut: _t);
    if (guncel != null) setState(() => _t = guncel);
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tedarikçi silinsin mi?'),
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
          .from('suppliers')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _t['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  Future<void> _odemeYap() async {
    final tutar = TextEditingController();
    final not = TextEditingController();
    String odeyen = 'kasa';
    String? hata;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Tedarikçiye ödeme'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: tutar,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tutar',
                      suffixText: '₺',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: not,
                    decoration: const InputDecoration(
                        labelText: 'Not', border: OutlineInputBorder()),
                  ),
                  if (hata != null) ...[
                    const SizedBox(height: 12),
                    Text(hata!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () async {
                final miktar = sayi(tutar.text);
                if (miktar <= 0) {
                  setS(() => hata = 'Tutarı yazın.');
                  return;
                }
                try {
                  await _db.from('supplier_payments').insert({
                    'supplier_id': _t['id'],
                    'amount': miktar,
                    'paid_by': odeyen,
                    'note': not.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
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
    if (tamam == true) _yukle();
  }

  Future<void> _odemeSil(Map<String, dynamic> o) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödeme kaydı silinsin mi?'),
        content: const Text('Tedarikçi borcu buna göre yeniden hesaplanır.'),
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
          .from('supplier_payments')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', o['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  Future<void> _alisEkle() async {
    final sonuc = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AlisFormu(tedarikci: _t)),
    );
    if (sonuc == true) _yukle();
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

  @override
  Widget build(BuildContext context) {
    final kalan = _toplamAlis - _toplamOdeme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_t['name']}'),
        actions: [
          IconButton(
              onPressed: _duzenle,
              icon: const Icon(Icons.edit),
              tooltip: 'Düzenle'),
          IconButton(
              onPressed: _sil,
              icon: const Icon(Icons.delete),
              tooltip: 'Sil'),
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
                  leading: const Icon(Icons.phone),
                  title: Text('${_t['phone']}'.isEmpty
                      ? 'Telefon yok'
                      : '${_t['phone']}'),
                  subtitle: '${_t['note']}'.isEmpty ? null : Text('${_t['note']}'),
                ),
              ),
              Row(
                children: [
                  _kutu('Toplam alış', para(_toplamAlis)),
                  _kutu('Toplam ödeme', para(_toplamOdeme)),
                  _kutu('Kalan borç', para(kalan),
                      renk: kalan > 0 ? Colors.red : Colors.green),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _odemeYap,
                          icon: const Icon(Icons.payments),
                          label: const Text('Ödeme yap'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _alisEkle,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Parça alışı ekle'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_yukleniyor)
                const Center(child: CircularProgressIndicator())
              else if (_hata != null)
                Text(_hata!, style: const TextStyle(color: Colors.red))
              else ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Text('Alışlar',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (_alislar.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Henüz alış kaydı yok.'),
                  ),
                ..._alislar.map((a) {
                  final parca =
                      (a['parts'] as Map<String, dynamic>?)?['name'] ?? '';
                  final kalanAlis = alan(a, 'remaining');
                  return Card(
                    child: ListTile(
                      title: Text('$parca'),
                      subtitle: Text(
                          '${a['qty']} adet × ${para(alan(a, 'unit_price'))} • ${tarih(a['created_at'])}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            kalanAlis > 0
                                ? 'Kalan ${para(kalanAlis)}'
                                : 'Ödendi',
                            style: TextStyle(
                                color:
                                    kalanAlis > 0 ? Colors.red : Colors.green),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (await alisSilOnayli(context, a)) _yukle();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Text('Ödemeler',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (_odemeler.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Henüz ayrı bir ödeme kaydı yok.'),
                  ),
                ..._odemeler.map(
                  (o) => Card(
                    child: ListTile(
                      title: Text(para(alan(o, 'amount'))),
                      subtitle: Text(
                          '${tarih(o['created_at'])} • ${odeyenler['${o['paid_by']}'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _odemeSil(o),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}