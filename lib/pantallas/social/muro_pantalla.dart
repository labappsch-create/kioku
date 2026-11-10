import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../modelos/publicacion.dart';
import '../../servicios/errores.dart';
import '../../servicios/sesion.dart';
import '../../servicios/social_servicio.dart';
import '../../tema.dart';
import '../../widgets/avatar.dart';
import '../../widgets/tarjeta_publicacion.dart';
import '../barra_acciones.dart';
import 'amigos_pantalla.dart';
import 'crear_publicacion_pantalla.dart';

/// Si la barra de abajo se ve. El Muro la esconde al bajar y la muestra al
/// subir; la pantalla principal la vuelve a mostrar al cambiar de pestaña.
final ValueNotifier<bool> barraInferiorVisible = ValueNotifier<bool>(true);

/// Pantalla 1: el muro (pestaña "Muro").
class MuroPantalla extends StatefulWidget {
  const MuroPantalla({super.key});

  @override
  State<MuroPantalla> createState() => _MuroPantallaState();
}

class _MuroPantallaState extends State<MuroPantalla> {
  final _servicio = SocialServicio();
  Future<List<Publicacion>>? _carga;
  String _firma = '';

  @override
  void initState() {
    super.initState();
    Sesion.cambios.addListener(_siCambio);
    _cargar();
  }

  @override
  void dispose() {
    Sesion.cambios.removeListener(_siCambio);
    super.dispose();
  }

  String _firmaActual(Relaciones r) => [
        (r.amigos.toList()..sort()).join(','),
        (r.siguiendo.keys.toList()..sort()).join(','),
        (r.bloqueados.toList()..sort()).join(','),
      ].join('|');

  /// Recarga si cambiaron los amigos, los dojos seguidos o los bloqueos.
  void _siCambio() {
    final r = Sesion.relaciones;
    if (r == null) return;
    if (_firmaActual(r) != _firma) _cargar();
  }

  Future<void> _cargar() async {
    final uid = Sesion.uid;
    final r = Sesion.relaciones;
    if (uid == null || r == null) return;
    _firma = _firmaActual(r);
    final perfil = Sesion.perfil;
    final miDojo = perfil?.dojoEstado == 'confirmado' ? perfil?.dojoId : null;
    final f = _servicio.muro(
      yo: uid,
      amigos: r.amigos,
      bloqueados: r.bloqueados,
      miDojo: miDojo,
      dojosSeguidos: r.siguiendo.keys,
    );
    setState(() => _carga = f);
    await f;
  }

  Future<void> _publicar({bool conFotos = false}) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CrearPublicacionPantalla(elegirFotosAlAbrir: conFotos)));
    if (r == true) _cargar();
  }

  /// Esconde la barra de abajo al bajar y la muestra al subir.
  bool _alDesplazar(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse) {
      barraInferiorVisible.value = false;
    } else if (n.direction == ScrollDirection.forward) {
      barraInferiorVisible.value = true;
    }
    return false;
  }

  Widget _cajaPublicar() {
    final uid = Sesion.uid ?? '';
    final nombre = Sesion.perfil?.nombre ?? '';
    final suspendido = Sesion.relaciones?.suspendido ?? false;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(children: [
        Avatar(uid: uid, nombre: nombre),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: suspendido ? null : () => _publicar(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '¿Qué entrenaste hoy?',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Publicar con foto',
          icon: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
          onPressed: suspendido ? null : () => _publicar(conFotos: true),
        ),
      ]),
    );
  }

  Widget _botonAmigos() => ValueListenableBuilder<int>(
        valueListenable: Sesion.cambios,
        builder: (context, _, __) {
          final n = Sesion.relaciones?.recibidas.length ?? 0;
          return IconButton(
            tooltip: 'Amigos',
            icon: Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              child: const Icon(Icons.group),
            ),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AmigosPantalla())),
          );
        },
      );

  List<Widget> _contenido(AsyncSnapshot<List<Publicacion>> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (snap.hasError) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(mensajeDeError(snap.error!), textAlign: TextAlign.center),
          ),
        ),
      ];
    }
    final lista = snap.data ?? const <Publicacion>[];
    if (lista.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tu muro está vacío.\n\nAgrega amigos (búscalos con la lupa 🔍), '
                'sigue dojos o publica algo tú.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: lista.length,
        itemBuilder: (context, i) =>
            TarjetaPublicacion(publicacion: lista[i], alCambiar: _cargar),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final r = Sesion.relaciones;
    return Scaffold(
      backgroundColor: grisSeparador,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _alDesplazar,
        child: RefreshIndicator(
          edgeOffset: 56 + MediaQuery.paddingOf(context).top,
          onRefresh: _cargar,
          child: FutureBuilder<List<Publicacion>>(
            future: _carga,
            builder: (context, snap) => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  titleSpacing: 12,
                  title: Row(mainAxisSize: MainAxisSize.min, children: [
                    ClipOval(
                      child: Image.asset('assets/icono/icono.png', width: 32, height: 32),
                    ),
                    const SizedBox(width: 10),
                    const Text('Kioku',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ]),
                  actions: [
                    BotonCrear(alPublicar: _cargar),
                    const BotonBuscar(),
                    _botonAmigos(),
                  ],
                ),
                if (r?.suspendido ?? false)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.all(12),
                      child: const Text(
                          'Tu cuenta está suspendida por un administrador: no puedes '
                          'publicar, comentar ni enviar solicitudes de amistad.'),
                    ),
                  ),
                SliverToBoxAdapter(child: _cajaPublicar()),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ..._contenido(snap),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
