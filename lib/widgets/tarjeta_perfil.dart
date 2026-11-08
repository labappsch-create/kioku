import 'package:flutter/material.dart';

import '../datos/grados.dart';
import '../modelos/competencia.dart';
import '../modelos/dojo.dart';
import '../modelos/perfil.dart';
import '../servicios/competencias_servicio.dart';
import '../servicios/dojos_servicio.dart';

/// Muestra un perfil público: solo lo que la persona permite ver.
class TarjetaPerfil extends StatelessWidget {
  const TarjetaPerfil({super.key, required this.perfil});

  final PerfilPublico perfil;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final grado = gradoPorId(perfil.gradoId);

    final lugar = [perfil.ciudad, perfil.region, perfil.pais]
        .whereType<String>()
        .where((t) => t.isNotEmpty)
        .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(perfil.nombre, style: textos.headlineSmall),
        if (grado != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Cinturon(grado: grado),
            const SizedBox(width: 10),
            Expanded(child: Text(grado.descripcion, style: textos.titleSmall)),
          ]),
        ],
        const SizedBox(height: 16),
        _Dato(
          icono: Icons.sports_martial_arts,
          titulo: 'Dojo',
          valor: perfil.dojo.isEmpty ? 'Sin dojo' : perfil.dojo,
          extra: perfil.dojo.isEmpty
              ? null
              : perfil.dojoId == null
                  ? const TextoEstadoDojo(estado: null)
                  : EstadoDojo(dojoId: perfil.dojoId!, uid: perfil.id),
        ),
        if (perfil.rol != null)
          _Dato(icono: Icons.badge, titulo: 'Rol', valor: nombreDelRol(perfil.rol!)),
        if (perfil.edad != null)
          _Dato(icono: Icons.cake, titulo: 'Edad', valor: '${perfil.edad} años'),
        if (perfil.sexo != null)
          _Dato(icono: Icons.wc, titulo: 'Sexo', valor: nombreDelSexo(perfil.sexo!)),
        if (perfil.pesoKg != null)
          _Dato(
              icono: Icons.monitor_weight,
              titulo: 'Peso',
              valor: '${_numero(perfil.pesoKg!)} kg'),
        if (perfil.estaturaCm != null)
          _Dato(
              icono: Icons.height,
              titulo: 'Estatura',
              valor: '${perfil.estaturaCm} cm'),
        if (lugar.isNotEmpty)
          _Dato(icono: Icons.place, titulo: 'Lugar', valor: lugar),
        if (perfil.anosPractica != null)
          _Dato(
              icono: Icons.timeline,
              titulo: 'Años de práctica',
              valor: '${perfil.anosPractica}'),
        if (perfil.sobreMi != null) ...[
          const SizedBox(height: 8),
          Text('Sobre mí', style: textos.titleSmall),
          const SizedBox(height: 4),
          Text(perfil.sobreMi!),
        ],
        if (!perfil.esMenor && perfil.mostrarHistorial) ...[
          const SizedBox(height: 16),
          Text('Historial de competencias', style: textos.titleSmall),
          const SizedBox(height: 4),
          _Historial(uid: perfil.id),
        ],
      ],
    );
  }

  static String _numero(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.titulo,
    required this.valor,
    this.extra,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
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
                if (extra != null) extra!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Historial extends StatelessWidget {
  const _Historial({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return StreamBuilder<List<EntradaHistorial>>(
      stream: CompetenciasServicio().historial(uid),
      builder: (context, snap) {
        final lista = snap.data;
        if (snap.hasError || lista == null || lista.isEmpty) {
          return Text('Aún no hay competencias registradas.',
              style: textos.bodySmall);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final h in lista)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emoji_events, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          '${h.competenciaNombre} (${nombreNivel(h.nivel)}, '
                          '${textoFecha(h.fecha)})\n${h.categoriaNombre}'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Estado en vivo de la relación con un dojo de Kioku.
class EstadoDojo extends StatelessWidget {
  const EstadoDojo({super.key, required this.dojoId, required this.uid});

  final String dojoId;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: DojosServicio().estadoMiembro(dojoId, uid),
      builder: (context, snap) => TextoEstadoDojo(estado: snap.data),
    );
  }
}

class TextoEstadoDojo extends StatelessWidget {
  const TextoEstadoDojo({super.key, required this.estado});

  /// pendiente, confirmado o null (escrito a mano o sin respuesta).
  final String? estado;

  @override
  Widget build(BuildContext context) {
    final confirmado = estado == estadoConfirmado;
    final color = confirmado ? Colors.green.shade700 : Colors.grey.shade600;
    return Text(
      confirmado ? 'Confirmado ✓' : 'Sin confirmar',
      style: TextStyle(color: color, fontSize: 12),
    );
  }
}

/// Dibujo simple del cinturón.
class Cinturon extends StatelessWidget {
  const Cinturon({super.key, required this.grado});

  final Grado grado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 14,
      decoration: BoxDecoration(
        color: grado.color,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerRight,
      child: grado.conFranja
          ? Container(width: 6, color: Colors.black87)
          : null,
    );
  }
}
