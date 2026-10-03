import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const ZarovaApp());
}

class ZarovaApp extends StatelessWidget {
  const ZarovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zarova Teknik Servis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const BaglantiTestiSayfasi(),
    );
  }
}

class BaglantiTestiSayfasi extends StatefulWidget {
  const BaglantiTestiSayfasi({super.key});

  @override
  State<BaglantiTestiSayfasi> createState() => _BaglantiTestiSayfasiState();
}

class _BaglantiTestiSayfasiState extends State<BaglantiTestiSayfasi> {
  String durum = 'Bağlantı kontrol ediliyor...';
  bool? tamam;

  @override
  void initState() {
    super.initState();
    _kontrol();
  }

  Future<void> _kontrol() async {
    setState(() {
      tamam = null;
      durum = 'Bağlantı kontrol ediliyor...';
    });
    try {
      final cevap = await http.get(
        Uri.parse('$supabaseUrl/auth/v1/health'),
        headers: {'apikey': supabaseKey},
      );
      if (!mounted) return;
      setState(() {
        tamam = cevap.statusCode == 200;
        durum = tamam!
            ? 'Veritabanına bağlanıldı ✓'
            : 'Sunucu cevap verdi ama sorun var (kod: ${cevap.statusCode})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        tamam = false;
        durum = 'Bağlanılamadı: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = tamam == null
        ? Colors.orange
        : (tamam! ? Colors.green : Colors.red);
    return Scaffold(
      appBar: AppBar(title: const Text('Zarova Teknik Servis')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done, size: 80, color: renk),
              const SizedBox(height: 16),
              Text(durum,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _kontrol,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}