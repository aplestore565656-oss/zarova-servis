import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'yardimci.dart';

final _db = Supabase.instance.client;

const _kaynaklar = <String, String>{
  'servis': 'servis kaydından',
  'aksesuar_satis': 'aksesuar satışından',
  'alis': 'parça alışından',
  'tedarikci_odeme': 'tedarikçi ödemesinden',
  'manuel': 'elle girildi',
};

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
  String? _tur;

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
      final b = await _db.from('account_balances').select();
      final h = await _db
          .from('ledger')
          .select()
          .neq('kind', 'transfer')
          .order('entry_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      setState(() {
        _bakiye = List<Map<String, dynamic>>.from(b)
            .fold(0.0, (t, x) => t + alan(x, 'balance'));
        _liste = List<Map<String, dynamic>>.from(h);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kasa bilgisi alınamadı: $e';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _ekle(String tur) async {
    final s = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HareketFormu(tur: tur)),
    );
    if (s == true) _yukle();
  }

  Future<void> _sil(Map<String, dynamic> h) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hareket silinsin mi?'),
        content: const Text(
            'Kasa bakiyesi buna göre yeniden hesaplanır. Kayıt veritabanında saklanır.'),
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
          .from('cash_entries')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', h['source_id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
    }
  }

  List<Map<String, dynamic>> get _gorunen => _tur == null
      ? _liste
      : _liste.where((h) => h['kind'] == _tur).toList();

  Widget _hareket(Map<String, dynamic> h) {
    final gelir = h['kind'] == 'gelir';
    final renk = gelir ? Colors.green : Colors.red;
    final aciklama = '${h['description'] ?? ''}'.trim();
    final kaynak = _kaynaklar['${h['source']}'] ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: renk.withOpacity(0.12),
          child: Icon(gelir ? Icons.arrow_downward : Icons.arrow_upward,
              color: renk),
        ),
        title: Text(
            '${h['category']}'.isEmpty ? 'Hareket' : '${h['category']}',
            style: const TextStyle(fontSize: 17)),
        subtitle: Text(
            '${tarih(h['entry_date'])}\n${aciklama.isEmpty ? kaynak : '$aciklama ($kaynak)'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${gelir ? '+' : '-'}${para(alan(h, 'amount'))}',
                style: TextStyle(
                    color: renk, fontWeight: FontWeight.bold, fontSize: 16)),
            if (h['source'] == 'manuel')
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Sil',
                onPressed: () => _sil(h),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _hata != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_hata!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _yukle,
                                child: const Text('Tekrar dene')),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          color: _bakiye >= 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Text('Kasa bakiyesi',
                                    style: TextStyle(fontSize: 16)),
                                const SizedBox(height: 6),
                                Text(para(_bakiye),
                                    style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: _bakiye >= 0
                                            ? Colors.green
                                            : Colors.red)),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _ekle('gelir'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Gelir ekle'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _ekle('gider'),
                                  icon: const Icon(Icons.remove),
                                  label: const Text('Gider ekle'),
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
                              selected: _tur == null,
                              onSelected: (_) => setState(() => _tur = null),
                            ),
                            ChoiceChip(
                              label: const Text('Gelir'),
                              selected: _tur == 'gelir',
                              onSelected: (_) => setState(() => _tur = 'gelir'),
                            ),
                            ChoiceChip(
                              label: const Text('Gider'),
                              selected: _tur == 'gider',
                              onSelected: (_) => setState(() => _tur = 'gider'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_gorunen.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: Text('Henüz hareket yok.',
                                    style: TextStyle(fontSize: 16))),
                          ),
                        ..._gorunen.map(_hareket),
                        const SizedBox(height: 24),
                      ],
                    ),
        ),
      ),
    );
  }
}

class HareketFormu extends StatefulWidget {
  final String tur;
  const HareketFormu({super.key, required this.tur});

  @override
  State<HareketFormu> createState() => _HareketFormuState();
}

class _HareketFormuState extends State<HareketFormu> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  late String _kategori = widget.tur == 'gelir' ? 'Parça satışı' : 'Kira';
  DateTime _tarih = DateTime.now();
  bool _kaydediliyor = false;
  String? _hata;

  List<String> get _kategoriler => widget.tur == 'gelir'
      ? ['Parça satışı', 'Diğer']
      : ['Kira', 'Elektrik', 'Diğer'];

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
    final tutar = sayi(_tutar.text);
    if (tutar <= 0) {
      setState(() => _hata = 'Tutarı yazın.');
      return;
    }
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      await _db.from('cash_entries').insert({
        'kind': widget.tur,
        'category': _kategori,
        'amount': tutar,
        'account': 'kasa',
        'description': _aciklama.text.trim(),
        'entry_date': _tarih.toIso8601String().substring(0, 10),
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.tur == 'gelir' ? 'Gelir ekle' : 'Gider ekle')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              const SizedBox(height: 16),
              const Text('Kategori', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _kategoriler
                    .map((k) => ChoiceChip(
                          label: Text(k),
                          selected: _kategori == k,
                          onSelected: (_) => setState(() => _kategori = k),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Tarih: ${tarih(_tarih.toIso8601String())}'),
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
                      style: const TextStyle(color: Colors.red, fontSize: 16)),
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
    );
  }
}