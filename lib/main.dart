import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ana_menu.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const ZarovaApp());
}

final supabase = Supabase.instance.client;

class ZarovaApp extends StatelessWidget {
  const ZarovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: uygulamaAdi,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GirisKontrol(),
    );
  }
}

class GirisKontrol extends StatelessWidget {
  const GirisKontrol({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (supabase.auth.currentSession == null) {
          return const GirisSayfasi();
        }
        return const AnaMenu();
      },
    );
  }
}

class GirisSayfasi extends StatefulWidget {
  const GirisSayfasi({super.key});

  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

class _GirisSayfasiState extends State<GirisSayfasi> {
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  bool _yukleniyor = false;
  String? _hata;

  @override
  void dispose() {
    _eposta.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (_eposta.text.trim().isEmpty || _sifre.text.isEmpty) {
      setState(() => _hata = 'E-posta ve şifreyi yazın.');
      return;
    }
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: _eposta.text.trim(),
        password: _sifre.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      setState(() => _hata = m.contains('invalid')
          ? 'E-posta veya şifre hatalı.'
          : 'Giriş yapılamadı: ${e.message}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _hata = 'Bağlantı hatası. İnternetinizi kontrol edin.');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.cyan,
          useMaterial3: true),
      child: YildizArkaplan(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.cyan.withValues(alpha: 0.15),
                          blurRadius: 40),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 64,
                        color: Colors.cyanAccent,
                        shadows: [
                          Shadow(color: Colors.cyanAccent, blurRadius: 24)
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        uygulamaAdi,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.cyanAccent, blurRadius: 18)
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _eposta,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _sifre,
                        obscureText: true,
                        onSubmitted: (_) => _girisYap(),
                        decoration: const InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_hata != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _hata!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 16),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _yukleniyor ? null : _girisYap,
                          child: _yukleniyor
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 3))
                              : const Text('Giriş Yap',
                                  style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}