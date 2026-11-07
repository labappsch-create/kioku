import 'package:flutter/material.dart';

void main() {
  runApp(const KiokuApp());
}

class KiokuApp extends StatelessWidget {
  const KiokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kioku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const PantallaBienvenida(),
    );
  }
}

/// Pantalla de prueba: confirma que la app se instaló bien.
/// Se reemplazará cuando construyamos los perfiles.
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kioku', style: textos.displayMedium),
                const SizedBox(height: 8),
                Text('Karate Kyokushin', style: textos.titleMedium),
                const SizedBox(height: 32),
                Text(
                  'Versión de prueba.\n'
                  'Si ves esta pantalla, la instalación funcionó.',
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
