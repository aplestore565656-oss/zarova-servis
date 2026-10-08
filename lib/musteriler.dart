import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ana_menu.dart' show YildizArkaplan;
import 'servisler.dart' show ServisDetaySayfasi, durumRengi;
import 'yardimci.dart';

final _db = Supabase.instance.client;

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

Future<Map<String, dynamic>?> musteriFormuAc(BuildContext context,
    {Map<String, dynamic>? mevcut}) async {
  final ad = TextEditingController(text: mevcut?['full_name'] ?? '');
  final tel = TextEditingController(text: mevcut?['phone'] ?? '');
  final alt = TextEditingController(text: mevcut?['alt_phone'] ?? '');
  final adres = TextEditingController(text: mevcut?['address'] ?? '');
  final not = TextEditingController(text: mevcut?['note'] ?? '');
  String? hata;

  Widget alan0(TextEditingController c, String etiket,
      {TextInputType? tip, int satir = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: tip,
        maxLines: satir,
        decoration:
            InputDecoration(labelText: etiket, border: const OutlineInputBorder()),
      ),
    );
  }

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
                alan0(ad, 'Ad Soyad'),
                alan0(tel, 'Telefon', tip: TextInputType.phone),
                alan0(alt, 'Alternatif telefon', tip: TextInputType.phone),
                alan0(adres, 'Adres', satir: 2),
                alan0(not, 'Not', satir: 2),
                if (hata != null)
                  Text(hata!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              if (ad.text.trim().isEmpty) {
                setS(() => hata = 'Ad Soyad yazın.');
                return;
              }
              final veri = {
                'full_name': ad.text.trim(),
                'phone': tel.text.trim(),
                'alt_phone': alt.text.trim(),
                'address': adres.text.trim(),
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
                setS(() => hata = 'Kaydedilemedi: ${hataMetni(e)}');
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
      final v = await _db
          .from('customers')
          .select()
          .isFilter('deleted_at', null)
          .order('full_name');
      final b = await _db.from('customer_balances').select();
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(v);
        _bakiye = {
          for (final x in List<Map<String, dynamic>>.from(b)) x['customer_id']: x
        };
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Müşteriler alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  double _borc(Map<String, dynamic> m) {
    final b = _bakiye[m['id']];
    return b == null ? 0.0 : alan(b, 'balance');
  }

  double get _toplamAlacak =>
      _liste.fold(0.0, (t, m) => t + (_borc(m) > 0 ? _borc(m) : 0));

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    if (a.isEmpty) return _liste;
    return _liste
        .where((m) =>
            '${m['full_name']} ${m['phone']} ${m['alt_phone']}'
                .toLowerCase()
                .contains(a))
        .toList();
  }

  Future<void> _yeni() async {
    final y = await musteriFormuAc(context);
    if (y != null) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> m) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => MusteriDetaySayfasi(musteri: m)));
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
          child: Text('Müşteri bulunamadı.', style: TextStyle(fontSize: 18)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final m = liste[i];
        final b = _borc(m);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text('${m['full_name']}', style: const TextStyle(fontSize: 18)),
            subtitle: Text('${m['phone']}'),
            trailing: b > 0.004
                ? Text('Borç ${para(b)}',
                    style: const TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold))
                : const Icon(Icons.chevron_right),
            onTap: () => _detay(m),
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
            title: const Text('Müşteriler'),
            actions: [
              IconButton(
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile'),
            ],
          ),
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
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: TextField(
                      onChanged: (v) => setState(() => _arama = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'İsim veya telefon ara',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (!_yukleniyor && _hata == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Card(
                        color: Colors.indigo.withValues(alpha: 0.25),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Müşterilerden toplam alacak',
                                  style: TextStyle(fontSize: 15)),
                              Text(para(_toplamAlacak),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _toplamAlacak > 0
                                          ? Colors.redAccent
                                          : Colors.greenAccent)),
                            ],
                          ),
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

class MusteriDetaySayfasi extends StatefulWidget {
  final Map<String, dynamic> musteri;
  const MusteriDetaySayfasi({super.key, required this.musteri});

  @override
  State<MusteriDetaySayfasi> createState() => _MusteriDetaySayfasiState();
}

class _MusteriDetaySayfasiState extends State<MusteriDetaySayfasi> {
  late Map<String, dynamic> _m = widget.musteri;
  List<Map<String, dynamic>> _servisler = [];
  Map<dynamic, Map<String, dynamic>> _ozet = {};
  Map<String, dynamic>? _bakiye;
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
          .from('service_orders')
          .select()
          .eq('customer_id', _m['id'])
          .isFilter('deleted_at', null)
          .order('received_at', ascending: false);
      final liste = List<Map<String, dynamic>>.from(v);
      Map<dynamic, Map<String, dynamic>> ozet = {};
      if (liste.isNotEmpty) {
        final s = await _db
            .from('service_summary')
            .select()
            .inFilter('service_order_id', liste.map((e) => e['id']).toList());
        ozet = {
          for (final x in List<Map<String, dynamic>>.from(s))
            x['service_order_id']: x
        };
      }
      final b = await _db
          .from('customer_balances')
          .select()
          .eq('customer_id', _m['id'])
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _servisler = liste;
        _ozet = ozet;
        _bakiye = b;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Servisler alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  double _bk(String k) => _bakiye == null ? 0.0 : alan(_bakiye!, k);

  Future<void> _duzenle() async {
    final g = await musteriFormuAc(context, mevcut: _m);
    if (g != null) setState(() => _m = g);
  }

  Future<void> _sil() async {
    if (_bk('balance').abs() > 0.004) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Borcu veya alacağı olan müşteri silinemez.')));
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteri silinsin mi?'),
        content: const Text(
            'Kayıt listeden kalkar ama veritabanında saklanır, geçmiş servisler korunur.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: ${hataMetni(e)}')));
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
    final borc = _bk('balance');
    final alt = '${_m['alt_phone'] ?? ''}'.trim();
    final adres = '${_m['address'] ?? ''}'.trim();
    final not = '${_m['note'] ?? ''}'.trim();
    final ekler = [
      if (alt.isNotEmpty) 'Alternatif: $alt',
      if (adres.isNotEmpty) adres,
      if (not.isNotEmpty) not,
    ].join('\n');
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
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
                      subtitle: ekler.isEmpty ? null : Text(ekler),
                    ),
                  ),
                  Row(
                    children: [
                      _kutu('Toplam ücret', para(_bk('total_charged'))),
                      _kutu('Toplam ödeme', para(_bk('total_paid'))),
                      _kutu('Kalan borç', para(borc),
                          renk: borc > 0.004
                              ? Colors.redAccent
                              : Colors.greenAccent),
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
                    Text(_hata!, style: const TextStyle(color: Colors.redAccent))
                  else if (_servisler.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Bu müşterinin henüz servis kaydı yok.'),
                    )
                  else
                    ..._servisler.map((s) {
                      final o = _ozet[s['id']];
                      final kalan = o == null ? 0.0 : alan(o, 'remaining');
                      final durum = '${s['status']}';
                      return Card(
                        child: ListTile(
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ServisDetaySayfasi(siparis: s)));
                            _yukle();
                          },
                          title: Text(
                              '${s['order_no']} • ${s['brand']} ${s['model']}'
                                  .trim()),
                          subtitle: Text(
                              '${tarih('${s['received_at']}')} • $durum\n${s['problem']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          isThreeLine: true,
                          leading: Icon(Icons.circle,
                              size: 14, color: durumRengi(durum)),
                          trailing: Text(
                            kalan > 0.004 ? 'Kalan ${para(kalan)}' : 'Ödendi',
                            style: TextStyle(
                                color: kalan > 0.004
                                    ? Colors.redAccent
                                    : Colors.greenAccent),
                          ),
                        ),
                      );
                    }),
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