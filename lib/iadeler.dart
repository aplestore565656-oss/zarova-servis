import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri;
import 'ortak.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;
String _gun(DateTime d) => d.toIso8601String().substring(0, 10);

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
                      '${tur == 'tedarikci' ? 'Tedarikçiye iade' : 'Müşteri iadesi'}${kisi.isEmpty ? '' : ' • $kisi'} • ${tarih('${r['return_date']}')}\n${_sonucYazi(tur, '${r['outcome']}')}${neden.isEmpty ? '' : ' • $neden'}'),
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
  final _neden = TextEditingController();
  final _not = TextEditingController();
  String _sonuc = 'cari';
  String _yontem = 'nakit';
  DateTime _tarih = DateTime.now();
  bool _kay = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in [_adet, _tutar, _neden, _not]) {
      c.dispose();
    }
    super.dispose();
  }

  void _turDegis(String t) => setState(() {
        _tur = t;
        _sonuc = t == 'tedarikci' ? 'cari' : 'para';
      });

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
          .select('id, name, brand, model, stock')
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
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Parçalar alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _kaydet() async {
    if (_tur == 'tedarikci' && _tedId == null) {
      setState(() => _hata = 'Önce tedarikçi seçin.');
      return;
    }
    if (_urunId == null) {
      setState(() => _hata = 'Önce iade edilen parçayı seçin.');
      return;
    }
    if (tamSayi(_adet.text) <= 0) {
      setState(() => _hata = 'Adet 1 veya daha fazla olmalı.');
      return;
    }
    setState(() {
      _kay = true;
      _hata = null;
    });
    try {
      await _db.rpc('create_return', params: {
        'p_kind': _tur,
        'p_supplier': _tur == 'tedarikci' ? _tedId : null,
        'p_customer': _tur == 'musteri' ? _musId : null,
        'p_product': _urunId,
        'p_qty': tamSayi(_adet.text),
        'p_amount': _sonuc == 'degisim' ? 0 : sayi(_tutar.text),
        'p_reason': _neden.text.trim(),
        'p_outcome': _sonuc,
        'p_replacement': _sonuc == 'degisim' ? _yedekId : null,
        'p_date': _gun(_tarih),
        'p_note': _not.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final ted = _tur == 'tedarikci';
    final sonuclar = ted
        ? const {
            'cari': 'Borçtan düşüldü',
            'para': 'Para geri geldi',
            'degisim': 'Değişim'
          }
        : const {'para': 'Para iade edildi', 'degisim': 'Değişim'};
    final bilgi = ted
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
                  selected: ted,
                  onSelected: (_) => _turDegis('tedarikci')),
              ChoiceChip(
                  label: const Text('Müşteriden iade'),
                  selected: !ted,
                  onSelected: (_) => _turDegis('musteri')),
            ],
          ),
          const SizedBox(height: 12),
          if (ted)
            _secKart(Icons.local_shipping, _tedAd ?? 'Tedarikçi seçin',
                _tedarikciSec)
          else
            _secKart(Icons.person, _musAd ?? 'Müşteri seçin (isteğe bağlı)',
                _musteriSec),
          _secKart(Icons.memory, _urunAd ?? 'İade edilen parçayı seçin',
              () => _urunSec(false)),
          const SizedBox(height: 12),
          girdi(_adet, 'Adet', tamMi: true),
          girdi(_neden, 'İade nedeni'),
          const Text('Sonuç', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: sonuclar.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _sonuc == e.key,
                      onSelected: (_) => setState(() => _sonuc = e.key),
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
          else ...[
            girdi(_tutar, ted ? 'İade tutarı (tedarikçiden)' : 'İade tutarı (müşteriye)',
                sayiMi: true, tl: true),
            if (_sonuc == 'para')
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
          ],
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