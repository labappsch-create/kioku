import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../servicios/errores.dart';
import '../widgets/campo_clave.dart';
import 'registro_pantalla.dart';

/// Pantalla 2: iniciar sesión.
class EntrarPantalla extends StatefulWidget {
  const EntrarPantalla({super.key});

  @override
  State<EntrarPantalla> createState() => _EntrarPantallaState();
}

class _EntrarPantallaState extends State<EntrarPantalla> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _correo.text.trim(),
        password: _clave.text,
      );
      // Al entrar, la app cambia sola a la pantalla siguiente.
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipOval(
                      child: Image.asset('assets/icono/icono.png', height: 120),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Kioku',
                      textAlign: TextAlign.center,
                      style: textos.displayMedium),
                  Text('Karate Kyokushin',
                      textAlign: TextAlign.center, style: textos.titleMedium),
                  const SizedBox(height: 40),
                  Text('Iniciar sesión', style: textos.headlineSmall),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Escribe tu correo'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CampoClave(
                    controller: _clave,
                    etiqueta: 'Contraseña',
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Escribe tu contraseña'
                        : null,
                    alEnviar: (_) => _entrar(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const RegistroPantalla())),
                    child: const Text('¿No tienes cuenta? Crear cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
