import 'package:flutter/material.dart';

import '../../datos/grados.dart';
import '../../modelos/dojo.dart';
import '../../servicios/dojos_servicio.dart';
import '../../servicios/errores.dart';
import '../../widgets/tarjeta_perfil.dart';
import '../ver_perfil_pantalla.dart';

/// Pantallas 3 y 4: solicitudes (aceptar o rechazar) y miembros (quitar).
class MiembrosPantalla extends StatelessWidget {
  const MiembrosPantalla({
    super.key,
    required this.dojoId,
    required this.nombreDojo,
  });

  final String dojoId;
  final String nombreDojo;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(nombreDojo),
          bottom: const TabBar(tabs: [
            Tab(text: 'Solicitudes'),
            Tab(text: 'Miembros'),
          ]),
        ),
        body: TabBarView(children: [
          _Lista(dojoId: dojoId, estado: estadoPendiente),
          _Lista(dojoId: dojoId, estado: estadoConfirmado),
        ]),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.dojoId, required this.estado});

  final String dojoId;
  final String estado;

  bool get _sonSolicitudes => estado == estadoPendiente;

  Future<bool> _confirmar(BuildContext context, String pregunta) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(pregunta),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sí')),
        ],
      ),
    );
    return si ?? false;
  }

  Future<void> _hacer(BuildContext context, Future<void> Function() accion,
      String listo) async {
    final mensajes = ScaffoldMessenger.of(context);
    try {
      await accion();
      mensajes.showSnackBar(SnackBar(content: Text(listo)));
    } catch (e) {
      mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = DojosServicio();
    return StreamBuilder<List<Miembro>>(
      stream: servicio.miembros(dojoId, estado),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(mensajeDeError(snap.error!),
                  textAlign: TextAlign.center),
            ),
          );
        }
        final lista = snap.data;
        if (lista == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (lista.isEmpty) {
          return Center(
            child: Text(_sonSolicitudes
                ? 'No hay solicitudes pendientes.'
                : 'Aún no hay miembros confirmados.'),
          );
        }
        return ListView.separated(
          itemCount: lista.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = lista[i];
            final grado = gradoPorId(m.gradoId);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: grado == null ? null : Cinturon(grado: grado),
                    title: Text(m.nombre),
                    subtitle: Text(grado?.descripcion ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VerPerfilPantalla(uid: m.uid))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: _sonSolicitudes
                          ? [
                              TextButton(
                                onPressed: () async {
                                  if (await _confirmar(context,
                                          '¿Rechazar la solicitud de ${m.nombre}?') &&
                                      context.mounted) {
                                    await _hacer(
                                        context,
                                        () => servicio.quitar(dojoId, m.uid),
                                        'Solicitud rechazada');
                                  }
                                },
                                child: const Text('Rechazar'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _hacer(
                                    context,
                                    () => servicio.aceptar(dojoId, m.uid),
                                    '${m.nombre} ahora es miembro'),
                                child: const Text('Aceptar'),
                              ),
                            ]
                          : [
                              TextButton(
                                onPressed: () async {
                                  if (await _confirmar(context,
                                          '¿Quitar a ${m.nombre} del dojo?') &&
                                      context.mounted) {
                                    await _hacer(
                                        context,
                                        () => servicio.quitar(dojoId, m.uid),
                                        '${m.nombre} ya no es miembro');
                                  }
                                },
                                child: const Text('Quitar del dojo'),
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
