// Pruebas automáticas de las reglas de la red social.
// Se ejecutan en GitHub con los emuladores de Firestore y Storage.
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

const env = await initializeTestEnvironment({
  projectId: 'demo-kioku',
  firestore: {
    rules: readFileSync('firebase/firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
  storage: {
    rules: readFileSync('firebase/storage.rules', 'utf8'),
    host: '127.0.0.1',
    port: 9199,
  },
});

// ---------- Datos de prueba ----------
// ana y beto: adultos amigos. sara: adulta desconocida (bloqueada por ana).
// mia y mati: menores del dojo d1 (confirmados). kenji: sensei de d1.
// xavi: menor de otro dojo. ursula: adulta suspendida. leo: seguidor de d1.
const adulto = (nombre) => ({ nombreMostrado: nombre, esMenor: false, dojoId: null });
const menor = (nombre, dojoId) => ({ nombreMostrado: nombre, esMenor: true, dojoId });

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  const perfiles = {
    ana: adulto('Ana Pérez'),
    beto: adulto('Beto Soto'),
    sara: adulto('Sara Ríos'),
    kenji: adulto('Kenji Mora'),
    leo: adulto('Leo Paz'),
    ursula: adulto('Úrsula Vega'),
    mia: menor('Mía', 'd1'),
    mati: menor('Mati', 'd1'),
    xavi: menor('Xavi', 'd2'),
  };
  for (const [uid, p] of Object.entries(perfiles)) {
    await db.doc(`perfiles/${uid}`).set(p);
  }
  await db.doc('dojos/d1').set({ senseiUid: 'kenji', nombre: 'Dojo Uno' });
  await db.doc('dojos/d2').set({ senseiUid: 'otro', nombre: 'Dojo Dos' });
  await db.doc('dojos/d1/miembros/mia').set({ estado: 'confirmado' });
  await db.doc('dojos/d1/miembros/mati').set({ estado: 'confirmado' });
  await db.doc('dojos/d2/miembros/xavi').set({ estado: 'confirmado' });
  await db.doc('dojos/d1/seguidores/leo').set({});
  await db.doc('amistades/ana_beto').set({ miembros: ['ana', 'beto'] });
  await db.doc('bloqueos/ana_sara').set({ bloqueador: 'ana', bloqueado: 'sara' });
  await db.doc('suspendidos/ursula').set({ nombre: 'Úrsula Vega' });

  const pub = (autorUid, autorNombre, visibilidad, esMenor = false) => ({
    autorUid, autorNombre, visibilidad, esMenor, texto: 'Hola', fotos: [],
  });
  await db.doc('muros/ana/publicaciones/p_amigos').set(pub('ana', 'Ana Pérez', 'amigos'));
  await db.doc('muros/ana/publicaciones/p_todos').set(pub('ana', 'Ana Pérez', 'todos'));
  await db.doc('muros/mia/publicaciones/p_mia').set(pub('mia', 'Mía', 'amigos', true));
  await db.doc('muros_dojo/d1/publicaciones/d_seg').set(pub('kenji', 'Dojo Uno', 'seguidores'));
  await db.doc('muros_dojo/d1/publicaciones/d_miem').set(pub('kenji', 'Dojo Uno', 'miembros'));
  await db.doc('fotos_perfil/mia').set({ url: 'x', esMenor: true });
  await db.doc('fotos_perfil/ana').set({ url: 'y', esMenor: false });
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const st = (uid) => env.authenticatedContext(uid).storage();
const nueva = (autorUid, autorNombre, visibilidad, esMenor = false) => ({
  autorUid, autorNombre, visibilidad, esMenor, texto: 'Nueva', fotos: [],
});
const subir = (ctx, ruta) =>
  Promise.resolve(ctx.ref(ruta).put(new Uint8Array([1, 2, 3]), { contentType: 'image/jpeg' }));

let fallas = 0;
async function prueba(nombre, debe, promesa) {
  try {
    await (debe ? assertSucceeds(promesa) : assertFails(promesa));
    console.log(`✓ ${nombre}`);
  } catch (e) {
    fallas++;
    console.log(`✗ ${nombre}\n    ${e.message}`);
  }
}

// ---------- Publicaciones de personas ----------
await prueba('Adulto publica para amigos', true,
  db('ana').doc('muros/ana/publicaciones/n1').set(nueva('ana', 'Ana Pérez', 'amigos')));
await prueba('Adulto publica para cualquiera', true,
  db('ana').doc('muros/ana/publicaciones/n2').set(nueva('ana', 'Ana Pérez', 'todos')));
await prueba('Nadie publica en el muro de otro', false,
  db('beto').doc('muros/ana/publicaciones/n3').set(nueva('ana', 'Ana Pérez', 'amigos')));
await prueba('Menor NO puede publicar para cualquiera', false,
  db('mia').doc('muros/mia/publicaciones/n4').set(nueva('mia', 'Mía', 'todos', true)));
await prueba('Menor no puede fingir ser adulto', false,
  db('mia').doc('muros/mia/publicaciones/n5').set(nueva('mia', 'Mía', 'todos', false)));
await prueba('Menor publica para amigos', true,
  db('mia').doc('muros/mia/publicaciones/n6').set(nueva('mia', 'Mía', 'amigos', true)));
await prueba('Cuenta suspendida no puede publicar', false,
  db('ursula').doc('muros/ursula/publicaciones/n7').set(nueva('ursula', 'Úrsula Vega', 'todos')));

await prueba('Amigo ve todas las publicaciones', true,
  db('beto').collection('muros/ana/publicaciones').get());
await prueba('Desconocido NO ve todas las publicaciones', false,
  db('sara').collection('muros/ana/publicaciones').get());
await prueba('Desconocido ve las publicaciones para cualquiera', true,
  db('sara').collection('muros/ana/publicaciones').where('visibilidad', '==', 'todos').get());
await prueba('Desconocido NO abre una publicación solo para amigos', false,
  db('sara').doc('muros/ana/publicaciones/p_amigos').get());

await prueba('Sensei ve las publicaciones de su alumna menor', true,
  db('kenji').collection('muros/mia/publicaciones').get());
await prueba('Desconocido NO ve publicaciones de una menor', false,
  db('sara').collection('muros/mia/publicaciones').where('visibilidad', '==', 'todos').get()
    .then((r) => { if (r.size > 0) throw new Error('vio algo'); })
    .then(() => db('sara').doc('muros/mia/publicaciones/p_mia').get()));
await prueba('Sensei puede borrar una publicación de su alumna menor', true,
  db('kenji').doc('muros/mia/publicaciones/n6').delete());
await prueba('Desconocido NO borra publicaciones ajenas', false,
  db('sara').doc('muros/ana/publicaciones/p_todos').delete());

// ---------- Comentarios ----------
const com = (uid, nombre) => ({ autorUid: uid, autorNombre: nombre, texto: '¡Oss!' });
await prueba('Desconocido comenta una publicación para cualquiera', true,
  db('leo').doc('muros/ana/publicaciones/p_todos/comentarios/c1').set(com('leo', 'Leo Paz')));
await prueba('Desconocido NO comenta una publicación solo para amigos', false,
  db('leo').doc('muros/ana/publicaciones/p_amigos/comentarios/c2').set(com('leo', 'Leo Paz')));
await prueba('Bloqueado NO comenta publicaciones de quien lo bloqueó', false,
  db('sara').doc('muros/ana/publicaciones/p_todos/comentarios/c3').set(com('sara', 'Sara Ríos')));
await prueba('Menor NO comenta publicaciones de desconocidos', false,
  db('mia').doc('muros/ana/publicaciones/p_todos/comentarios/c4').set(com('mia', 'Mía')));
await prueba('Dueño de la publicación borra un comentario ajeno', true,
  db('ana').doc('muros/ana/publicaciones/p_todos/comentarios/c1').delete());

// ---------- Amistades ----------
const sol = (de, para, deNombre) => ({ de, para, deNombre });
await prueba('Adulto envía solicitud a otro adulto', true,
  db('leo').doc('solicitudes_amistad/leo_beto').set(sol('leo', 'beto', 'Leo Paz')));
await prueba('Adulto NO envía solicitud a una menor de otro dojo', false,
  db('leo').doc('solicitudes_amistad/leo_mia').set(sol('leo', 'mia', 'Leo Paz')));
await prueba('Menor de otro dojo NO envía solicitud', false,
  db('xavi').doc('solicitudes_amistad/xavi_mia').set(sol('xavi', 'mia', 'Xavi')));
await prueba('Menores del mismo dojo pueden ser amigos', true,
  db('mati').doc('solicitudes_amistad/mati_mia').set(sol('mati', 'mia', 'Mati')));
await prueba('Bloqueado NO envía solicitud', false,
  db('sara').doc('solicitudes_amistad/sara_ana').set(sol('sara', 'ana', 'Sara Ríos')));
await prueba('Aceptar crea la amistad', true,
  db('beto').doc('amistades/beto_leo').set({ miembros: ['beto', 'leo'] }));
await prueba('Nadie crea una amistad sin solicitud', false,
  db('sara').doc('amistades/beto_sara').set({ miembros: ['sara', 'beto'] }));

// ---------- Dojos ----------
await prueba('Seguidor ve publicaciones para seguidores', true,
  db('leo').collection('muros_dojo/d1/publicaciones').where('visibilidad', '==', 'seguidores').get());
await prueba('Seguidor NO ve las solo para miembros', false,
  db('leo').collection('muros_dojo/d1/publicaciones').get());
await prueba('Miembro ve todas las del dojo', true,
  db('mia').collection('muros_dojo/d1/publicaciones').get());
await prueba('Sensei publica a nombre de su dojo', true,
  db('kenji').doc('muros_dojo/d1/publicaciones/dn').set(nueva('kenji', 'Dojo Uno', 'miembros')));
await prueba('Otro NO publica a nombre del dojo', false,
  db('ana').doc('muros_dojo/d1/publicaciones/dx').set(nueva('ana', 'Dojo Uno', 'miembros')));

// ---------- Fotos de perfil ----------
await prueba('Desconocido NO ve la foto de perfil de una menor', false,
  db('sara').doc('fotos_perfil/mia').get());
await prueba('Sensei ve la foto de perfil de su alumna menor', true,
  db('kenji').doc('fotos_perfil/mia').get());
await prueba('Cualquiera ve la foto de perfil de un adulto', true,
  db('sara').doc('fotos_perfil/ana').get());

// ---------- Fotos (Storage) ----------
await prueba('Subir foto a mi publicación', true,
  subir(st('ana'), 'publicaciones/ana/p1/1.jpg'));
await prueba('NO subir fotos a publicaciones de otro', false,
  subir(st('sara'), 'publicaciones/ana/p1/2.jpg'));
await prueba('Sensei sube foto a publicación del dojo', true,
  subir(st('kenji'), 'publicaciones_dojo/d1/p1/1.jpg'));
await prueba('Cuenta suspendida NO sube fotos', false,
  subir(st('ursula'), 'publicaciones/ursula/p1/1.jpg'));

await env.cleanup();
if (fallas > 0) {
  console.error(`\n${fallas} prueba(s) de reglas fallaron.`);
  process.exit(1);
}
console.log('\nPruebas de reglas: todas correctas ✓');
