import 'package:flutter/material.dart';

String para(num n) => '${n.toStringAsFixed(2).replaceAll('.', ',')} ₺';

double sayi(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

int tamSayi(String s) => int.tryParse(s.trim()) ?? 0;

double alan(Map<String, dynamic> m, String anahtar) =>
    ((m[anahtar] as num?) ?? 0).toDouble();

int tam(Map<String, dynamic> m, String anahtar) =>
    ((m[anahtar] as num?) ?? 0).toInt();

/// Formda göstermek için: 0 ise boş, tam sayıysa küsuratsız yazar.
String sayiYaz(num? v) {
  if (v == null || v == 0) return '';
  final d = v.toDouble();
  return d == d.roundToDouble()
      ? d.toInt().toString()
      : d.toString().replaceAll('.', ',');
}

String tarih(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final g = d.day.toString().padLeft(2, '0');
  final a = d.month.toString().padLeft(2, '0');
  return '$g.$a.${d.year}';
}

String odemeDurumu(double toplam, double odenen) {
  if (toplam <= 0) return 'Ücret girilmedi';
  if (odenen <= 0) return 'Ödenmedi';
  if (odenen < toplam) return 'Kısmi ödeme';
  return 'Ödendi';
}

const odeyenler = <String, String>{
  'yonetici': 'Yönetici',
  'ortak': 'Ortak',
  'kasa': 'Ortak kasa',
};

/// Aranabilir seçim penceresi. Seçilen satırı geri verir.
Future<Map<String, dynamic>?> secimPenceresi(
  BuildContext context, {
  required String baslik,
  required List<Map<String, dynamic>> liste,
  required String ana,
  String? alt,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        _SecimDialog(baslik: baslik, liste: liste, ana: ana, alt: alt),
  );
}

class _SecimDialog extends StatefulWidget {
  final String baslik;
  final List<Map<String, dynamic>> liste;
  final String ana;
  final String? alt;
  const _SecimDialog({
    required this.baslik,
    required this.liste,
    required this.ana,
    this.alt,
  });

  @override
  State<_SecimDialog> createState() => _SecimDialogState();
}

class _SecimDialogState extends State<_SecimDialog> {
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final a = _arama.toLowerCase().trim();
    final liste = widget.liste.where((m) {
      final altMetin = widget.alt == null ? '' : '${m[widget.alt]}';
      return '${m[widget.ana]} $altMetin'.toLowerCase().contains(a);
    }).toList();
    return AlertDialog(
      title: Text(widget.baslik),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _arama = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Ara',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: liste.isEmpty
                  ? const Center(child: Text('Kayıt bulunamadı.'))
                  : ListView(
                      children: liste
                          .map((m) => ListTile(
                                title: Text('${m[widget.ana]}'),
                                subtitle: widget.alt == null
                                    ? null
                                    : Text('${m[widget.alt]}'),
                                onTap: () => Navigator.pop(context, m),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}