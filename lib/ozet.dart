import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'yardimci.dart';

final _db = Supabase.instance.client;

class OzetPaneli extends StatefulWidget {
  const OzetPaneli({super.key});

  @override
  State<OzetPaneli> createState() => _OzetPaneliState();
}

class _OzetPaneliState extends State<OzetPaneli> {
  Map<String, dynamic>? _o;
  bool _yukleniyor = true;
  String? _hata;

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
      final v = await _db.from('dashboard_summary').select().single();
      if (!mounted) return;
      setState(() {
        _o = v;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Özet alınamadı: ${hataMetni(e)}';
        _yukleniyor = false;
      });
    }
  }

  Widget _kart(String baslik, String deger, IconData ikon, Color renk) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: renk.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 16, color: renk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(baslik,
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(deger,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: renk)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_yukleniyor) {
      govde = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_hata != null || _o == null) {
      govde = Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_hata ?? 'Özet alınamadı.',
            style: const TextStyle(color: Colors.redAccent)),
      );
    } else {
      final o = _o!;
      final kasa = alan(o, 'cash');
      govde = Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _kart('Bugünkü tahsilat', para(alan(o, 'today_collected')),
              Icons.payments, Colors.greenAccent),
          _kart('Bugünkü gider', para(alan(o, 'today_expense')),
              Icons.south_east, Colors.redAccent),
          _kart('Kasa', para(kasa), Icons.account_balance_wallet,
              kasa >= 0 ? Colors.greenAccent : Colors.redAccent),
          _kart('Bugünkü kâr', para(alan(o, 'today_profit')), Icons.trending_up,
              alan(o, 'today_profit') >= 0
                  ? Colors.greenAccent
                  : Colors.redAccent),
          _kart('Müşteri alacağı', para(alan(o, 'customer_receivable')),
              Icons.people, Colors.orangeAccent),
          _kart('Tedarikçi borcu', para(alan(o, 'supplier_debt')),
              Icons.local_shipping, Colors.orangeAccent),
          _kart('Stok değeri', para(alan(o, 'stock_value')), Icons.inventory_2,
              Colors.lightBlueAccent),
          _kart('Bugün gelen servis', '${tam(o, 'today_services')}',
              Icons.login, Colors.lightBlueAccent),
          _kart('Bekleyen tamir', '${tam(o, 'waiting_services')}', Icons.build,
              Colors.amberAccent),
          _kart('Parça bekleyen', '${tam(o, 'waiting_part')}',
              Icons.hourglass_bottom, Colors.purpleAccent),
          _kart('Teslime hazır', '${tam(o, 'ready_services')}',
              Icons.check_circle, Colors.greenAccent),
          _kart('Azalan stok', '${tam(o, 'low_stock')}', Icons.warning_amber,
              tam(o, 'low_stock') > 0 ? Colors.redAccent : Colors.greenAccent),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('Genel durum',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Yenile'),
            ],
          ),
          govde,
        ],
      ),
    );
  }
}