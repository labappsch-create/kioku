// Funciones de Kioku en los servidores de Google (ver docs/decisiones.md).
// Las publica GitHub (archivo .github/workflows/armar-app.yml).
const { setGlobalOptions } = require('firebase-functions/v2');
const {
  onDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');

initializeApp();

// Misma región que la base de datos (São Paulo). Pocas copias a la vez,
// para que el costo no se dispare.
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 3, memory: '256MiB' });

const ADMIN_PRINCIPAL = 'labappsch@gmail.com';

// Avisos que juntan a varias personas: suenan solo la primera vez.
const AGRUPADOS = new Set(['reaccion', 'comentario', 'inscripcion_nueva']);

const db = () => getFirestore();
const { mensaje } = require('./mensaje');

/** Deja un aviso en la campanita de una persona. */
function avisar(uid, id, datos) {
  if (!uid) return null;
  return db().doc(`notificaciones/${uid}/avisos/${id}`).set({
    ...datos,
    leido: false,
    actualizado: FieldValue.serverTimestamp(),
  });
}

// ---------- Hacer sonar el teléfono ----------

exports.sonarAviso = onDocumentWritten('notificaciones/{uid}/avisos/{aid}', async (event) => {
  const despues = event.data && event.data.after;
  if (!despues || !despues.exists) return;
  const d = despues.data();
  if (d.leido) return;

  const antesDoc = event.data.before;
  const antes = antesDoc && antesDoc.exists ? antesDoc.data() : null;
  // Solo cambió otra cosa (por ejemplo, se marcó como leído).
  if (antes && antes.actualizado && d.actualizado && antes.actualizado.isEqual(d.actualizado)) {
    return;
  }
  const { uid, aid } = event.params;

  // Agrupados: si la persona todavía no abrió la campanita desde la última
  // novedad, se actualiza en silencio.
  if (antes && AGRUPADOS.has(d.tipo)) {
    const base = await db().doc(`notificaciones/${uid}`).get();
    const visto = base.exists ? base.get('vistoHasta') : null;
    if (!visto) return;
    if (antes.actualizado && antes.actualizado.toMillis() > visto.toMillis()) return;
  }

  // Lo que la persona eligió en sus ajustes.
  const ajustes = await db().doc(`usuarios/${uid}/ajustes/avisos`).get();
  if (ajustes.exists && ajustes.get(d.tipo) === false) return;

  const tokens = await db().collection(`usuarios/${uid}/tokens`).get();
  if (tokens.empty) return;
  const lista = tokens.docs.map((t) => t.id);

  const r = await getMessaging().sendEachForMulticast({
    tokens: lista,
    notification: { title: 'Kioku', body: mensaje(d) },
    data: { aviso: aid },
    android: { priority: 'high', notification: { tag: aid, color: '#C8102E' } },
  });

  // Teléfonos que ya no existen (app desinstalada): se borran.
  const malos = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ]);
  await Promise.all(
    r.responses.map((x, i) =>
      !x.success && x.error && malos.has(x.error.code)
        ? db().doc(`usuarios/${uid}/tokens/${lista[i]}`).delete()
        : null,
    ),
  );
});

// ---------- Avisos que crea el servidor ----------

/** Quedaste en el podio. */
exports.avisoPodio = onDocumentWritten('podios/{pid}', async (event) => {
  const { pid } = event.params;
  const antes = event.data.before.exists ? event.data.before.data() : null;
  const p = event.data.after.exists ? event.data.after.data() : null;

  // Si el puesto cambió de persona (o se borró), se quita el aviso anterior.
  if (antes && antes.atletaUid && (!p || p.atletaUid !== antes.atletaUid)) {
    await db().doc(`notificaciones/${antes.atletaUid}/avisos/podio_${pid}`).delete();
  }
  if (!p || !p.atletaUid || p.atletaNombre === 'Atleta eliminado') return;
  if (antes && antes.atletaUid === p.atletaUid && antes.puesto === p.puesto) return;

  await avisar(p.atletaUid, `podio_${pid}`, {
    tipo: 'podio',
    competenciaId: p.competenciaId || null,
    texto:
      `¡Quedaste en el ${p.puesto}.º lugar en ${p.competenciaNombre || ''}!\n` +
      `${p.categoriaNombre || ''}`,
  });
});

/** Torneo cancelado, suspendido, reactivado o con fecha nueva. */
exports.avisoTorneo = onDocumentUpdated('competencias/{cid}', async (event) => {
  const antes = event.data.before.data();
  const c = event.data.after.data();
  if (!c.avisoId || c.avisoId === antes.avisoId) return;
  const { cid } = event.params;

  const insc = await db().collection('inscripciones').where('competenciaId', '==', cid).get();
  const personas = new Set();
  insc.forEach((d) => {
    const x = d.data();
    if (x.atletaUid) personas.add(x.atletaUid);
    if (x.senseiUid) personas.add(x.senseiUid);
  });
  personas.delete(c.organizadorUid);

  const texto = c.avisoTexto || `Hay novedades en el torneo "${c.nombre}".`;
  const lista = [...personas];
  for (let i = 0; i < lista.length; i += 200) {
    const lote = db().batch();
    for (const u of lista.slice(i, i + 200)) {
      lote.set(db().doc(`notificaciones/${u}/avisos/torneo_${cid}`), {
        tipo: 'torneo',
        competenciaId: cid,
        texto,
        leido: false,
        actualizado: FieldValue.serverTimestamp(),
      });
      // Así la app no lo vuelve a avisar al abrirse.
      lote.set(db().doc(`usuarios/${u}/avisos_vistos/${cid}`), { avisoId: c.avisoId });
    }
    await lote.commit();
  }
});

/** Solicitud de organizador aprobada. */
exports.avisoOrganizadorAprobado = onDocumentCreated('organizadores/{uid}', (event) =>
  avisar(event.params.uid, 'organizador_ok', {
    tipo: 'organizador',
    texto:
      'Tu solicitud para ser organizador fue aprobada ✓\n' +
      'Ya puedes crear torneos regionales, nacionales e internacionales.',
  }),
);

/** Solicitud de organizador rechazada (con el motivo). */
exports.avisoOrganizadorRechazado = onDocumentUpdated(
  'solicitudes_organizador/{uid}',
  async (event) => {
    const antes = event.data.before.data();
    const s = event.data.after.data();
    if (s.estado !== 'rechazada' || antes.estado === 'rechazada') return;
    await avisar(event.params.uid, 'organizador', {
      tipo: 'organizador',
      texto:
        `Tu solicitud para ser organizador fue rechazada.\nMotivo: ${s.motivo || ''}\n` +
        'Puedes enviar otra desde Torneos → 🏆 → Ser organizador.',
    });
    // Ya se avisó: se borra para que pueda enviar otra.
    await event.data.after.ref.delete();
  },
);

/** Denuncia nueva: avisa a los administradores. */
exports.avisoDenuncia = onDocumentCreated('denuncias/{did}', async (event) => {
  const d = event.data.data();
  const admins = new Set((await db().collection('admins').get()).docs.map((x) => x.id));
  try {
    admins.add((await getAuth().getUserByEmail(ADMIN_PRINCIPAL)).uid);
  } catch (_) {
    // Si la cuenta principal no existe, se sigue con los demás.
  }
  admins.delete(d.denuncianteUid);
  const tipo =
    d.tipo === 'publicacion' ? 'una publicación' : d.tipo === 'comentario' ? 'un comentario' : 'un perfil';
  await Promise.all(
    [...admins].map((u) =>
      avisar(u, `denuncia_${event.params.did}`, {
        tipo: 'denuncia',
        texto: `Nueva denuncia sobre ${tipo}: ${d.motivo || ''}`,
      }),
    ),
  );
});
