import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ortak.dart';
import 'servisler.dart' show ServisDetaySayfasi;
import 'yardimci.dart';

final _db = Supabase.instance.client;

String _cihaz(Map<String, dynamic> s) =>
    '${s['brand'] ?? ''} ${s['model'] ?? ''}'.trim();

String _parcalar(Map<String, dynamic> s) =>
    List<Map<String, dynamic>>.from(s['service_items'] ?? const [])
        .where((e) => e['removed_at'] == null)
        .map((e) => '${e['description'] ?? ''}'.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');

class AlacakDefteriSayfasi extends StatefulWidget {
  const AlacakDefteriSayfasi({super.key});

  @override
  State<AlacakDefteriSayfasi> createState() => _AlacakDefteriSayfasiState();
}

class _AlacakDefteriSayfasiState extends State<AlacakDefteriSayfasi> {
  List<Map<String, dynamic>> _gruplar = [];
  bool _yuk = true;
  String? _hata;
  String _arama = '';

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
          .from('service_orders')
          .select(
              '*, customers(full_name, phone), service_items(description, removed_at)')
          .isFilter('deleted_at', null)
          .order('received_at', ascending: false)
          .limit(2000);
      final s = await _db.from('service_summary').select();
      final ozet = {
        for (final x in List<Map<String, dynamic>>.from(s))
          x['service_order_id']: x
      };
      final harita = <String, Map<String, dynamic>>{};
      for (final o in List<Map<String, dynamic>>.from(v)) {
        final durum = '${o['status']}';
        if (durum == 'İptal edildi' || durum == 'İade edildi') continue;
        final z = ozet[o['id']];
        if (z == null) continue;
        final kalan = alan(z, 'remaining');
        if (kalan <= 0.004) continue;
        final m = o['customers'] as Map<String, dynamic>?;
        final mid = '${o['customer_id']}';
        final g = harita.putIfAbsent(
            mid,
            () => <String, dynamic>{
                  'ad': '${m?['full_name'] ?? ''}',
                  'tel': '${m?['phone'] ?? ''}',
                  'siparisler': <Map<String, dynamic>>[],
                  'odenen': 0.0,
                  'kalan': 0.0,
                });
        (g['siparisler'] as List<Map<String, dynamic>>).add({...o, '_z': z});
        g['odenen'] = (g['odenen'] as double) + alan(z, 'paid');
        g['kalan'] = (g['kalan'] as double) + kalan;
      }
      final liste = harita.values.toList()
        ..sort((a, b) => (b['kalan'] as double).compareTo(a['kalan'] as double));
      if (!mounted) return;
      setState(() {
        _gruplar = liste;
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Alacaklar alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  Widget _isSatiri(Map<String, dynamic> s) {
    final z = s['_z'] as Map<String, dynamic>;
    final cihaz = _cihaz(s);
    final ariza = '${s['problem'] ?? ''}'.trim();
    final yapilan = '${s['work_done'] ?? ''}'.trim();
    final parca = _parcalar(s);
    final satirlar = <String>[
      '${tarih('${s['received_at']}')} • ${s['status']} • ${s['order_no']}',
      if (yapilan.isNotEmpty)
        'Yapılan: $yapilan'
      else if (ariza.isNotEmpty)
        'Arıza: $ariza',
      if (parca.isNotEmpty) 'Parça: $parca',
      'Toplam ${para(alan(z, 'total'))} • Ödenen ${para(alan(z, 'paid'))}',
    ];
    return ListTile(
      isThreeLine: true,
      title: Text(cihaz.isEmpty ? '${s['order_no']}' : cihaz,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      subtitle: Text(satirlar.join('\n'),
          style: const TextStyle(color: Colors.white70)),
      trailing: Text('Kalan\n${para(alan(z, 'remaining'))}',
          textAlign: TextAlign.right,
          style: const TextStyle(
              color: Colors.redAccent, fontWeight: FontWeight.bold)),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServisDetaySayfasi(siparis: s)),
        );
        _yukle();
      },
    );
  }

  Widget _musteriKart(Map<String, dynamic> g) {
    final sip = g['siparisler'] as List<Map<String, dynamic>>;
    final cihazlar = sip
        .map(_cihaz)
        .where((e) => e.isNotEmpty)
        .toSet()
        .join(', ');
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          textColor: Colors.white,
          collapsedTextColor: Colors.white,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('${g['ad']}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          subtitle: Text(
              '${cihazlar.isEmpty ? '' : '$cihazlar\n'}${g['tel']} • ${sip.length} iş • Ödenen ${para(g['odenen'] as double)}',
              style: const TextStyle(color: Colors.white70)),
          trailing: Text(para(g['kalan'] as double),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          children: sip.map(_isSatiri).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Alacak Defteri',
      actions: [
        IconButton(
            onPressed: _yukle,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile'),
      ],
      govde: durumGovdesi(
        yukleniyor: _yuk,
        hata: _hata,
        tekrar: _yukle,
        govde: () {
          final a = _arama.toLowerCase().trim();
          final liste = _gruplar
              .where((g) =>
                  a.isEmpty || '${g['ad']} ${g['tel']}'.toLowerCase().contains(a))
              .toList();
          final toplam =
              _gruplar.fold<double>(0.0, (t, g) => t + (g['kalan'] as double));
          final isSayisi = _gruplar.fold<int>(
              0, (t, g) => t + (g['siparisler'] as List).length);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                color: Colors.orange.withValues(alpha: 0.18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Müşterilerden toplam alacak',
                          style: TextStyle(fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(para(toplam),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent)),
                      const SizedBox(height: 4),
                      Text('${_gruplar.length} müşteri • $isSayisi açık iş',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  key: const ValueKey('alacak-ara'),
                  onChanged: (v) => setState(() => _arama = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Müşteri adı veya telefon ara',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (liste.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('Borçlu müşteri yok.',
                          style: TextStyle(fontSize: 17))),
                ),
              ...liste.map(_musteriKart),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}