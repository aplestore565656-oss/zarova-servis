import 'package:flutter/material.dart';
import 'alislar.dart' show odemeYontemleri;
import 'ana_menu.dart' show YildizArkaplan;
import 'yardimci.dart';

ThemeData koyuTema() => ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: Colors.cyan,
    useMaterial3: true);

class Sayfa extends StatelessWidget {
  final String baslik;
  final Widget govde;
  final List<Widget> actions;
  final Widget? fab;
  final double genislik;
  const Sayfa({
    super.key,
    required this.baslik,
    required this.govde,
    this.actions = const [],
    this.fab,
    this.genislik = 760,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: koyuTema(),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(baslik),
              actions: actions),
          floatingActionButton: fab,
          body: Center(
            child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: genislik), child: govde),
          ),
        ),
      ),
    );
  }
}

Future<bool> onayAl(
    BuildContext c, String baslik, String metin, String evet) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: Text(metin),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(evet)),
      ],
    ),
  );
  return r == true;
}

void bildir(BuildContext c, String m) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

Widget girdi(TextEditingController c, String etiket,
    {bool sayiMi = false,
    bool tamMi = false,
    int satir = 1,
    bool tl = false,
    VoidCallback? degisti}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: satir,
      keyboardType: sayiMi
          ? const TextInputType.numberWithOptions(decimal: true)
          : (tamMi ? TextInputType.number : TextInputType.text),
      onChanged: degisti == null ? null : (_) => degisti(),
      decoration: InputDecoration(
        labelText: etiket,
        border: const OutlineInputBorder(),
        suffixText: tl ? '₺' : null,
      ),
    ),
  );
}

Widget bolumBasligi(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(t,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );

Widget hataYazisi(String? h) => h == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(h,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
      );

Widget durumGovdesi({
  required bool yukleniyor,
  String? hata,
  required VoidCallback tekrar,
  required Widget Function() govde,
}) {
  if (yukleniyor) return const Center(child: CircularProgressIndicator());
  if (hata != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hata,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            FilledButton(onPressed: tekrar, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
  return govde();
}

Future<DateTime?> tarihSec(BuildContext c, DateTime ilk) => showDatePicker(
      context: c,
      initialDate: ilk,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

Future<int?> adetSor(BuildContext c, String baslik) {
  final k = TextEditingController(text: '1');
  String? hata;
  return showDialog<int>(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(baslik),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: k,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Adet', border: OutlineInputBorder()),
            ),
            if (hata != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(hata!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final n = tamSayi(k.text);
              if (n <= 0) {
                setS(() => hata = 'Adet 1 veya daha fazla olmalı.');
                return;
              }
              Navigator.pop(ctx, n);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    ),
  );
}

/// Tutar ve ödeme yöntemi sorar. {'tutar': double, 'yontem': String} verir.
Future<Map<String, dynamic>?> tutarSor(BuildContext c, String baslik,
    {String ilk = ''}) {
  final k = TextEditingController(text: ilk);
  String yontem = 'nakit';
  String? hata;
  return showDialog<Map<String, dynamic>>(
    context: c,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(baslik),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: k,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Tutar',
                  suffixText: '₺',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: odemeYontemleri.entries
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: yontem == e.key,
                        onSelected: (_) => setS(() => yontem = e.key),
                      ))
                  .toList(),
            ),
            if (hata != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(hata!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              final kurus = (sayi(k.text) * 100).round();
              if (kurus < 0) {
                setS(() => hata = 'Tutar negatif olamaz.');
                return;
              }
              Navigator.pop(ctx, {'tutar': kurus / 100, 'yontem': yontem});
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    ),
  );
}