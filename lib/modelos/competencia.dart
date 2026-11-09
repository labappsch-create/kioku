import 'package:cloud_firestore/cloud_firestore.dart';

import '../datos/grados.dart';

// ---------- Niveles ----------

const String nivelLocal = 'local';
const List<String> niveles = ['local', 'regional', 'nacional', 'internacional'];

/// Niveles que solo pueden crear los organizadores aprobados.
const List<String> nivelesOrganizador = ['regional', 'nacional', 'internacional'];

String nombreNivel(String nivel) {
  switch (nivel) {
    case 'local':
      return 'Local';
    case 'regional':
      return 'Regional';
    case 'nacional':
      return 'Nacional';
    case 'internacional':
      return 'Internacional';
  }
  return nivel;
}

// ---------- Modalidades ----------

const String modalidadKumite = 'kumite';
const String modalidadKata = 'kata';
const List<String> modalidades = [modalidadKumite, modalidadKata];

String nombreModalidad(String m) => m == modalidadKata ? 'Kata' : 'Kumite';

// ---------- Sexo de la categoría ----------

const String sexoMasculino = 'masculino';
const String sexoFemenino = 'femenino';

/// Ya no se puede elegir. Solo existe en categorías creadas antes.
const String sexoMixtoAntiguo = 'mixto';
const List<String> sexosCategoria = [sexoMasculino, sexoFemenino];

String nombreSexoCategoria(String s) {
  switch (s) {
    case sexoMasculino:
      return 'Masculino';
    case sexoFemenino:
      return 'Femenino';
  }
  return 'Mixto';
}

// ---------- Estado ----------

const String inscripcionPendiente = 'pendiente';
const String inscripcionConfirmada = 'confirmada';

enum EstadoCompetencia {
  abiertas,
  cerradas,
  enCurso,
  finalizada,
  suspendida,
  cancelada,
}

/// Situación que fija el organizador (además de lo que dicen las fechas).
const String situacionNormal = 'normal';
const String situacionSuspendida = 'suspendida';
const String situacionCancelada = 'cancelada';

String nombreEstado(EstadoCompetencia e) {
  switch (e) {
    case EstadoCompetencia.abiertas:
      return 'Inscripciones abiertas';
    case EstadoCompetencia.cerradas:
      return 'Inscripciones cerradas';
    case EstadoCompetencia.enCurso:
      return 'En curso';
    case EstadoCompetencia.finalizada:
      return 'Finalizada';
    case EstadoCompetencia.suspendida:
      return 'Suspendida';
    case EstadoCompetencia.cancelada:
      return 'Cancelada';
  }
}

// ---------- Ayudas ----------

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime diaSiguiente(DateTime d) => DateTime(d.year, d.month, d.day + 1);
String textoFecha(DateTime d) => '${d.day}/${d.month}/${d.year}';

String textoNumero(num n) =>
    n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1);

DateTime _fecha(Object? v) => v is Timestamp ? v.toDate() : DateTime(2000);

String? _opcional(Object? v) {
  final t = (v as String?)?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

// ---------- Competencia ----------

/// Una competencia (colección pública `competencias`).
class Competencia {
  Competencia(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  String get nombre => datos['nombre'] as String? ?? '';
  String get nivel => datos['nivel'] as String? ?? nivelLocal;
  String get organizadorUid => datos['organizadorUid'] as String? ?? '';
  String get organizadorNombre => datos['organizadorNombre'] as String? ?? '';
  String? get dojoId => _opcional(datos['dojoId']);
  String? get dojoNombre => _opcional(datos['dojoNombre']);
  DateTime get fechaInicio => _fecha(datos['fechaInicio']);
  DateTime get fechaFin => _fecha(datos['fechaFin']);
  DateTime get fechaLimite => _fecha(datos['fechaLimite']);
  bool get cerradaAntes => datos['cerradaAntes'] as bool? ?? false;
  String get situacion => datos['situacion'] as String? ?? situacionNormal;
  bool get cancelada => situacion == situacionCancelada;
  bool get suspendida => situacion == situacionSuspendida;
  String? get motivo => _opcional(datos['motivo']);

  /// Último aviso del organizador (cancelación, suspensión, reactivación o
  /// cambio de fecha). El id sirve para mostrarlo una sola vez.
  String? get avisoId => _opcional(datos['avisoId']);
  String? get avisoTexto => _opcional(datos['avisoTexto']);

  /// Después de reactivar: hasta cuándo se puede anular una inscripción
  /// aunque esté confirmada.
  DateTime? get anularHasta {
    final v = datos['anularHasta'];
    return v is Timestamp ? v.toDate() : null;
  }

  bool puedeAnularConfirmada(DateTime ahora) =>
      situacion == situacionNormal &&
      anularHasta != null &&
      ahora.isBefore(anularHasta!);
  String get pais => datos['pais'] as String? ?? '';
  String get region => datos['region'] as String? ?? '';
  String get ciudad => datos['ciudad'] as String? ?? '';
  String get direccion => datos['direccion'] as String? ?? '';
  String get descripcion => datos['descripcion'] as String? ?? '';
  String get contacto => datos['contacto'] as String? ?? '';
  String? get costo => _opcional(datos['costo']);
  String? get reglamento => _opcional(datos['reglamento']);
  String? get aficheUrl => _opcional(datos['aficheUrl']);
  String? get aficheRuta => _opcional(datos['aficheRuta']);

  List<String> get modalidadesElegidas {
    final v = datos['modalidades'];
    if (v is! List) return const [];
    return [for (final m in modalidades) if (v.contains(m)) m];
  }

  /// Quién organiza: el dojo (torneo local) o la persona aprobada.
  String get organiza => dojoNombre ?? organizadorNombre;

  String get lugar =>
      [ciudad, region, pais].where((t) => t.isNotEmpty).join(', ');

  String get textoFechas {
    final a = soloDia(fechaInicio);
    final b = soloDia(fechaFin);
    return a == b ? textoFecha(a) : '${textoFecha(a)} al ${textoFecha(b)}';
  }

  /// Último momento en que el organizador puede cargar o corregir
  /// resultados: 30 días después del último día (incluido).
  /// Debe coincidir con firebase/firestore.rules.
  DateTime get limiteResultados {
    final f = soloDia(fechaFin);
    return DateTime(f.year, f.month, f.day + 31);
  }

  bool resultadosEmpezaron(DateTime ahora) =>
      situacion == situacionNormal && !ahora.isBefore(soloDia(fechaInicio));

  bool organizadorPuedeCargar(DateTime ahora) =>
      resultadosEmpezaron(ahora) && ahora.isBefore(limiteResultados);

  EstadoCompetencia estado(DateTime ahora) {
    if (cancelada) return EstadoCompetencia.cancelada;
    if (suspendida) return EstadoCompetencia.suspendida;
    if (!cerradaAntes && ahora.isBefore(diaSiguiente(fechaLimite))) {
      return EstadoCompetencia.abiertas;
    }
    if (ahora.isBefore(soloDia(fechaInicio))) return EstadoCompetencia.cerradas;
    if (ahora.isBefore(diaSiguiente(fechaFin))) return EstadoCompetencia.enCurso;
    return EstadoCompetencia.finalizada;
  }
}

// ---------- Datos del atleta para competir ----------

class DatosAtleta {
  const DatosAtleta({
    required this.uid,
    required this.nombre,
    required this.gradoId,
    required this.edad,
    required this.pesoKg,
    required this.estaturaCm,
    required this.sexo,
  });

  final String uid;
  final String nombre;
  final String gradoId;
  final int edad;
  final double pesoKg;
  final int estaturaCm;

  /// masculino o femenino.
  final String sexo;

  String get resumen => [
        '$edad años',
        '${textoNumero(pesoKg)} kg',
        '$estaturaCm cm',
        nombreSexoCategoria(sexo),
        gradoPorId(gradoId)?.nombre ?? '',
      ].where((t) => t.isNotEmpty).join(' · ');

  /// Desde la ficha que el practicante comparte con su dojo.
  static DatosAtleta? desdeFicha({
    required String uid,
    required String nombre,
    required String? gradoId,
    required Map<String, dynamic>? ficha,
  }) {
    if (ficha == null) return null;
    final sexo = ficha['sexo'] as String?;
    if (sexo == null || gradoId == null) return null;
    return DatosAtleta(
      uid: uid,
      nombre: nombre,
      gradoId: gradoId,
      edad: (ficha['edad'] as num?)?.toInt() ?? 0,
      pesoKg: (ficha['pesoKg'] as num?)?.toDouble() ?? 0,
      estaturaCm: (ficha['estaturaCm'] as num?)?.toInt() ?? 0,
      sexo: sexo,
    );
  }
}

// ---------- Categoría ----------

String? _rango(num? min, num? max, String unidad) {
  if (min == null && max == null) return null;
  if (min != null && max != null) {
    return '${textoNumero(min)} a ${textoNumero(max)} $unidad';
  }
  if (min != null) return 'desde ${textoNumero(min)} $unidad';
  return 'hasta ${textoNumero(max!)} $unidad';
}

/// Categoría de una competencia
/// (subcolección `competencias/{id}/categorias`).
/// Un rango vacío significa "sin límite".
class Categoria {
  const Categoria({
    this.id = '',
    required this.modalidad,
    required this.sexo,
    this.edadMin,
    this.edadMax,
    this.pesoMin,
    this.pesoMax,
    this.gradoMinId,
    this.gradoMaxId,
    this.inscritos = 0,
  });

  final String id;
  final String modalidad;
  final String sexo;
  final int? edadMin;
  final int? edadMax;
  final double? pesoMin;
  final double? pesoMax;
  final String? gradoMinId;
  final String? gradoMaxId;
  final int inscritos;

  String get nombre {
    final partes = <String>[nombreModalidad(modalidad), nombreSexoCategoria(sexo)];
    final edad = _rango(edadMin, edadMax, 'años');
    if (edad != null) partes.add(edad);
    final peso = _rango(pesoMin, pesoMax, 'kg');
    if (peso != null) partes.add(peso);
    final grado = _rangoGrado();
    if (grado != null) partes.add(grado);
    return partes.join(' · ');
  }

  String? _rangoGrado() {
    final min = gradoPorId(gradoMinId)?.nombre;
    final max = gradoPorId(gradoMaxId)?.nombre;
    if (min == null && max == null) return null;
    if (min != null && max != null) return min == max ? min : '$min a $max';
    if (min != null) return 'desde $min';
    return 'hasta $max';
  }

  /// true si el atleta cumple sexo, edad, peso y grado de la categoría.
  bool calza(DatosAtleta a) {
    if (sexo != sexoMixtoAntiguo && sexo != a.sexo) return false;
    final eMin = edadMin, eMax = edadMax, pMin = pesoMin, pMax = pesoMax;
    if (eMin != null && a.edad < eMin) return false;
    if (eMax != null && a.edad > eMax) return false;
    if (pMin != null && a.pesoKg < pMin) return false;
    if (pMax != null && a.pesoKg > pMax) return false;
    final g = indiceGrado(a.gradoId);
    final gMin = gradoMinId == null ? null : indiceGrado(gradoMinId);
    final gMax = gradoMaxId == null ? null : indiceGrado(gradoMaxId);
    if (gMin != null && g < gMin) return false;
    if (gMax != null && g > gMax) return false;
    return true;
  }

  /// Datos que edita el organizador (sin el conteo de inscritos).
  Map<String, Object?> aMapa() => {
        'modalidad': modalidad,
        'sexo': sexo,
        'edadMin': edadMin,
        'edadMax': edadMax,
        'pesoMin': pesoMin,
        'pesoMax': pesoMax,
        'gradoMinId': gradoMinId,
        'gradoMaxId': gradoMaxId,
        'nombre': nombre,
      };

  static Categoria desdeMapa(String id, Map<String, dynamic> m) => Categoria(
        id: id,
        modalidad: m['modalidad'] as String? ?? modalidadKumite,
        sexo: m['sexo'] as String? ?? sexoMixtoAntiguo,
        edadMin: (m['edadMin'] as num?)?.toInt(),
        edadMax: (m['edadMax'] as num?)?.toInt(),
        pesoMin: (m['pesoMin'] as num?)?.toDouble(),
        pesoMax: (m['pesoMax'] as num?)?.toDouble(),
        gradoMinId: m['gradoMinId'] as String?,
        gradoMaxId: m['gradoMaxId'] as String?,
        inscritos: (m['inscritos'] as num?)?.toInt() ?? 0,
      );

  static int comparar(Categoria a, Categoria b) {
    final m = modalidades.indexOf(a.modalidad).compareTo(modalidades.indexOf(b.modalidad));
    return m != 0 ? m : a.nombre.compareTo(b.nombre);
  }
}

// ---------- Inscripción ----------

/// Identificador fijo: una inscripción por atleta y modalidad.
String idInscripcion(String competenciaId, String atletaUid, String modalidad) =>
    '${competenciaId}_${atletaUid}_$modalidad';

/// Una inscripción (colección `inscripciones`).
class Inscripcion {
  Inscripcion(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  String get estado => datos['estado'] as String? ?? inscripcionPendiente;
  bool get confirmada => estado == inscripcionConfirmada;
  String get competenciaId => datos['competenciaId'] as String? ?? '';
  String get competenciaNombre => datos['competenciaNombre'] as String? ?? '';
  String get nivel => datos['nivel'] as String? ?? nivelLocal;
  DateTime get fechaInicio => _fecha(datos['fechaInicio']);
  DateTime get fechaFin => _fecha(datos['fechaFin']);
  String get categoriaId => datos['categoriaId'] as String? ?? '';
  String get categoriaNombre => datos['categoriaNombre'] as String? ?? '';
  String get modalidad => datos['modalidad'] as String? ?? modalidadKumite;
  String get atletaUid => datos['atletaUid'] as String? ?? '';
  String get atletaNombre => datos['atletaNombre'] as String? ?? '';
  String? get gradoId => datos['gradoId'] as String?;
  String get dojoId => datos['dojoId'] as String? ?? '';
  String get dojoNombre => datos['dojoNombre'] as String? ?? '';
  int get edad => (datos['edad'] as num?)?.toInt() ?? 0;
  double get pesoKg => (datos['pesoKg'] as num?)?.toDouble() ?? 0;
  int get estaturaCm => (datos['estaturaCm'] as num?)?.toInt() ?? 0;
  String get sexo => datos['sexo'] as String? ?? '';

  String get textoEstado => confirmada ? 'Confirmada ✓' : 'Pendiente';

  String get resumenAtleta => [
        '$edad años',
        '${textoNumero(pesoKg)} kg',
        '$estaturaCm cm',
        nombreSexoCategoria(sexo),
        gradoPorId(gradoId)?.nombre ?? '',
      ].where((t) => t.isNotEmpty).join(' · ');
}

/// Una línea del historial de competencias del perfil.
class EntradaHistorial {
  EntradaHistorial(this.datos);

  final Map<String, dynamic> datos;

  String get competenciaNombre => datos['competenciaNombre'] as String? ?? '';
  String get categoriaNombre => datos['categoriaNombre'] as String? ?? '';
  String get nivel => datos['nivel'] as String? ?? nivelLocal;
  DateTime get fecha => _fecha(datos['fecha']);

  /// 1 a 4, o null si no quedó en el podio.
  int? get puesto => (datos['puesto'] as num?)?.toInt();
}
