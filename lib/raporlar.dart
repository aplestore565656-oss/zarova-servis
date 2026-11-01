import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';
import 'yedek.dart' show csvOlustur, dosyaKaydet;

final _db = Supabase.instance.client;

class RaporlarSayfasi extends StatefulWidget {
  const RaporlarSayfasi({super.key});

  @override
  State<RaporlarSayfasi> createState() => _RaporlarSayfasiState();
}

class _RaporlarSayfasiState extends State<RaporlarSayfasi> {
  String _tur = 'ay';
  late DateTime _bas;
  late DateTime _bit;
  Map<String, dynamic>? _r;
  Map<String, dynamic>? _d;
  bool _yukleniyor = true;
  String? _hata;

  String _t(DateTime x) => x.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _aralik('ay');
    _yukle();
  }

  void _aralik(String tur) {
    final n = DateTime.now();
    final bugun = DateTime(n.year, n.month, n.day);
    _tur = tur;
    switch (tur) {
      case 'gun':
        _bas = bugun;
        _bit = bugun;
        break;
      case 'hafta':
        _bas = bugun.subtract(Duration(days: bugun.weekday - 1));
        _bit = bugun;
        break;
      case 'yil':
        _bas = DateTime(n.year, 1, 1);
        _bit = bugun;
        break;
      default:
        _bas = DateTime(n.year, n.month, 1);
        _bit = bugun;
    }
  }

  Future<void> _sec(String tur) async {
    if (tur == 'ozel') {
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: DateTimeRange(start: _bas, end: _bit),
      );
      if (r == null) return;
      _tur = 'ozel';
      _bas = r.start;
      _bit = r.end;
    } else {
      _aralik(tur);
    }
    setState(() {});
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final r = await _db.rpc('report_summary',
          params: {'p_from': _t(_bas), 'p_to': _t(_bit)});
      final d = await _db.from('dashboard_summary').select().single();
      if (!mounted) return;
      setState(() {
        _r = Map<String, dynamic>.from(r as Map);
        _d = d;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Rapor alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  double _v(String k) => alan(_r!, k);

  Future<void> _disaAktar() async {
    try {
      String p(double x) => x.toStringAsFixed(2).replaceAll('.', ',');
      final brut = _v('brut_kar');
      final hk = _v('hurda_kar');
      final gider = _v('gider');
      final satirlar = <Map<String, dynamic>>[
        {'Kalem': 'Dönem', 'Değer': '${tarih(_bas.toIso8601String())} - ${tarih(_bit.toIso8601String())}'},
        {'Kalem': 'Net kâr', 'Değer': p(brut + hk - gider)},
        {'Kalem': 'Servis kârı', 'Değer': p(brut)},
        {'Kalem': 'Hurda kârı', 'Değer': p(hk)},
        {'Kalem': 'Gider', 'Değer': p(gider)},
        {'Kalem': 'Müşteriden alınan', 'Değer': p(_v('tahsilat'))},
        {'Kalem': 'Teslim edilen iş', 'Değer': '${tam(_r!, 'teslim')}'},
        {'Kalem': 'Yeni gelen servis', 'Değer': '${tam(_r!, 'kabul')}'},
        {'Kalem': 'Ciro (servis tutarı)', 'Değer': p(_v('ciro'))},
        {'Kalem': 'Parça satışı', 'Değer': p(_v('parca_satis'))},
        {'Kalem': 'Parça maliyeti', 'Değer': p(_v('parca_maliyet'))},
        {'Kalem': 'İşçilik', 'Değer': p(_v('iscilik'))},
        {'Kalem': 'Parça alışı (fatura)', 'Değer': p(_v('alis_toplam'))},
        {'Kalem': 'Tedarikçi ödemesi', 'Değer': p(_v('tedarikci_odeme'))},
        {'Kalem': 'Müşteri iadesi', 'Değer': p(_v('musteri_iade'))},
        {'Kalem': 'Diğer gelir', 'Değer': p(_v('diger_gelir'))},
        {'Kalem': 'Para çekme', 'Değer': p(_v('para_cekme'))},
        {'Kalem': 'Hurda alış', 'Değer': p(_v('hurda_alis'))},
        {'Kalem': 'Hurda satış', 'Değer': p(_v('hurda_satis'))},
        {'Kalem': 'Kasa (şu an)', 'Değer': p(alan(_d!, 'cash'))},
        {'Kalem': 'Müşteri alacağı (şu an)', 'Değer': p(alan(_d!, 'customer_receivable'))},
        {'Kalem': 'Tedarikçi borcu (şu an)', 'Değer': p(alan(_d!, 'supplier_debt'))},
        {'Kalem': 'Stok değeri (şu an)', 'Değer': p(alan(_d!, 'stock_value'))},
      ];
      final yol = await dosyaKaydet('rapor_${_t(_bas)}_${_t(_bit)}.csv',
          csvOlustur(satirlar, ['Kalem', 'Değer']));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kaydedildi: $yol')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: ${hataMetni(e)}')));
    }
  }

  Widget _chip(String tur, String etiket) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(etiket),
          selected: _tur == tur,
          onSelected: (_) => _sec(tur),
        ),
      );

  Widget _kart(String baslik, String deger, Color renk, {bool genis = false}) {
    return SizedBox(
      width: genis ? 342 : 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(baslik,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(deger,
                    style: TextStyle(
                        fontSize: genis ? 26 : 18,
                        fontWeight: FontWeight.bold,
                        color: renk)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baslik(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(t,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );

  Widget _satir(String a, String b) => ListTile(
        dense: true,
        title: Text(a),
        trailing:
            Text(b, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: CircularProgressIndicator());
    } else if (_hata != null || _r == null || _d == null) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata ?? 'Rapor alınamadı.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _yukle, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    } else {
      final r = _r!;
      final d = _d!;
      final brut = _v('brut_kar');
      final hk = _v('hurda_kar');
      final gider = _v('gider');
      final net = brut + hk - gider;
      Color kr(double x) => x >= 0 ? Colors.greenAccent : Colors.redAccent;
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              _kart('NET KÂR (servis kârı + hurda kârı − gider)', para(net),
                  kr(net),
                  genis: true),
              _kart('Servis kârı', para(brut), kr(brut)),
              _kart('Hurda kârı', para(hk), kr(hk)),
              _kart('Gider', para(gider), Colors.redAccent),
              _kart('Müşteriden alınan', para(_v('tahsilat')),
                  Colors.greenAccent),
              _kart('Teslim edilen iş', '${tam(r, 'teslim')}', Colors.white),
            ],
          ),
          _baslik('Şu anki durum (tarihten bağımsız)'),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 2,
            children: [
              _kart('Kasa', para(alan(d, 'cash')), Colors.cyanAccent),
              _kart('Müşteri alacağı', para(alan(d, 'customer_receivable')),
                  Colors.orangeAccent),
              _kart('Tedarikçi borcu', para(alan(d, 'supplier_debt')),
                  Colors.redAccent),
              _kart('Stok değeri', para(alan(d, 'stock_value')),
                  Colors.lightBlueAccent),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('Ayrıntılar'),
                children: [
                  _satir('Yeni gelen servis', '${tam(r, 'kabul')}'),
                  _satir('Ciro (servis tutarı)', para(_v('ciro'))),
                  _satir('Parça satışı', para(_v('parca_satis'))),
                  _satir('Parça maliyeti', para(_v('parca_maliyet'))),
                  _satir('İşçilik', para(_v('iscilik'))),
                  _satir('Parça alışı (fatura)', para(_v('alis_toplam'))),
                  _satir('Tedarikçi ödemesi', para(_v('tedarikci_odeme'))),
                  _satir('Müşteri iadesi', para(_v('musteri_iade'))),
                  _satir('Diğer gelir', para(_v('diger_gelir'))),
                  _satir('Para çekme', para(_v('para_cekme'))),
                  _satir('Hurda alış (kasadan çıkan)', para(_v('hurda_alis'))),
                  _satir('Hurda satış (kasaya giren)', para(_v('hurda_satis'))),
                ],
              ),
            ),
          ),
        ],
      );
    }
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
            title: const Text('Raporlar'),
            actions: [
              TextButton.icon(
                onPressed: (_r == null || _yukleniyor) ? null : _disaAktar,
                icon: const Icon(Icons.table_view),
                label: const Text('Excel (CSV)'),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _chip('gun', 'Bugün'),
                        _chip('hafta', 'Bu hafta'),
                        _chip('ay', 'Bu ay'),
                        _chip('yil', 'Bu yıl'),
                        _chip('ozel', 'Özel aralık'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${tarih(_bas.toIso8601String())}  –  ${tarih(_bit.toIso8601String())}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Expanded(child: govde),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}