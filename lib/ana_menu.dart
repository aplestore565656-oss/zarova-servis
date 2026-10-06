import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart';
import 'kasa.dart';
import 'musteriler.dart';
import 'satislar.dart';
import 'servisler.dart';
import 'stok.dart';
import 'tedarikciler.dart';
import 'urunler.dart';

/// Uygulamanın adı. İleride değiştirmek için sadece bu satırı değiştirin.
const uygulamaAdi = 'Zarova Teknik Servis';

class _Yildiz {
  final double x, y, boyut, faz;
  final int hiz, renk;
  const _Yildiz(this.x, this.y, this.boyut, this.faz, this.hiz, this.renk);
}

/// Parlayıp sönen, yavaşça kayan yıldızlı arka plan.
class YildizArkaplan extends StatefulWidget {
  final Widget child;
  const YildizArkaplan({super.key, required this.child});

  @override
  State<YildizArkaplan> createState() => _YildizArkaplanState();
}

class _YildizArkaplanState extends State<YildizArkaplan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  late final List<_Yildiz> _yildizlar = () {
    final r = Random(11);
    return List.generate(
      120,
      (_) => _Yildiz(
        r.nextDouble(),
        r.nextDouble(),
        0.6 + r.nextDouble() * 2.0,
        r.nextDouble(),
        6 + r.nextInt(25),
        r.nextInt(4),
      ),
    );
  }();

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF050816),
                  Color(0xFF0B1030),
                  Color(0xFF1A1145),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.8, -0.9),
                radius: 1.3,
                colors: [Color(0x403B82F6), Color(0x003B82F6)],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _kontrol,
              builder: (context, _) => CustomPaint(
                painter: _YildizCizici(_yildizlar, _kontrol.value),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _YildizCizici extends CustomPainter {
  final List<_Yildiz> yildizlar;
  final double t;
  _YildizCizici(this.yildizlar, this.t);

  static const _renkler = [
    Color(0xFFFFFFFF),
    Color(0xFFBFE9FF),
    Color(0xFFD9C6FF),
    Color(0xFFFFE6B8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final y in yildizlar) {
      final kat = y.boyut > 1.8 ? 2 : 1;
      final dikey = (y.y - t * kat) % 1.0;
      final parlak =
          0.35 + 0.65 * (0.5 + 0.5 * sin(2 * pi * (t * y.hiz + y.faz)));
      final merkez = Offset(y.x * size.width, dikey * size.height);
      final renk = _renkler[y.renk];
      if (y.boyut > 1.5) {
        canvas.drawCircle(
          merkez,
          y.boyut * 3.2,
          Paint()
            ..color = renk.withValues(alpha: 0.28 * parlak)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(
        merkez,
        y.boyut * (0.7 + 0.3 * parlak),
        Paint()..color = renk.withValues(alpha: parlak),
      );
    }
  }

  @override
  bool shouldRepaint(_YildizCizici old) => old.t != t;
}

class _Oge {
  final IconData ikon;
  final String yazi;
  final Widget sayfa;
  const _Oge(this.ikon, this.yazi, this.sayfa);
}

class AnaMenu extends StatelessWidget {
  const AnaMenu({super.key});

  static const _mavi = Color(0xFF38BDF8);
  static const _pembe = Color(0xFFF472B6);
  static const _yesil = Color(0xFF34D399);

  void _git(BuildContext context, Widget sayfa) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => sayfa));
  }

  Widget _kolon(BuildContext context, String baslik, IconData ikon,
      Color renk, List<_Oge> ogeler) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(ikon, color: renk, size: 22),
              const SizedBox(width: 8),
              Text(
                baslik,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: renk,
                ),
              ),
            ],
          ),
        ),
        ...ogeler.map(
          (o) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CamDugme(
              ikon: o.ikon,
              yazi: o.yazi,
              renk: renk,
              onTap: () => _git(context, o.sayfa),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final teknik = _kolon(
      context,
      'TEKNİK SERVİS',
      Icons.build_circle,
      _mavi,
      const [
        _Oge(Icons.build, 'Servis Kayıtları', ServislerSayfasi()),
        _Oge(Icons.people, 'Müşteriler', MusterilerSayfasi()),
        _Oge(Icons.inventory_2, 'Stok ve Parçalar', UrunlerSayfasi(bolum: 'teknik')),
        _Oge(Icons.add_shopping_cart, 'Parça Alışları', AlislarSayfasi()),
        _Oge(Icons.local_shipping, 'Tedarikçiler', TedarikcilerSayfasi()),
      ],
    );
    final aksesuar = _kolon(
      context,
      'AKSESUAR',
      Icons.headphones,
      _pembe,
      const [
        _Oge(Icons.point_of_sale, 'Aksesuar Satışı', SatislarSayfasi()),
        _Oge(Icons.inventory, 'Aksesuar Stoku',
            UrunlerSayfasi(bolum: 'aksesuar')),
        _Oge(Icons.add_shopping_cart, 'Aksesuar Alışı', AlislarSayfasi()),
      ],
    );

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
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              uygulamaAdi,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 14)],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış'),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: LayoutBuilder(
                builder: (context, kisit) {
                  final genis = kisit.maxWidth >= 700;
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (genis)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: teknik),
                            const SizedBox(width: 24),
                            Expanded(child: aksesuar),
                          ],
                        )
                      else ...[
                        teknik,
                        const SizedBox(height: 12),
                        aksesuar,
                      ],
                      const SizedBox(height: 8),
                      _CamDugme(
                        ikon: Icons.account_balance_wallet,
                        yazi: 'Kasa',
                        renk: _yesil,
                        onTap: () => _git(context, const KasaSayfasi()),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CamDugme extends StatelessWidget {
  final IconData ikon;
  final String yazi;
  final Color renk;
  final VoidCallback onTap;
  const _CamDugme({
    required this.ikon,
    required this.yazi,
    required this.renk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: renk.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(color: renk.withValues(alpha: 0.18), blurRadius: 18),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              Icon(ikon, color: renk, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  yazi,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}