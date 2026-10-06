import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'musteriler.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

const servisDurumlari = [
  'Bekliyor',
  'Onay bekliyor',
  'İşlemde',
  'Parça bekliyor',
  'Hazır',
  'Teslim edildi',
  'İptal',
];

Color durumRengi(String d) {
  switch (d) {
    case 'Bekliyor':
      return Colors.orange;
    case 'Onay bekliyor':
      return Colors.amber.shade800;
    case 'İşlemde':
      return Colors.blue;
    case 'Parça bekliyor':
      return Colors.purple;
    case 'Hazır':
      return Colors.green;
    case 'İptal':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class ServislerSayfasi extends StatefulWidget {
  const ServislerSayfasi({super.key});

  @override
  State<ServislerSayfasi> createState() => _ServislerSayfasiState();
}

class _ServislerSayfasiState extends State<ServislerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';
  String? _durum;

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
          .select('*, customers(full_name, phone), parts(name, brand, model)')
          .isFilter('deleted_at', null)
          .order('service_no', ascending: false);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
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

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    return _liste.where((s) {
      if (_durum != null && s['status'] != _durum) return false;
      if (a.isEmpty) return true;
      final m = s['customers'] as Map<String, dynamic>?;
      final metin = [
        s['service_no'],
        s['brand'],
        s['model'],
        s['imei'],
        m?['full_name'],
        m?['phone'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return metin.contains(a);
    }).toList();
  }

  Future<void> _ac([Map<String, dynamic>? kayit]) async {
    final sonuc = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ServisFormu(kayit: kayit)),
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
        child: Text('Servis kaydı bulunamadı.', style: TextStyle(fontSize: 18)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final s = liste[i];
        final m = s['customers'] as Map<String, dynamic>?;
        final kalan = alan(s, 'remaining');
        final toplam = alan(s, 'total');
        final durum = '${s['status']}';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            onTap: () => _ac(s),
            isThreeLine: true,
            title: Text(
              'No ${s['service_no']} • ${s['brand']} ${s['model']}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${m?['full_name'] ?? ''} • ${tarih(s['created_at'])}\n${s['problem']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(durum,
                    style: TextStyle(
                        color: durumRengi(durum), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (kalan > 0)
                  Text('Kalan ${para(kalan)}',
                      style: const TextStyle(color: Colors.red))
                else if (toplam > 0)
                  const Text('Ödendi', style: TextStyle(color: Colors.green)),
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
      appBar: AppBar(
        title: const Text('Servis Kayıtları'),
        actions: [
          IconButton(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh),
              tooltip: 'Yenile'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ac(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni servis'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Müşteri, telefon, IMEI, model veya servis no ara',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text('Tümü'),
                        selected: _durum == null,
                        onSelected: (_) => setState(() => _durum = null),
                      ),
                    ),
                    ...servisDurumlari.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(d),
                          selected: _durum == d,
                          onSelected: (_) => setState(() => _durum = d),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(child: _icerik()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusteriSecDialog extends StatefulWidget {
  final List<Map<String, dynamic>> musteriler;
  const _MusteriSecDialog({required this.musteriler});

  @override
  State<_MusteriSecDialog> createState() => _MusteriSecDialogState();
}

class _MusteriSecDialogState extends State<_MusteriSecDialog> {
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final a = _arama.toLowerCase().trim();
    final liste = widget.musteriler.where((m) {
      return '${m['full_name']} ${m['phone']}'.toLowerCase().contains(a);
    }).toList();
    return AlertDialog(
      title: const Text('Müşteri seç'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _arama = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'İsim veya telefon ara',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: liste.isEmpty
                  ? const Center(child: Text('Müşteri bulunamadı.'))
                  : ListView(
                      children: liste
                          .map((m) => ListTile(
                                title: Text('${m['full_name']}'),
                                subtitle: Text('${m['phone']}'),
                                onTap: () => Navigator.pop(context, m),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Yeni müşteri'),
          onPressed: () async {
            final yeni = await musteriFormuAc(context);
            if (yeni != null && context.mounted) Navigator.pop(context, yeni);
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class ServisFormu extends StatefulWidget {
  final Map<String, dynamic>? kayit;
  const ServisFormu({super.key, this.kayit});

  @override
  State<ServisFormu> createState() => _ServisFormuState();
}

class _ServisFormuState extends State<ServisFormu> {
  final _anahtar = GlobalKey<FormState>();

  String _t(String k) => (widget.kayit?[k] ?? '').toString();

  String? _ilkParcaAdi() {
    final p = widget.kayit?['parts'] as Map<String, dynamic>?;
    if (p == null) return null;
    return '${p['name']} ${p['brand']} ${p['model']}'.trim();
  }

  late final _marka = TextEditingController(text: _t('brand'));
  late final _model = TextEditingController(text: _t('model'));
  late final _imei = TextEditingController(text: _t('imei'));
  late final _ariza = TextEditingController(text: _t('problem'));
  late final _islem = TextEditingController(text: _t('work_done'));
  late final _parca = TextEditingController(text: _t('part_used'));
  late final _parcaAdet = TextEditingController(
      text: widget.kayit == null ? '' : sayiYaz(widget.kayit!['part_qty']));
  late final _parcaMaliyet =
      TextEditingController(text: sayiYaz(widget.kayit?['part_cost']));
  late final _iscilik =
      TextEditingController(text: sayiYaz(widget.kayit?['labor']));
  late final _toplam =
      TextEditingController(text: sayiYaz(widget.kayit?['total']));
  late final _odenen =
      TextEditingController(text: sayiYaz(widget.kayit?['paid']));
  late final _yapan = TextEditingController(text: _t('technician'));
  late final _not = TextEditingController(text: _t('note'));

  late String _durum = widget.kayit?['status'] ?? 'Bekliyor';
    late String _tahsilEden = widget.kayit?['received_by'] ?? 'kasa';
  late String? _musteriId = widget.kayit?['customer_id'];
  late String? _musteriAd =
      (widget.kayit?['customers'] as Map<String, dynamic>?)?['full_name'];
  late String? _parcaId = widget.kayit?['part_id'];
  late String? _parcaAd = _ilkParcaAdi();
  double? _alisFiyati;
  int? _secStok;
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in [
      _marka, _model, _imei, _ariza, _islem, _parca, _parcaAdet,
      _parcaMaliyet, _iscilik, _toplam, _odenen, _yapan, _not,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _maliyetiHesapla() {
    if (_alisFiyati != null) {
      final c = _alisFiyati! * tamSayi(_parcaAdet.text);
      _parcaMaliyet.text = sayiYaz(c);
    }
  }

  Future<void> _musteriSec() async {
    try {
      final veri = await _db
          .from('customers')
          .select('id, full_name, phone')
          .isFilter('deleted_at', null)
          .order('full_name');
      if (!mounted) return;
      final secilen = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _MusteriSecDialog(
          musteriler: List<Map<String, dynamic>>.from(veri),
        ),
      );
      if (secilen != null) {
        setState(() {
          _musteriId = secilen['id'];
          _musteriAd = secilen['full_name'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Müşteriler alınamadı: $e');
    }
  }

  Future<void> _parcaSec() async {
    try {
      final veri = await _db
          .from('parts')
          .select('id, name, brand, model, buy_price, stock')
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
        baslik: 'Stoktan parça seç',
        liste: liste,
        ana: 'etiket',
        alt: 'stokYazi',
      );
      if (p != null) {
        setState(() {
          _parcaId = p['id'];
          _parcaAd = p['etiket'];
          _parca.text = '${p['etiket']}';
          _alisFiyati = alan(p, 'buy_price');
          _secStok = tam(p, 'stock');
          if (_parcaAdet.text.trim().isEmpty) _parcaAdet.text = '1';
          _maliyetiHesapla();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Parçalar alınamadı: $e');
    }
  }

  void _parcayiKaldir() {
    setState(() {
      _parcaId = null;
      _parcaAd = null;
      _alisFiyati = null;
      _secStok = null;
      _parcaAdet.text = '';
    });
  }

  Future<void> _kaydet() async {
    if (_musteriId == null) {
      setState(() => _hata = 'Önce müşteri seçin.');
      return;
    }
    if (!_anahtar.currentState!.validate()) return;
    final adet = tamSayi(_parcaAdet.text);
    if (_parcaId != null && adet <= 0) {
      setState(() => _hata = 'Stoktan seçtiğiniz parça için adet yazın.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    final Map<String, dynamic> veri = {
      'customer_id': _musteriId,
      'brand': _marka.text.trim(),
      'model': _model.text.trim(),
      'imei': _imei.text.trim(),
      'problem': _ariza.text.trim(),
      'work_done': _islem.text.trim(),
      'part_used': _parca.text.trim(),
      'part_id': _parcaId,
      'part_qty': _parcaId == null ? 0 : adet,
      'part_cost': sayi(_parcaMaliyet.text),
      'labor': sayi(_iscilik.text),
      'total': sayi(_toplam.text),
      'paid': sayi(_odenen.text),
            'received_by': _tahsilEden,
      'status': _durum,
      'technician': _yapan.text.trim(),
      'note': _not.text.trim(),
    };
    try {
      if (widget.kayit == null) {
        await _db.from('service_records').insert(veri);
      } else {
        await _db
            .from('service_records')
            .update(veri)
            .eq('id', widget.kayit!['id']);
      }
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

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servis kaydı silinsin mi?'),
        content: const Text(
            'Kayıt listeden kalkar ama veritabanında saklanır. Kullanılan parça stoğa geri döner.'),
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
          .from('service_records')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.kayit!['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Silinemedi: $e');
    }
  }

  Widget _girdi(TextEditingController c, String etiket,
      {bool sayiMi = false,
      bool tamMi = false,
      bool zorunlu = false,
      int satir = 1,
      bool hesapla = false,
      bool maliyet = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: satir,
        keyboardType: sayiMi
            ? const TextInputType.numberWithOptions(decimal: true)
            : (tamMi ? TextInputType.number : TextInputType.text),
        onChanged: (hesapla || maliyet)
            ? (_) {
                if (maliyet) _maliyetiHesapla();
                setState(() {});
              }
            : null,
        decoration: InputDecoration(
          labelText: etiket,
          border: const OutlineInputBorder(),
          suffixText: sayiMi ? '₺' : null,
        ),
        validator: zorunlu
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bu alanı doldurun' : null
            : null,
      ),
    );
  }

  Widget _stokUyarisi() {
    if (_parcaId == null || _secStok == null) return const SizedBox.shrink();
    final adet = tamSayi(_parcaAdet.text);
    final eski = (widget.kayit != null &&
            widget.kayit!['part_id'] == _parcaId &&
            widget.kayit!['status'] != 'İptal')
        ? tam(widget.kayit!, 'part_qty')
        : 0;
    final kullanilabilir = _secStok! + eski;
    if (adet <= kullanilabilir) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Dikkat: Stokta $kullanilabilir adet var, kaydederseniz stok eksiye düşer.',
        style: TextStyle(color: Colors.orange.shade900, fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toplam = sayi(_toplam.text);
    final odenen = sayi(_odenen.text);
    final kalan = toplam - odenen;
    final yeniMi = widget.kayit == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(yeniMi
            ? 'Yeni servis kaydı'
            : 'Servis No ${widget.kayit!['service_no']}'),
        actions: [
          if (!yeniMi)
            IconButton(
                onPressed: _sil,
                icon: const Icon(Icons.delete),
                tooltip: 'Sil'),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _anahtar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(_musteriAd ?? 'Müşteri seçin'),
                    trailing: const Icon(Icons.search),
                    onTap: _musteriSec,
                  ),
                ),
                const SizedBox(height: 12),
                _girdi(_marka, 'Marka', zorunlu: true),
                _girdi(_model, 'Model'),
                _girdi(_imei, 'IMEI'),
                _girdi(_ariza, 'Arıza', zorunlu: true, satir: 2),
                _girdi(_islem, 'Yapılan işlem', satir: 2),
                const Text('Takılan parça', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.memory),
                    title: Text(_parcaAd ?? 'Stoktan parça seçin (isteğe bağlı)'),
                    subtitle: _parcaId == null
                        ? const Text('Seçerseniz stoktan otomatik düşer')
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_parcaId != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Parçayı kaldır',
                            onPressed: _parcayiKaldir,
                          ),
                        const Icon(Icons.search),
                      ],
                    ),
                    onTap: _parcaSec,
                  ),
                ),
                if (_parcaId != null)
                  _girdi(_parcaAdet, 'Kullanılan adet',
                      tamMi: true, maliyet: true),
                _stokUyarisi(),
                _girdi(_parca, 'Parça notu (stokta yoksa buraya yazın)'),
                const Text('Durum', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: servisDurumlari
                      .map((d) => ChoiceChip(
                            label: Text(d),
                            selected: _durum == d,
                            onSelected: (_) => setState(() => _durum = d),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                _girdi(_parcaMaliyet, 'Parça maliyeti', sayiMi: true),
                _girdi(_iscilik, 'İşçilik', sayiMi: true),
                _girdi(_toplam, 'Toplam ücret (müşteriden alınacak)',
                    sayiMi: true, hesapla: true),
                _girdi(_odenen, 'Ödenen', sayiMi: true, hesapla: true),
                                const Text('Parayı kim aldı?', style: TextStyle(fontSize: 16)),

                Card(
                  color: kalan > 0 ? Colors.red.shade50 : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(odemeDurumu(toplam, odenen),
                            style: const TextStyle(fontSize: 16)),
                        Text('Kalan: ${para(kalan < 0 ? 0 : kalan)}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kalan > 0 ? Colors.red : Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _girdi(_yapan, 'Servisi yapan'),
                _girdi(_not, 'Not', satir: 2),
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
      ),
    );
  }
}