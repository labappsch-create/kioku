import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../modelos/perfil.dart';
import '../servicios/admin_servicio.dart';
import '../servicios/competencias_servicio.dart';
import '../servicios/dojos_servicio.dart';
import '../servicios/notificaciones_servicio.dart';
import '../servicios/social_servicio.dart';
import '../servicios/errores.dart';
import '../servicios/perfiles_servicio.dart';
import '../widgets/tarjeta_perfil.dart';
import 'acerca_pantalla.dart';
import 'notificaciones_pantalla.dart';
import 'barra_acciones.dart';
import 'admin/admin_pantalla.dart';
import 'competencias/competencias_pantalla.dart';
import 'dojos/dojos_pantalla.dart';
import 'rankings/rankings_pantalla.dart';
import 'competencias/ver_competencia_pantalla.dart';
import 'dojos/ver_dojo_pantalla.dart';
import 'social/alumnos_menores_pantalla.dart';
import 'social/amigos_pantalla.dart';
import 'social/crear_publicacion_pantalla.dart';
import 'social/muro_pantalla.dart';
import 'social/ver_publicacion_pantalla.dart';
import '../servicios/sesion.dart';
import '../widgets/cabecera_perfil.dart';
import '../widgets/tarjeta_publicacion.dart';
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
    perfilCambiado.addListener(_recargar);
  }

  @override
  void dispose() {
    perfilCambiado.removeListener(_recargar);
    super.dispose();
  }

  Future<Perfil?> _cargar() async {
    final perfil = await _servicio.leerMiPerfil(widget.uid);
    if (perfil == null) return null;
    // Recalcula la parte pública y revisa la respuesta del dojo.
    final (actual, aviso) = await _servicio.sincronizar(widget.uid, perfil);
    // Lo demás (historial y avisos de la campanita) va sin hacer esperar.
    unawaited(_revisarAvisos(aviso));
    return actual;
  }

  /// Revisa lo que hay que avisar en la campanita. Si algo falla, sigue.
  Future<void> _revisarAvisos(AvisoDojo? aviso) async {
    final uid = widget.uid;
    final avisos = NotificacionesServicio();
    if (aviso != null) {
      await avisos.resultadoDojo(uid,
          dojoId: aviso.dojoId, subtipo: aviso.subtipo, texto: aviso.mensaje);
    }
    // Pasa al historial las competencias terminadas.
    try {
      await CompetenciasServicio().sincronizarHistorial(uid);
    } catch (_) {}
    // Solicitud de organizador rechazada: aviso y se borra para poder enviar otra.
    try {
      final s = await AdminServicio().leerMiSolicitud(uid);
      if (s != null && s.rechazada) {
        await avisos.organizadorRechazado(uid, s.motivo);
        await AdminServicio().cancelarSolicitud(uid);
      }
    } catch (_) {}
    await avisos.revisarOrganizador(uid);
    // Torneos cancelados, suspendidos, reactivados o con fecha nueva.
    try {
      for (final c in await CompetenciasServicio().avisosPendientes(uid)) {
        await avisos.torneo(uid, c);
        await CompetenciasServicio().marcarAvisoVisto(uid, c);
      }
    } catch (_) {}
    await avisos.revisarPodios(uid);
    await avisos.limpiarViejos(uid);
  }

  void _recargar() => setState(() => _carga = _cargar());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Perfil?>(
      future: _carga,
      builder: (context, snap) {
        // Al recargar se sigue mostrando lo anterior (no se pierde la pestaña).
        if (snap.connectionState != ConnectionState.done && !snap.hasData) {
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
  StreamSubscription<bool>? _admin;
  StreamSubscription<Object?>? _denuncias;
  StreamSubscription<String?>? _miDojo;
  String? _dojoEscuchado;

  @override
  void initState() {
    super.initState();
    Sesion.iniciar(widget.uid, widget.perfil);
    _admin = AdminServicio()
        .esAdmin(widget.uid, FirebaseAuth.instance.currentUser?.email)
        .listen(_siEsAdmin, onError: (_) {});
    _escucharDojo();
    _conectarNavegacion();
  }

  @override
  void didUpdateWidget(covariant InicioPantalla anterior) {
    super.didUpdateWidget(anterior);
    Sesion.iniciar(widget.uid, widget.perfil);
    _escucharDojo();
  }

  @override
  void dispose() {
    _admin?.cancel();
    _denuncias?.cancel();
    _miDojo?.cancel();
    super.dispose();
  }

  /// Los administradores reciben en la campanita las denuncias nuevas.
  void _siEsAdmin(bool v) {
    Sesion.esAdmin = v;
    if (v && _denuncias == null) {
      _denuncias = SocialServicio().denuncias().listen(
            (docs) => NotificacionesServicio().revisarDenuncias(widget.uid, docs),
            onError: (_) {},
          );
    }
  }

  /// Si el dojo responde mientras la app está abierta, se recarga el perfil
  /// (eso crea el aviso en la campanita).
  void _escucharDojo() {
    final dojoId = widget.perfil.dojoId;
    if (dojoId == _dojoEscuchado) return;
    _miDojo?.cancel();
    _miDojo = null;
    _dojoEscuchado = dojoId;
    if (dojoId == null) return;
    _miDojo = DojosServicio().estadoMiembro(dojoId, widget.uid).listen((estado) {
      if (estado != widget.perfil.dojoEstado) perfilCambiado.value++;
    }, onError: (_) {});
  }

  /// Las tarjetas de publicaciones abren estas pantallas.
  void _conectarNavegacion() {
    Navegacion.abrirPerfil = (ctx, uid) => Navigator.of(ctx)
        .push(MaterialPageRoute(builder: (_) => VerPerfilPantalla(uid: uid)));
    Navegacion.abrirDojo = (ctx, id) => Navigator.of(ctx)
        .push(MaterialPageRoute(builder: (_) => VerDojoPantalla(dojoId: id)));
    Navegacion.abrirCompetencia = (ctx, id) {
      final perfil = Sesion.perfil;
      final uid = Sesion.uid;
      if (perfil == null || uid == null) return;
      Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) =>
              VerCompetenciaPantalla(competenciaId: id, uid: uid, perfil: perfil)));
    };
    Navegacion.abrirPublicacion = (ctx, p, moderar) => Navigator.of(ctx).push(
        MaterialPageRoute(
            builder: (_) => VerPublicacionPantalla(publicacion: p, puedeModerar: moderar)));
    Navegacion.editarPublicacion = (ctx, p) => Navigator.of(ctx).push(
        MaterialPageRoute(builder: (_) => CrearPublicacionPantalla(editar: p)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          const MuroPantalla(),
          MiPerfilPantalla(
              uid: widget.uid, perfil: widget.perfil, alCambiar: widget.alCambiar),
          DojosPantalla(uid: widget.uid, perfil: widget.perfil),
          CompetenciasPantalla(uid: widget.uid, perfil: widget.perfil),
          RankingsPantalla(paisInicial: widget.perfil.pais),
        ],
      ),
      // Se esconde al bajar por el Muro (ver muro_pantalla.dart).
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: barraInferiorVisible,
        builder: (context, visible, barra) => ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            heightFactor: visible ? 1 : 0,
            child: barra,
          ),
        ),
        child: NavigationBar(
        selectedIndex: _pestana,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) {
          barraInferiorVisible.value = true;
          setState(() => _pestana = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dynamic_feed), label: 'Muro'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Mi perfil'),
          NavigationDestination(
              icon: Icon(Icons.sports_martial_arts), label: 'Dojos'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'Torneos'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard), label: 'Rankings'),
        ],
      ),
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
          const BotonCrear(),
          const BotonBuscar(),
          const BotonAvisos(),
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
            padding: EdgeInsets.zero,
            children: [
              CabeceraPerfil(uid: uid, nombre: publico.nombre),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.group),
                  label: const Text('Amigos'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AmigosPantalla())),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.dynamic_feed),
                  label: const Text('Mis publicaciones'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VerPerfilPantalla(uid: uid))),
                ),
                if (esEntrenador(perfil))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.shield),
                    label: const Text('Alumnos menores'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AlumnosMenoresPantalla(uid: uid))),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Acerca de Kioku'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AcercaPantalla())),
                ),
              ]),
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
