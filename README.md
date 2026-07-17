# ServiExpress — App real (reemplaza Google Forms + Sheets)

Esto es código real, no una simulación — cuando lo conectes a tus cuentas, funciona con datos de verdad.
Incluye: página de inicio, formulario de clientes (con subida de fotos), formulario de proveedores
(con fotos de trabajos), y panel del operador con difusión manual a varios proveedores (para medir
la densidad de proveedores disponibles, Cap. 10 del Plan Maestro).

Los formularios escriben a la base de datos a través de **funciones RPC de Postgres** (validan los
datos del lado del servidor y corren de forma atómica y segura), no con inserciones directas. Las
fotos se guardan en **Supabase Storage**. Todo esto se crea automáticamente al correr `sql/schema.sql`.

**No incluye todavía:** el motor de despacho automático en tiempo real (Cap. 10, 10.9-bis) — según lo
acordado, eso queda pendiente hasta que confirmes cuántos proveedores reales podés conseguir.

---

## Paso 1 — Crear tu proyecto en Supabase (gratis)

1. Andá a [supabase.com](https://supabase.com) y creá una cuenta (podés usar tu cuenta de Google).
2. Creá un nuevo proyecto — elegí una contraseña de base de datos y guardala en un lugar seguro.
3. Esperá 1-2 minutos a que se aprovisione.

## Paso 2 — Crear las tablas

1. En el menú izquierdo, andá a **SQL Editor** → **New query**.
2. Abrí el archivo `sql/schema.sql` de esta carpeta, copiá todo el contenido, pegalo en el editor.
3. Apretá **Run**. Con eso quedan creados, en una sola corrida: las tablas, los datos base (zonas y categorías), las funciones RPC (`crear_solicitud`, `registrar_proveedor`, `crear_resena`), las políticas de seguridad (RLS) y el bucket de Storage `serviexpress` para las fotos. El script es idempotente: podés volver a correrlo sin romper nada.

## Paso 3 — Obtener tus claves de API

1. Andá a **Project Settings** (ícono de engranaje) → **API**.
2. Copiá el **Project URL** y la clave **anon public**.
3. Abrí el archivo `public/supabase-config.js` de esta carpeta y reemplazá:
   - `TU-PROYECTO.supabase.co` por tu Project URL
   - `TU-CLAVE-ANON-PUBLICA` por tu clave anon

## Paso 4 — Crear tu usuario de operador (para entrar al panel)

1. En Supabase, andá a **Authentication** → **Users** → **Add user**.
2. Cargá tu email y una contraseña — con eso vas a entrar al panel (`panel.html`).

## Paso 5 — Poner tu número de WhatsApp real

Buscá `59170000000` en `cliente.html` y `proveedor.html` (donde dice `WHATSAPP_OPERADOR`) y reemplazalo por tu número real, en formato `591` + número, sin espacios ni +.

## Paso 6 — Publicar la app (gratis, con URL pública)

**Opción más simple — Netlify Drop (sin cuenta necesaria para probar):**
1. Andá a [app.netlify.com/drop](https://app.netlify.com/drop)
2. Arrastrá la carpeta `public` completa a la página.
3. En segundos te da una URL pública (ej. `algo-random.netlify.app`) — ya funciona.
4. Para que no se borre y tener más control, creá una cuenta gratis en Netlify (podés hacerlo después).

**Opción con más control — Vercel:**
1. Creá cuenta en [vercel.com](https://vercel.com).
2. "Add New Project" → subís la carpeta `public` (o conectás un repositorio de GitHub si preferís).
3. Deploy — te da una URL pública gratuita.

## Qué vas a tener andando

- `tu-sitio.netlify.app/` → página de inicio con los dos accesos (cliente / proveedor)
- `tu-sitio.netlify.app/cliente.html` → formulario real de solicitud (compartir con clientes)
- `tu-sitio.netlify.app/proveedor.html` → formulario real de registro (compartir con proveedores)
- `tu-sitio.netlify.app/panel.html` → tu panel privado (solo vos, con tu login)

## Cómo funciona el flujo de difusión manual (mide la densidad de proveedores)

1. Un cliente envía una solicitud desde `cliente.html`.
2. Vos entrás al panel (`panel.html`), la ves en la pestaña "Solicitudes".
3. Seleccionás 2-3 proveedores candidatos (de la misma categoría/zona) y apretás "Enviar a seleccionados".
4. Les avisás por WhatsApp (todavía manual, a propósito).
5. El primero que te confirme que acepta, le apretás "Aceptó" en el panel — eso:
   - Le asigna la solicitud a ese proveedor.
   - Marca a los demás como "sin respuesta".
   - **Genera automáticamente el cobro de Bs 10** en la tabla `cobros` (consultable desde Supabase).
6. Con el tiempo, esta tabla (`solicitud_contactos`) te va a decir exactamente cuántos proveedores
   responden y en cuánto tiempo — el dato que hace falta para decidir si construir el despacho automático.

## Seguridad (ya configurada en schema.sql)

- El público NO inserta directamente en las tablas: los formularios llaman a funciones RPC (`SECURITY DEFINER`) que validan los datos (WhatsApp boliviano, campos obligatorios, aceptación de términos) antes de guardar, y hacen cliente+solicitud (o proveedor+categorías+zonas) en una sola operación atómica.
- La escritura directa a las tablas está bloqueada por RLS para usuarios anónimos.
- Solo tu usuario autenticado puede *ver y editar* los datos desde el panel — nadie más puede leer la lista de solicitudes o proveedores sin loguearse.
- Los catálogos (`zonas`, `categorias`) son de lectura pública solo en sus filas activas, porque los formularios los necesitan.
- El bucket de Storage `serviexpress` es de lectura pública (las fotos se muestran en el panel) y permite subida anónima solo a ese bucket.

## Pendiente para más adelante (no ahora)

- Motor de despacho automático (Cap. 10, 10.9-bis) — cuando confirmes densidad real de proveedores.
- Integración con WhatsApp Business API oficial para notificaciones automáticas (hoy es manual, a propósito).
- Chat interno con números enmascarados (Cap. 10, 10.10) — condicionado a que el piloto dé Go.
