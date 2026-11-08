import 'package:flutter/material.dart';

import '../datos/grados.dart';
import '../modelos/perfil.dart';

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
          valor: perfil.dojo,
          extra: _EstadoDojo(confirmado: perfil.dojoConfirmado),
        ),
        if (perfil.rol != null)
          _Dato(icono: Icons.badge, titulo: 'Rol', valor: nombreDelRol(perfil.rol!)),
        if (perfil.edad != null)
          _Dato(icono: Icons.cake, titulo: 'Edad', valor: '${perfil.edad} años'),
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
          Text('Aún no hay competencias registradas.',
              style: textos.bodySmall),
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

class _EstadoDojo extends StatelessWidget {
  const _EstadoDojo({required this.confirmado});

  final bool confirmado;

  @override
  Widget build(BuildContext context) {
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
