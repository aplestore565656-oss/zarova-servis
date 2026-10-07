import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';

final _db = Supabase.instance.client;

class GunRaporuSayfasi extends StatefulWidget {
  const GunRaporuSayfasi({super.key});

  @override
  State<GunRaporuSayfasi> createState() => _GunRaporuSayfasiState();
}

class _GunRaporuSayfasiState extends State<GunRaporuSayfasi> {
  DateTime _gun = DateTime.now();
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;

  String get _gunYazi =>
      DateTime(_gun.year, _gun.month, _gun.day).toIso8601String().substring(0, 10);

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
          .from('daily_activity')
          .select()
          .eq('activity_date', _gunYazi)
          .order('sort_at', ascending: false)
          .limit(500);
      if (!mounted) return;
      setState(() {
        _liste = List<Map<String, dynamic>>.from(veri);
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

  void _gunDegistir(DateTime yeni) {
    setState(() => _gun = yeni);
    _yukle();
  }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _gun,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (t != null) _gunDegistir(t);
  }

  double _toplam(bool Function(Map<String, dynamic>) f, String k) =>
      _liste.where(f).fold(0.0, (t, x) => t + alan(x, k));

  int _say(bool Function(Map<String, dynamic>) f) => _liste.where(f).length;

  Widget _kutu(String baslik, String deger, {Color? renk}) {
    return SizedBox(
      width: 165,
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

  Widget _satir(Map<String, dynamic> x) {
    final kaynak = '${x['source']}';
    final yon = x['direction'];
    IconData ikon;
    Color renk;
    String isaret = '';
    if (kaynak == 'para') {
      final giris = yon == 'giris';
      ikon = giris ? Icons.arrow_downward : Icons.arrow_upward;
      renk = giris ? Colors.greenAccent : Colors.redAccent;
      isaret = giris ? '+' : '-';
    } else if (kaynak == 'alis') {
      ikon = Icons.add_shopping_cart;
      renk = Colors.orangeAccent;
    } else if (kaynak == 'servis') {
      ikon = Icons.build;
      renk = Colors.lightBlueAccent;
    } else {
      ikon = Icons.point_of_sale;
      renk = Colors.pinkAccent;
    }
    final d = DateTime.tryParse('${x['sort_at']}')?.toLocal();
    final saat = d == null
        ? ''
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final detay = '${x['detail'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: renk.withValues(alpha: 0.18),
          child: Icon(ikon, color: renk),
        ),
        title: Text('${x['title']}', style: const TextStyle(fontSize: 16)),
        subtitle: Text('$saat${detay.isEmpty ? '' : ' • $detay'}'),
        trailing: Text('$isaret${para(alan(x, 'amount'))}',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kaynak == 'para' ? renk : null)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool para0(Map<String, dynamic> x) => x['source'] == 'para';
    final giris = _toplam((x) => para0(x) && x['direction'] == 'giris', 'amount');
    final cikis = _toplam((x) => para0(x) && x['direction'] == 'cikis', 'amount');
    final kar = _toplam((x) => true, 'profit');
    final kabul = _say((x) => x['title'] == 'Servis kabul');
    final teslim = _say((x) => x['title'] == 'Servis teslim');
    final satis = _say((x) => x['source'] == 'satis');
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
            title: const Text('Günlük Rapor'),
            actions: [
              IconButton(
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile'),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Önceki gün',
                            onPressed: () => _gunDegistir(
                                _gun.subtract(const Duration(days: 1))),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _tarihSec,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(tarih(_gun.toIso8601String()),
                                  style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Sonraki gün',
                            onPressed: () =>
                                _gunDegistir(_gun.add(const Duration(days: 1))),
                          ),
                          TextButton(
                            onPressed: () => _gunDegistir(DateTime.now()),
                            child: const Text('Bugün'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_yukleniyor)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(_hata!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent)),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _yukle,
                              child: const Text('Tekrar dene')),
                        ],
                      ),
                    )
                  else ...[
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        _kutu('Kasaya giren', para(giris),
                            renk: Colors.greenAccent),
                        _kutu('Kasadan çıkan', para(cikis),
                            renk: Colors.redAccent),
                        _kutu('Net', para(giris - cikis),
                            renk: giris - cikis >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent),
                        _kutu('Kâr (brüt)', para(kar)),
                        _kutu('Servis kabul', '$kabul'),
                        _kutu('Servis teslim', '$teslim'),
                        _kutu('Satış sayısı', '$satis'),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text('Bu günün işlemleri',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (_liste.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('Bu tarihte işlem yok.',
                                style: TextStyle(fontSize: 16))),
                      ),
                    ..._liste.map(_satir),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Alış ve servis kayıtlarının tutarı bilgi içindir, kasa toplamına sadece gerçek para hareketleri girer. Kâr, teslim edilen servis ve satışlardan hesaplanır.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
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