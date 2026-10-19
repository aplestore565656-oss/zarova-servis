import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'yardimci.dart';

final _db = Supabase.instance.client;

class KasaOzeti extends StatefulWidget {
  const KasaOzeti({super.key});

  @override
  State<KasaOzeti> createState() => _KasaOzetiState();
}

class _KasaOzetiState extends State<KasaOzeti> {
  Map<String, Map<String, dynamic>> _yontem = {};
  Map<String, dynamic>? _d;
  bool _yuk = true;
  String? _hata;

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
      final m = await _db.from('cash_by_method').select();
      final d = await _db.from('dashboard_summary').select().single();
      if (!mounted) return;
      setState(() {
        _yontem = {
          for (final x in List<Map<String, dynamic>>.from(m)) '${x['method']}': x
        };
        _d = d;
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kasa özeti alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  double _b(String m) {
    final x = _yontem[m];
    return x == null ? 0.0 : alan(x, 'balance');
  }

  String _bugun(String m) {
    final x = _yontem[m];
    if (x == null) return '';
    return 'Bugün +${para(alan(x, 'today_in'))} / -${para(alan(x, 'today_out'))}';
  }

  Widget _kutu(String baslik, IconData ikon, double deger, Color renk,
      {String? alt}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: renk.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 14, color: renk),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(baslik,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(para(deger),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: renk)),
            ),
            if (alt != null && alt.isNotEmpty)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(alt,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_yuk) {
      govde = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_hata != null || _d == null) {
      govde = Padding(
        padding: const EdgeInsets.all(8),
        child: Text(_hata ?? 'Kasa özeti alınamadı.',
            style: const TextStyle(color: Colors.redAccent)),
      );
    } else {
      final d = _d!;
      final kasa = alan(d, 'cash');
      govde = Column(
        children: [
          Row(
            children: [
              _kutu('Nakit', Icons.payments, _b('nakit'), Colors.greenAccent,
                  alt: _bugun('nakit')),
              _kutu('Kart', Icons.credit_card, _b('kart'),
                  Colors.lightBlueAccent,
                  alt: _bugun('kart')),
              _kutu('Havale/EFT', Icons.account_balance, _b('havale'),
                  Colors.purpleAccent,
                  alt: _bugun('havale')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _kutu('Toplam kasa', Icons.account_balance_wallet, kasa,
                 kasa >= 0 ? Colors.cyanAccent : Colors.redAccent,
                  alt: 'Borç ödenince: ${para(kasa - alan(d, 'supplier_debt'))}'),
              _kutu('Müşteri alacağı', Icons.people,
                  alan(d, 'customer_receivable'), Colors.orangeAccent),
              _kutu('Tedarikçi borcu', Icons.local_shipping,
                  alan(d, 'supplier_debt'), Colors.redAccent),
            ],
          ),
        ],
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('Kasa özeti',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                onPressed: _yukle,
                tooltip: 'Yenile',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          govde,
        ],
      ),
    );
  }
}