import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

/// Müşteri ekleme/düzenleme penceresi. Kaydedilen müşteriyi geri verir.
Future<Map<String, dynamic>?> musteriFormuAc(BuildContext context,
    {Map<String, dynamic>? mevcut}) async {
  final ad = TextEditingController(text: mevcut?['full_name'] ?? '');
  final tel = TextEditingController(text: mevcut?['phone'] ?? '');
  final not = TextEditingController(text: mevcut?['note'] ?? '');
  String? hata;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(mevcut == null ? 'Yeni müşteri' : 'Müşteriyi düzenle'),
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
                      labelText: 'Ad Soyad', border: OutlineInputBorder()),
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
                setS(() => hata = 'Ad Soyad yazın.');
                return;
              }
              final veri = {
                'full_name': ad.text.trim(),
                'phone': tel.text.trim(),
                'note': not.text.trim(),
              };
              try {
                final Map<String, dynamic> satir = mevcut == null
                    ? await _db.from('customers').insert(veri).select().single()
                    : await _db
                        .from('customers')
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

class MusterilerSayfasi extends StatefulWidget {
  const MusterilerSayfasi({super.key});

  @override
  State<MusterilerSayfasi> createState() => _MusterilerSayfasiState();
}

class _MusterilerSayfasiState extends State<MusterilerSayfasi> {
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
          .from('customers')
          .select()
          .isFilter('deleted_at', null)
          .order('full_name');
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Müşteriler alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    if (a.isEmpty) return _liste;
    return _liste.where((m) {
      final metin = '${m['full_name']} ${m['phone']}'.toLowerCase();
      return metin.contains(a);
    }).toList();
  }

  Future<void> _yeni() async {
    final yeni = await musteriFormuAc(context);
    if (yeni != null) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> m) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MusteriDetaySayfasi(musteri: m)),
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
        child: Text('Müşteri bulunamadı.', style: TextStyle(fontSize: 18)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final m = liste[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('${m['full_name']}',
                style: const TextStyle(fontSize: 18)),
            subtitle: Text('${m['phone']}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _detay(m),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteriler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yeni,
        icon: const Icon(Icons.person_add),
        label: const Text('Yeni müşteri'),
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
                    hintText: 'İsim veya telefon ara',
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

class MusteriDetaySayfasi extends StatefulWidget {
  final Map<String, dynamic> musteri;
  const MusteriDetaySayfasi({super.key, required this.musteri});

  @override
  State<MusteriDetaySayfasi> createState() => _MusteriDetaySayfasiState();
}

class _MusteriDetaySayfasiState extends State<MusteriDetaySayfasi> {
  late Map<String, dynamic> _m = widget.musteri;
  List<Map<String, dynamic>> _servisler = [];
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
          .from('service_records')
          .select()
          .eq('customer_id', _m['id'])
          .isFilter('deleted_at', null)
          .order('service_no', ascending: false);
      if (!mounted) return;
      setState(() {
        _servisler = List<Map<String, dynamic>>.from(veri);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Servisler alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  double _topla(String anahtar) => _servisler
      .where((s) => s['status'] != 'İptal')
      .fold(0.0, (t, s) => t + alan(s, anahtar));

  Future<void> _duzenle() async {
    final guncel = await musteriFormuAc(context, mevcut: _m);
    if (guncel != null) setState(() => _m = guncel);
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteri silinsin mi?'),
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
          .from('customers')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _m['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
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
    final toplam = _topla('total');
    final odenen = _topla('paid');
    final kalan = toplam - odenen;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_m['full_name']}'),
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
                  title: Text('${_m['phone']}'.isEmpty
                      ? 'Telefon yok'
                      : '${_m['phone']}'),
                  subtitle: '${_m['note']}'.isEmpty ? null : Text('${_m['note']}'),
                ),
              ),
              Row(
                children: [
                  _kutu('Toplam ücret', para(toplam)),
                  _kutu('Ödenen', para(odenen)),
                  _kutu('Kalan borç', para(kalan),
                      renk: kalan > 0 ? Colors.red : Colors.green),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text('Geçmiş servisler',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (_yukleniyor)
                const Center(child: CircularProgressIndicator())
              else if (_hata != null)
                Text(_hata!, style: const TextStyle(color: Colors.red))
              else if (_servisler.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Bu müşterinin henüz servis kaydı yok.'),
                )
              else
                ..._servisler.map(
                  (s) => Card(
                    child: ListTile(
                      title: Text(
                          'No ${s['service_no']} • ${s['brand']} ${s['model']}'),
                      subtitle: Text(
                          '${tarih(s['created_at'])} • ${s['status']}'),
                      trailing: Text(
                        alan(s, 'remaining') > 0
                            ? 'Kalan ${para(alan(s, 'remaining'))}'
                            : 'Ödendi',
                        style: TextStyle(
                          color: alan(s, 'remaining') > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}