import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'musteriler.dart';
import 'servisler.dart';

class AnaMenu extends StatelessWidget {
  const AnaMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Supabase.instance.client;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarova Teknik Servis'),
        actions: [
          TextButton.icon(
            onPressed: () => db.auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dugme(
                  icon: Icons.build,
                  yazi: 'Servis Kayıtları',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ServislerSayfasi()),
                  ),
                ),
                const SizedBox(height: 16),
                _Dugme(
                  icon: Icons.people,
                  yazi: 'Müşteriler',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MusterilerSayfasi()),
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

class _Dugme extends StatelessWidget {
  final IconData icon;
  final String yazi;
  final VoidCallback onTap;
  const _Dugme({required this.icon, required this.yazi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 32),
        label: Text(yazi, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}