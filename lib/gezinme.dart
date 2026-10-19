import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorAnahtari = GlobalKey<NavigatorState>();
final ValueNotifier<int> sayfaDerinligi = ValueNotifier<int>(0);

/// Kaç sayfa açık olduğunu sayar, ev düğmesini göstermek için kullanılır.
class DerinlikGozlemci extends NavigatorObserver {
  int _n = 0;

  void _yaz() {
    WidgetsBinding.instance.addPostFrameCallback((_) => sayfaDerinligi.value = _n);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _n++;
      _yaz();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _n--;
      _yaz();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _n--;
      _yaz();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PageRoute) _n--;
    if (newRoute is PageRoute) _n++;
    _yaz();
  }
}

/// Her sayfanın sol altında görünen ana menü (ev) düğmesi.
class AnaMenuDugmesi extends StatelessWidget {
  const AnaMenuDugmesi({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: sayfaDerinligi,
      builder: (context, d, _) {
        if (d <= 1) return const SizedBox.shrink();
        return Positioned(
          left: 12,
          bottom: 12,
          child: SafeArea(
            child: Material(
              color: const Color(0xFF0E7490),
              elevation: 6,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () =>
                    navigatorAnahtari.currentState?.popUntil((r) => r.isFirst),
                child: const Padding(
                  padding: EdgeInsets.all(13),
                  child: Icon(Icons.home, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}