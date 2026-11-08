import 'package:cloud_firestore/cloud_firestore.dart';

/// Administrador principal de Kioku (ver docs/decisiones.md).
/// Debe coincidir con firebase/firestore.rules.
const String correoAdminPrincipal = 'labappsch@gmail.com';

bool esAdminPrincipal(String? correo) =>
    correo?.trim().toLowerCase() == correoAdminPrincipal;

/// Un documento simple: identificador (uid) y sus datos.
class Registro {
  Registro(this.id, this.datos);

  final String id;
  final Map<String, dynamic> datos;

  String get nombre => datos['nombre'] as String? ?? '';
  String get mensaje => datos['mensaje'] as String? ?? '';

  /// Solo en solicitudes: true si un administrador la rechazó.
  bool get rechazada => datos['estado'] == estadoRechazada;
  String get motivo => datos['motivo'] as String? ?? '';
}

const String estadoRechazada = 'rechazada';

/// Administradores, organizadores aprobados y solicitudes.
///
/// - `admins/{uid}`
/// - `organizadores/{uid}`
/// - `solicitudes_organizador/{uid}`
class AdminServicio {
  AdminServicio({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _admins =>
      _db.collection('admins');

  CollectionReference<Map<String, dynamic>> get _organizadores =>
      _db.collection('organizadores');

  CollectionReference<Map<String, dynamic>> get _solicitudes =>
      _db.collection('solicitudes_organizador');

  List<Registro> _registros(QuerySnapshot<Map<String, dynamic>> r) {
    final lista = [for (final d in r.docs) Registro(d.id, d.data())];
    lista.sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }

  Stream<bool> esAdmin(String uid, String? correo) {
    if (esAdminPrincipal(correo)) return Stream.value(true);
    return _admins.doc(uid).snapshots().map((d) => d.exists);
  }

  Stream<bool> esOrganizador(String uid) =>
      _organizadores.doc(uid).snapshots().map((d) => d.exists);

  Stream<Registro?> miSolicitud(String uid) => _solicitudes
      .doc(uid)
      .snapshots()
      .map((d) => d.data() == null ? null : Registro(d.id, d.data()!));

  Future<void> solicitar(String uid, String nombre, String mensaje) =>
      _solicitudes.doc(uid).set({
        'nombre': nombre,
        'mensaje': mensaje,
        'creado': FieldValue.serverTimestamp(),
      });

  Future<void> cancelarSolicitud(String uid) => _solicitudes.doc(uid).delete();

  /// Solo las pendientes (las rechazadas esperan a que la persona vea el aviso).
  Stream<List<Registro>> solicitudes() => _solicitudes
      .snapshots()
      .map((r) => _registros(r).where((s) => !s.rechazada).toList());

  /// Lee mi solicitud una vez (para el aviso al abrir la app).
  Future<Registro?> leerMiSolicitud(String uid) async {
    final d = await _solicitudes.doc(uid).get();
    return d.data() == null ? null : Registro(d.id, d.data()!);
  }

  Future<void> aprobar(Registro solicitud) {
    final lote = _db.batch();
    lote.set(_organizadores.doc(solicitud.id), {
      'nombre': solicitud.nombre,
      'aprobado': FieldValue.serverTimestamp(),
    });
    lote.delete(_solicitudes.doc(solicitud.id));
    return lote.commit();
  }

  /// Marca la solicitud como rechazada, con el motivo. La persona verá un
  /// aviso y, al cerrarlo, la solicitud se borra.
  Future<void> rechazar(String uid, String motivo) =>
      _solicitudes.doc(uid).update({
        'estado': estadoRechazada,
        'motivo': motivo,
        'rechazado': FieldValue.serverTimestamp(),
      });

  Future<void> quitarOrganizador(String uid) => _organizadores.doc(uid).delete();

  /// El administrador principal no está en esta lista, así que no se puede quitar.
  Future<void> quitarAdmin(String uid) => _admins.doc(uid).delete();

  Stream<List<Registro>> organizadores() =>
      _organizadores.snapshots().map(_registros);

  Stream<List<Registro>> administradores() =>
      _admins.snapshots().map(_registros);

  Future<void> agregarAdmin(String uid, String nombre) => _admins.doc(uid).set({
        'nombre': nombre,
        'creado': FieldValue.serverTimestamp(),
      });
}
