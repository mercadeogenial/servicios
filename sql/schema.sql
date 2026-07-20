-- ============================================================
-- ServiExpress — Esquema de base de datos (Supabase / PostgreSQL)
-- Reemplaza el flujo de Google Forms + Sheets del piloto no-code
-- Ejecutar completo en: Supabase → SQL Editor → New query → Run
--
-- Diseño de seguridad (revisado):
--   * Los formularios públicos NO insertan directamente en las tablas.
--     Toda escritura pública pasa por funciones RPC SECURITY DEFINER
--     (crear_solicitud, registrar_proveedor, crear_resena) que validan
--     los datos y corren con privilegios del dueño, evitando exponer
--     políticas de INSERT/SELECT amplias sobre datos sensibles.
--   * El panel del operador (autenticado con Supabase Auth) tiene acceso
--     de lectura/escritura completo vía políticas RLS.
-- Este archivo es idempotente: se puede volver a ejecutar sin error.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- 1. ZONAS (Cap. 1, con la ampliación de zonas piloto acordada)
-- ------------------------------------------------------------
create table if not exists zonas (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null unique,
  eje text, -- ej. 'Urubó - Eje Central', null para zonas que no son de Urubó
  activa boolean default true
);

insert into zonas (nombre, eje) values
  ('Equipetrol', null),
  ('Zona Norte', null),
  ('Urbarí', null),
  ('Las Palmas', null),
  ('Av. Las Américas', null),
  ('Av. Velarde', null),
  ('Colinas del Urubó', 'Urubó - Eje Central'),
  ('Condominio La Hacienda del Urubó', 'Urubó - Eje Central'),
  ('Condominio Urubó Green', 'Urubó - Eje Central'),
  ('Condominio Urubó Garden', 'Urubó - Eje Central'),
  ('Condominio Floresta del Urubó', 'Urubó - Eje Central'),
  ('Condominio Urubó Country', 'Urubó - Eje Central'),
  ('Condominio Rio Sierra', 'Urubó - Eje Central'),
  ('Condominio Santa Cruz de la Colina', 'Urubó - Eje Central'),
  ('Urubó Village', 'Urubó - Eje Roca y Coronado'),
  ('Condominio Providencia Urubó', 'Urubó - Eje Roca y Coronado'),
  ('Condominio Vista Urubó', 'Urubó - Eje Roca y Coronado'),
  ('Urbanización Las Palmas del Urubó', 'Urubó - Eje Roca y Coronado'),
  ('Condominio Lomas del Urubó', 'Urubó - Eje Roca y Coronado'),
  ('Urbanización Urubó Norte', 'Urubó - Eje Norte'),
  ('Condominio Urubó Norte', 'Urubó - Eje Norte'),
  ('Condominio Urubó Golf & Country Club', 'Urubó - Eje Norte'),
  ('Condominio Paseo Villa Bonita', 'Urubó - Eje Norte'),
  ('Playa Turquesa', 'Urubó - Eje Norte'),
  ('Mar Adentro', 'Urubó - Eje Norte'),
  ('Toda Santa Cruz (proveedor)', null), -- opción amplia solo para el registro de proveedores
  ('Otra zona (lista de espera)', null)
on conflict (nombre) do nothing;

-- ------------------------------------------------------------
-- 2. CATEGORÍAS DE SERVICIO (Cap. 6.4/6.5)
-- ------------------------------------------------------------
create table if not exists categorias (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null unique,
  activa boolean default true
);

insert into categorias (nombre) values
  ('Plomería'), ('Electricidad'), ('Limpieza'), ('Jardinería'), ('Pintura'),
  ('Albañilería'), ('Aire Acondicionado'), ('Carpintería'), ('Cerrajería'),
  ('Mantenimiento general'), ('Reparaciones'), ('Otro')
on conflict (nombre) do nothing;

-- ------------------------------------------------------------
-- 3. CLIENTES
-- ------------------------------------------------------------
create table if not exists clientes (
  id uuid primary key default uuid_generate_v4(),
  nombre text not null,
  whatsapp text not null,
  zona_id uuid references zonas(id),
  direccion_exacta text, -- clave para condominios cerrados con control de acceso (Cap. 6, ajuste de landing)
  acepto_terminos boolean not null default false,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 4. PROVEEDORES
-- ------------------------------------------------------------
create table if not exists proveedores (
  id uuid primary key default uuid_generate_v4(),
  nombre_razon_social text not null,
  whatsapp text not null,
  anos_experiencia int,
  modo_trabajo text check (modo_trabajo in ('Solo','Con 1-2 ayudantes','Con equipo de 3 o más')),
  situacion_tributaria text check (situacion_tributaria in ('Régimen Simplificado (RTS)','Régimen General','No tengo registro tributario actualmente','Prefiero no decir')),
  metodo_cobro text check (metodo_cobro in ('QR Simple (banco)','Tigo Money','Ambos')),
  disponibilidad text, -- texto libre por ahora: días/horarios aproximados (Cap. 6.5, campo 11)
  disponible_ahora boolean default false, -- reservado para el futuro toggle "en línea" del motor de despacho (Cap. 10, 10.9-bis) — no se usa todavía
  fotos_trabajos text[], -- URLs a Supabase Storage
  referencias text,
  activo boolean default true,
  acepto_terminos boolean not null default false,
  created_at timestamptz default now()
);

create table if not exists proveedor_categorias (
  proveedor_id uuid references proveedores(id) on delete cascade,
  categoria_id uuid references categorias(id),
  primary key (proveedor_id, categoria_id)
);

create table if not exists proveedor_zonas (
  proveedor_id uuid references proveedores(id) on delete cascade,
  zona_id uuid references zonas(id),
  primary key (proveedor_id, zona_id)
);

-- ------------------------------------------------------------
-- 5. SOLICITUDES (reemplaza la hoja "Solicitudes" de Sheets, Cap. 6.3)
-- ------------------------------------------------------------
create table if not exists solicitudes (
  id uuid primary key default uuid_generate_v4(),
  cliente_id uuid references clientes(id) not null,
  categoria_id uuid references categorias(id) not null,
  zona_id uuid references zonas(id),
  descripcion text not null,
  fotos text[],
  urgencia text check (urgencia in ('Hoy mismo','En los próximos 2-3 días','Esta semana','Sin apuro')),
  rango_presupuesto text, -- insumo para X1, ticket promedio (Cap. 4)
  como_se_entero text,
  estado text not null default 'pendiente'
    check (estado in ('pendiente','difundida','aceptada','cotizada','pagada','en_ejecucion','completada','cancelada','sin_respuesta')),
  proveedor_asignado_id uuid references proveedores(id),
  prioridad boolean default false, -- true si urgencia = 'Hoy mismo'
  created_at timestamptz default now(),
  fecha_aceptacion timestamptz,
  fecha_completada timestamptz
);

-- ------------------------------------------------------------
-- 6. DIFUSIÓN MANUAL A VARIOS PROVEEDORES (Cap. 6.3 actualizado / Cap. 10 Anexo A)
-- Esta tabla es la que mide la variable pendiente más importante del Cap. 10:
-- "densidad de proveedores disponibles simultáneamente por zona/categoría"
-- ------------------------------------------------------------
create table if not exists solicitud_contactos (
  id uuid primary key default uuid_generate_v4(),
  solicitud_id uuid references solicitudes(id) on delete cascade,
  proveedor_id uuid references proveedores(id),
  fecha_envio timestamptz default now(),
  respuesta text default 'pendiente' check (respuesta in ('pendiente','aceptado','rechazado','sin_respuesta')),
  fecha_respuesta timestamptz,
  tiempo_respuesta_segundos int generated always as
    (extract(epoch from (fecha_respuesta - fecha_envio))::int) stored
);

-- ------------------------------------------------------------
-- 7. COBROS AL PROVEEDOR (Bs 10 por contacto aceptado — Cap. 4-5, Quinta revisión)
-- El cobro se dispara SOLO cuando respuesta = 'aceptado', nunca al enviar ni al rechazar
-- ------------------------------------------------------------
create table if not exists cobros (
  id uuid primary key default uuid_generate_v4(),
  proveedor_id uuid references proveedores(id) not null,
  solicitud_id uuid references solicitudes(id) not null,
  monto_bs numeric(10,2) not null default 10.00,
  fecha timestamptz default now(),
  pagado boolean default false -- seguimiento manual del operador en esta etapa
);

-- ------------------------------------------------------------
-- 8. MEDIACIÓN DE DISPUTAS (a discreción de ServiExpress — T. de Uso, Sección 9)
-- ------------------------------------------------------------
create table if not exists mediaciones (
  id uuid primary key default uuid_generate_v4(),
  solicitud_id uuid references solicitudes(id) not null,
  motivo text not null,
  atendida boolean default false,
  resolucion text,
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- 9. RESEÑAS (Cap. 6.3 paso 12-13; incluye pregunta de re-contratación, Cap. 5 A.2-bis)
-- ------------------------------------------------------------
create table if not exists resenas (
  id uuid primary key default uuid_generate_v4(),
  solicitud_id uuid references solicitudes(id) not null unique,
  calificacion int check (calificacion between 1 and 5),
  comentario text,
  volveria_a_pedir_por_serviexpress boolean, -- mide intención de evasión (Cap. 5, A.2-bis, punto 7)
  created_at timestamptz default now()
);

-- ------------------------------------------------------------
-- Índices para las consultas más frecuentes del panel del operador
-- ------------------------------------------------------------
create index if not exists idx_solicitudes_estado on solicitudes(estado);
create index if not exists idx_solicitudes_categoria_zona on solicitudes(categoria_id, zona_id);
create index if not exists idx_solicitud_contactos_solicitud on solicitud_contactos(solicitud_id);
create index if not exists idx_proveedor_categorias_cat on proveedor_categorias(categoria_id);
create index if not exists idx_proveedor_zonas_zona on proveedor_zonas(zona_id);

-- ============================================================
-- SEGURIDAD A NIVEL DE FILA (RLS)
-- ============================================================

-- Catálogos: lectura pública solo de filas activas (los formularios los necesitan).
alter table zonas enable row level security;
alter table categorias enable row level security;
drop policy if exists "leer_zonas_activas" on zonas;
drop policy if exists "leer_categorias_activas" on categorias;
create policy "leer_zonas_activas" on zonas for select using (activa = true);
create policy "leer_categorias_activas" on categorias for select using (activa = true);

-- Tablas operativas: RLS activada, SIN inserción pública directa.
-- La escritura pública ocurre solo vía las funciones RPC de más abajo.
alter table clientes enable row level security;
alter table proveedores enable row level security;
alter table proveedor_categorias enable row level security;
alter table proveedor_zonas enable row level security;
alter table solicitudes enable row level security;
alter table solicitud_contactos enable row level security;
alter table cobros enable row level security;
alter table mediaciones enable row level security;
alter table resenas enable row level security;

-- ------------------------------------------------------------
-- Acceso del operador (autenticado vía Supabase Auth) al panel:
-- lectura y edición completas sobre todas las tablas operativas.
-- Crear el usuario operador en: Supabase → Authentication → Add user
-- ------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'clientes','proveedores','proveedor_categorias','proveedor_zonas',
    'solicitudes','solicitud_contactos','cobros','mediaciones','resenas'
  ]
  loop
    execute format('drop policy if exists "operador_todo_%1$s" on %1$I', t);
    execute format(
      'create policy "operador_todo_%1$s" on %1$I for all to authenticated using (true) with check (true)',
      t
    );
  end loop;
end $$;

-- ============================================================
-- FUNCIONES RPC (escritura pública validada y atómica)
-- SECURITY DEFINER: corren como dueño y saltan RLS de forma controlada.
-- ============================================================

-- Normaliza un número de WhatsApp boliviano a formato 591XXXXXXXX.
-- Acepta entradas con +, espacios, guiones y con/sin prefijo 591.
create or replace function normalizar_whatsapp(p_raw text)
returns text
language plpgsql
immutable
as $$
declare
  digitos text;
begin
  if p_raw is null then
    raise exception 'El número de WhatsApp es obligatorio.';
  end if;
  digitos := regexp_replace(p_raw, '\D', '', 'g'); -- solo dígitos
  -- Quitar prefijo de país si viene incluido
  if length(digitos) = 11 and left(digitos, 3) = '591' then
    digitos := substring(digitos from 4);
  end if;
  if length(digitos) <> 8 or left(digitos, 1) not in ('6','7') then
    raise exception 'Número de WhatsApp boliviano inválido: debe tener 8 dígitos y empezar en 6 o 7.';
  end if;
  return '591' || digitos;
end;
$$;

-- Crea cliente + solicitud en una sola operación atómica.
-- Devuelve el id de la solicitud creada.
create or replace function crear_solicitud(
  p_nombre text,
  p_whatsapp text,
  p_zona_id uuid,
  p_direccion text,
  p_acepto_terminos boolean,
  p_categoria_id uuid,
  p_descripcion text,
  p_urgencia text,
  p_rango_presupuesto text,
  p_como_se_entero text,
  p_fotos text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cliente_id uuid;
  v_solicitud_id uuid;
  v_whatsapp text;
begin
  if coalesce(trim(p_nombre), '') = '' then
    raise exception 'El nombre es obligatorio.';
  end if;
  if coalesce(trim(p_descripcion), '') = '' then
    raise exception 'La descripción del trabajo es obligatoria.';
  end if;
  if p_categoria_id is null then
    raise exception 'La categoría es obligatoria.';
  end if;
  if p_acepto_terminos is not true then
    raise exception 'Debés aceptar los Términos de Uso para enviar la solicitud.';
  end if;

  v_whatsapp := normalizar_whatsapp(p_whatsapp);

  insert into clientes (nombre, whatsapp, zona_id, direccion_exacta, acepto_terminos)
  values (trim(p_nombre), v_whatsapp, p_zona_id, nullif(trim(p_direccion), ''), true)
  returning id into v_cliente_id;

  insert into solicitudes (
    cliente_id, categoria_id, zona_id, descripcion, fotos,
    urgencia, rango_presupuesto, como_se_entero, prioridad
  )
  values (
    v_cliente_id, p_categoria_id, p_zona_id, trim(p_descripcion),
    coalesce(p_fotos, '{}'),
    nullif(p_urgencia, ''), nullif(p_rango_presupuesto, ''), nullif(p_como_se_entero, ''),
    p_urgencia = 'Hoy mismo'
  )
  returning id into v_solicitud_id;

  return v_solicitud_id;
end;
$$;

-- Registra un proveedor con sus categorías y zonas en una sola operación.
-- Devuelve el id del proveedor creado.
create or replace function registrar_proveedor(
  p_nombre text,
  p_whatsapp text,
  p_anos_experiencia int,
  p_modo_trabajo text,
  p_situacion_tributaria text,
  p_metodo_cobro text,
  p_disponibilidad text,
  p_acepto_terminos boolean,
  p_categorias uuid[],
  p_zonas uuid[],
  p_fotos_trabajos text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_proveedor_id uuid;
  v_whatsapp text;
  v_cat uuid;
  v_zona uuid;
begin
  if coalesce(trim(p_nombre), '') = '' then
    raise exception 'El nombre o razón social es obligatorio.';
  end if;
  if p_categorias is null or array_length(p_categorias, 1) is null then
    raise exception 'Elegí al menos una categoría.';
  end if;
  if p_zonas is null or array_length(p_zonas, 1) is null then
    raise exception 'Elegí al menos una zona.';
  end if;
  if p_acepto_terminos is not true then
    raise exception 'Debés aceptar los Términos de Uso para Proveedores.';
  end if;

  v_whatsapp := normalizar_whatsapp(p_whatsapp);

  insert into proveedores (
    nombre_razon_social, whatsapp, anos_experiencia, modo_trabajo,
    situacion_tributaria, metodo_cobro, disponibilidad, fotos_trabajos, acepto_terminos
  )
  values (
    trim(p_nombre), v_whatsapp, p_anos_experiencia, nullif(p_modo_trabajo, ''),
    nullif(p_situacion_tributaria, ''), nullif(p_metodo_cobro, ''),
    nullif(trim(p_disponibilidad), ''), coalesce(p_fotos_trabajos, '{}'), true
  )
  returning id into v_proveedor_id;

  foreach v_cat in array p_categorias loop
    insert into proveedor_categorias (proveedor_id, categoria_id)
    values (v_proveedor_id, v_cat)
    on conflict do nothing;
  end loop;

  foreach v_zona in array p_zonas loop
    insert into proveedor_zonas (proveedor_id, zona_id)
    values (v_proveedor_id, v_zona)
    on conflict do nothing;
  end loop;

  return v_proveedor_id;
end;
$$;

-- Registra una reseña de un servicio (Cap. 6.3, paso 12-13).
create or replace function crear_resena(
  p_solicitud_id uuid,
  p_calificacion int,
  p_comentario text,
  p_volveria boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_solicitud_id is null then
    raise exception 'La solicitud es obligatoria.';
  end if;
  if p_calificacion is null or p_calificacion < 1 or p_calificacion > 5 then
    raise exception 'La calificación debe estar entre 1 y 5.';
  end if;

  insert into resenas (solicitud_id, calificacion, comentario, volveria_a_pedir_por_serviexpress)
  values (p_solicitud_id, p_calificacion, nullif(trim(p_comentario), ''), p_volveria)
  on conflict (solicitud_id) do update
    set calificacion = excluded.calificacion,
        comentario = excluded.comentario,
        volveria_a_pedir_por_serviexpress = excluded.volveria_a_pedir_por_serviexpress
  returning id into v_id;

  return v_id;
end;
$$;

-- Permisos: los roles públicos de Supabase pueden ejecutar solo estas funciones.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant execute on function crear_solicitud(text,text,uuid,text,boolean,uuid,text,text,text,text,text[]) to anon, authenticated;
    grant execute on function registrar_proveedor(text,text,int,text,text,text,text,boolean,uuid[],uuid[],text[]) to anon, authenticated;
    grant execute on function crear_resena(uuid,int,text,boolean) to anon, authenticated;
  end if;
end $$;

-- ============================================================
-- SUPABASE STORAGE — bucket público para fotos (solicitudes y trabajos)
-- Este bloque solo se aplica en Supabase (donde existe el esquema "storage").
-- En un PostgreSQL común se omite automáticamente, para poder validar el
-- resto del esquema localmente sin errores.
-- ============================================================
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public)
    values ('serviexpress', 'serviexpress', true)
    on conflict (id) do nothing;

    execute 'drop policy if exists "se_lectura_publica_fotos" on storage.objects';
    execute 'drop policy if exists "se_subida_publica_fotos" on storage.objects';

    -- Lectura pública de las fotos del bucket
    execute $p$
      create policy "se_lectura_publica_fotos" on storage.objects
      for select using (bucket_id = 'serviexpress')
    $p$;

    -- Subida pública (anónima) limitada a este bucket — necesaria para los formularios
    execute $p$
      create policy "se_subida_publica_fotos" on storage.objects
      for insert with check (bucket_id = 'serviexpress')
    $p$;
  end if;
end $$;
