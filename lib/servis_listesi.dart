import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri;
import 'ana_menu.dart' show YildizArkaplan;
import 'servisler.dart'
    show ServisFormu, ServisDetaySayfasi, durumRengi, servisDurumlari;
import 'yardimci.dart';

final _db = Supabase.instance.client;

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

Color _renk(String d) =>
    d == 'İade edildi' ? Colors.deepOrangeAccent : durumRengi(d);

void _mesaj(BuildContext c, String m) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

class ServisListesi extends StatefulWidget {
  const ServisListesi({super.key});

  @override
  State<ServisListesi> createState() => _ServisListesiState();
}

class _ServisListesiState extends State<ServisListesi> {
  List<Map<String, dynamic>> _liste = [];
  Map<dynamic, Map<String, dynamic>> _ozet = {};
  Set<String> _bugunIds = {};
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
          .select('*, customers(full_name, phone), cash_transactions(method, amount, kind, voided_at)')
          .isFilter('deleted_at', null)
          .order('received_at', ascending: false)
          .limit(500);
      final s = await _db.from('service_summary').select();
      final bugun = <String>{};
      try {
        final n = DateTime.now();
        final bas = DateTime(n.year, n.month, n.day).toUtc().toIso8601String();
        final h = await _db
            .from('service_status_history')
            .select('service_order_id')
            .gte('changed_at', bas);
        for (final x in List<Map<String, dynamic>>.from(h)) {
          bugun.add('${x['service_order_id']}');
        }
        final gun =
            '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
        final p = await _db
            .from('cash_transactions')
            .select('service_order_id')
            .eq('tx_date', gun)
            .inFilter('kind', ['musteri_odeme', 'musteri_iade'])
            .isFilter('voided_at', null);
        for (final x in List<Map<String, dynamic>>.from(p)) {
          if (x['service_order_id'] != null) {
            bugun.add('${x['service_order_id']}');
          }
        }
      } catch (_) {}
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
        _bugunIds = bugun;
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

  bool _bugunMu(Map<String, dynamic> s) => _bugunIds.contains('${s['id']}');

  int _say(String f) {
    if (f == 'tumu') return _liste.length;
    if (f == 'bugun') return _liste.where(_bugunMu).length;
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
      if (_filtre == 'bugun' && !_bugunMu(s)) return false;
      if (_filtre == 'acik' && _kapaliDurumlar.contains(d)) return false;
      if (_filtre != 'acik' &&
          _filtre != 'tumu' &&
          _filtre != 'bugun' &&
          d != _filtre) {
        return false;
      }
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

  Widget _chip(String deger, String etiket,
      {Color? renk, double boyut = 14, bool kalin = false, bool buyuk = false}) {
    final c = renk ?? Colors.white;
    return ChoiceChip(
      padding: buyuk
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : null,
      label: Text('$etiket (${_say(deger)})',
          style: TextStyle(
              color: c,
              fontSize: boyut,
              fontWeight: kalin ? FontWeight.w900 : FontWeight.w500)),
      selected: _filtre == deger,
      selectedColor: c.withValues(alpha: 0.28),
      side: BorderSide(color: c.withValues(alpha: 0.6)),
      onSelected: (_) => setState(() => _filtre = deger),
    );
  }

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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip('bugun', 'Bugün',
                      renk: Colors.cyanAccent, kalin: true, boyut: 15),
                  _chip('acik', 'Açık işler'),
                  _chip('tumu', 'Tümü'),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Süreçteki işler',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    _acikDurumlar.map((d) => _chip(d, d, renk: _renk(d))).toList(),
              ),
              const SizedBox(height: 14),
              _chip('Teslim edildi', '✓ Teslim edildi',
                  renk: Colors.white, boyut: 17, kalin: true, buyuk: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip('İptal edildi', 'İptal edildi',
                      renk: Colors.redAccent, boyut: 12),
                  _chip('İade edildi', 'İade edildi',
                      renk: Colors.deepOrangeAccent, boyut: 12),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _durumYazi(String d) {
    final renk = _renk(d);
    final teslim = d == 'Teslim edildi';
    final iptal = d == 'İptal edildi';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (teslim) Icon(Icons.check_circle, size: 16, color: renk),
        if (iptal) Icon(Icons.cancel, size: 14, color: renk),
        if (teslim || iptal) const SizedBox(width: 3),
        Text(d,
            style: TextStyle(
                color: renk,
                fontWeight: teslim ? FontWeight.w900 : FontWeight.bold,
                fontSize: teslim ? 15 : 12)),
        Icon(Icons.arrow_drop_down, size: 18, color: renk),
      ],
    );
  }

  String _odemeYontemi(Map<String, dynamic> s) {
    final yontemler = <String>{};
    for (final c in List<Map<String, dynamic>>.from(
        s['cash_transactions'] ?? const [])) {
      if (c['voided_at'] != null || c['kind'] != 'musteri_odeme') continue;
      final y = odemeYontemleri['${c['method']}'];
      if (y != null) yontemler.add(y);
    }
    return yontemler.join(' + ');
  }

  Widget _kart(Map<String, dynamic> s) {
    final m = s['customers'] as Map<String, dynamic>?;
    final o = _ozet[s['id']];
    final kalan = o == null ? 0.0 : alan(o, 'remaining');
    final toplam = o == null ? 0.0 : alan(o, 'total');
    final odenen = o == null ? 0.0 : alan(o, 'paid');
    final durum = '${s['status']}';
    final yontem = _odemeYontemi(s);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => _detay(s),
        isThreeLine: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s['brand']} ${s['model']}'.trim().isEmpty
                  ? 'Cihaz bilgisi yok'
                  : '${s['brand']} ${s['model']}'.trim(),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
            Text('${s['order_no']}',
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
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
                        child: Text(d,
                            style: TextStyle(
                                color: _renk(d),
                                fontWeight: d == 'Teslim edildi'
                                    ? FontWeight.w900
                                    : FontWeight.normal)),
                      ))
                  .toList(),
              child: _durumYazi(durum),
            ),
            if (kalan > 0.004 && odenen > 0.004)
              Text('Ödenen ${para(odenen)}${yontem.isEmpty ? '' : ' • $yontem'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (kalan > 0.004)
              Text('Kalan ${para(kalan)}',
                  style: const TextStyle(color: Colors.redAccent))
            else if (toplam > 0)
              Text('Ödendi ${para(odenen)}${yontem.isEmpty ? '' : ' • $yontem'}',
                  style: const TextStyle(color: Colors.greenAccent)),
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
      data: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.cyan,
          useMaterial3: true),
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