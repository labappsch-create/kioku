import 'package:cloud_firestore/cloud_firestore.dart';

/// Rol opcional de la persona.
enum Rol { atleta, entrenador, ambos }

String nombreDelRol(Rol rol) {
  switch (rol) {
    case Rol.atleta:
      return 'Atleta';
    case Rol.entrenador:
      return 'Entrenador';
    case Rol.ambos:
      return 'Atleta y entrenador';
  }
}

Rol? rolDesdeTexto(Object? valor) {
  for (final r in Rol.values) {
    if (r.name == valor) return r;
  }
  return null;
}

/// Calcula la edad en años cumplidos a la fecha [hoy].
int calcularEdad(DateTime nacimiento, DateTime hoy) {
  var edad = hoy.year - nacimiento.year;
  final yaCumplio = hoy.month > nacimiento.month ||
      (hoy.month == nacimiento.month && hoy.day >= nacimiento.day);
  if (!yaCumplio) edad--;
  return edad;
}

/// Pasa a minúsculas y quita tildes, para que la búsqueda no dependa de eso.
String normalizarParaBuscar(String texto) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final letra in texto.toLowerCase().trim().split('')) {
    final i = con.indexOf(letra);
    buffer.write(i >= 0 ? sin[i] : letra);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Perfil completo. Solo lo lee y lo escribe su dueño
/// (colección privada `usuarios`).
class Perfil {
  Perfil({
    required this.nombre,
    required this.apellido,
    required this.gradoId,
    required this.dojo,
    required this.pais,
    required this.region,
    required this.ciudad,
    required this.fechaNacimiento,
    required this.pesoKg,
    required this.estaturaCm,
    this.rol,
    this.anosPractica,
    this.sobreMi,
    this.mostrarRol = true,
    this.mostrarAnosPractica = true,
    this.mostrarSobreMi = true,
    this.mostrarHistorial = true,
  });

  final String nombre;
  final String apellido;
  final String gradoId;
  final String dojo;
  final String pais;
  final String region;
  final String ciudad;
  final DateTime fechaNacimiento;
  final double pesoKg;
  final int estaturaCm;

  // Opcionales.
  final Rol? rol;
  final int? anosPractica;
  final String? sobreMi;

  // Lo que un adulto elige mostrar.
  final bool mostrarRol;
  final bool mostrarAnosPractica;
  final bool mostrarSobreMi;
  final bool mostrarHistorial;

  bool esMenorDeEdad(DateTime hoy) => calcularEdad(fechaNacimiento, hoy) < 18;

  Map<String, Object?> aMapa() => {
        'nombre': nombre,
        'apellido': apellido,
        'gradoId': gradoId,
        'dojo': dojo,
        'pais': pais,
        'region': region,
        'ciudad': ciudad,
        'fechaNacimiento': Timestamp.fromDate(fechaNacimiento),
        'pesoKg': pesoKg,
        'estaturaCm': estaturaCm,
        'rol': rol?.name,
        'anosPractica': anosPractica,
        'sobreMi': sobreMi,
        'mostrarRol': mostrarRol,
        'mostrarAnosPractica': mostrarAnosPractica,
        'mostrarSobreMi': mostrarSobreMi,
        'mostrarHistorial': mostrarHistorial,
        'actualizado': FieldValue.serverTimestamp(),
      };

  static Perfil desdeMapa(Map<String, dynamic> m) => Perfil(
        nombre: m['nombre'] as String? ?? '',
        apellido: m['apellido'] as String? ?? '',
        gradoId: m['gradoId'] as String? ?? 'sin_grado',
        dojo: m['dojo'] as String? ?? '',
        pais: m['pais'] as String? ?? '',
        region: m['region'] as String? ?? '',
        ciudad: m['ciudad'] as String? ?? '',
        fechaNacimiento:
            (m['fechaNacimiento'] as Timestamp?)?.toDate() ?? DateTime(2000),
        pesoKg: (m['pesoKg'] as num?)?.toDouble() ?? 0,
        estaturaCm: (m['estaturaCm'] as num?)?.toInt() ?? 0,
        rol: rolDesdeTexto(m['rol']),
        anosPractica: (m['anosPractica'] as num?)?.toInt(),
        sobreMi: m['sobreMi'] as String?,
        mostrarRol: m['mostrarRol'] as bool? ?? true,
        mostrarAnosPractica: m['mostrarAnosPractica'] as bool? ?? true,
        mostrarSobreMi: m['mostrarSobreMi'] as bool? ?? true,
        mostrarHistorial: m['mostrarHistorial'] as bool? ?? true,
      );

  /// Lo que pueden ver los demás, según las reglas de docs/decisiones.md.
  /// Se guarda en la colección pública `perfiles`.
  Map<String, Object?> aMapaPublico(DateTime hoy) {
    if (esMenorDeEdad(hoy)) {
      // Menores: solo nombre de pila, dojo y grado.
      return {
        'esMenor': true,
        'nombreMostrado': nombre,
        'nombreBusqueda': normalizarParaBuscar(nombre),
        'gradoId': gradoId,
        'dojo': dojo,
        'dojoConfirmado': false,
        'actualizado': FieldValue.serverTimestamp(),
      };
    }
    final completo = '$nombre $apellido';
    return {
      'esMenor': false,
      'nombreMostrado': completo,
      'nombreBusqueda': normalizarParaBuscar(completo),
      'gradoId': gradoId,
      'dojo': dojo,
      'dojoConfirmado': false,
      'edad': calcularEdad(fechaNacimiento, hoy),
      'pesoKg': pesoKg,
      'estaturaCm': estaturaCm,
      'pais': pais,
      'region': region,
      'ciudad': ciudad,
      if (mostrarRol && rol != null) 'rol': rol!.name,
      if (mostrarAnosPractica && anosPractica != null)
        'anosPractica': anosPractica,
      if (mostrarSobreMi && sobreMi != null && sobreMi!.isNotEmpty)
        'sobreMi': sobreMi,
      'mostrarHistorial': mostrarHistorial,
      'actualizado': FieldValue.serverTimestamp(),
    };
  }
}

/// Lo que se ve de una persona (colección pública `perfiles`).
class PerfilPublico {
  PerfilPublico(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  bool get esMenor => datos['esMenor'] as bool? ?? true;
  String get nombre => datos['nombreMostrado'] as String? ?? '';
  String? get gradoId => datos['gradoId'] as String?;
  String get dojo => datos['dojo'] as String? ?? '';
  bool get dojoConfirmado => datos['dojoConfirmado'] as bool? ?? false;
  int? get edad => (datos['edad'] as num?)?.toInt();
  double? get pesoKg => (datos['pesoKg'] as num?)?.toDouble();
  int? get estaturaCm => (datos['estaturaCm'] as num?)?.toInt();
  String? get pais => datos['pais'] as String?;
  String? get region => datos['region'] as String?;
  String? get ciudad => datos['ciudad'] as String?;
  Rol? get rol => rolDesdeTexto(datos['rol']);
  int? get anosPractica => (datos['anosPractica'] as num?)?.toInt();
  String? get sobreMi => datos['sobreMi'] as String?;
  bool get mostrarHistorial => datos['mostrarHistorial'] as bool? ?? false;
}
