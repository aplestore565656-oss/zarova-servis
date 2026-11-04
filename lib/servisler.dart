import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri, bugunTarih;
import 'ana_menu.dart' show YildizArkaplan;
import 'ayarlar.dart' show UstaSecici;
import 'foto.dart' show FotoPaneli;
import 'musteriler.dart' show musteriFormuAc;
import 'parca_ekle.dart';
import 'marka.dart';
import 'servis_formu.dart' show servisFormuYazdir;
import 'yardimci.dart';

final _db = Supabase.instance.client;

const servisDurumlari = [
  'Kayıt alındı',
  'Arıza tespiti yapılıyor',
  'Parça bekleniyor',
  'Tamirde',
  'Test ediliyor',
  'Hazır',
  'Müşteriye haber verildi',
  'Teslim edildi',
  'İptal edildi',
  'İade edildi',
];
const _kapaliDurumlar = ['Teslim edildi', 'İptal edildi', 'İade edildi'];
const _acikDurumlar = [
  'Kayıt alındı',
  'Arıza tespiti yapılıyor',
  'Parça bekleniyor',
  'Tamirde',
  'Test ediliyor',
  'Hazır',
  'Müşteriye haber verildi',
];

Color durumRengi(String d) {
  switch (d) {
    case 'Kayıt alındı':
      return Colors.orangeAccent;
    case 'Arıza tespiti yapılıyor':
      return Colors.amberAccent;
    case 'Parça bekleniyor':
      return Colors.purpleAccent;
    case 'Tamirde':
      return Colors.lightBlueAccent;
    case 'Test ediliyor':
      return Colors.cyanAccent;
    case 'Hazır':
      return Colors.greenAccent;
    case 'Müşteriye haber verildi':
      return Colors.tealAccent;
    case 'Teslim edildi':
      return Colors.white;
    default:
      return Colors.redAccent;
  }
}

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

int _k(String s) => (sayi(s) * 100).round();

String _zaman(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  String i(int n) => n.toString().padLeft(2, '0');
  return '${i(d.day)}.${i(d.month)}.${d.year} ${i(d.hour)}:${i(d.minute)}';
}

Future<bool> _onay(
    BuildContext c, String baslik, String metin, String evet) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: Text(metin),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(evet)),
      ],
    ),
  );
  return r == true;
}

void _mesaj(BuildContext c, String m) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

// ======================= LİSTE =======================
class ServislerSayfasi extends StatefulWidget {
  const ServislerSayfasi({super.key});

  @override
  State<ServislerSayfasi> createState() => _ServislerSayfasiState();
}

class _ServislerSayfasiState extends State<ServislerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  Map<dynamic, Map<String, dynamic>> _ozet = {};
  double _tedBorc = 0;
  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';
  String _filtre = 'acik';

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
          .select('*, customers(full_name, phone)')
          .isFilter('deleted_at', null)
          .order('received_at', ascending: false)
          .limit(500);
      final s = await _db.from('service_summary').select();
      double borc = 0;
      try {
        final t = await _db.from('supplier_accounts').select('balance');
        for (final x in List<Map<String, dynamic>>.from(t)) {
          final b = alan(x, 'balance');
          if (b > 0) borc += b;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(v);
        _ozet = {
          for (final x in List<Map<String, dynamic>>.from(s))
            x['service_order_id']: x
        };
        _tedBorc = borc;
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

  bool _kapali(Map<String, dynamic> s) =>
      _kapaliDurumlar.contains('${s['status']}');

  int _say(String f) {
    if (f == 'tumu') return _liste.length;
    if (f == 'acik') return _liste.where((s) => !_kapali(s)).length;
    return _liste.where((s) => s['status'] == f).length;
  }

  double _kalan(Map<String, dynamic> s) {
    final o = _ozet[s['id']];
    return o == null ? 0.0 : alan(o, 'remaining');
  }

  double get _alinacak => _liste
      .where((s) => s['status'] != 'İptal edildi' && s['status'] != 'İade edildi')
      .fold<double>(0.0, (t, s) => t + (_kalan(s) > 0 ? _kalan(s) : 0));

  double get _hazirAlinacak => _liste
      .where((s) =>
          s['status'] == 'Hazır' || s['status'] == 'Müşteriye haber verildi')
      .fold<double>(0.0, (t, s) => t + (_kalan(s) > 0 ? _kalan(s) : 0));

  double get _buAyKar {
    final n = DateTime.now();
    return _liste.where((s) {
      if (s['status'] != 'Teslim edildi') return false;
      final d = DateTime.tryParse('${s['delivered_at'] ?? ''}')?.toLocal();
      return d != null && d.year == n.year && d.month == n.month;
    }).fold<double>(0.0, (t, s) {
      final o = _ozet[s['id']];
      return t + (o == null ? 0.0 : alan(o, 'profit'));
    });
  }

  List<Map<String, dynamic>> get _gorunen {
    final a = _arama.toLowerCase().trim();
    return _liste.where((s) {
      final d = '${s['status']}';
      if (_filtre == 'acik' && _kapaliDurumlar.contains(d)) return false;
      if (_filtre != 'acik' && _filtre != 'tumu' && d != _filtre) return false;
      if (a.isEmpty) return true;
      final m = s['customers'] as Map<String, dynamic>?;
      final metin = [
        s['order_no'], s['brand'], s['model'], s['imei'],
        m?['full_name'], m?['phone'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');
      return metin.contains(a);
    }).toList();
  }

  Future<void> _yeni() async {
    final s = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const ServisFormu()));
    if (s == true) _yukle();
  }

  Future<void> _detay(Map<String, dynamic> s) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ServisDetaySayfasi(siparis: s)));
    _yukle();
  }

  Future<void> _hizliDurum(Map<String, dynamic> s, String yeni) async {
    if (yeni == '${s['status']}') return;
    if (_kapaliDurumlar.contains(yeni)) {
      _mesaj(context,
          'Teslim, iptal ve iade için servis kaydını açıp durumu orada değiştirin.');
      await _detay(s);
      return;
    }
    try {
      await _db
          .from('service_orders')
          .update({'status': yeni}).eq('id', s['id']);
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'Durum değiştirilemedi: ${hataMetni(e)}');
    }
  }

  Widget _ozetKutu(String baslik, double deger, Color renk) {
    return Container(
      width: 152,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,
              style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(para(deger),
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: renk)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String deger, String etiket) => ChoiceChip(
        label: Text('$etiket (${_say(deger)})'),
        selected: _filtre == deger,
        onSelected: (_) => setState(() => _filtre = deger),
      );

  Widget _baslik() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            key: const ValueKey('servis-ara'),
            onChanged: (v) => setState(() => _arama = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Müşteri, telefon, IMEI, model veya iş emri ara',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ozetKutu('Müşteriden alınacak', _alinacak, Colors.orangeAccent),
              _ozetKutu('Teslime hazır, alınacak', _hazirAlinacak,
                  Colors.greenAccent),
              _ozetKutu('Bu ay kâr (teslim edilen)', _buAyKar,
                  Colors.cyanAccent),
              _ozetKutu('Tedarikçiye borç', _tedBorc, Colors.redAccent),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chip('acik', 'Açık işler'),
                _chip('tumu', 'Tümü'),
                ...servisDurumlari.map((d) => _chip(d, d)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kart(Map<String, dynamic> s) {
    final m = s['customers'] as Map<String, dynamic>?;
    final o = _ozet[s['id']];
    final kalan = o == null ? 0.0 : alan(o, 'remaining');
    final toplam = o == null ? 0.0 : alan(o, 'total');
    final durum = '${s['status']}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => _detay(s),
        isThreeLine: true,
        title: Text('${s['order_no']} • ${s['brand']} ${s['model']}'.trim(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${m?['full_name'] ?? ''} • ${tarih('${s['received_at']}')}\n${s['problem']}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Durumu değiştir',
              onSelected: (v) => _hizliDurum(s, v),
              itemBuilder: (_) => servisDurumlari
                  .map((d) => PopupMenuItem<String>(
                        value: d,
                        child: Text(d, style: TextStyle(color: durumRengi(d))),
                      ))
                  .toList(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(durum,
                      style: TextStyle(
                          color: durumRengi(durum),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: durumRengi(durum)),
                ],
              ),
            ),
            if (kalan > 0.004)
              Text('Kalan ${para(kalan)}',
                  style: const TextStyle(color: Colors.redAccent))
            else if (toplam > 0)
              const Text('Ödendi', style: TextStyle(color: Colors.greenAccent)),
          ],
        ),
      ),
    );
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
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: liste.isEmpty ? 2 : liste.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _baslik();
        if (liste.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text('Bu sekmede servis kaydı yok.',
                    style: TextStyle(fontSize: 17))),
          );
        }
        return _kart(liste[i - 1]);
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
            title: const Text('Servis Kayıtları'),
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
            label: const Text('Yeni servis'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: _icerik(),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= FORM (yeni / düzenle) =======================
class ServisFormu extends StatefulWidget {
  final Map<String, dynamic>? siparis;
  const ServisFormu({super.key, this.siparis});

  @override
  State<ServisFormu> createState() => _ServisFormuState();
}

class _ServisFormuState extends State<ServisFormu> {
  bool get _yeni => widget.siparis == null;
  String _t(String k) => (widget.siparis?[k] ?? '').toString();

  late final _marka = TextEditingController(text: _t('brand'));
  late final _model = TextEditingController(text: _t('model'));
  late final _imei = TextEditingController(text: _t('imei'));
  late final _durumu = TextEditingController(text: _t('device_condition'));
  late final _ariza = TextEditingController(text: _t('problem'));
  late final _plan = TextEditingController(text: _t('planned_work'));
  late final _yapilan = TextEditingController(text: _t('work_done'));
  late final _teslimNotu = TextEditingController(text: _t('device_notes'));
  late final _usta = TextEditingController(text: _t('technician'));
  late final _garanti =
      TextEditingController(text: sayiYaz(widget.siparis?['warranty_days']));
  late final _not = TextEditingController(text: _t('note'));
  final _iscilik = TextEditingController();
  final _odenen = TextEditingController();

  late String? _musteriId = widget.siparis?['customer_id'];
  late String? _musteriAd =
      (widget.siparis?['customers'] as Map<String, dynamic>?)?['full_name'];
  final List<Map<String, dynamic>> _kalemler = [];
  String _durumSec = 'Kayıt alındı';
  String _yontem = 'nakit';
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void dispose() {
    for (final c in [
      _marka, _model, _imei, _durumu, _ariza, _plan, _yapilan,
      _teslimNotu, _usta, _garanti, _not, _iscilik, _odenen,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _parcaKurus => _kalemler.fold<int>(
      0,
      (t, k) =>
          t + (k['qty'] as int) * (((k['unit_price'] as num) * 100).round()));

  Future<void> _musteriSec() async {
    try {
      final veri = await _db
          .from('customers')
          .select('id, full_name, phone')
          .isFilter('deleted_at', null)
          .order('full_name');
      if (!mounted) return;
      final s = await secimPenceresi(context,
          baslik: 'Müşteri seç',
          liste: List<Map<String, dynamic>>.from(veri),
          ana: 'full_name',
          alt: 'phone');
      if (s != null) {
        setState(() {
          _musteriId = s['id'];
          _musteriAd = s['full_name'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Müşteriler alınamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _yeniMusteri() async {
    final m = await musteriFormuAc(context);
    if (m != null) {
      setState(() {
        _musteriId = m['id'];
        _musteriAd = m['full_name'];
      });
    }
  }

  Future<void> _kalemEkle() async {
    final k = await kalemDialogu(context);
    if (k != null) setState(() => _kalemler.add(k));
  }

  Future<void> _kaydet() async {
    if (_musteriId == null) {
      setState(() => _hata = 'Önce müşteri seçin.');
      return;
    }
    if (_ariza.text.trim().isEmpty) {
      setState(() => _hata = 'Müşterinin bildirdiği arızayı yazın.');
      return;
    }
    final garanti = tamSayi(_garanti.text);
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      if (_yeni) {
        final parca = _parcaKurus;
        var iscilik = _k(_iscilik.text);
        final odenen = _k(_odenen.text);
        if (odenen > parca + iscilik) iscilik = odenen - parca;
        final id = await _db.rpc('create_service_order', params: {
          'p_customer': _musteriId,
          'p_brand': _marka.text.trim(),
          'p_model': _model.text.trim(),
          'p_imei': _imei.text.trim(),
          'p_condition': _durumu.text.trim(),
          'p_problem': _ariza.text.trim(),
          'p_planned': _plan.text.trim(),
          'p_device_notes': _teslimNotu.text.trim(),
          'p_technician': _usta.text.trim(),
          'p_warranty': garanti,
          'p_labor': iscilik / 100,
          'p_note': _not.text.trim(),
          'p_items': _kalemler
              .map((k) => {
                    'product_id': k['product_id'],
                    'description': k['description'],
                    'qty': k['qty'],
                    'unit_price': k['unit_price'],
                    'unit_cost': k['unit_cost'],
                  })
              .toList(),
          'p_paid': odenen / 100,
          'p_method': _yontem,
        });
        if (_durumSec != 'Kayıt alındı') {
          try {
            await _db
                .from('service_orders')
                .update({'status': _durumSec}).eq('id', '$id');
          } catch (_) {}
        }
      } else {
        await _db.from('service_orders').update({
          'brand': _marka.text.trim(),
          'model': _model.text.trim(),
          'imei': _imei.text.trim(),
          'device_condition': _durumu.text.trim(),
          'problem': _ariza.text.trim(),
          'planned_work': _plan.text.trim(),
          'work_done': _yapilan.text.trim(),
          'device_notes': _teslimNotu.text.trim(),
          'technician': _usta.text.trim(),
          'warranty_days': garanti,
          'note': _not.text.trim(),
        }).eq('id', widget.siparis!['id']);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kaydedilemedi: ${hataMetni(e)}';
        _kaydediliyor = false;
      });
    }
  }

  Widget _girdi(TextEditingController c, String etiket,
      {int satir = 1, bool sayiMi = false, bool tamMi = false, bool para = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: satir,
        keyboardType: sayiMi
            ? const TextInputType.numberWithOptions(decimal: true)
            : (tamMi ? TextInputType.number : TextInputType.text),
        onChanged: (sayiMi || tamMi) ? (_) => setState(() {}) : null,
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
    final parca = _parcaKurus;
    final iscilikYazi = _k(_iscilik.text);
    final odenenYazi = _k(_odenen.text);
    final fazla = odenenYazi > parca + iscilikYazi;
    final toplam = (fazla ? odenenYazi : parca + iscilikYazi) / 100;
    final kalan = toplam - odenenYazi / 100;
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(_yeni
                ? 'Yeni servis kaydı'
                : 'Düzenle • ${widget.siparis!['order_no']}'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(_musteriAd ?? 'Müşteri seçin'),
                      trailing: _yeni
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.person_add),
                                    tooltip: 'Yeni müşteri',
                                    onPressed: _yeniMusteri),
                                const Icon(Icons.search),
                              ],
                            )
                          : null,
                      onTap: _yeni ? _musteriSec : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_yeni) ...[
                    const Text('Başlangıç durumu',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _acikDurumlar
                          .map((d) => ChoiceChip(
                                label: Text(d),
                                selected: _durumSec == d,
                                onSelected: (_) =>
                                    setState(() => _durumSec = d),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  MarkaSecici(controller: _marka),
                  _girdi(_marka, 'Cihaz markası'),
                  _girdi(_model, 'Model'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _imei,
                      keyboardType: TextInputType.number,
                      maxLength: 15,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                          labelText: 'IMEI (15 hane)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  _girdi(_durumu, 'Cihazın mevcut durumu (çizik, kırık vb.)',
                      satir: 2),
                  _girdi(_ariza, 'Müşterinin bildirdiği arıza', satir: 2),
                  _girdi(_plan, 'Yapılacak işlem', satir: 2),
                  if (!_yeni) _girdi(_yapilan, 'Yapılan işlem', satir: 2),
                  _girdi(_teslimNotu,
                      'Teslim notları (şifre/PIN, SIM, yanındaki eşyalar)',
                      satir: 2),
                  _girdi(_usta, 'İşlemi yapan usta'),
                  UstaSecici(controller: _usta),
                  _girdi(_garanti, 'Garanti süresi (gün)', tamMi: true),
                  if (_yeni) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 8, 4, 6),
                      child: Text('Parçalar ve işçilik',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Parçayı şimdi eklemeyebilirsiniz. Arıza tespitinden sonra servis detayından da ekleyebilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    ..._kalemler.asMap().entries.map((e) {
                      final k = e.value;
                      final tutar =
                          (k['qty'] as int) * (k['unit_price'] as num);
                      return Card(
                        child: ListTile(
                          title: Text('${k['description']}'),
                          subtitle: Text(
                              '${k['qty']} adet × ${para((k['unit_price'] as num).toDouble())}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(para(tutar.toDouble()),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                    () => _kalemler.removeAt(e.key)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _kalemEkle,
                        icon: const Icon(Icons.add),
                        label: const Text('Parça / işlem ekle'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _girdi(_iscilik, 'İşçilik', sayiMi: true, para: true),
                    _girdi(_odenen, 'Şimdi alınan ödeme (yoksa boş)',
                        sayiMi: true, para: true),
                    Wrap(
                      spacing: 8,
                      children: odemeYontemleri.entries
                          .map((e) => ChoiceChip(
                                label: Text(e.value),
                                selected: _yontem == e.key,
                                onSelected: (_) =>
                                    setState(() => _yontem = e.key),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.indigo.withValues(alpha: 0.25),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Toplam ücret',
                                    style: TextStyle(fontSize: 16)),
                                Text(para(toplam),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Kalan',
                                    style: TextStyle(fontSize: 16)),
                                Text(para(kalan < 0 ? 0 : kalan),
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: kalan > 0
                                            ? Colors.redAccent
                                            : Colors.greenAccent)),
                              ],
                            ),
                            if (fazla)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Aldığınız tutar toplamı aşıyor, fazlası işçilik olarak eklenir.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade300),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _girdi(_not, 'Not', satir: 2),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_hata!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 16)),
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
                          : Text(_yeni ? 'Servisi kaydet' : 'Kaydet',
                              style: const TextStyle(fontSize: 18)),
                    ),
                  ),
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

// ======================= DETAY =======================
class ServisDetaySayfasi extends StatefulWidget {
  final Map<String, dynamic> siparis;
  const ServisDetaySayfasi({super.key, required this.siparis});

  @override
  State<ServisDetaySayfasi> createState() => _ServisDetaySayfasiState();
}

class _ServisDetaySayfasiState extends State<ServisDetaySayfasi> {
  Map<String, dynamic>? _o;
  Map<String, dynamic>? _s;
  List<Map<String, dynamic>> _kalemler = [];
  List<Map<String, dynamic>> _odemeler = [];
  List<Map<String, dynamic>> _gecmis = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  double _sv(String k) => _s == null ? 0.0 : alan(_s!, k);
  String get _durum => '${_o?['status'] ?? widget.siparis['status']}';

  Future<void> _yukle() async {
    try {
      final id = widget.siparis['id'];
      final o = await _db
          .from('service_orders')
          .select('*, customers(full_name, phone)')
          .eq('id', id)
          .single();
      final s = await _db
          .from('service_summary')
          .select()
          .eq('service_order_id', id)
          .maybeSingle();
      final k = await _db
          .from('service_items')
          .select('*, products(suppliers(name))')
          .eq('service_order_id', id)
          .isFilter('removed_at', null)
          .order('created_at');
      final p = await _db
          .from('cash_transactions')
          .select()
          .eq('service_order_id', id)
          .inFilter('kind', ['musteri_odeme', 'musteri_iade'])
          .isFilter('voided_at', null)
          .order('created_at', ascending: false);
      final h = await _db
          .from('service_status_history')
          .select()
          .eq('service_order_id', id)
          .order('changed_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _o = o;
        _s = s;
        _kalemler = List<Map<String, dynamic>>.from(k);
        _odemeler = List<Map<String, dynamic>>.from(p);
        _gecmis = List<Map<String, dynamic>>.from(h);
        _yukleniyor = false;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Servis bilgisi alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _duzenle() async {
    final s = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ServisFormu(siparis: _o)));
    if (s == true) _yukle();
  }

  Future<void> _durumDegistir(String yeni) async {
    if (yeni == _durum || _o == null) return;
    final kalan = _sv('remaining');
    final odenen = _sv('paid');
    bool iadeYap = false;
    final kapat = yeni == 'İptal edildi' || yeni == 'İade edildi';

    if (yeni == 'Teslim edildi' && kalan > 0.004) {
      final c = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Teslim edilsin mi?'),
          content: Text('Müşteriden ${para(kalan)} tahsil edilmedi.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'vazgec'),
                child: const Text('Vazgeç')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'borc'),
                child: const Text('Borç kalsın, teslim et')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'para'),
                child: const Text('Ödeme al')),
          ],
        ),
      );
      if (c == 'para') {
        await _odemeAl();
        return;
      }
      if (c != 'borc') return;
    } else if (kapat && odenen > 0.004) {
      final c = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(yeni),
          content: Text(
              'Müşteriden ${para(odenen)} ödeme alınmış. Bu tutar müşteriye iade edilsin mi? (Kasadan çıkış olarak yazılır.) Kullanılan parçalar stoğa geri döner.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'vazgec'),
                child: const Text('Vazgeç')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'iadesiz'),
                child: const Text('İade etme')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'iade'),
                child: const Text('İade et')),
          ],
        ),
      );
      if (c == null || c == 'vazgec') return;
      iadeYap = c == 'iade';
    } else if (kapat) {
      final ok = await _onay(context, yeni,
          'Kullanılan parçalar stoğa geri döner. Devam edilsin mi?', 'Evet');
      if (!ok) return;
    }

    try {
      await _db
          .from('service_orders')
          .update({'status': yeni}).eq('id', _o!['id']);
      if (iadeYap) {
        await _db.from('cash_transactions').insert({
          'tx_date': bugunTarih(),
          'direction': 'cikis',
          'kind': 'musteri_iade',
          'section': 'teknik',
          'amount': (odenen * 100).round() / 100,
          'method': 'nakit',
          'description': 'Servis iptali iadesi',
          'customer_id': _o!['customer_id'],
          'service_order_id': _o!['id'],
        });
      }
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'Durum değiştirilemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _odemeAl() async {
    final o = _o;
    if (o == null) return;
    final toplam = _sv('total');
    final odenen = _sv('paid');
    final maliyet = _sv('parts_cost');
    final kalanKurus = ((toplam - odenen) * 100).round();
    final kalanPoz = kalanKurus > 0 ? kalanKurus : 0;
    final tutar = TextEditingController(
        text: kalanPoz > 0 ? sayiYaz(kalanPoz / 100) : '');
    String yontem = 'nakit';
    String? hata;
    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final girilen = _k(tutar.text);
          final fazla = girilen - kalanPoz;
          final yeniToplam = fazla > 0 ? toplam + fazla / 100 : toplam;
          final kar = yeniToplam - maliyet;
          return AlertDialog(
            title: const Text('Müşteriden para al'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Servis toplamı ${para(toplam)} • alınan ${para(odenen)} • parça maliyeti ${para(maliyet)}',
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tutar,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setS(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Şimdi müşteriden alınan tutar',
                          suffixText: '₺',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
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
                    if (fazla > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                            'Aldığınız tutar servis toplamını ${para(fazla / 100)} aşıyor. Fazlası işçilik / ek ücret olarak eklenir.',
                            style: TextStyle(
                                color: Colors.orange.shade300, fontSize: 13)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('Bu servisten kâr: ${para(kar)}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    if (hata != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(hata!,
                            style: const TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç')),
              FilledButton(
                onPressed: () {
                  if (girilen <= 0) {
                    setS(() => hata = 'Tutarı yazın.');
                    return;
                  }
                  Navigator.pop(ctx, {
                    'alinan': girilen,
                    'yontem': yontem,
                    'ek': fazla > 0 ? fazla : 0,
                  });
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
    if (sonuc == null) return;
    final int alinan = sonuc['alinan'] as int;
    final int ek = sonuc['ek'] as int;
    try {
      if (ek > 0) {
        await _db
            .from('service_orders')
            .update({'labor': alan(o, 'labor') + ek / 100}).eq('id', o['id']);
      }
      await _db.from('cash_transactions').insert({
        'tx_date': bugunTarih(),
        'direction': 'giris',
        'kind': 'musteri_odeme',
        'section': 'teknik',
        'amount': alinan / 100,
        'method': sonuc['yontem'],
        'description': '',
        'customer_id': o['customer_id'],
        'service_order_id': o['id'],
      });
    } catch (e) {
      if (ek > 0) {
        try {
          await _db
              .from('service_orders')
              .update({'labor': alan(o, 'labor')}).eq('id', o['id']);
        } catch (_) {}
      }
      if (!mounted) return;
      _mesaj(context, 'Kaydedilemedi: ${hataMetni(e)}');
      return;
    }
    await _yukle();
    if (!mounted) return;
    final kalanSonra = kalanPoz + ek - alinan;
    if (kalanSonra <= 0 && !_kapaliDurumlar.contains(_durum)) {
      final evet = await _onay(
          context,
          'Servis teslim edilsin mi?',
          'Ödemenin tamamı alındı. Durumu "Teslim edildi" yapayım mı?',
          'Teslim et');
      if (evet) await _durumDegistir('Teslim edildi');
    }
  }

  Future<void> _odemeIptal(Map<String, dynamic> p) async {
    final iade = p['kind'] == 'musteri_iade';
    final ok = await _onay(
        context,
        iade ? 'İade kaydı iptal edilsin mi?' : 'Ödeme iptal edilsin mi?',
        'Kalan tutar ve kasa buna göre yeniden hesaplanır. Kayıt silinmez, iptal olarak saklanır.',
        'İptal et');
    if (!ok) return;
    try {
      await _db.from('cash_transactions').update({
        'voided_at': DateTime.now().toUtc().toIso8601String(),
        'void_reason': 'Kullanıcı iptal etti',
      }).eq('id', p['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'İptal edilemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _kalemEkle() async {
    final k = await kalemDialogu(context);
    if (k == null) return;
    try {
      await _db.from('service_items').insert({
        'service_order_id': _o!['id'],
        'product_id': k['product_id'],
        'description': k['description'],
        'qty': k['qty'],
        'unit_price': k['unit_price'],
        'unit_cost': k['unit_cost'],
      });
      _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'Eklenemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _kalemFiyat(Map<String, dynamic> k) async {
    final c = TextEditingController(text: sayiYaz(k['unit_price']));
    String? hata;
    final yeni = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Müşteriye satış fiyatı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${k['description']} • ${tam(k, 'qty')} adet'),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Birim satış fiyatı',
                    suffixText: '₺',
                    border: OutlineInputBorder()),
              ),
              if (hata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(hata!,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                final kurus = _k(c.text);
                final fark =
                    (kurus - (alan(k, 'unit_price') * 100).round()) *
                        tam(k, 'qty') /
                        100;
                if (_sv('total') + fark < _sv('paid') - 0.004) {
                  setS(() => hata = 'Toplam, ödenen tutarın altına düşemez.');
                  return;
                }
                Navigator.pop(ctx, kurus);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (yeni == null) return;
    try {
      await _db
          .from('service_items')
          .update({'unit_price': yeni / 100}).eq('id', k['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'Kaydedilemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _kalemIade(Map<String, dynamic> k) async {
    final maliyet = tam(k, 'qty') * alan(k, 'unit_cost');
    final satis = tam(k, 'qty') * alan(k, 'unit_price');
    if (_sv('total') - satis < _sv('paid') - 0.004) {
      _mesaj(context,
          'Bu parçayı çıkarırsanız toplam, ödenen tutarın altına düşer. Önce ödemeyi iptal edin veya iade edin.');
      return;
    }
    final ok = await _onay(
        context,
        'Parça tedarikçiye iade edilsin mi?',
        'Parça servisten çıkar, stoktan düşer ve tedarikçi borcunuzdan ${para(maliyet)} düşülür.',
        'İade et');
    if (!ok) return;
    try {
      await _db.rpc('return_service_part',
          params: {'p_item': k['id'], 'p_reason': 'Müşteri vazgeçti'});
      await _yukle();
      if (!mounted) return;
      _mesaj(context, 'Parça tedarikçiye iade edildi, borç düşüldü.');
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'İade edilemedi: ${hataMetni(e)}');
    }
  }

  Future<void> _kalemKaldir(Map<String, dynamic> k) async {
    final tutar = tam(k, 'qty') * alan(k, 'unit_price');
    if (_sv('total') - tutar < _sv('paid') - 0.004) {
      _mesaj(context,
          'Bu kalemi kaldırırsanız toplam, ödenen tutarın altına düşer. Önce ödemeyi iptal edin veya iade edin.');
      return;
    }
    final ok = await _onay(
        context,
        'Kalem kaldırılsın mı?',
        k['product_id'] != null
            ? 'Stoktan düşülen parça stoğa geri döner. Tedarikçi borcu değişmez. Parçayı tedarikçiye iade ediyorsanız "Tedarikçiye iade et" seçeneğini kullanın.'
            : 'Bu kalem servisten çıkarılır.',
        'Kaldır');
    if (!ok) return;
    try {
      await _db
          .from('service_items')
          .update({'removed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', k['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'Kaldırılamadı: ${hataMetni(e)}');
    }
  }

  Future<void> _iscilikDuzenle() async {
    final c = TextEditingController(text: sayiYaz(_o!['labor']));
    String? hata;
    final yeni = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('İşçilik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'İşçilik tutarı',
                    suffixText: '₺',
                    border: OutlineInputBorder()),
              ),
              if (hata != null) ...[
                const SizedBox(height: 10),
                Text(hata!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                final kurus = _k(c.text);
                final yeniToplam = _sv('parts_sell') + kurus / 100;
                if (yeniToplam < _sv('paid') - 0.004) {
                  setS(() => hata = 'Toplam, ödenen tutarın altına düşemez.');
                  return;
                }
                Navigator.pop(ctx, kurus);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (yeni == null) return;
    try {
      await _db
          .from('service_orders')
          .update({'labor': yeni / 100}).eq('id', _o!['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      _mesaj(context, 'Kaydedilemedi: ${hataMetni(e)}');
    }
  }

  Widget _kutu(String baslik, String deger, {Color? renk}) {
    return SizedBox(
      width: 160,
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

  Widget _bilgi(String baslik, dynamic v) {
    final t = '${v ?? ''}'.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(baslik, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(t, style: const TextStyle(fontSize: 15)),
    );
  }

  Widget _baslik(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(t,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  String _kalemAlt(Map<String, dynamic> k) {
    final t = ((k['products'] as Map<String, dynamic>?)?['suppliers']
        as Map<String, dynamic>?)?['name'];
    final maliyet = k['unit_cost'] == null
        ? ''
        : ' • maliyet ${para(alan(k, 'unit_cost'))}';
    return '${tam(k, 'qty')} adet × ${para(alan(k, 'unit_price'))}$maliyet${t == null ? '' : '\nTedarikçi: $t'}';
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    final kalan = _sv('remaining');
    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: CircularProgressIndicator());
    } else if (_hata != null || o == null) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_hata ?? 'Kayıt bulunamadı.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    } else {
      final m = o['customers'] as Map<String, dynamic>?;
      final garanti = tam(o, 'warranty_days');
      final teslim = DateTime.tryParse('${o['delivered_at'] ?? ''}')?.toLocal();
      String garantiYazi = '';
      if (garanti > 0) {
        garantiYazi = teslim == null
            ? 'Garanti: $garanti gün (teslimden itibaren)'
            : 'Garanti: $garanti gün • bitiş ${tarih(teslim.add(Duration(days: garanti)).toIso8601String())}';
      }
      final hazir =
          _durum == 'Hazır' || _durum == 'Müşteriye haber verildi';
      govde = ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text('${o['order_no']}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${o['brand']} ${o['model']}'.trim() +
                      '\n${m?['full_name'] ?? ''} • ${m?['phone'] ?? ''}\nKabul: ${_zaman('${o['received_at']}')}' +
                      ('${o['technician']}'.isEmpty
                          ? ''
                          : '\nUsta: ${o['technician']}') +
                      (garantiYazi.isEmpty ? '' : '\n$garantiYazi')),
              isThreeLine: true,
            ),
          ),
          if (hazir && kalan > 0.004)
            Card(
              color: Colors.green.withValues(alpha: 0.18),
              child: ListTile(
                leading: const Icon(Icons.payments),
                title: Text('Müşteriden alınacak: ${para(kalan)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              _kutu('Toplam', para(_sv('total'))),
              _kutu('Ödenen', para(_sv('paid'))),
              _kutu(kalan < -0.004 ? 'Fazla ödeme' : 'Kalan',
                  para(kalan.abs()),
                  renk: kalan > 0.004
                      ? Colors.redAccent
                      : (kalan < -0.004
                          ? Colors.orangeAccent
                          : Colors.greenAccent)),
              _kutu('Parça maliyeti', para(_sv('parts_cost'))),
              _kutu('Kâr (brüt)', para(_sv('profit')),
                  renk: _sv('profit') >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent),
            ],
          ),
          _baslik('Durum'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: servisDurumlari
                .map((d) => ChoiceChip(
                      label: Text(d),
                      selected: _durum == d,
                      selectedColor: durumRengi(d).withValues(alpha: 0.35),
                      labelStyle: TextStyle(
                        color: durumRengi(d),
                        fontWeight: d == 'Teslim edildi'
                            ? FontWeight.w900
                            : FontWeight.w500,
                        fontSize: d == 'Teslim edildi' ? 16 : 14,
                      ),
                      onSelected: (_) => _durumDegistir(d),
                    ))
                .toList(),
          ),
          _baslik('Cihaz ve arıza'),
          Card(
            child: Column(
              children: [
                _bilgi('IMEI', o['imei']),
                _bilgi('Cihazın durumu', o['device_condition']),
                _bilgi('Bildirilen arıza', o['problem']),
                _bilgi('Yapılacak işlem', o['planned_work']),
                _bilgi('Yapılan işlem', o['work_done']),
                _bilgi('Teslim notları', o['device_notes']),
                _bilgi('Not', o['note']),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: _baslik('Parçalar')),
              TextButton.icon(
                onPressed: _kalemEkle,
                icon: const Icon(Icons.add),
                label: const Text('Parça / işlem ekle'),
              ),
            ],
          ),
          if (_kalemler.isEmpty)
            const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                    'Parça eklenmemiş. Arıza tespitinden sonra "Parça / işlem ekle" ile tedarikçi ve fiyatı girin.')),
          ..._kalemler.map((k) => Card(
                child: ListTile(
                  title: Text('${k['description']}'),
                  subtitle: Text(_kalemAlt(k)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(para(tam(k, 'qty') * alan(k, 'unit_price')),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'fiyat') {
                            _kalemFiyat(k);
                          } else if (v == 'iade') {
                            _kalemIade(k);
                          } else {
                            _kalemKaldir(k);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'fiyat',
                              child: Text('Satış fiyatını değiştir')),
                          if (k['product_id'] != null)
                            const PopupMenuItem(
                                value: 'iade',
                                child: Text(
                                    'Tedarikçiye iade et (borçtan düşer)')),
                          const PopupMenuItem(
                              value: 'kaldir',
                              child: Text('Servisten kaldır')),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          Card(
            child: ListTile(
              leading: const Icon(Icons.handyman),
              title: const Text('İşçilik'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(para(alan(o, 'labor')),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'İşçiliği düzenle',
                      onPressed: _iscilikDuzenle),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _baslik('Ödemeler')),
              FilledButton.icon(
                onPressed: _odemeAl,
                icon: const Icon(Icons.payments),
                label: const Text('Ödeme al'),
              ),
            ],
          ),
          if (_odemeler.isEmpty)
            const Padding(
                padding: EdgeInsets.all(8), child: Text('Ödeme alınmamış.')),
          ..._odemeler.map((p) {
            final iade = p['kind'] == 'musteri_iade';
            final ac = '${p['description'] ?? ''}'.trim();
            return Card(
              child: ListTile(
                title: Text('${iade ? '-' : '+'}${para(alan(p, 'amount'))}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: iade ? Colors.redAccent : Colors.greenAccent)),
                subtitle: Text(
                    '${tarih('${p['tx_date']}')} • ${odemeYontemleri['${p['method']}'] ?? ''}${iade ? ' • iade' : ''}${ac.isEmpty ? '' : '\n$ac'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'İptal et',
                  onPressed: () => _odemeIptal(p),
                ),
              ),
            );
          }),
          FotoPaneli(servisId: '${o['id']}'),
          _baslik('Durum geçmişi'),
          ..._gecmis.map((h) => ListTile(
                dense: true,
                leading: Icon(Icons.circle,
                    size: 12, color: durumRengi('${h['status']}')),
                title: Text('${h['status']}'),
                subtitle: Text(_zaman('${h['changed_at']}')),
              )),
          const SizedBox(height: 24),
        ],
      );
    }

    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text('${widget.siparis['order_no']}'),
            actions: [
              IconButton(
                  onPressed: o == null ? null : _duzenle,
                  icon: const Icon(Icons.edit),
                  tooltip: 'Bilgileri düzenle'),
              IconButton(
                  onPressed: o == null
                      ? null
                      : () => servisFormuYazdir(context, o, _kalemler, _s),
                  icon: const Icon(Icons.print),
                  tooltip: 'Servis formu (PDF)'),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: govde,
            ),
          ),
        ),
      ),
    );
  }
}