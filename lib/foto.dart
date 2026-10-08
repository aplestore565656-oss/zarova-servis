import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart' show hataMetni;
import 'ortak.dart';

final _db = Supabase.instance.client;
const _etiketler = ['Ön', 'Arka', 'Sağ', 'Sol', 'Hasar', 'Diğer'];

class FotoPaneli extends StatefulWidget {
  final String servisId;
  const FotoPaneli({super.key, required this.servisId});

  @override
  State<FotoPaneli> createState() => _FotoPaneliState();
}

class _FotoPaneliState extends State<FotoPaneli> {
  List<Map<String, dynamic>> _liste = [];
  bool _yuk = true;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final v = await _db
          .from('service_photos')
          .select()
          .eq('service_order_id', widget.servisId)
          .isFilter('removed_at', null)
          .order('created_at');
      final liste = List<Map<String, dynamic>>.from(v);
      for (final f in liste) {
        try {
          f['url'] = await _db.storage
              .from('device-photos')
              .createSignedUrl('${f['path']}', 3600);
        } catch (_) {
          f['url'] = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _liste = liste;
        _yuk = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = 'Fotoğraflar alınamadı: ${hataMetni(e)}';
        _yuk = false;
      });
    }
  }

  Future<void> _ekle() async {
    final etiket = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Hangi yön?'),
        children: _etiketler
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(e, style: const TextStyle(fontSize: 18)),
                  ),
                ))
            .toList(),
      ),
    );
    if (etiket == null) return;
    final secilen = await ImagePicker().pickMultiImage();
    if (secilen.isEmpty) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      for (final x in secilen) {
        final ham = await x.readAsBytes();
        final dec = img.decodeImage(ham);
        if (dec == null) throw Exception('Görsel okunamadı.');
        final buyuk = dec.width > dec.height ? dec.width : dec.height;
        final kucuk = buyuk > 1280
            ? img.copyResize(dec,
                width: dec.width >= dec.height ? 1280 : null,
                height: dec.height > dec.width ? 1280 : null)
            : dec;
        final bytes = img.encodeJpg(kucuk, quality: 80);
        final yol =
            '${widget.servisId}/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await _db.storage.from('device-photos').uploadBinary(yol, bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'));
        await _db.from('service_photos').insert({
          'service_order_id': widget.servisId,
          'path': yol,
          'label': etiket,
        });
      }
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Yüklenemedi: ${hataMetni(e)}');
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _buyut(Map<String, dynamic> f) async {
    final sil = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${f['label']}'),
        content: SizedBox(
          width: 500,
          child: f['url'] == null
              ? const Text('Görsel yüklenemedi.')
              : Image.network('${f['url']}', fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Fotoğrafı kaldır')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kapat')),
        ],
      ),
    );
    if (sil != true) return;
    try {
      await _db
          .from('service_photos')
          .update({'removed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', f['id']);
      _yukle();
    } catch (e) {
      if (!mounted) return;
      bildir(context, 'Kaldırılamadı: ${hataMetni(e)}');
    }
  }

  Widget _kucuk(Map<String, dynamic> f) {
    return InkWell(
      onTap: () => _buyut(f),
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: f['url'] == null
                  ? const SizedBox(
                      width: 110,
                      height: 110,
                      child: Icon(Icons.broken_image))
                  : Image.network(
                      '${f['url']}',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                          width: 110,
                          height: 110,
                          child: Icon(Icons.broken_image)),
                    ),
            ),
            const SizedBox(height: 4),
            Text('${f['label']}', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: bolumBasligi('Fotoğraflar')),
            TextButton.icon(
              onPressed: _yukleniyor ? null : _ekle,
              icon: const Icon(Icons.add_a_photo),
              label: Text(_yukleniyor ? 'Yükleniyor...' : 'Fotoğraf ekle'),
            ),
          ],
        ),
        hataYazisi(_hata),
        if (_yuk)
          const Center(child: CircularProgressIndicator())
        else if (_liste.isEmpty)
          const Padding(
              padding: EdgeInsets.all(8), child: Text('Fotoğraf eklenmemiş.'))
        else
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _liste.map(_kucuk).toList()),
      ],
    );
  }
}