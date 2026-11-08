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
2. Clubes (dojos) ← siguiente
3. Competencias e inscripciones
4. Rankings y resultados
5. Red social
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
  - Siempre visibles: nombre completo, edad, dojo, grado, peso, estatura, país, región y ciudad.
  - Cada uno elige si muestra: rol, años de práctica, sobre mí e historial de competencias.
- La edad se calcula sola desde la fecha de nacimiento. Al cumplir 18 se aplican las reglas de adulto.
- La fecha de nacimiento nunca se muestra; solo la edad.

### Pantallas

1. Crear cuenta
2. Iniciar sesión
3. Llenar o editar mi perfil
4. Ver mi perfil (cómo me ven los demás)
5. Buscar practicantes por nombre

- Los campos de contraseña tienen un ojito para mostrarla u ocultarla (Crear cuenta e Iniciar sesión).

## 2. Dojos (para cuando se construya)

- Un entrenador puede crear, además de su perfil personal, un **perfil de dojo**.
- El practicante indica a qué dojo pertenece (envía una solicitud).
- El dojo acepta o rechaza. Al aceptar, el practicante queda como miembro confirmado.

## 5. Red social (para cuando se construya)

- Muro de noticias como el de Facebook.
- Publicaciones: pensamientos (texto), fotos, videos cortos de práctica y torneos.
- Las ven los amigos (solicitudes de amistad aceptadas).
- Fotos y videos requieren el plan Blaze de Firebase.
