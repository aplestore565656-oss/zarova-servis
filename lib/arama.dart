import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'musteriler.dart' show MusteriDetaySayfasi;
import 'ortak.dart';
import 'servisler.dart' show ServisDetaySayfasi;
import 'tedarikciler.dart' show TedarikciDetaySayfasi;
import 'urunler.dart' show UrunFormu;
import 'yardimci.dart';

final _db = Supabase.instance.client;

class AramaSayfasi extends StatefulWidget {
  const AramaSayfasi({super.key});

  @override
  State<AramaSayfasi> createState() => _AramaSayfasiState();
}

class _AramaSayfasiState extends State<AramaSayfasi> {
  Timer? _zaman;
  int _sira = 0;
  bool _yuk = false;
  String? _hata;
  String _son = '';
  List<Map<String, dynamic>> _musteriler = [];
  List<Map<String, dynamic>> _servisler = [];
  List<Map<String, dynamic>> _urunler = [];
  List<Map<String, dynamic>> _tedarikciler = [];

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  void _degisti(String ham) {
    _zaman?.cancel();
    _zaman = Timer(const Duration(milliseconds: 350), () => _ara(ham));
  }

  Future<void> _ara(String ham) async {
    final q = ham.replaceAll(RegExp(r'[,()%*\\"]'), ' ').trim();
    final sira = ++_sira;
    if (q.length < 2) {
      setState(() {
        _son = '';
        _musteriler = [];
        _servisler = [];
        _urunler = [];
        _tedarikciler = [];
        _yuk = false;
        _hata = null;
      });
      return;
    }
    setState(() {
      _yuk = true;
      _hata = null;
    });
    try {
      final m = await _db
          .from('customers')
          .select()
          .or('full_name.ilike.*$q*,phone.ilike.*$q*,alt_phone.ilike.*$q*')
          .isFilter('deleted_at', null)
          .limit(15);
      final ml = List<Map<String, dynamic>>.from(m);
      final s1 = await _db
          .from('service_orders')
          .select('*, customers(full_name, phone)')
          .or('order_no.ilike.*$q*,imei.ilike.*$q*,brand.ilike.*$q*,model.ilike.*$q*')
          .isFilter('deleted_at', null)
          .order('received_at', ascending: false)
          .limit(15);
      final sl = List<Map<String, dynamic>>.from(s1);
      if (ml.isNotEmpty) {
        final s2 = await _db
            .from('service_orders')
            .select('*, customers(full_name, phone)')
            .inFilter('customer_id', ml.map((e) => e['id']).toList())
            .isFilter('deleted_at', null)
            .order('received_at', ascending: false)
            .limit(15);
        for (final x in List<Map<String, dynamic>>.from(s2)) {
          if (!sl.any((y) => y['id'] == x['id'])) sl.add(x);
        }
      }
      final u = await _db
          .from('products')
          .select()
          .or('name.ilike.*$q*,brand.ilike.*$q*,model.ilike.*$q*,compatible.ilike.*$q*,serial_no.ilike.*$q*')
          .isFilter('deleted_at', null)
          .limit(15);
      final t = await _db
          .from('suppliers')
          .select()
          .or('name.ilike.*$q*,phone.ilike.*$q*')
          .isFilter('deleted_at', null)
          .limit(15);
      if (!mounted || sira != _sira) return;
      setState(() {
        _son = q;
        _musteriler = ml;
        _servisler = sl;
        _urunler = List<Map<String, dynamic>>.from(u);
        _tedarikciler = List<Map<String, dynamic>>.from(t);
        _yuk = false;
      });
    } catch (e) {
      if (!mounted || sira != _sira) return;
      setState(() {
        _hata = 'Arama yapılamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  void _git(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final bos = _son.isNotEmpty &&
        _musteriler.isEmpty &&
        _servisler.isEmpty &&
        _urunler.isEmpty &&
        _tedarikciler.isEmpty;
    return Sayfa(
      baslik: 'Genel Arama',
      govde: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            autofocus: true,
            onChanged: _degisti,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Müşteri, telefon, IMEI, iş emri, model, parça, tedarikçi',
              border: OutlineInputBorder(),
            ),
          ),
          if (_yuk)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          hataYazisi(_hata),
          if (_son.isEmpty && !_yuk)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('En az 2 harf yazın.',
                      style: TextStyle(color: Colors.grey))),
            ),
          if (bos && !_yuk)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('Sonuç bulunamadı.',
                      style: TextStyle(fontSize: 16))),
            ),
          if (_musteriler.isNotEmpty) bolumBasligi('Müşteriler'),
          ..._musteriler.map((m) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text('${m['full_name']}'),
                  subtitle: Text('${m['phone']}'),
                  onTap: () => _git(MusteriDetaySayfasi(musteri: m)),
                ),
              )),
          if (_servisler.isNotEmpty) bolumBasligi('Servis kayıtları'),
          ..._servisler.map((s) {
            final c = s['customers'] as Map<String, dynamic>?;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.build),
                title: Text(
                    '${s['order_no']} • ${s['brand']} ${s['model']}'.trim()),
                subtitle: Text(
                    '${c?['full_name'] ?? ''} • ${s['status']} • ${tarih('${s['received_at']}')}'),
                onTap: () => _git(ServisDetaySayfasi(siparis: s)),
              ),
            );
          }),
          if (_urunler.isNotEmpty) bolumBasligi('Parçalar'),
          ..._urunler.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.memory),
                  title: Text(
                      '${p['name']} ${p['brand']} ${p['model']}'.trim()),
                  subtitle: Text('Stok ${tam(p, 'stock')} • Satış ${para(alan(p, 'sell_price'))}'),
                  onTap: () =>
                      _git(UrunFormu(bolum: '${p['section']}', urun: p)),
                ),
              )),
          if (_tedarikciler.isNotEmpty) bolumBasligi('Tedarikçiler'),
          ..._tedarikciler.map((t) => Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: Text('${t['name']}'),
                  subtitle: Text('${t['phone']}'),
                  onTap: () => _git(TedarikciDetaySayfasi(tedarikci: t)),
                ),
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}