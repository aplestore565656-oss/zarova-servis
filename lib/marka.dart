import 'package:flutter/material.dart';

class _Marka {
  final String ad;
  final Color renk;
  final Color yazi;
  const _Marka(this.ad, this.renk, this.yazi);
}

const _markalar = <_Marka>[
  _Marka('Apple', Color(0xFFF2F2F7), Color(0xFF111111)),
  _Marka('Samsung', Color(0xFF1428A0), Colors.white),
  _Marka('Xiaomi', Color(0xFFFF6900), Colors.white),
  _Marka('Huawei', Color(0xFFCF0A2C), Colors.white),
  _Marka('Oppo', Color(0xFF1BA261), Colors.white),
  _Marka('Realme', Color(0xFFFFC915), Color(0xFF111111)),
];

/// Marka düğmeleri: dokununca marka kutusunu doldurur.
class MarkaSecici extends StatelessWidget {
  final TextEditingController controller;
  const MarkaSecici({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, v, _) {
        final yazilan = v.text.trim().toLowerCase();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _markalar.map((m) {
              final secili = yazilan == m.ad.toLowerCase();
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  controller.text = m.ad;
                  controller.selection =
                      TextSelection.collapsed(offset: m.ad.length);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: m.renk,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: secili ? Colors.cyanAccent : Colors.transparent,
                        width: 3),
                  ),
                  child: Text(
                    m.ad,
                    style: TextStyle(
                      color: m.yazi,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// Listelerde marka için küçük renkli rozet.
class MarkaRozeti extends StatelessWidget {
  final String marka;
  final double boyut;
  const MarkaRozeti({super.key, required this.marka, this.boyut = 30});

  @override
  Widget build(BuildContext context) {
    final a = marka.trim().toLowerCase();
    _Marka? m;
    for (final x in _markalar) {
      if (x.ad.toLowerCase() == a) m = x;
    }
    return Container(
      width: boyut,
      height: boyut,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: m?.renk ?? Colors.blueGrey,
        shape: BoxShape.circle,
      ),
      child: m == null
          ? Icon(Icons.smartphone, size: boyut * 0.6, color: Colors.white)
          : Text(m.ad.substring(0, 1),
              style: TextStyle(
                  color: m.yazi,
                  fontWeight: FontWeight.w900,
                  fontSize: boyut * 0.5)),
    );
  }
}