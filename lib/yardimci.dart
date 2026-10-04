String para(num n) => '${n.toStringAsFixed(2).replaceAll('.', ',')} ₺';

double sayi(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;

double alan(Map<String, dynamic> m, String anahtar) =>
    ((m[anahtar] as num?) ?? 0).toDouble();

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