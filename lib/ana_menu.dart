import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alislar.dart';
import 'musteriler.dart';
import 'servisler.dart';
import 'stok.dart';
import 'tedarikciler.dart';

class AnaMenu extends StatelessWidget {
  const AnaMenu({super.key});

  void _git(BuildContext context, Widget sayfa) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => sayfa));
  }

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
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _Dugme(
                icon: Icons.build,
                yazi: 'Servis Kayıtları',
                onTap: () => _git(context, const ServislerSayfasi()),
              ),
              const SizedBox(height: 16),
              _Dugme(
                icon: Icons.people,
                yazi: 'Müşteriler',
                onTap: () => _git(context, const MusterilerSayfasi()),
              ),
              const SizedBox(height: 16),
              _Dugme(
                icon: Icons.inventory_2,
                yazi: 'Stok ve Parçalar',
                onTap: () => _git(context, const StokSayfasi()),
              ),
              const SizedBox(height: 16),
              _Dugme(
                icon: Icons.add_shopping_cart,
                yazi: 'Parça Alışları',
                onTap: () => _git(context, const AlislarSayfasi()),
              ),
              const SizedBox(height: 16),
              _Dugme(
                icon: Icons.local_shipping,
                yazi: 'Tedarikçiler',
                onTap: () => _git(context, const TedarikcilerSayfasi()),
              ),
            ],
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