import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri;
import 'kur.dart' show dolarKuruGetir;
import 'ortak.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;
String _gun(DateTime d) => d.toIso8601String().substring(0, 10);

int _d4(String s) => (sayi(s) * 10000).round();
int _kurus(String s) => (sayi(s) * 100).round();
int _tlHesap(String usd, String kur) =>
    (_d4(usd) * _d4(kur) + 500000) ~/ 1000000;
String _usd(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';

String _sonucYazi(String tur, String s) {
  if (s == 'degisim') return 'Değişim';
  if (s == 'cari') return 'Tedarikçi borcundan düşüldü';
  return tur == 'tedarikci' ? 'Para geri geldi' : 'Müşteriye para iade edildi';
}

class IadelerSayfasi extends StatefulWidget {
  const IadelerSayfasi({super.key});

  @override
  State<IadelerSayfasi> createState() => _IadelerSayfasiState();
}

class _IadelerSayfasiState extends State<IadelerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yuk = true;
  String? _hata;
  String? _tur;

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
          .from('return_list')
          .select()
          .order('return_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(v);
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'İadeler alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const IadeFormu()));
    if (s == true) _yukle();
  }

  Future<void> _iptal(Map<String, dynamic> r) async {
    final ok = await onayAl(
        context,
        'İade iptal edilsin mi?',
        'Stok hareketleri geri alınır, kasadaki iade kaydı ve tedarikçi borç düzeltmesi iptal edilir. Kayıt silinmez.',
        'İptal et');
    if (!ok) return;
    try {
      await _db.rpc('void_return', params: {'p_id': r['id']});
      _yukle();
    } catch (e) {
      if (!mounted) return;
      bildir(context, 'İptal edilemedi: ${hataMetni(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste =
        _tur == null ? _liste : _liste.where((r) => r['kind'] == _tur).toList();
    return Sayfa(
      baslik: 'İadeler',
      actions: [
        IconButton(
            onPressed: _yukle,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile'),
      ],
      fab: FloatingActionButton.extended(
        onPressed: _yeni,
        icon: const Icon(Icons.add),
        label: const Text('Yeni iade'),
      ),
      govde: durumGovdesi(
        yukleniyor: _yuk,
        hata: _hata,
        tekrar: _yukle,
        govde: () => ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('Tümü'),
                    selected: _tur == null,
                    onSelected: (_) => setState(() => _tur = null)),
                ChoiceChip(
                    label: const Text('Tedarikçiye iade'),
                    selected: _tur == 'tedarikci',
                    onSelected: (_) => setState(() => _tur = 'tedarikci')),
                ChoiceChip(
                    label: const Text('Müşteri iadesi'),
                    selected: _tur == 'musteri',
                    onSelected: (_) => setState(() => _tur = 'musteri')),
              ],
            ),
            if (liste.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('İade kaydı yok.',
                        style: TextStyle(fontSize: 16))),
              ),
            ...liste.map((r) {
              final tur = '${r['kind']}';
              final kisi = tur == 'tedarikci'
                  ? '${r['supplier_name'] ?? ''}'
                  : '${r['customer_name'] ?? ''}';
              final neden = '${r['reason'] ?? ''}'.trim();
              final not = '${r['note'] ?? ''}'.trim();
              final tutar = alan(r, 'amount');
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  isThreeLine: true,
                  leading: CircleAvatar(
                    child: Icon(tur == 'tedarikci'
                        ? Icons.local_shipping
                        : Icons.person),
                  ),
                  title: Text('${r['product_name']} × ${tam(r, 'qty')}',
                      style: const TextStyle(fontSize: 16)),
                  subtitle: Text(
                      '${tur == 'tedarikci' ? 'Tedarikçiye iade' : 'Müşteri iadesi'}${kisi.isEmpty ? '' : ' • $kisi'} • ${tarih('${r['return_date']}')}\n${_sonucYazi(tur, '${r['outcome']}')}${neden.isEmpty ? '' : ' • $neden'}${not.isEmpty ? '\n$not' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tutar > 0)
                        Text(para(tutar),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'İptal et',
                        onPressed: () => _iptal(r),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class IadeFormu extends StatefulWidget {
  const IadeFormu({super.key});

  @override
  State<IadeFormu> createState() => _IadeFormuState();
}

class _IadeFormuState extends State<IadeFormu> {
  String _tur = 'tedarikci';
  String? _tedId, _tedAd, _musId, _musAd, _urunId, _urunAd, _yedekId, _yedekAd;
  final _adet = TextEditingController(text: '1');
  final _tutar = TextEditingController();
  final _kur = TextEditingController();
  final _neden = TextEditingController();
  final _not = TextEditingController();
  String _sonuc = 'cari';
  String _yontem = 'nakit';
  DateTime _tarih = DateTime.now();
  bool _dolar = false;
  bool _tutarElle = false;
  bool _kurYuk = false;
  String _ilkKur = '';
  String? _kurNotu;
  double _urunTl = 0;
  double _urunUsd = 0;
  bool _kay = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in [_adet, _tutar, _kur, _neden, _not]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _ted => _tur == 'tedarikci';
  int get _adetSayi => tamSayi(_adet.text);

  int get _tutarKurus {
    if (_sonuc == 'degisim') return 0;
    if (!_dolar) return _kurus(_tutar.text);
    final adet = _adetSayi;
    if (_urunUsd > 0 &&
        _urunTl > 0 &&
        _kur.text == _ilkKur &&
        _d4(_tutar.text) == (_urunUsd * 10000).round() * adet) {
      return adet * (_urunTl * 100).round();
    }
    return _tlHesap(_tutar.text, _kur.text);
  }

  void _otoDoldur() {
    if (_tutarElle || !_ted || _urunId == null) return;
    final adet = _adetSayi;
    if (adet <= 0) return;
    if (_dolar && _urunUsd > 0) {
      _tutar.text = sayiYaz(((_urunUsd * adet) * 10000).round() / 10000);
      if (_ilkKur.isNotEmpty) _kur.text = _ilkKur;
    } else if (!_dolar && _urunTl > 0) {
      _tutar.text = sayiYaz(((_urunTl * adet) * 100).round() / 100);
    }
  }

  void _turDegis(String t) => setState(() {
        _tur = t;
        _sonuc = t == 'tedarikci' ? 'cari' : 'para';
        if (t != 'tedarikci') _dolar = false;
        _tutarElle = false;
        _tutar.text = '';
        _otoDoldur();
      });

  void _paraBirimi(bool d) {
    if (_dolar == d) return;
    setState(() {
      _dolar = d;
      _tutarElle = false;
      _tutar.text = '';
      _otoDoldur();
    });
    if (d && _kur.text.trim().isEmpty) _kurGetir();
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
        _kurNotu =
            'Güncel kur (${k.tarih}). Alış günündeki kurdan farklıysa borçta küçük fark kalabilir.';
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

  Future<void> _musteriSec() async {
    try {
      final v = await _db
          .from('customers')
          .select('id, full_name, phone')
          .isFilter('deleted_at', null)
          .order('full_name');
      if (!mounted) return;
      final s = await secimPenceresi(context,
          baslik: 'Müşteri seç',
          liste: List<Map<String, dynamic>>.from(v),
          ana: 'full_name',
          alt: 'phone');
      if (s != null) {
        setState(() {
          _musId = s['id'];
          _musAd = s['full_name'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Müşteriler alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _urunSec(bool yedek) async {
    try {
      final v = await _db
          .from('products')
          .select('id, name, brand, model, stock, buy_price, buy_price_usd')
          .eq('section', 'teknik')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final liste = List<Map<String, dynamic>>.from(v)
          .map((p) => {
                ...p,
                'etiket': '${p['name']} ${p['brand']} ${p['model']}'.trim(),
                'stokYazi': 'Stok: ${tam(p, 'stock')} adet',
              })
          .toList();
      final p = await secimPenceresi(context,
          baslik: yedek ? 'Değişimdeki yeni parça' : 'İade edilen parça',
          liste: liste,
          ana: 'etiket',
          alt: 'stokYazi');
      if (p == null) return;
      setState(() {
        if (yedek) {
          _yedekId = p['id'];
          _yedekAd = p['etiket'];
        } else {
          _urunId = p['id'];
          _urunAd = p['etiket'];
          _urunTl = alan(p, 'buy_price');
          _urunUsd = alan(p, 'buy_price_usd');
          _ilkKur = (_urunUsd > 0 && _urunTl > 0)
              ? (_urunTl / _urunUsd).toStringAsFixed(4).replaceAll('.', ',')
              : '';
          if (_ted) _dolar = _urunUsd > 0;
          _tutarElle = false;
          _otoDoldur();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Parçalar alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _kaydet() async {
    if (_ted && _tedId == null) {
      setState(() => _hata = 'Önce tedarikçi seçin.');
      return;
    }
    if (_urunId == null) {
      setState(() => _hata = 'Önce iade edilen parçayı seçin.');
      return;
    }
    if (_adetSayi <= 0) {
      setState(() => _hata = 'Adet 1 veya daha fazla olmalı.');
      return;
    }
    final dolarIade = _ted && _dolar && _sonuc != 'degisim';
    if (_sonuc != 'degisim' && _tutarKurus <= 0) {
      setState(() => _hata = 'İade tutarını yazın.');
      return;
    }
    if (dolarIade && _d4(_kur.text) <= 0) {
      setState(() => _hata = 'Dolar kurunu yazın.');
      return;
    }
    setState(() {
      _kay = true;
      _hata = null;
    });
    final notMetni = [
      _not.text.trim(),
      if (dolarIade)
        'Dolar iade: ${_usd(_d4(_tutar.text) / 10000)} × kur ${(_d4(_kur.text) / 10000).toStringAsFixed(4).replaceAll('.', ',')}',
    ].where((e) => e.isNotEmpty).join(' | ');
    try {
      await _db.rpc('create_return', params: {
        'p_kind': _tur,
        'p_supplier': _ted ? _tedId : null,
        'p_customer': !_ted ? _musId : null,
        'p_product': _urunId,
        'p_qty': _adetSayi,
        'p_amount': _tutarKurus / 100,
        'p_reason': _neden.text.trim(),
        'p_outcome': _sonuc,
        'p_replacement': _sonuc == 'degisim' ? _yedekId : null,
        'p_date': _gun(_tarih),
        'p_note': notMetni,
        'p_method': _yontem,
      });
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

  Widget _secKart(IconData ikon, String metin, VoidCallback ac) => Card(
        child: ListTile(
          leading: Icon(ikon),
          title: Text(metin),
          trailing: const Icon(Icons.search),
          onTap: ac,
        ),
      );

  List<Widget> _tutarAlani() {
    final dolarMod = _ted && _dolar;
    return [
      if (_ted)
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Dolar (\$)'),
              selected: _dolar,
              onSelected: (_) => _paraBirimi(true),
            ),
            ChoiceChip(
              label: const Text('Türk Lirası (₺)'),
              selected: !_dolar,
              onSelected: (_) => _paraBirimi(false),
            ),
          ],
        ),
      const SizedBox(height: 10),
      TextField(
        controller: _tutar,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() => _tutarElle = true),
        decoration: InputDecoration(
          labelText: !_ted
              ? 'İade tutarı (müşteriye, ₺)'
              : (dolarMod ? 'İade tutarı (dolar)' : 'İade tutarı (₺)'),
          suffixText: dolarMod ? '\$' : '₺',
          border: const OutlineInputBorder(),
        ),
      ),
      if (dolarMod) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _kur,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
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
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _kurNotu ??
                (_ilkKur.isNotEmpty && _kur.text == _ilkKur
                    ? 'Alış günündeki kur yazıldı. Değiştirmezseniz borç tam kapanır.'
                    : 'Kuru değiştirirseniz borçta küçük fark kalabilir.'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'TL karşılığı: ${para(_tutarKurus / 100)}${_ted ? ' (borçtan bu kadar düşer)' : ''}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
      if (_ted && _urunId != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Kayıtlı alış: ${_urunUsd > 0 ? '${_usd(_urunUsd)} • ' : ''}${para(_urunTl)} (birim)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      if (_sonuc == 'para') ...[
        const SizedBox(height: 10),
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
      ],
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sonuclar = _ted
        ? const {
            'cari': 'Borçtan düşüldü',
            'para': 'Para geri geldi',
            'degisim': 'Değişim'
          }
        : const {'para': 'Para iade edildi', 'degisim': 'Değişim'};
    final bilgi = _ted
        ? (_sonuc == 'cari'
            ? 'Parça stoktan düşer, iade tutarı tedarikçiye olan borcunuzdan düşülür.'
            : (_sonuc == 'para'
                ? 'Parça stoktan düşer, tedarikçi borcu düşer ve iade parası kasaya girer.'
                : 'Eski parça stoktan düşer, yeni parça stoğa girer. Borç ve kasa değişmez.'))
        : (_sonuc == 'para'
            ? 'Parça stoğa geri girer ve iade tutarı kasadan çıkar.'
            : 'İade edilen parça stoğa girer, verilen yeni parça stoktan düşer.');
    return Sayfa(
      baslik: 'Yeni iade',
      govde: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                  label: const Text('Tedarikçiye iade'),
                  selected: _ted,
                  onSelected: (_) => _turDegis('tedarikci')),
              ChoiceChip(
                  label: const Text('Müşteriden iade'),
                  selected: !_ted,
                  onSelected: (_) => _turDegis('musteri')),
            ],
          ),
          const SizedBox(height: 12),
          if (_ted)
            _secKart(Icons.local_shipping, _tedAd ?? 'Tedarikçi seçin',
                _tedarikciSec)
          else
            _secKart(Icons.person, _musAd ?? 'Müşteri seçin (isteğe bağlı)',
                _musteriSec),
          _secKart(Icons.memory, _urunAd ?? 'İade edilen parçayı seçin',
              () => _urunSec(false)),
          const SizedBox(height: 12),
          girdi(_adet, 'Adet',
              tamMi: true, degisti: () => setState(_otoDoldur)),
          girdi(_neden, 'İade nedeni'),
          const Text('Sonuç', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: sonuclar.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _sonuc == e.key,
                      onSelected: (_) => setState(() {
                        _sonuc = e.key;
                        _tutarElle = false;
                        _otoDoldur();
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Text(bilgi, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          if (_sonuc == 'degisim')
            _secKart(
                Icons.swap_horiz,
                _yedekAd ?? 'Yeni parça (boş bırakırsanız aynı parça)',
                () => _urunSec(true))
          else
            ..._tutarAlani(),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text('Tarih: ${tarih(_tarih.toIso8601String())}'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final t = await tarihSec(context, _tarih);
                if (t != null) setState(() => _tarih = t);
              },
            ),
          ),
          const SizedBox(height: 8),
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
                  : const Text('İadeyi kaydet', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}