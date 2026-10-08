import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri;
import 'ortak.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;
const _durumlar = ['Beklemede', 'Parçalanıyor', 'Parçalandı'];

Color _renk(String d) {
  switch (d) {
    case 'Beklemede':
      return Colors.orangeAccent;
    case 'Parçalanıyor':
      return Colors.lightBlueAccent;
    case 'Parçalandı':
      return Colors.purpleAccent;
    default:
      return Colors.greenAccent;
  }
}

String _ad(Map<String, dynamic> h) => '${h['brand']} ${h['model']}'.trim();
String _gun(DateTime d) => d.toIso8601String().substring(0, 10);

class HurdaSayfasi extends StatefulWidget {
  const HurdaSayfasi({super.key});

  @override
  State<HurdaSayfasi> createState() => _HurdaSayfasiState();
}

class _HurdaSayfasiState extends State<HurdaSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yuk = true;
  String? _hata;
  bool _hepsi = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yuk = true;
      _hata = null;
    });
    try {
      final v = await _db
          .from('scrap_devices')
          .select()
          .isFilter('deleted_at', null)
          .order('acquired_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(500);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(v);
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Hurdalar alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const HurdaFormu()));
    if (s == true) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> h) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => HurdaDetay(hurda: h)));
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final gorunen =
        _hepsi ? _liste : _liste.where((h) => h['status'] != 'Satıldı').toList();
    final maliyet = gorunen.fold(0.0, (t, h) => t + alan(h, 'cost'));
    final tahmin = gorunen
        .where((h) => h['status'] != 'Satıldı')
        .fold(0.0, (t, h) => t + alan(h, 'estimated_value'));
    return Sayfa(
      baslik: 'Hurda Cihazlar',
      actions: [
        IconButton(
            onPressed: _yukle,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile'),
      ],
      fab: FloatingActionButton.extended(
        onPressed: _yeni,
        icon: const Icon(Icons.add),
        label: const Text('Yeni hurda'),
      ),
      govde: durumGovdesi(
        yukleniyor: _yuk,
        hata: _hata,
        tekrar: _yukle,
        govde: () => ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: [
            Card(
              color: Colors.indigo.withValues(alpha: 0.25),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${gorunen.length} cihaz'),
                    Text('Maliyet ${para(maliyet)}'),
                    Text('Tahmini ${para(tahmin)}'),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Satılanları da göster'),
                selected: _hepsi,
                onSelected: (v) => setState(() => _hepsi = v),
              ),
            ),
            if (gorunen.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Hurda cihaz yok.',
                        style: TextStyle(fontSize: 16))),
              ),
            ...gorunen.map((h) {
              final d = '${h['status']}';
              final kaynak = '${h['source'] ?? ''}'.trim();
              return Card(
                child: ListTile(
                  onTap: () => _detay(h),
                  title: Text(_ad(h), style: const TextStyle(fontSize: 17)),
                  subtitle: Text(
                      '${tarih('${h['acquired_at']}')}${kaynak.isEmpty ? '' : ' • $kaynak'} • Maliyet ${para(alan(h, 'cost'))}'),
                  trailing: Text(d,
                      style: TextStyle(
                          color: _renk(d),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class HurdaFormu extends StatefulWidget {
  final Map<String, dynamic>? hurda;
  const HurdaFormu({super.key, this.hurda});

  @override
  State<HurdaFormu> createState() => _HurdaFormuState();
}

class _HurdaFormuState extends State<HurdaFormu> {
  String _t(String k) => (widget.hurda?[k] ?? '').toString();
  bool get _yeni => widget.hurda == null;

  late final _marka = TextEditingController(text: _t('brand'));
  late final _model = TextEditingController(text: _t('model'));
  late final _imei = TextEditingController(text: _t('imei'));
  late final _kaynak = TextEditingController(text: _t('source'));
  late final _maliyet =
      TextEditingController(text: sayiYaz(widget.hurda?['cost']));
  late final _tahmin =
      TextEditingController(text: sayiYaz(widget.hurda?['estimated_value']));
  late final _parcalar = TextEditingController(text: _t('usable_parts'));
  late final _not = TextEditingController(text: _t('note'));
  late DateTime _tarih =
      DateTime.tryParse(_t('acquired_at')) ?? DateTime.now();
  late String _durum = widget.hurda?['status'] ?? 'Beklemede';
  bool _kasadan = true;
  String _yontem = 'nakit';
  bool _kay = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in [
      _marka, _model, _imei, _kaynak, _maliyet, _tahmin, _parcalar, _not,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_marka.text.trim().isEmpty && _model.text.trim().isEmpty) {
      setState(() => _hata = 'Marka veya model yazın.');
      return;
    }
    setState(() {
      _kay = true;
      _hata = null;
    });
    try {
      if (_yeni) {
        await _db.rpc('create_scrap', params: {
          'p_brand': _marka.text.trim(),
          'p_model': _model.text.trim(),
          'p_imei': _imei.text.trim(),
          'p_source': _kaynak.text.trim(),
          'p_date': _gun(_tarih),
          'p_cost': sayi(_maliyet.text),
          'p_estimated': sayi(_tahmin.text),
          'p_usable': _parcalar.text.trim(),
          'p_note': _not.text.trim(),
          'p_pay': _kasadan,
          'p_method': _yontem,
        });
      } else {
        final Map<String, dynamic> veri = {
          'brand': _marka.text.trim(),
          'model': _model.text.trim(),
          'imei': _imei.text.trim(),
          'source': _kaynak.text.trim(),
          'acquired_at': _gun(_tarih),
          'estimated_value': sayi(_tahmin.text),
          'usable_parts': _parcalar.text.trim(),
          'note': _not.text.trim(),
        };
        if (_durum != 'Satıldı') veri['status'] = _durum;
        await _db
            .from('scrap_devices')
            .update(veri)
            .eq('id', widget.hurda!['id']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kaydedilemedi: ${hataMetni(e)}';
        _kay = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: _yeni ? 'Yeni hurda cihaz' : 'Hurdayı düzenle',
      govde: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          girdi(_marka, 'Marka'),
          girdi(_model, 'Model'),
          girdi(_imei, 'IMEI'),
          girdi(_kaynak, 'Kimden / nereden geldi'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Geliş tarihi: ${tarih(_tarih.toIso8601String())}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final t = await tarihSec(context, _tarih);
                if (t != null) setState(() => _tarih = t);
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_yeni) girdi(_maliyet, 'Alış değeri (maliyet)', sayiMi: true, tl: true),
          girdi(_tahmin, 'Tahmini değer', sayiMi: true, tl: true),
          girdi(_parcalar, 'Kullanılabilir parçalar (not)', satir: 2),
          if (_yeni) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alış parasını kasadan öde'),
              subtitle: const Text('Kasaya gider olarak yazılır'),
              value: _kasadan,
              onChanged: (v) => setState(() => _kasadan = v),
            ),
            if (_kasadan)
              Wrap(
                spacing: 8,
                children: odemeYontemleri.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _yontem == e.key,
                          onSelected: (_) => setState(() => _yontem = e.key),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 12),
          ] else if (_durum != 'Satıldı') ...[
            const Text('Durum', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _durumlar
                  .map((d) => ChoiceChip(
                        label: Text(d),
                        selected: _durum == d,
                        onSelected: (_) => setState(() => _durum = d),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          girdi(_not, 'Not', satir: 2),
          hataYazisi(_hata),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _kay ? null : _kaydet,
              child: _kay
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
    );
  }
}

class HurdaDetay extends StatefulWidget {
  final Map<String, dynamic> hurda;
  const HurdaDetay({super.key, required this.hurda});

  @override
  State<HurdaDetay> createState() => _HurdaDetayState();
}

class _HurdaDetayState extends State<HurdaDetay> {
  Map<String, dynamic>? _h;
  List<Map<String, dynamic>> _parcalar = [];
  bool _yuk = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final id = widget.hurda['id'];
      final h = await _db.from('scrap_devices').select().eq('id', id).single();
      final p = await _db
          .from('scrap_parts')
          .select('*, products(name, brand, model)')
          .eq('scrap_id', id)
          .order('created_at');
      if (!mounted) return;
      setState(() {
        _h = h;
        _parcalar = List<Map<String, dynamic>>.from(p);
        _yuk = false;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Hurda bilgisi alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  Future<void> _duzenle() async {
    final s = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => HurdaFormu(hurda: _h)));
    if (s == true) _yukle();
  }

  Future<void> _sil() async {
    final ok = await onayAl(
        context,
        'Hurda kaydı silinsin mi?',
        'Kayıt listeden kalkar, kasadaki alış/satış kayıtları iptal edilir. Stoğa girmiş parçalar stokta kalır.',
        'Sil');
    if (!ok) return;
    try {
      await _db.rpc('delete_scrap', params: {'p_id': _h!['id']});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      bildir(context, 'Silinemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _parcaEkle() async {
    try {
      final veri = await _db
          .from('products')
          .select('id, name, brand, model, stock')
          .eq('section', 'teknik')
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
      final p = await secimPenceresi(context,
          baslik: 'Stoğa girecek parça (yoksa önce Stok bölümünde açın)',
          liste: liste,
          ana: 'etiket',
          alt: 'stokYazi');
      if (p == null || !mounted) return;
      final adet = await adetSor(context, 'Kaç adet stoğa girsin?');
      if (adet == null) return;
      await _db.rpc('add_scrap_part', params: {
        'p_scrap': _h!['id'],
        'p_product': p['id'],
        'p_qty': adet,
      });
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      bildir(context, 'Eklenemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _sat() async {
    final r = await tutarSor(context, 'Satış fiyatı',
        ilk: sayiYaz(_h!['estimated_value']));
    if (r == null) return;
    try {
      await _db.rpc('sell_scrap', params: {
        'p_id': _h!['id'],
        'p_price': r['tutar'],
        'p_method': r['yontem'],
      });
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      bildir(context, 'Satış kaydedilemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _geriAl() async {
    final ok = await onayAl(context, 'Satış geri alınsın mı?',
        'Cihaz tekrar satılmamış olur, kasadaki satış girişi iptal edilir.', 'Geri al');
    if (!ok) return;
    try {
      await _db.rpc('unsell_scrap', params: {'p_id': _h!['id']});
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      bildir(context, 'Geri alınamadı: ${hataMetni(e)}');
    }
  }

  Widget _bilgi(String a, dynamic v) {
    final t = '${v ?? ''}'.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(a, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(t, style: const TextStyle(fontSize: 15)),
    );
  }

  Widget _icerik(Map<String, dynamic> h) {
    final satildi = h['status'] == 'Satıldı';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Column(
            children: [
              _bilgi('Durum', h['status']),
              _bilgi('IMEI', h['imei']),
              _bilgi('Nereden geldi', h['source']),
              _bilgi('Geliş tarihi', tarih('${h['acquired_at']}')),
              _bilgi('Alış değeri', para(alan(h, 'cost'))),
              _bilgi('Tahmini değer', para(alan(h, 'estimated_value'))),
              _bilgi('Kullanılabilir parçalar', h['usable_parts']),
              if (satildi)
                _bilgi('Satış',
                    '${para(alan(h, 'sale_price'))} • ${tarih('${h['sold_at']}')}'),
              _bilgi('Not', h['note']),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _parcaEkle,
                  icon: const Icon(Icons.memory),
                  label: const Text('Parça stoğa ekle'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: satildi
                    ? OutlinedButton.icon(
                        onPressed: _geriAl,
                        icon: const Icon(Icons.undo),
                        label: const Text('Satışı geri al'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _sat,
                        icon: const Icon(Icons.sell),
                        label: const Text('Cihazı sat'),
                      ),
              ),
            ),
          ],
        ),
        bolumBasligi('Stoğa giren parçalar'),
        if (_parcalar.isEmpty)
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Bu cihazdan henüz parça stoğa eklenmedi.')),
        ..._parcalar.map((p) {
          final pr = p['products'] as Map<String, dynamic>?;
          return Card(
            child: ListTile(
              title: Text(
                  '${pr?['name'] ?? ''} ${pr?['brand'] ?? ''} ${pr?['model'] ?? ''}'
                      .trim()),
              trailing: Text('${tam(p, 'qty')} adet',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _h;
    return Sayfa(
      baslik: _ad(widget.hurda),
      actions: [
        IconButton(
            onPressed: h == null ? null : _duzenle,
            icon: const Icon(Icons.edit),
            tooltip: 'Düzenle'),
        IconButton(
            onPressed: h == null ? null : _sil,
            icon: const Icon(Icons.delete),
            tooltip: 'Sil'),
      ],
      govde: durumGovdesi(
        yukleniyor: _yuk,
        hata: _hata,
        tekrar: _yukle,
        govde: () => _icerik(h!),
      ),
    );
  }
}