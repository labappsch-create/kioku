import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../datos/grados.dart';
import '../../modelos/dojo.dart';
import '../../modelos/publicacion.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/perfiles_servicio.dart';
import '../../servicios/sesion.dart';
import '../../servicios/social_servicio.dart';
import '../../widgets/avatar.dart';
import '../../widgets/tarjeta_perfil.dart';
import '../../widgets/tarjeta_publicacion.dart';
import '../social/crear_publicacion_pantalla.dart';
import '../ver_perfil_pantalla.dart';
import 'editar_dojo_pantalla.dart';
import 'miembros_pantalla.dart';

/// Pantalla 5: ver un dojo (lo que el sensei eligió mostrar).
/// Si quien lo ve es el sensei, aparecen las opciones de administración.
class VerDojoPantalla extends StatelessWidget {
  const VerDojoPantalla({super.key, required this.dojoId});

  final String dojoId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final servicio = DojosServicio();

    return StreamBuilder<DojoPublico?>(
      stream: servicio.ver(dojoId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(mensajeDeError(snap.error!))));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final dojo = snap.data;
        if (dojo == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Este dojo no existe.')));
        }
        final esSensei = uid != null && dojo.senseiUid == uid;
        final textos = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Dojo')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Avatar(uid: '', nombre: dojo.nombre, radio: 32, urlFija: dojo.logoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dojo.nombre, style: textos.headlineSmall),
                      const SizedBox(height: 4),
                      Text(dojo.organizacion, style: textos.titleSmall),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (!esSensei) _BotonSeguir(dojoId: dojoId, nombre: dojo.nombre),
              const SizedBox(height: 16),
              if (esSensei) ...[
                _AccionesSensei(dojoId: dojoId, nombre: dojo.nombre, uid: uid),
                const SizedBox(height: 16),
              ],
              _Fila(icono: Icons.place, titulo: 'Lugar', valor: dojo.lugar),
              _Fila(
                  icono: Icons.person,
                  titulo: 'Sensei a cargo',
                  valor: dojo.senseiNombre,
                  alTocar: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VerPerfilPantalla(uid: dojo.senseiUid)))),
              if (dojo.direccion != null)
                _Fila(
                    icono: Icons.map, titulo: 'Dirección', valor: dojo.direccion!),
              if (dojo.telefono != null)
                _Fila(
                    icono: Icons.phone,
                    titulo: 'Teléfono / WhatsApp',
                    valor: dojo.telefono!),
              if (dojo.correo != null)
                _Fila(icono: Icons.email, titulo: 'Correo', valor: dojo.correo!),
              if (dojo.instagram != null)
                _Fila(
                    icono: Icons.camera_alt,
                    titulo: 'Instagram',
                    valor: dojo.instagram!),
              if (dojo.facebook != null)
                _Fila(
                    icono: Icons.facebook,
                    titulo: 'Facebook',
                    valor: dojo.facebook!),
              if (dojo.descripcion != null) ...[
                const SizedBox(height: 12),
                Text('Sobre el dojo', style: textos.titleSmall),
                const SizedBox(height: 4),
                Text(dojo.descripcion!),
              ],
              if (dojo.horarios != null) ...[
                const SizedBox(height: 16),
                Text('Horarios', style: textos.titleSmall),
                const SizedBox(height: 4),
                if (dojo.horarios!.isEmpty) const Text('Sin clases registradas.'),
                for (final c in dojo.horarios!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(c.texto),
                  ),
              ],
              if (dojo.mostrarMiembros || esSensei) ...[
                const SizedBox(height: 16),
                Text(
                    esSensei && !dojo.mostrarMiembros
                        ? 'Miembros (solo tú los ves)'
                        : 'Miembros',
                    style: textos.titleSmall),
                const SizedBox(height: 4),
                _ListaMiembros(dojoId: dojoId),
              ],
              const SizedBox(height: 24),
              Text('Publicaciones del dojo', style: textos.titleMedium),
              _PublicacionesDojo(dojoId: dojoId, nombre: dojo.nombre, esSensei: esSensei),
            ],
          ),
        );
      },
    );
  }
}

class _BotonSeguir extends StatelessWidget {
  const _BotonSeguir({required this.dojoId, required this.nombre});

  final String dojoId;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Sesion.cambios,
      builder: (context, _, __) {
        final r = Sesion.relaciones;
        final yo = Sesion.uid;
        if (r == null || yo == null) return const SizedBox.shrink();
        final sigo = r.siguiendo.containsKey(dojoId);
        Future<void> cambiar() async {
          final mensajes = ScaffoldMessenger.of(context);
          try {
            if (sigo) {
              await SocialServicio().dejarDeSeguir(yo, dojoId);
            } else {
              await SocialServicio().seguir(yo, dojoId, nombre);
            }
          } catch (e) {
            mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
          }
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: sigo
              ? OutlinedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Siguiendo'),
                  onPressed: cambiar,
                )
              : FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Seguir'),
                  onPressed: cambiar,
                ),
        );
      },
    );
  }
}

class _PublicacionesDojo extends StatefulWidget {
  const _PublicacionesDojo({
    required this.dojoId,
    required this.nombre,
    required this.esSensei,
  });

  final String dojoId;
  final String nombre;
  final bool esSensei;

  @override
  State<_PublicacionesDojo> createState() => _PublicacionesDojoState();
}

class _PublicacionesDojoState extends State<_PublicacionesDojo> {
  late Future<List<Publicacion>> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _cargar();
  }

  Future<List<Publicacion>> _cargar() async {
    final yo = Sesion.uid;
    var completo = widget.esSensei;
    if (!completo && yo != null) {
      final estado = await DojosServicio().estadoMiembro(widget.dojoId, yo).first;
      completo = estado == estadoConfirmado;
    }
    return SocialServicio().deDojo(widget.dojoId, completo: completo);
  }

  void _recargar() => setState(() => _carga = _cargar());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.esSensei)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Publicar como dojo'),
              onPressed: () async {
                final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => CrearPublicacionPantalla(
                      dojo: DojoQuePublica(widget.dojoId, widget.nombre)),
                ));
                if (r == true) _recargar();
              },
            ),
          ),
        FutureBuilder<List<Publicacion>>(
          future: _carga,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(mensajeDeError(snap.error!)),
              );
            }
            final lista = snap.data ?? const <Publicacion>[];
            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aún no hay publicaciones que puedas ver.'),
              );
            }
            return Column(children: [
              for (final p in lista)
                TarjetaPublicacion(publicacion: p, alCambiar: _recargar),
            ]);
          },
        ),
      ],
    );
  }
}

class _AccionesSensei extends StatelessWidget {
  const _AccionesSensei({
    required this.dojoId,
    required this.nombre,
    required this.uid,
  });

  final String dojoId;
  final String nombre;
  final String uid;

  Future<void> _editar(BuildContext context) async {
    final navegador = Navigator.of(context);
    final mensajes = ScaffoldMessenger.of(context);
    try {
      final dojo = await DojosServicio().leerPrivado(dojoId);
      final perfil = await PerfilesServicio().leerMiPerfil(uid);
      if (dojo == null || perfil == null) return;
      await navegador.push(MaterialPageRoute(
        builder: (_) => EditarDojoPantalla(
            perfilSensei: perfil, uid: uid, dojoId: dojoId, dojo: dojo),
      ));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Eres el sensei a cargo de este dojo.'),
            const SizedBox(height: 8),
            StreamBuilder<List<Miembro>>(
              stream: DojosServicio().miembros(dojoId, estadoPendiente),
              builder: (context, snap) {
                final n = snap.data?.length ?? 0;
                return FilledButton.icon(
                  icon: const Icon(Icons.group),
                  label: Text(n == 0
                      ? 'Solicitudes y miembros'
                      : 'Solicitudes y miembros ($n nuevas)'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          MiembrosPantalla(dojoId: dojoId, nombreDojo: nombre))),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Editar dojo'),
              onPressed: () => _editar(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaMiembros extends StatelessWidget {
  const _ListaMiembros({required this.dojoId});

  final String dojoId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Miembro>>(
      stream: DojosServicio().miembros(dojoId, estadoConfirmado),
      builder: (context, snap) {
        if (snap.hasError) return Text(mensajeDeError(snap.error!));
        final lista = snap.data;
        if (lista == null) return const LinearProgressIndicator();
        if (lista.isEmpty) return const Text('Aún no hay miembros confirmados.');
        return Column(
          children: [
            for (final m in lista)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: gradoPorId(m.gradoId) == null
                    ? null
                    : Cinturon(grado: gradoPorId(m.gradoId)!),
                title: Text(m.nombre),
                subtitle: Text(gradoPorId(m.gradoId)?.nombre ?? ''),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VerPerfilPantalla(uid: m.uid))),
              ),
          ],
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.valor,
    this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return InkWell(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: textos.labelSmall),
                  Text(valor, style: textos.bodyLarge),
                ],
              ),
            ),
            if (alTocar != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
