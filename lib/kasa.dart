import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni, odemeYontemleri, bugunTarih;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';

final _db = Supabase.instance.client;

ThemeData _koyu() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

const _tipAdlari = <String, String>{
  'musteri_odeme': 'Müşteri tahsilatı',
  'satis': 'Satış',
  'diger_gelir': 'Diğer gelir',
  'acilis': 'Açılış bakiyesi',
  'tedarikci_iade': 'Tedarikçi iadesi',
  'tedarikci_odeme': 'Tedarikçi ödemesi',
  'gider': 'Gider',
  'para_cekme': 'Para çekme',
  'musteri_iade': 'Müşteri iadesi',
};
const _elleTipler = ['diger_gelir', 'acilis', 'gider', 'para_cekme'];
const _giderKategorileri = [
  'Kira', 'Elektrik', 'Su / doğalgaz', 'İnternet / telefon', 'Yemek', 'Diğer'
];

class KasaSayfasi extends StatefulWidget {
  const KasaSayfasi({super.key});

  @override
  State<KasaSayfasi> createState() => _KasaSayfasiState();
}

class _KasaSayfasiState extends State<KasaSayfasi> {
  double _bakiye = 0;
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String? _yon;

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
      final b = await _db.from('cash_balance').select().single();
      final h = await _db
          .from('cash_transactions')
          .select('*, customers(full_name), suppliers(name)')
          .isFilter('voided_at', null)
          .order('tx_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      setState(() {
        _bakiye = alan(b, 'balance');
        _liste = List<Map<String, dynamic>>.from(h);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kasa bilgisi alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  double _bugun(String yon) {
    final t = bugunTarih();
    return _liste
        .where((x) => '${x['tx_date']}' == t && x['direction'] == yon)
        .fold(0.0, (s, x) => s + alan(x, 'amount'));
  }

  Future<void> _ekle(String yon) async {
    final s = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => HareketFormu(yon: yon)));
    if (s == true) _yukle();
  }

  Future<void> _iptal(Map<String, dynamic> x) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hareket iptal edilsin mi?'),
        content: const Text(
            'Kasa bakiyesi buna göre yeniden hesaplanır. Kayıt silinmez, iptal olarak saklanır.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('İptal et')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await _db.from('cash_transactions').update({
        'voided_at': DateTime.now().toUtc().toIso8601String(),
        'void_reason': 'Kullanıcı iptal etti',
      }).eq('id', x['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İptal edilemedi: ${hataMetni(e)}')));
    }
  }

  Widget _kutu(String baslik, String deger, Color renk) {
    return Expanded(
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

  Widget _satir(Map<String, dynamic> x) {
    final giris = x['direction'] == 'giris';
    final renk = giris ? Colors.greenAccent : Colors.redAccent;
    final tip = '${x['kind']}';
    final kat = '${x['category'] ?? ''}'.trim();
    final baslik = (_tipAdlari[tip] ?? tip) + (kat.isEmpty ? '' : ' • $kat');
    final kisi = (x['customers'] as Map<String, dynamic>?)?['full_name'] ??
        (x['suppliers'] as Map<String, dynamic>?)?['name'];
    final ac = '${x['description'] ?? ''}'.trim();
    final detay = [
      tarih('${x['tx_date']}'),
      odemeYontemleri['${x['method']}'] ?? '',
      if (kisi != null) '$kisi',
      if (ac.isNotEmpty) ac,
    ].join(' • ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: renk.withValues(alpha: 0.18),
          child: Icon(giris ? Icons.arrow_downward : Icons.arrow_upward,
              color: renk),
        ),
        title: Text(baslik, style: const TextStyle(fontSize: 16)),
        subtitle: Text(detay),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${giris ? '+' : '-'}${para(alan(x, 'amount'))}',
                style: TextStyle(
                    color: renk, fontWeight: FontWeight.bold, fontSize: 16)),
            if (_elleTipler.contains(tip))
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'İptal et',
                onPressed: () => _iptal(x),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liste = _yon == null
        ? _liste
        : _liste.where((x) => x['direction'] == _yon).toList();
    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: CircularProgressIndicator());
    } else if (_hata != null) {
      govde = Center(
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
    } else {
      govde = ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: Colors.indigo.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Kasa bakiyesi', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(para(_bakiye),
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _bakiye >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _kutu('Bugün giren', para(_bugun('giris')), Colors.greenAccent),
              _kutu('Bugün çıkan', para(_bugun('cikis')), Colors.redAccent),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _ekle('giris'),
                    icon: const Icon(Icons.add),
                    label: const Text('Para girişi'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _ekle('cikis'),
                    icon: const Icon(Icons.remove),
                    label: const Text('Para çıkışı'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _yon == null,
                  onSelected: (_) => setState(() => _yon = null)),
              ChoiceChip(
                  label: const Text('Giriş'),
                  selected: _yon == 'giris',
                  onSelected: (_) => setState(() => _yon = 'giris')),
              ChoiceChip(
                  label: const Text('Çıkış'),
                  selected: _yon == 'cikis',
                  onSelected: (_) => setState(() => _yon = 'cikis')),
            ],
          ),
          const SizedBox(height: 8),
          if (liste.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('Henüz hareket yok.',
                      style: TextStyle(fontSize: 16))),
            ),
          ...liste.map(_satir),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Servis, satış ve tedarikçi hareketleri kendi ekranlarından yapılınca buraya otomatik gelir. Burada sadece gider, açılış bakiyesi, para çekme ve diğer gelirleri elle girersiniz.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
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
            title: const Text('Kasa'),
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
              child: govde,
            ),
          ),
        ),
      ),
    );
  }
}

class HareketFormu extends StatefulWidget {
  final String yon;
  const HareketFormu({super.key, required this.yon});

  @override
  State<HareketFormu> createState() => _HareketFormuState();
}

class _HareketFormuState extends State<HareketFormu> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  late String _tip = widget.yon == 'giris' ? 'diger_gelir' : 'gider';
  String _kategori = 'Kira';
  String _yontem = 'nakit';
  DateTime _tarih = DateTime.now();
  bool _kaydediliyor = false;
  String? _hata;

  List<String> get _tipler => widget.yon == 'giris'
      ? ['diger_gelir', 'acilis']
      : ['gider', 'para_cekme'];

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (t != null) setState(() => _tarih = t);
  }

  Future<void> _kaydet() async {
    final kurus = (sayi(_tutar.text) * 100).round();
    if (kurus <= 0) {
      setState(() => _hata = 'Tutarı yazın.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      await _db.from('cash_transactions').insert({
        'tx_date': _tarih.toIso8601String().substring(0, 10),
        'direction': widget.yon,
        'kind': _tip,
        'section': 'genel',
        'amount': kurus / 100,
        'method': _yontem,
        'description': _aciklama.text.trim(),
        'category': _tip == 'gider' ? _kategori : '',
      });
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

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _koyu(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(widget.yon == 'giris' ? 'Para girişi' : 'Para çıkışı'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Türü', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _tipler
                        .map((t) => ChoiceChip(
                              label: Text(_tipAdlari[t] ?? t),
                              selected: _tip == t,
                              onSelected: (_) => setState(() => _tip = t),
                            ))
                        .toList(),
                  ),
                  if (_tip == 'acilis')
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Uygulamaya başlarken kasada bulunan parayı bir kez girin.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  if (_tip == 'gider') ...[
                    const SizedBox(height: 16),
                    const Text('Kategori', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _giderKategorileri
                          .map((k) => ChoiceChip(
                                label: Text(k),
                                selected: _kategori == k,
                                onSelected: (_) =>
                                    setState(() => _kategori = k),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tutar,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tutar',
                      suffixText: '₺',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title:
                          Text('Tarih: ${tarih(_tarih.toIso8601String())}'),
                      trailing: const Icon(Icons.edit),
                      onTap: _tarihSec,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _aciklama,
                    decoration: const InputDecoration(
                        labelText: 'Açıklama', border: OutlineInputBorder()),
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_hata!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 16)),
                    ),
                  const SizedBox(height: 20),
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
      ),
    );
  }
}