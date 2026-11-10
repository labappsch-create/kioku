import 'package:flutter/material.dart';

import '../../modelos/competencia.dart';
import '../../servicios/competencias_servicio.dart';
import '../../servicios/errores.dart';
import '../../servicios/sesion.dart';

/// Solo se pueden ocultar los torneos cancelados o terminados.
bool sePuedeOcultar(Competencia c) {
  final e = c.estado(DateTime.now());
  return e == EstadoCompetencia.cancelada || e == EstadoCompetencia.finalizada;
}

bool estaOculto(String cid) => Sesion.relaciones?.ocultos.contains(cid) ?? false;

Future<void> cambiarOculto(BuildContext context, Competencia c, {required bool ocultar}) async {
  final mensajes = ScaffoldMessenger.of(context);
  final uid = Sesion.uid;
  if (uid == null) return;
  try {
    if (ocultar) {
      await CompetenciasServicio().ocultar(uid, c.id);
      mensajes.showSnackBar(const SnackBar(
          content: Text('Torneo oculto. Puedes verlo con "Ver ocultos" al final de la lista.')));
    } else {
      await CompetenciasServicio().mostrar(uid, c.id);
      mensajes.showSnackBar(const SnackBar(content: Text('Torneo visible de nuevo')));
    }
  } catch (e) {
    mensajes.showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
  }
}

/// Menú ⋮ para ocultar o volver a mostrar un torneo en una lista.
/// Si no se puede ocultar, muestra la flecha de siempre.
class MenuOcultar extends StatelessWidget {
  const MenuOcultar({super.key, required this.competencia});

  final Competencia? competencia;

  @override
  Widget build(BuildContext context) {
    final c = competencia;
    if (c == null || !sePuedeOcultar(c)) return const Icon(Icons.chevron_right);
    final oculto = estaOculto(c.id);
    return PopupMenuButton<String>(
      tooltip: 'Opciones',
      onSelected: (_) => cambiarOculto(context, c, ocultar: !oculto),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'x',
          child: Text(oculto ? 'Mostrar de nuevo' : 'Ocultar de mis listas'),
        ),
      ],
    );
  }
}

/// Botón al final de una lista para ver u ocultar los torneos ocultos.
class BotonVerOcultos extends StatelessWidget {
  const BotonVerOcultos({
    super.key,
    required this.cantidad,
    required this.mostrando,
    required this.alCambiar,
  });

  final int cantidad;
  final bool mostrando;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    if (cantidad == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: TextButton.icon(
          icon: Icon(mostrando ? Icons.visibility_off : Icons.visibility),
          label: Text(mostrando ? 'Esconder ocultos' : 'Ver ocultos ($cantidad)'),
          onPressed: alCambiar,
        ),
      ),
    );
  }
}
