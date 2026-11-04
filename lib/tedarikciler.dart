import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart';
import 'ana_menu.dart' show YildizArkaplan;
import 'tedarikci_ekstre.dart';
import 'tedarikci_kalemler.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

String _usd(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';

String _borcYazi(double b) => b > 0.004
    ? 'Borç ${para(b)}'
    : (b < -0.004 ? 'Alacak ${para(-b)}' : 'Borç yok');

Color _borcRenk(double b) => b > 0.004
    ? Colors.redAccent
    : (b < -0.004 ? Colors.orangeAccent : Colors.greenAccent);

String _kalemAdi(Map<String, dynamic> k) {
  final p = k['products'] as Map<String, dynamic>?;
  final ad = '${p?['name'] ?? ''}'.trim();
  final bm = '${p?['brand'] ?? ''} ${p?['model'] ?? ''}'.trim();
  return bm.isEmpty ? ad : '$ad ($bm)';
}

String _kalemSatiri(Map<String, dynamic> k) {
  final q = tam(k, 'qty');
  final usd = '${k['currency']}' == 'USD';
  final fiyat = usd
      ? '${_usd(alan(k, 'unit_cost_fx'))} → ${para(alan(k, 'unit_cost'))}'
      : para(alan(k, 'unit_cost'));
  return '${_kalemAdi(k)} × $q • $fiyat';
}

Future<Map<String, dynamic>?> tedarikciFormuAc(BuildContext context,
    {Map<String, dynamic>? mevcut}) async {
  final ad = TextEditingController(text: mevcut?['name'] ?? '');
  final tel = TextEditingController(text: mevcut?['phone'] ?? '');
  final adres = TextEditingController(text: mevcut?['address'] ?? '');
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
                  controller: adres,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Adres', border: OutlineInputBorder()),
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
                  Text(hata!, style: const TextStyle(color: Colors.redAccent)),
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
                'address': adres.text.trim(),
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

class TedarikcilerSayfasi extends StatefulWidget {
  const TedarikcilerSayfasi({super.key});

  @override
  State<TedarikcilerSayfasi> createState() => _TedarikcilerSayfasiState();
}

class _TedarikcilerSayfasiState extends State<TedarikcilerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  Map<dynamic, Map<String, dynamic>> _hesap = {};
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
      final b = await _db.from('supplier_accounts').select();
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
        _hesap = {
          for (final x in List<Map<String, dynamic>>.from(b)) x['supplier_id']: x
        };
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Tedarikçiler alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  double _bakiye(Map<String, dynamic> t) {
    final h = _hesap[t['id']];
    return h == null ? 0.0 : alan(h, 'balance');
  }

  double get _toplamBorc => _liste.fold(0.0, (t, s) => t + _bakiye(s));

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
          child: Text('Tedarikçi bulunamadı.', style: TextStyle(fontSize: 18)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final t = liste[i];
        final b = _bakiye(t);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
            title: Text('${t['name']}', style: const TextStyle(fontSize: 18)),
            subtitle: Text('${t['phone']}'),
            trailing: Text(_borcYazi(b),
                style: TextStyle(
                    color: _borcRenk(b), fontWeight: FontWeight.bold)),
            onTap: () => _detay(t),
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
            title: const Text('Tedarikçiler'),
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
            label: const Text('Yeni tedarikçi'),
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
                        hintText: 'Tedarikçi adı veya telefon ara',
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
                              const Text('Toplam tedarikçi borcu',
                                  style: TextStyle(fontSize: 15)),
                              Text(para(_toplamBorc),
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _borcRenk(_toplamBorc))),
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

class TedarikciDetaySayfasi extends StatefulWidget {
  final Map<String, dynamic> tedarikci;
  const TedarikciDetaySayfasi({super.key, required this.tedarikci});

  @override
  State<TedarikciDetaySayfasi> createState() => _TedarikciDetaySayfasiState();
}

class _TedarikciDetaySayfasiState extends State<TedarikciDetaySayfasi> {
  late Map<String, dynamic> _t = widget.tedarikci;
  List<Map<String, dynamic>> _alislar = [];
  Map<String, List<Map<String, dynamic>>> _kalemler = {};
  List<Map<String, dynamic>> _odemeler = [];
  Map<String, dynamic>? _hesap;
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
      final a = List<Map<String, dynamic>>.from(await _db
          .from('purchase_summary')
          .select()
          .eq('supplier_id', _t['id'])
          .order('purchase_date', ascending: false)
          .order('created_at', ascending: false));
      final ids = a.map((x) => '${x['purchase_order_id']}').toList();
      final km = <String, List<Map<String, dynamic>>>{};
      if (ids.isNotEmpty) {
        final k = await _db
            .from('purchase_order_items')
            .select(
                'purchase_order_id, qty, unit_cost, currency, unit_cost_fx, fx_rate, products(name, brand, model)')
            .inFilter('purchase_order_id', ids)
            .isFilter('removed_at', null)
            .order('created_at');
        for (final x in List<Map<String, dynamic>>.from(k)) {
          km.putIfAbsent('${x['purchase_order_id']}', () => []).add(x);
        }
      }
      final o = await _db
          .from('cash_transactions')
          .select()
          .eq('supplier_id', _t['id'])
          .eq('kind', 'tedarikci_odeme')
          .isFilter('voided_at', null)
          .order('tx_date', ascending: false)
          .order('created_at', ascending: false);
      final h = await _db
          .from('supplier_accounts')
          .select()
          .eq('supplier_id', _t['id'])
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _alislar = a;
        _kalemler = km;
        _odemeler = List<Map<String, dynamic>>.from(o);
        _hesap = h;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kayıtlar alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  double get _bakiye => _hesap == null ? 0.0 : alan(_hesap!, 'balance');

  Future<void> _duzenle() async {
    final guncel = await tedarikciFormuAc(context, mevcut: _t);
    if (guncel != null) setState(() => _t = guncel);
  }

  Future<void> _ekstre() async {
    final gun = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ekstre dönemi'),
        children: [
          for (final e in {
            0: 'Tüm hareketler',
            30: 'Son 30 gün',
            60: 'Son 60 gün',
            90: 'Son 90 gün',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(e.value, style: const TextStyle(fontSize: 17)),
              ),
            ),
        ],
      ),
    );
    if (gun == null || !mounted) return;
    await tedarikciEkstresiYazdir(context, _t, gun);
  }

  Future<void> _sil() async {
    if (_bakiye.abs() > 0.004) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Borcu veya alacağı olan tedarikçi silinemez.')));
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tedarikçi silinsin mi?'),
        content: const Text(
            'Kayıt listeden kalkar ama veritabanında saklanır, geçmiş alışlar korunur.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Silinemedi: ${hataMetni(e)}')));
    }
  }

  Future<void> _odemeYap() async {
    final bakiyeKurus = (_bakiye * 100).round();
    if (bakiyeKurus <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu tedarikçiye borcunuz görünmüyor.')));
      return;
    }
    final tutar = TextEditingController();
    final not = TextEditingController();
    String yontem = 'nakit';
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
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Tutar',
                      suffixText: '₺',
                      helperText: 'Kalan borç: ${para(bakiyeKurus / 100)}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: odemeYontemleri.entries
                        .map((e) => ChoiceChip(
                              label: Text(e.value),
                              selected: yontem == e.key,
                              onSelected: (_) => setS(() => yontem = e.key),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: not,
                    decoration: const InputDecoration(
                        labelText: 'Not', border: OutlineInputBorder()),
                  ),
                  if (hata != null) ...[
                    const SizedBox(height: 12),
                    Text(hata!,
                        style: const TextStyle(color: Colors.redAccent)),
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
                final kurus = (sayi(tutar.text) * 100).round();
                if (kurus <= 0) {
                  setS(() => hata = 'Tutarı yazın.');
                  return;
                }
                if (kurus > bakiyeKurus) {
                  setS(() => hata =
                      'Ödeme, kalan borçtan (${para(bakiyeKurus / 100)}) fazla olamaz.');
                  return;
                }
                try {
                  await _db.from('cash_transactions').insert({
                    'tx_date': bugunTarih(),
                    'direction': 'cikis',
                    'kind': 'tedarikci_odeme',
                    'section': 'genel',
                    'amount': kurus / 100,
                    'method': yontem,
                    'description': not.text.trim(),
                    'supplier_id': _t['id'],
                  });
                  if (ctx.mounted) Navigator.pop(ctx, true);
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
    if (tamam == true) _yukle();
  }

  Future<void> _odemeIptal(Map<String, dynamic> o) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödeme iptal edilsin mi?'),
        content: const Text(
            'Tedarikçi borcu ve kasa buna göre yeniden hesaplanır. Kayıt silinmez, iptal olarak saklanır.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ödemeyi iptal et')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await _db.from('cash_transactions').update({
        'voided_at': DateTime.now().toUtc().toIso8601String(),
        'void_reason': 'Kullanıcı iptal etti',
      }).eq('id', o['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İptal edilemedi: ${hataMetni(e)}')));
    }
  }

  Future<void> _alisEkle() async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AlisFormu(bolum: 'teknik', tedarikci: _t)),
    );
    if (s == true) _yukle();
  }

  Future<void> _alisDetay(Map<String, dynamic> a) async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AlisDetaySayfasi(alis: a)),
    );
    if (s == true) _yukle();
  }

  Widget _kutu(String baslik, String deger, {Color? renk}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(baslik,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
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

  Widget _alisKarti(Map<String, dynamic> a) {
    final kalemler = _kalemler['${a['purchase_order_id']}'] ?? const [];
    final usdToplam = kalemler
        .where((k) => '${k['currency']}' == 'USD')
        .fold<double>(0.0, (s, k) => s + tam(k, 'qty') * alan(k, 'unit_cost_fx'));
    return Card(
      child: ListTile(
        onTap: () => _alisDetay(a),
        isThreeLine: kalemler.length > 1,
        title: Text(tarih('${a['purchase_date']}'),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          kalemler.isEmpty
              ? '${tam(a, 'item_count')} kalem'
              : kalemler.map(_kalemSatiri).join('\n'),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(para(alan(a, 'total')),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            if (usdToplam > 0)
              Text(_usd(usdToplam),
                  style: const TextStyle(
                      fontSize: 12, color: Colors.greenAccent)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alisToplam = _hesap == null ? 0.0 : alan(_hesap!, 'total_purchase');
    final odemeToplam = _hesap == null ? 0.0 : alan(_hesap!, 'total_paid');
    final b = _bakiye;
    final adres = '${_t['address'] ?? ''}'.trim();
    final not = '${_t['note'] ?? ''}'.trim();
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text('${_t['name']}'),
            actions: [
              IconButton(
                  onPressed: _ekstre,
                  icon: const Icon(Icons.print),
                  tooltip: 'Hesap ekstresi (PDF)'),
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
                      subtitle: (adres.isEmpty && not.isEmpty)
                          ? null
                          : Text([adres, not]
                              .where((e) => e.isNotEmpty)
                              .join('\n')),
                    ),
                  ),
                  Row(
                    children: [
                      _kutu('Toplam alış', para(alisToplam)),
                      _kutu('Toplam ödeme', para(odemeToplam)),
                      _kutu(b < -0.004 ? 'Alacağınız' : 'Kalan borç',
                          para(b.abs()),
                          renk: _borcRenk(b)),
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
                              label: const Text('Alış ekle'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _ekstre,
                      icon: const Icon(Icons.print),
                      label: const Text('Hesap ekstresi çıkar (toptancıyla karşılaştır)'),
                    ),
                  ),
                  if (_yukleniyor)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_hata != null)
                    Text(_hata!, style: const TextStyle(color: Colors.redAccent))
                  else ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text('Aldığımız malzemeler',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (_alislar.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Henüz alış kaydı yok.'),
                      ),
                    MalzemeListesi(tedarikci: _t, bakiye: _bakiye, degisti: _yukle),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: Text('Ödemeler',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (_odemeler.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Henüz ödeme kaydı yok.'),
                      ),
                    ..._odemeler.map((o) {
                      final alisla = o['purchase_order_id'] != null;
                      final aciklama = '${o['description'] ?? ''}'.trim();
                      return Card(
                        child: ListTile(
                          title: Text(para(alan(o, 'amount'))),
                          subtitle: Text(
                              '${tarih('${o['tx_date']}')} • ${odemeYontemleri['${o['method']}'] ?? ''}${alisla ? ' • alış sırasında' : ''}${aciklama.isEmpty ? '' : '\n$aciklama'}'),
                          trailing: alisla
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Ödemeyi iptal et',
                                  onPressed: () => _odemeIptal(o),
                                ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}