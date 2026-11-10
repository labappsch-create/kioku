import 'package:flutter/material.dart';

/// Versión que se muestra. Debe coincidir con "version" en pubspec.yaml.
const String versionKioku = '0.10.1';

/// "Acerca de Kioku": significado del nombre, versión y créditos.
class AcercaPantalla extends StatelessWidget {
  const AcercaPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Kioku')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipOval(
              child: Image.asset('assets/icono/icono.png', height: 120),
            ),
          ),
          const SizedBox(height: 16),
          Text('Kioku', textAlign: TextAlign.center, style: textos.headlineMedium),
          Text('記憶', textAlign: TextAlign.center, style: textos.titleLarge),
          const SizedBox(height: 4),
          Text('Versión $versionKioku',
              textAlign: TextAlign.center, style: textos.bodySmall),
          const SizedBox(height: 24),
          Text('El nombre', style: textos.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Kioku (記憶) significa "memoria" en japonés. Esta app es para '
            'recordar tu camino en el karate: quién eres, dónde entrenas y lo '
            'que has logrado.',
          ),
          const SizedBox(height: 24),
          Text('Créditos', style: textos.titleMedium),
          const SizedBox(height: 8),
          const Text('Ícono e imagen de bienvenida creados con Grok.'),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Kioku',
                applicationVersion: versionKioku,
              ),
              child: const Text('Licencias de software'),
            ),
          ),
        ],
      ),
    );
  }
}
