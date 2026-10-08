import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ortak.dart';

final _db = Supabase.instance.client;

Future<Map<String, dynamic>> isletmeAyarlari() async {
  try {
    final v = await _db.from('business_settings').select().eq('id', 1).single();
    return Map<String, dynamic>.from(v);
  } catch (_) {
    return {
      'name': 'Zarova Teknik Servis',
      'phone': '',
      'address': '',
      'technicians': '',
      'form_note': '',
    };
  }
}

Future<List<String>> ustalariGetir() async {
  final a = await isletmeAyarlari();
  return '${a['technicians'] ?? ''}'
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// Servis formunda ustaların adını tek dokunuşla seçtirir.
class UstaSecici extends StatefulWidget {
  final TextEditingController controller;
  const UstaSecici({super.key, required this.controller});

  @override
  State<UstaSecici> createState() => _UstaSeciciState();
}

class _UstaSeciciState extends State<UstaSecici> {
  List<String> _ustalar = [];

  @override
  void initState() {
    super.initState();
    ustalariGetir().then((l) {
      if (mounted) setState(() => _ustalar = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ustalar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        children: _ustalar
            .map((u) => ActionChip(
                  label: Text(u),
                  onPressed: () => widget.controller.text = u,
                ))
            .toList(),
      ),
    );
  }
}

class AyarlarSayfasi extends StatefulWidget {
  const AyarlarSayfasi({super.key});

  @override
  State<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  final _ad = TextEditingController();
  final _tel = TextEditingController();
  final _adres = TextEditingController();
  final _ustalar = TextEditingController();
  final _not = TextEditingController();
  bool _yuk = true;
  bool _kay = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [_ad, _tel, _adres, _ustalar, _not]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _yukle() async {
    final a = await isletmeAyarlari();
    if (!mounted) return;
    setState(() {
      _ad.text = '${a['name'] ?? ''}';
      _tel.text = '${a['phone'] ?? ''}';
      _adres.text = '${a['address'] ?? ''}';
      _ustalar.text = '${a['technicians'] ?? ''}';
      _not.text = '${a['form_note'] ?? ''}';
      _yuk = false;
    });
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().isEmpty) {
      setState(() => _hata = 'İşletme adını yazın.');
      return;
    }
    setState(() {
      _kay = true;
      _hata = null;
    });
    try {
      await _db.from('business_settings').update({
        'name': _ad.text.trim(),
        'phone': _tel.text.trim(),
        'address': _adres.text.trim(),
        'technicians': _ustalar.text.trim(),
        'form_note': _not.text.trim(),
      }).eq('id', 1);
      if (!mounted) return;
      setState(() => _kay = false);
      bildir(context, 'Ayarlar kaydedildi.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Kaydedilemedi: ${hataMetni(e)}';
        _kay = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Ayarlar',
      govde: _yuk
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                girdi(_ad, 'İşletme adı (servis formunda görünür)'),
                girdi(_tel, 'Telefon'),
                girdi(_adres, 'Adres', satir: 2),
                girdi(_ustalar, 'Ustalar (virgülle ayırın: Fatih, Hanifi)'),
                girdi(_not, 'Servis formu alt notu', satir: 3),
                hataYazisi(_hata),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _kay ? null : _kaydet,
                    child: _kay
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 3))
                        : const Text('Kaydet', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
    );
  }
}