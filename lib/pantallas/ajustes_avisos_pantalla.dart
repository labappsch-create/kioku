import 'package:flutter/material.dart';

import '../modelos/aviso.dart';
import '../servicios/errores.dart';
import '../servicios/notificaciones_servicio.dart';
import '../servicios/sesion.dart';

/// Qué avisos suenan en el teléfono: un interruptor por tipo de aviso.
/// Todos están encendidos hasta que la persona apague alguno.
class AjustesAvisosPantalla extends StatelessWidget {
  const AjustesAvisosPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Sesion.uid;
    final servicio = NotificacionesServicio();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de avisos')),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<Map<String, bool>>(
              stream: servicio.ajustes(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(mensajeDeError(snap.error!)));
                }
                final ajustes = snap.data;
                if (ajustes == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Elige cuáles avisos suenan en tu teléfono, aunque la app '
                        'esté cerrada. Los apagados igual aparecen en la campanita.',
                      ),
                    ),
                    for (final grupo in gruposAvisos.entries) ...[
                      if (grupo.value.any((t) => !t.soloAdmin || Sesion.esAdmin))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Text(grupo.key,
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                      for (final tipo in grupo.value)
                        if (!tipo.soloAdmin || Sesion.esAdmin)
                          SwitchListTile(
                            title: Text(tipo.nombre),
                            value: ajustes[tipo.id] ?? true,
                            onChanged: (v) =>
                                servicio.guardarAjuste(uid, tipo.id, v).catchError((Object e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(mensajeDeError(e))));
                              }
                            }),
                          ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
