import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri, bugunTarih;
import 'kur.dart';
import 'tedarikciler.dart' show tedarikciFormuAc;
import 'yardimci.dart';

final _db = Supabase.instance.client;

int _d4(String s) => (sayi(s) * 10000).round();
int _kurus(String s) => (sayi(s) * 100).round();
int _tlKurus(String usd, String kur) =>
    (_d4(usd) * _d4(kur) + 500000) ~/ 1000000;
String _usd(num n) => '\$${n.toStringAsFixed(2).replaceAll('.', ',')}';

/// Servise parça/işlem ekleme penceresi. Seçilen kalemi verir.
Future<Map<String, dynamic>?> kalemDialogu(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _KalemDialog(),
  );
}

class _KalemDialog extends StatefulWidget {
  const _KalemDialog();

  @override
  State<_KalemDialog> createState() => _KalemDialogState();
}

class _KalemDialogState extends State<_KalemDialog> {
  String _mod = 'dis';
  String? _urunId;
  String? _urunAd;
  int? _stok;
  String? _tedId;
  String? _tedAd;
  bool _dolar = true;
  String _yontem = 'nakit';
  bool _kurYuk = false;
  String? _kurNotu;
  bool _bekliyor = false;
  String? _hata;
  final _kur = TextEditingController();
  final _odenen = TextEditingController();
  final _ad = TextEditingController();
  final _adet = TextEditingController(text: '1');
  final _maliyet = TextEditingController();
  final _fiyat = TextEditingController();

  @override
  void initState() {
    super.initState();
    _kurGetir();
  }

  @override
  void dispose() {
    for (final c in [_kur, _odenen, _ad, _adet, _maliyet, _fiyat]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _adetSayi => tamSayi(_adet.text);
  int get _birimKurus =>
      _dolar ? _tlKurus(_maliyet.text, _kur.text) : _kurus(_maliyet.text);
  int get _toplamKurus => _adetSayi * _birimKurus;
  int get _toplamUsd4 => _adetSayi * _d4(_maliyet.text);

  int get _odenenKurus {
    if (!_dolar) return _kurus(_odenen.text);
    final p4 = _d4(_odenen.text);
    if (p4 <= 0) return 0;
    if (p4 >= _toplamUsd4) return _toplamKurus;
    final k = _tlKurus(_odenen.text, _kur.text);
    return k > _toplamKurus ? _toplamKurus : k;
  }

  bool get _fazlaOdeme => _dolar
      ? _d4(_odenen.text) > _toplamUsd4
      : _kurus(_odenen.text) > _toplamKurus;

  String get _ipucu {
    switch (_mod) {
      case 'dis':
        return 'Servis için dışarıdan aldığınız parça. Ekle\'ye basınca alış kaydı hemen oluşur: tedarikçi borcu ve stok yazılır, parça servise takılı sayılır.';
      case 'serbest':
        return 'Tedarikçisiz parça veya işlem. Maliyet kâr hesabına girer, stok ve borç oluşmaz.';
      default:
        return 'Stokta olan parça. Servise eklenince stoktan düşer.';
    }
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
        _kurNotu = 'Kur kaynağı (${k.tarih})';
      }
    });
  }

  Future<void> _stoktanSec() async {
    try {
      final veri = await _db
          .from('products')
          .select('id, name, brand, model, sell_price, stock')
          .eq('section', 'teknik')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final liste = List<Map<String, dynamic>>.from(veri)
          .map((p) => {
                ...p,
                'etiket': '${p['name']} ${p['brand']} ${p['model']}'.trim(),
                'stokYazi':
                    'Stok: ${tam(p, 'stock')} adet • Satış ${para(alan(p, 'sell_price'))}',
              })
          .toList();
      final p = await secimPenceresi(context,
          baslik: 'Stoktan parça seç',
          liste: liste,
          ana: 'etiket',
          alt: 'stokYazi');
      if (p != null) {
        setState(() {
          _urunId = p['id'];
          _urunAd = p['etiket'];
          _stok = tam(p, 'stock');
          _fiyat.text = sayiYaz(alan(p, 'sell_price'));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Parçalar alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _tedarikciSec() async {
    try {
      final veri = await _db
          .from('suppliers')
          .select('id, name, phone')
          .isFilter('deleted_at', null)
          .order('name');
      if (!mounted) return;
      final s = await secimPenceresi(context,
          baslik: 'Tedarikçi seç',
          liste: List<Map<String, dynamic>>.from(veri),
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

  Future<void> _yeniTedarikci() async {
    final t = await tedarikciFormuAc(context);
    if (t != null) {
      setState(() {
        _tedId = t['id'];
        _tedAd = t['name'];
      });
    }
  }

  Future<void> _ekle() async {
    final adet = _adetSayi;
    if (adet <= 0) {
      setState(() => _hata = 'Adet 1 veya daha fazla olmalı.');
      return;
    }
    final satisKurus = _kurus(_fiyat.text);
    if (_mod == 'stok') {
      if (_urunId == null) {
        setState(() => _hata = 'Stoktan bir parça seçin.');
        return;
      }
      Navigator.pop(context, {
        'product_id': _urunId,
        'description': _urunAd,
        'qty': adet,
        'unit_price': satisKurus / 100,
        'unit_cost': null,
      });
      return;
    }
    if (_ad.text.trim().isEmpty) {
      setState(() => _hata = 'Parça veya işlem adını yazın.');
      return;
    }
    if (_mod == 'serbest') {
      Navigator.pop(context, {
        'product_id': null,
        'description': _ad.text.trim(),
        'qty': adet,
        'unit_price': satisKurus / 100,
        'unit_cost': _kurus(_maliyet.text) / 100,
      });
      return;
    }
    // Tedarikçiden aldım
    if (_tedId == null) {
      setState(() => _hata = 'Önce tedarikçi seçin.');
      return;
    }
    if (_dolar && _d4(_kur.text) <= 0) {
      setState(() => _hata = 'Dolar kurunu yazın.');
      return;
    }
    if (_birimKurus <= 0) {
      setState(() => _hata = 'Aldığınız birim fiyatı yazın.');
      return;
    }
    if (_fazlaOdeme) {
      setState(() => _hata = 'Ödenen tutar toplam alıştan fazla olamaz.');
      return;
    }
    setState(() {
      _bekliyor = true;
      _hata = null;
    });
    try {
      final id = await _db.rpc('purchase_for_service', params: {
        'p_supplier': _tedId,
        'p_name': _ad.text.trim(),
        'p_qty': adet,
        'p_currency': _dolar ? 'USD' : 'TRY',
        'p_fx': _dolar ? _d4(_maliyet.text) / 10000 : null,
        'p_rate': _dolar ? _d4(_kur.text) / 10000 : null,
        'p_cost': _birimKurus / 100,
        'p_paid': 0,
        'p_method': _yontem,
        'p_date': bugunTarih(),
      });
      if (!mounted) return;
      Navigator.pop(context, {
        'product_id': '$id',
        'description': _ad.text.trim(),
        'qty': adet,
        'unit_price': satisKurus / 100,
        'unit_cost': null,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kaydedilemedi: ${hataMetni(e)}';
        _bekliyor = false;
      });
    }
  }

  Widget _modChip(String m, String etiket) => ChoiceChip(
        label: Text(etiket),
        selected: _mod == m,
        onSelected: (_) => setState(() {
          _mod = m;
          _hata = null;
          _maliyet.text = '';
          _odenen.text = '';
        }),
      );

  Widget _alan(TextEditingController c, String etiket,
      {bool ondalik = false, String? ek}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: ondalik
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            labelText: etiket,
            suffixText: ek,
            border: const OutlineInputBorder()),
      ),
    );
  }

  List<Widget> _disAlanlari() => [
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping),
            title: Text(_tedAd ?? 'Tedarikçi seçin (kimden aldınız?)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Yeni tedarikçi',
                  onPressed: _yeniTedarikci,
                ),
                const Icon(Icons.search),
              ],
            ),
            onTap: _tedarikciSec,
          ),
        ),
        const SizedBox(height: 8),
        _alan(_ad, 'Parça adı (örn. iPhone 11 ekran)'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Dolar (\$)'),
              selected: _dolar,
              onSelected: (_) => setState(() {
                _dolar = true;
                _maliyet.text = '';
                _odenen.text = '';
              }),
            ),
            ChoiceChip(
              label: const Text('Türk Lirası (₺)'),
              selected: !_dolar,
              onSelected: (_) => setState(() {
                _dolar = false;
                _maliyet.text = '';
                _odenen.text = '';
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _alan(_maliyet,
            _dolar ? 'Aldığım birim fiyat (dolar)' : 'Aldığım birim fiyat (₺)',
            ondalik: true, ek: _dolar ? '\$' : '₺'),
        if (_dolar) ...[
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
          if (_kurNotu != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_kurNotu!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _dolar
                ? 'Birim ${para(_birimKurus / 100)} • Toplam alış ${_usd(_toplamUsd4 / 10000)} = ${para(_toplamKurus / 100)}'
                : 'Toplam alış ${para(_toplamKurus / 100)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        _alan(
            _odenen,
            _dolar
                ? 'Tedarikçiye şimdi ödenen (dolar, ödemediyseniz boş)'
                : 'Tedarikçiye şimdi ödenen (₺, ödemediyseniz boş)',
            ondalik: true,
            ek: _dolar ? '\$' : '₺'),
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
        const Padding(
          padding: EdgeInsets.only(top: 6, bottom: 10),
          child: Text(
            'Ödemediğiniz kısım tedarikçiye borç yazılır. Ödeme kasadan TL karşılığıyla düşer.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ];

  List<Widget> _disAlanlari2() => [
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping),
            title: Text(_tedAd ?? 'Tedarikçi seçin (kimden aldınız?)'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Yeni tedarikçi',
                  onPressed: _yeniTedarikci,
                ),
                const Icon(Icons.search),
              ],
            ),
            onTap: _tedarikciSec,
          ),
        ),
        const SizedBox(height: 8),
        _alan(_ad, 'Parça adı (örn. iPhone 11 ekran)'),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Dolar (\$)'),
              selected: _dolar,
              onSelected: (_) => setState(() {
                _dolar = true;
                _maliyet.text = '';
              }),
            ),
            ChoiceChip(
              label: const Text('Türk Lirası (₺)'),
              selected: !_dolar,
              onSelected: (_) => setState(() {
                _dolar = false;
                _maliyet.text = '';
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _alan(_maliyet,
            _dolar ? 'Aldığım birim fiyat (dolar)' : 'Aldığım birim fiyat (₺)',
            ondalik: true, ek: _dolar ? '\$' : '₺'),
        if (_dolar) ...[
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
          if (_kurNotu != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_kurNotu!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _dolar
                ? 'Birim ${para(_birimKurus / 100)} • Toplam alış ${_usd(_toplamUsd4 / 10000)} = ${para(_toplamKurus / 100)}'
                : 'Toplam alış ${para(_toplamKurus / 100)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Borç tedarikçi hesabına yazılır. Ödemeyi Tedarikçiler sayfasından istediğiniz zaman yaparsınız.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ];

  List<Widget> _serbestAlanlari() => [
        _alan(_ad, 'Parça / işlem adı'),
        _alan(_maliyet, 'Birim maliyetiniz (₺, bilmiyorsanız boş)',
            ondalik: true, ek: '₺'),
        DolarCeviri(hedef: _maliyet, etiket: 'Maliyeti dolar olarak girin'),
      ];

  @override
  Widget build(BuildContext context) {
    final stokUyari = _mod == 'stok' && _stok != null && _adetSayi > _stok!;
    return AlertDialog(
      title: const Text('Parça / işlem ekle'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _modChip('stok', 'Stoktan'),
                  _modChip('dis', 'Tedarikçiden aldım'),
                  _modChip('serbest', 'Serbest işlem'),
                ],
              ),
              const SizedBox(height: 6),
              Text(_ipucu,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              if (_mod == 'stok')
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.memory),
                    title: Text(_urunAd ?? 'Stoktan parça seçin'),
                    subtitle: _stok == null ? null : Text('Stokta $_stok adet'),
                    trailing: const Icon(Icons.search),
                    onTap: _stoktanSec,
                  ),
                ),
              if (_mod == 'dis') ..._disAlanlari2(),
              if (_mod == 'serbest') ..._serbestAlanlari(),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _adet,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Adet', border: OutlineInputBorder()),
                ),
              ),
              if (stokUyari)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      'Dikkat: Stokta $_stok adet var, stok eksiye düşer.',
                      style: TextStyle(color: Colors.orange.shade300)),
                ),
              _alan(_fiyat,
                  'Müşteriye birim satış fiyatı (₺, bilmiyorsanız boş)',
                  ondalik: true, ek: '₺'),
              if (_hata != null)
                Text(_hata!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _bekliyor ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _bekliyor ? null : _ekle,
          child: _bekliyor
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ekle'),
        ),
      ],
    );
  }
}