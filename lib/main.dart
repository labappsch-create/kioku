import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'servicios/sesion.dart';
import 'pantallas/entrar_pantalla.dart';
import 'pantallas/inicio_pantalla.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: opcionesFirebase);
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
      // Calendario y textos del sistema en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const PuertaDeEntrada(),
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
