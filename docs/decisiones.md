# Decisiones del proyecto Kioku

Este documento registra lo que el dueño del proyecto decidió. Antes de construir algo que no esté aquí, se le pregunta.

## General

- **Qué es:** app propia para **karate Kyokushin**, inspirada en las funciones de Fitofan, sin copiar su marca, diseño ni código.
- **Plataforma:** Android (celular), hecha con Flutter.
- **Idioma:** español.
- **Región:** Latinoamérica. Países incluidos (20): México, Guatemala, El Salvador, Honduras, Nicaragua, Costa Rica, Panamá, Cuba, República Dominicana, Puerto Rico, Colombia, Venezuela, Ecuador, Perú, Bolivia, Chile, Argentina, Paraguay, Uruguay y Brasil.
- **Servicio en la nube:** Firebase (Google).
- **Pruebas:** GitHub arma el APK automáticamente. El dueño lo instala en su teléfono y dice qué cambiar.

## Orden de las funciones

1. Perfiles de atletas y entrenadores ✅ terminado (versión de prueba 14)
2. Clubes (dojos) ✅ terminado (versión de prueba 18)
3. Competencias e inscripciones ✅ terminado (versión de prueba 23)
4. Rankings y resultados ✅ terminado (versión de prueba 31)
5. Red social ← siguiente
6. Biblioteca con el conocimiento de la disciplina

## 1. Perfiles

- **Cuentas:** en internet, con **correo y contraseña**. Una cuenta = un perfil. Cada persona crea el suyo.
- **Foto de perfil:** queda para después. Requiere el plan Blaze de Firebase (con tarjeta).
- **Certificaciones:** quedan para después.

### Datos del perfil (todos obligatorios salvo que se indique)

| Dato | Obligatorio |
|---|---|
| Nombre y apellido | Sí |
| Rol: atleta, entrenador o ambos | No |
| Grado y cinturón | Sí |
| Dojo | Sí |
| País, región y ciudad | Sí |
| Fecha de nacimiento | Sí |
| Peso (kg) | Sí |
| Estatura (cm) | Sí |
| Sexo (Masculino / Femenino) | Sí |
| Años de práctica | No |
| Sobre mí | No |
| Historial de competencias | Automático (vacío hasta la función 3) |

### Grados y cinturones

| Grado | Cinturón |
|---|---|
| Sin grado | Blanco |
| 10.º y 9.º kyu | Naranja (9.º con franja) |
| 8.º y 7.º kyu | Azul (7.º con franja) |
| 6.º y 5.º kyu | Amarillo (5.º con franja) |
| 4.º y 3.º kyu | Verde (3.º con franja) |
| 2.º y 1.º kyu | Café (1.º con franja) |
| 1.º a 10.º dan | Negro |

### Lugar

- País: se elige de la lista.
- Región: se elige de una lista que depende del país (estado, provincia, departamento, región, etc.).
- Ciudad: se escribe a mano.
- Sirve para los torneos y rankings internacionales, nacionales, regionales y locales.

### Dojo en el perfil

- El practicante escribe a qué dojo pertenece.
- Aparece como **"Sin confirmar"** hasta que el dojo acepte la relación; entonces pasa a **"Confirmado ✓"**.
- Mientras no existan los dojos (función 1), siempre aparece "Sin confirmar".

### Qué ven los demás (privacidad)

- **Menores de 18:** solo **nombre de pila, dojo y grado**. Todo lo demás, incluida la edad, queda oculto.
- **Adultos (18 o más):**
  - Siempre visibles: nombre completo, edad, sexo, dojo, grado, peso, estatura, país, región y ciudad.
  - Cada uno elige si muestra: rol, años de práctica, sobre mí e historial de competencias.
- La edad se calcula sola desde la fecha de nacimiento. Al cumplir 18 se aplican las reglas de adulto.
- La fecha de nacimiento nunca se muestra; solo la edad.
- **Excepción para competir:** el sensei ve edad, peso, estatura y sexo de los miembros confirmados de su dojo (incluidos menores). El organizador ve esos mismos datos solo de los inscritos en su competencia. La fecha de nacimiento sigue oculta para todos.

### Pantallas

1. Crear cuenta
2. Iniciar sesión
3. Llenar o editar mi perfil
4. Ver mi perfil (cómo me ven los demás)
5. Buscar practicantes por nombre

- Los campos de contraseña tienen un ojito para mostrarla u ocultarla (Crear cuenta e Iniciar sesión).

## 2. Dojos

- **Quién crea:** solo quien tenga rol "Entrenador" o "Atleta y entrenador". Un entrenador puede crear **varios** dojos (por ejemplo, uno por sede).
- **Administrador:** solo quien lo creó (el sensei a cargo).
- **Un practicante pertenece a un solo dojo.** Si se cambia, deja el anterior.
- **El sensei es miembro de su dojo:** al crear un dojo, si no tiene dojo, queda como **miembro confirmado** al instante. Si ya tiene otro dojo (confirmado, sin confirmar o escrito a mano), la app le pregunta si quiere pasarse al nuevo y salir del anterior. Si elige uno de sus propios dojos en "Editar perfil", queda confirmado al instante.

### Datos del dojo

| Dato | Obligatorio |
|---|---|
| Nombre del dojo | Sí |
| País, región y ciudad (mismas listas del perfil) | Sí |
| Dirección | Sí |
| Organización (lista + "Otra" escrita a mano) | Sí |
| Sensei a cargo | Automático (quien lo crea) |
| Horarios de clases (día, inicio, término, grupo) | Sí, al menos una clase |
| Teléfono o WhatsApp | Sí |
| Correo | Sí |
| Redes sociales (Instagram, Facebook) | No |
| Descripción | Sí |
| Lista de miembros confirmados | Automática |
| Logo o foto | Para después (requiere plan Blaze) |

- **Organizaciones:** IKO Kyokushinkaikan (Matsui), WKO Shinkyokushinkai, KWF, IFK, IKO3 (Matsushima), Kyokushin-kan (Royama), So-Kyokushin (Oishi), KWU, Independiente, Otra.
- **Grupos de clase:** Niños, Juveniles, Adultos, Todas las edades, Competidores, Otro (escrito a mano).

### Qué ven los demás

- Siempre visibles: nombre, organización, país, región, ciudad y sensei a cargo.
- El sensei elige si muestra: dirección, horarios, teléfono, correo, redes sociales, descripción y lista de miembros.
- En la lista de miembros, los menores aparecen solo con su nombre de pila.

### Relación practicante–dojo

- En su perfil, el practicante **elige su dojo de la lista** (envía una solicitud) **o lo escribe a mano** (queda siempre "Sin confirmar").
- Mientras el dojo no responde: "Sin confirmar". Si acepta: "Confirmado ✓".
- Si el dojo **rechaza**: el dojo se borra del perfil y aparece un aviso para elegir otro.
- Después de confirmado, **ambos pueden terminar la relación**: el practicante se sale o el sensei lo quita. El dojo se borra del perfil y aparece un aviso.

### Pantallas

1. Crear o editar dojo (solo entrenadores)
2. Mis dojos
3. Solicitudes (aceptar o rechazar)
4. Miembros (con opción de quitar)
5. Ver dojo
6. Buscar dojos: por nombre, con filtros de país, región y organización
7. Elegir mi dojo (dentro de Editar perfil), con opción de salirse
8. Aviso de rechazo o salida

## 3. Competencias e inscripciones

### Quién crea competencias

- **Locales:** el sensei de un dojo, a nombre de ese dojo.
- **Regionales, nacionales e internacionales:** solo **organizadores aprobados**.
- El organizador aprobado es **una persona**. Con una sola aprobación puede crear todos esos niveles.
- Aprueban los **administradores**. El administrador principal es **labappsch@gmail.com**, que puede nombrar a otros administradores.
- Para ser organizador, la persona envía una solicitud con un mensaje corto.
- Los administradores pueden **quitar organizadores y administradores**. Al administrador principal nunca se le puede quitar. Las competencias de un organizador quitado siguen existiendo y las sigue administrando él, pero no puede crear nuevas de nivel regional o superior.
- Si rechazan una solicitud de organizador, el administrador escribe el **motivo** y la persona ve un **aviso** al abrir la app. Después puede enviar otra.

### Datos de la competencia (obligatorios salvo que se indique)

Nombre · Nivel · Organizador (automático) · Fechas del evento · País, región, ciudad y dirección · Descripción o bases · Modalidades (kumite y/o kata) · Categorías · Fecha límite de inscripción · Costo (opcional, solo informativo; el pago es fuera de la app) · Contacto · Reglamento (opcional) · Estado (automático).

- Sin cupo máximo.
- Afiche o imagen: para después (requiere plan Blaze).

### Estado

- Automático según las fechas: inscripciones abiertas → cerradas → en curso → finalizada.
- El organizador puede **cerrar las inscripciones antes**.

### Cancelar o suspender

- **Cancelar:** definitivo. Las inscripciones se mantienen, marcadas "Torneo cancelado", y no van al historial del perfil. El pago se resuelve fuera de la app.
- **Suspender:** postergar. Las inscripciones se mantienen. Mientras está suspendido nadie puede inscribirse, y el atleta y su sensei no pueden anular. El organizador lo **reactiva con fechas nuevas**.
- Al reactivar, el atleta o su sensei pueden **anular su inscripción aunque esté confirmada**, hasta el nuevo cierre de inscripciones. Después vuelve la regla normal.
- El **motivo es obligatorio** al cancelar o suspender.
- Avisos (cancelación, suspensión, reactivación o cambio de fecha): se ven en la competencia, en "Mis inscripciones" y **al abrir la app**, para los atletas inscritos y sus senseis. Cada aviso se muestra una sola vez.

### Categorías

- El organizador crea cada categoría a mano: modalidad, sexo y rangos de edad, peso y grado.
- Sexo de la categoría: **Masculino** o **Femenino** (sin "Mixto").
- Un rango vacío significa **"sin límite"**.
- La edad que se usa es la del **día de la inscripción**.

### Inscripciones

- Se inscribe el propio atleta, o lo inscribe su sensei (miembros confirmados de su dojo).
- Solo atletas con **dojo confirmado**.
- Una categoría por modalidad (una de kumite y una de kata).
- Quedan **Pendientes** hasta que el organizador las confirma (por ejemplo, al recibir el pago).
- Anular: el atleta o su sensei, **solo si sigue Pendiente**. Confirmada, solo el organizador.
- Lista de inscritos: la ven el organizador (todos) y cada sensei (los de su dojo). Los demás ven solo cuántos hay por categoría.

### Historial en el perfil

- Competencias en las que participó (inscripción confirmada y competencia terminada), con su categoría. En la función 4 se agrega el resultado.

### Pantallas

1. Solicitar ser organizador
2. Administración (aprobar organizadores, nombrar administradores)
3. Buscar competencias (país, región, nivel, estado)
4. Ver competencia
5. Crear o editar competencia
6. Crear o editar categorías
7. Inscribirme
8. Inscribir a mis alumnos
9. Inscritos (organizador)
10. Inscritos de mi dojo (sensei)
11. Mis inscripciones
12. Sexo en el perfil
13. Historial de competencias con datos

## 4. Rankings y resultados

### Resultados

- Por categoría se registran **1.º, 2.º, 3.º y 4.º lugar**.
- Los carga **solo el organizador**, eligiendo de la lista de **inscritos confirmados** de esa categoría.
- Plazo: desde el **primer día del torneo** hasta **30 días después del último día**. Después solo un **administrador** puede corregirlos.
- Los resultados de cada competencia los ve **cualquier persona con cuenta**. Los menores aparecen con nombre de pila y dojo.
- Si el torneo se cancela, sus resultados se borran.

### Rankings

- Se ordenan **por puntos**. Los puntos dependen del puesto y del nivel del torneo:

| Puesto | Local | Regional | Nacional | Internacional |
|---|---|---|---|---|
| 1.º | 10 | 20 | 40 | 80 |
| 2.º | 7 | 14 | 28 | 56 |
| 3.º | 5 | 10 | 20 | 40 |
| 4.º | 3 | 6 | 12 | 24 |

- Si se cambia la tabla, los rankings se recalculan solos.
- Período: **año calendario** (cada 1 de enero se parte de cero; los años anteriores se pueden consultar).
- Alcance: **Latinoamérica, país y región**, según **dónde se hizo el torneo**.
- **Ranking de atletas:** separado por **modalidad, sexo y grupo de edad**. El grupo se toma de la **edad al inscribirse** en ese torneo.

| Grupo | Edades |
|---|---|
| Infantil | hasta 11 años |
| Juvenil | 12 a 17 años |
| Adultos | 18 a 39 años |
| Senior | 40 años o más |

- **Ranking de dojos:** total general y separado por modalidad (kumite y kata). Los puntos van al **dojo con que el atleta se inscribió**.
- Menores: aparecen con **nombre de pila y dojo**.
- Empates: gana quien tiene más 1.º lugares; si siguen empatados, más 2.º, y así.

### Pantallas

1. Cargar resultados (organizador)
2. Resultados dentro de la competencia (podio por categoría)
3. Corregir resultados (administradores, después del plazo)
4. Rankings (pestaña nueva, con filtros)
5. Tabla de puntos
6. Historial del perfil con el puesto obtenido

## 5. Red social (para cuando se construya)

- Muro de noticias como el de Facebook.
- Publicaciones: pensamientos (texto), fotos, videos cortos de práctica y torneos.
- Las ven los amigos (solicitudes de amistad aceptadas).
- Fotos y videos requieren el plan Blaze de Firebase.
- Los **dojos también publican**. Sus publicaciones las ven quienes siguen al dojo y sus miembros.
