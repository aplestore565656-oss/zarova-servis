import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      title: 'Zarova Teknik Servis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GirisKontrol(),
    );
  }
}

/// Giriş yapılmış mı diye bakar: yapılmışsa ana sayfa, yapılmamışsa giriş ekranı.
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
        return const AnaSayfa();
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
    } on AuthException {
      if (!mounted) return;
      setState(() => _hata = 'E-posta veya şifre hatalı.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Bağlantı hatası. İnternetinizi kontrol edin.');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.build_circle, size: 80, color: Colors.indigo),
                const SizedBox(height: 12),
                const Text(
                  'Zarova Teknik Servis',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _eposta,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
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
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_hata != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _hata!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
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
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text('Giriş Yap',
                            style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  late Future<Map<String, dynamic>?> _profil;

  @override
  void initState() {
    super.initState();
    _profil = _profilGetir();
  }

  Future<Map<String, dynamic>?> _profilGetir() async {
    final kullanici = supabase.auth.currentUser;
    if (kullanici == null) return null;
    return await supabase
        .from('profiles')
        .select()
        .eq('id', kullanici.id)
        .maybeSingle();
  }

  String _rolAdi(String? rol) {
    switch (rol) {
      case 'yonetici':
        return 'Yönetici';
      case 'ortak':
        return 'Ortak';
      default:
        return 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarova Teknik Servis'),
        actions: [
          TextButton.icon(
            onPressed: () => supabase.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış'),
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _profil,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Profil bilgisi alınamadı. İnternetinizi kontrol edin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              );
            }
            final profil = snapshot.data;
            if (profil == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu hesap için profil bulunamadı. Yöneticiye haber verin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.red),
                ),
              );
            }
            final ad = (profil['full_name'] as String?) ?? '';
            final rol = _rolAdi(profil['role'] as String?);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  ad.isEmpty ? 'Hoş geldiniz' : 'Hoş geldiniz, $ad',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Rolünüz: $rol', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text(supabase.auth.currentUser?.email ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            );
          },
        ),
      ),
    );
  }
}