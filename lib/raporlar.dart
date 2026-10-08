import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';
import 'yedek.dart' show csvOlustur, dosyaKaydet;

final _db = Supabase.instance.client;

class _G {
  final String a;
  final num? v;
  final String t; // b = başlık, p = para, s = sayı
  const _G(this.a, this.v, this.t);
}

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
      case 'ay':
        _bas = DateTime(n.year, n.month, 1);
        _bit = bugun;
        break;
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

  List<_G> _liste() {
    final r = _r!;
    final d = _d!;
    final brut = alan(r, 'brut_kar');
    final gider = alan(r, 'gider');
    return [
      const _G('Servis (teslim edilenler)', null, 'b'),
      _G('Servis kabul sayısı', tam(r, 'kabul'), 's'),
      _G('Teslim edilen servis', tam(r, 'teslim'), 's'),
      _G('Ciro (servis tutarı)', alan(r, 'ciro'), 'p'),
      _G('Parça satışı', alan(r, 'parca_satis'), 'p'),
      _G('Parça maliyeti', alan(r, 'parca_maliyet'), 'p'),
      _G('İşçilik', alan(r, 'iscilik'), 'p'),
      _G('Brüt kâr', brut, 'p'),
      const _G('Kasa hareketleri', null, 'b'),
      _G('Tahsilat', alan(r, 'tahsilat'), 'p'),
      _G('Müşteri iadesi', alan(r, 'musteri_iade'), 'p'),
      _G('Gider', gider, 'p'),
      _G('Tedarikçi ödemesi', alan(r, 'tedarikci_odeme'), 'p'),
      _G('Diğer gelir', alan(r, 'diger_gelir'), 'p'),
      _G('Para çekme', alan(r, 'para_cekme'), 'p'),
      const _G('Alış', null, 'b'),
      _G('Parça alışı (fatura toplamı)', alan(r, 'alis_toplam'), 'p'),
      const _G('Sonuç', null, 'b'),
      _G('Tahmini net kâr (brüt kâr − gider)', brut - gider, 'p'),
      const _G('Şu anki durum (tarihten bağımsız)', null, 'b'),
      _G('Kasa', alan(d, 'cash'), 'p'),
      _G('Müşteri alacağı', alan(d, 'customer_receivable'), 'p'),
      _G('Tedarikçi borcu', alan(d, 'supplier_debt'), 'p'),
      _G('Stok değeri', alan(d, 'stock_value'), 'p'),
    ];
  }

  Future<void> _disaAktar() async {
    try {
      final satirlar = <Map<String, dynamic>>[
        {'Kalem': 'Dönem', 'Değer': '${tarih(_bas.toIso8601String())} - ${tarih(_bit.toIso8601String())}'},
        ..._liste().where((x) => x.t != 'b').map((x) => {
              'Kalem': x.a,
              'Değer': x.t == 'p'
                  ? x.v!.toDouble().toStringAsFixed(2).replaceAll('.', ',')
                  : '${x.v}',
            }),
      ];
      final yol = await dosyaKaydet(
          'rapor_${_t(_bas)}_${_t(_bit)}.csv',
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
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: _liste().map((x) {
          if (x.t == 'b') {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
              child: Text(x.a,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            );
          }
          Color? renk;
          if (x.a.contains('kâr') && x.v != null) {
            renk = x.v! >= 0 ? Colors.greenAccent : Colors.redAccent;
          }
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              title: Text(x.a),
              trailing: Text(
                x.t == 'p' ? para(x.v!.toDouble()) : '${x.v}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: renk),
              ),
            ),
          );
        }).toList(),
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
              constraints: const BoxConstraints(maxWidth: 700),
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