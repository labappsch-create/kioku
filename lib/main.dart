import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'servicios/sesion.dart';
import 'tema.dart';
import 'pantallas/entrar_pantalla.dart';
import 'pantallas/inicio_pantalla.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KiokuApp());
}

class KiokuApp extends StatelessWidget {
  const KiokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kioku',
      debugShowCheckedModeBanner: false,
      theme: temaKioku(),
      // Calendario y textos del sistema en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Bienvenida(),
    );
  }
}

/// Pantalla de bienvenida: muestra la imagen unos 2 segundos mientras se
/// conecta con Firebase, y después entra a la app.
class Bienvenida extends StatefulWidget {
  const Bienvenida({super.key});

  @override
  State<Bienvenida> createState() => _BienvenidaState();
}

class _BienvenidaState extends State<Bienvenida> {
  bool _lista = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    setState(() => _error = null);
    try {
      await Future.wait([
        Firebase.initializeApp(options: opcionesFirebase),
        Future<void>.delayed(const Duration(seconds: 2)),
      ]);
      if (mounted) setState(() => _lista = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    if (_lista) {
      contenido = const PuertaDeEntrada();
    } else {
      contenido = Scaffold(
        key: const ValueKey('bienvenida'),
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Center(child: Image.asset('assets/bienvenida.jpg', fit: BoxFit.contain)),
            if (_error != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('No se pudo conectar. Revisa tu internet.',
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _preparar, child: const Text('Reintentar')),
                  ]),
                ),
              ),
          ]),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: contenido,
    );
  }
}

/// Si no hay sesión, muestra "Iniciar sesión". Si la hay, entra a la app.
class PuertaDeEntrada extends StatelessWidget {
  const PuertaDeEntrada({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final usuario = snap.data;
        if (usuario == null) {
          Sesion.cerrar();
          return const EntrarPantalla();
        }
        // La key fuerza a recargar todo si cambia la cuenta.
        return ComprobarPerfil(key: ValueKey(usuario.uid), uid: usuario.uid);
      },
    );
  }
}
