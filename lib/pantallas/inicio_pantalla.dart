import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modelos/perfil.dart';
import '../servicios/admin_servicio.dart';
import '../servicios/competencias_servicio.dart';
import '../servicios/errores.dart';
import '../servicios/perfiles_servicio.dart';
import '../widgets/tarjeta_perfil.dart';
import 'admin/admin_pantalla.dart';
import 'competencias/competencias_pantalla.dart';
import 'dojos/dojos_pantalla.dart';
import 'editar_perfil_pantalla.dart';
import 'ver_perfil_pantalla.dart';

/// Decide qué mostrar al entrar: crear el perfil o la app.
class ComprobarPerfil extends StatefulWidget {
  const ComprobarPerfil({super.key, required this.uid});

  final String uid;

  @override
  State<ComprobarPerfil> createState() => _ComprobarPerfilState();
}

class _ComprobarPerfilState extends State<ComprobarPerfil> {
  final _servicio = PerfilesServicio();
  late Future<Perfil?> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<Perfil?> _cargar() async {
    final perfil = await _servicio.leerMiPerfil(widget.uid);
    if (perfil == null) return null;
    // Recalcula la parte pública y revisa la respuesta del dojo.
    final (actual, aviso) = await _servicio.sincronizar(widget.uid, perfil);
    // Pasa al historial las competencias terminadas. Si falla, no bloquea.
    try {
      await CompetenciasServicio().sincronizarHistorial(widget.uid);
    } catch (_) {}
    if (aviso != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Aviso de tu dojo'),
            content: Text(aviso.mensaje),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Entendido')),
            ],
          ),
        );
      });
    }
    return actual;
  }

  void _recargar() => setState(() => _carga = _cargar());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Perfil?>(
      future: _carga,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(mensajeDeError(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _recargar, child: const Text('Reintentar')),
                  TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Cerrar sesión')),
                ]),
              ),
            ),
          );
        }
        final perfil = snap.data;
        if (perfil == null) {
          return EditarPerfilPantalla(alGuardar: _recargar);
        }
        if (perfil.sexo == null) {
          return EditarPerfilPantalla(
            perfil: perfil,
            alGuardar: _recargar,
            aviso: 'Agregamos un dato nuevo al perfil: el sexo. '
                'Complétalo y guarda para continuar.',
          );
        }
        return InicioPantalla(uid: widget.uid, perfil: perfil, alCambiar: _recargar);
      },
    );
  }
}

/// Pantalla principal con dos pestañas: Mi perfil y Buscar.
class InicioPantalla extends StatefulWidget {
  const InicioPantalla({
    super.key,
    required this.uid,
    required this.perfil,
    required this.alCambiar,
  });

  final String uid;
  final Perfil perfil;
  final VoidCallback alCambiar;

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          MiPerfilPantalla(
              uid: widget.uid, perfil: widget.perfil, alCambiar: widget.alCambiar),
          const BuscarPantalla(),
          DojosPantalla(uid: widget.uid, perfil: widget.perfil),
          CompetenciasPantalla(uid: widget.uid, perfil: widget.perfil),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Mi perfil'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Practicantes'),
          NavigationDestination(
              icon: Icon(Icons.sports_martial_arts), label: 'Dojos'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'Competencias'),
        ],
      ),
    );
  }
}

/// Pantalla 4: ver mi perfil tal como lo ven los demás.
class MiPerfilPantalla extends StatelessWidget {
  const MiPerfilPantalla({
    super.key,
    required this.uid,
    required this.perfil,
    required this.alCambiar,
  });

  final String uid;
  final Perfil perfil;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          StreamBuilder<bool>(
            stream: AdminServicio()
                .esAdmin(uid, FirebaseAuth.instance.currentUser?.email),
            builder: (context, snap) => snap.data == true
                ? IconButton(
                    tooltip: 'Administración',
                    icon: const Icon(Icons.admin_panel_settings),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminPantalla())),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<PerfilPublico?>(
        stream: PerfilesServicio().verPublico(uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(mensajeDeError(snap.error!)));
          }
          final publico = snap.data;
          if (publico == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Así ven tu perfil los demás.'),
                ),
              ),
              const SizedBox(height: 12),
              TarjetaPerfil(perfil: publico),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar perfil'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (ctx) => EditarPerfilPantalla(
                    perfil: perfil,
                    alGuardar: () {
                      Navigator.of(ctx).pop();
                      alCambiar();
                    },
                  ),
                )),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pantalla 5: buscar practicantes por nombre.
class BuscarPantalla extends StatefulWidget {
  const BuscarPantalla({super.key});

  @override
  State<BuscarPantalla> createState() => _BuscarPantallaState();
}

class _BuscarPantallaState extends State<BuscarPantalla> {
  final _servicio = PerfilesServicio();
  final _texto = TextEditingController();
  late Future<List<PerfilPublico>> _resultados;

  @override
  void initState() {
    super.initState();
    _resultados = _servicio.buscar('');
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _buscar() =>
      setState(() => _resultados = _servicio.buscar(_texto.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar practicantes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _texto,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                labelText: 'Nombre',
                helperText: 'Escribe el comienzo del nombre',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search), onPressed: _buscar),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PerfilPublico>>(
              future: _resultados,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(mensajeDeError(snap.error!),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                final lista = snap.data ?? const [];
                if (lista.isEmpty) {
                  return const Center(child: Text('No se encontró a nadie.'));
                }
                return ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    return ListTile(
                      title: Text(p.nombre),
                      subtitle: Text(p.dojo.isEmpty ? 'Sin dojo' : p.dojo),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => VerPerfilPantalla(uid: p.id))),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
