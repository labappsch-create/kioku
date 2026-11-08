import 'package:flutter/material.dart';

/// Un grado de Kyokushin con su cinturón.
class Grado {
  const Grado({
    required this.id,
    required this.nombre,
    required this.cinturon,
    required this.color,
    this.conFranja = false,
  });

  /// Identificador que se guarda en la base de datos. No cambiar.
  final String id;
  final String nombre;
  final String cinturon;
  final Color color;
  final bool conFranja;

  String get descripcion =>
      '$nombre · Cinturón ${cinturon.toLowerCase()}${conFranja ? ' con franja' : ''}';
}

const _blanco = Color(0xFFF5F5F5);
const _naranja = Color(0xFFF57C00);
const _azul = Color(0xFF1565C0);
const _amarillo = Color(0xFFFBC02D);
const _verde = Color(0xFF2E7D32);
const _cafe = Color(0xFF6D4C41);
const _negro = Color(0xFF212121);

/// Lista acordada en docs/decisiones.md, de menor a mayor.
final List<Grado> grados = [
  const Grado(id: 'sin_grado', nombre: 'Sin grado', cinturon: 'Blanco', color: _blanco),
  const Grado(id: 'kyu10', nombre: '10.º kyu', cinturon: 'Naranja', color: _naranja),
  const Grado(id: 'kyu9', nombre: '9.º kyu', cinturon: 'Naranja', color: _naranja, conFranja: true),
  const Grado(id: 'kyu8', nombre: '8.º kyu', cinturon: 'Azul', color: _azul),
  const Grado(id: 'kyu7', nombre: '7.º kyu', cinturon: 'Azul', color: _azul, conFranja: true),
  const Grado(id: 'kyu6', nombre: '6.º kyu', cinturon: 'Amarillo', color: _amarillo),
  const Grado(id: 'kyu5', nombre: '5.º kyu', cinturon: 'Amarillo', color: _amarillo, conFranja: true),
  const Grado(id: 'kyu4', nombre: '4.º kyu', cinturon: 'Verde', color: _verde),
  const Grado(id: 'kyu3', nombre: '3.º kyu', cinturon: 'Verde', color: _verde, conFranja: true),
  const Grado(id: 'kyu2', nombre: '2.º kyu', cinturon: 'Café', color: _cafe),
  const Grado(id: 'kyu1', nombre: '1.º kyu', cinturon: 'Café', color: _cafe, conFranja: true),
  for (var n = 1; n <= 10; n++)
    Grado(id: 'dan$n', nombre: '$n.º dan', cinturon: 'Negro', color: _negro),
];

Grado? gradoPorId(String? id) {
  for (final g in grados) {
    if (g.id == id) return g;
  }
  return null;
}

/// Posición del grado en la lista (0 = sin grado). -1 si no existe.
int indiceGrado(String? id) {
  for (var i = 0; i < grados.length; i++) {
    if (grados[i].id == id) return i;
  }
  return -1;
}
