-- ============================================================
-- ServiExpress — Migración 02: cobro flexible + configuración
-- Ejecutar en: Supabase → SQL Editor → New query → Run
-- Es seguro volver a correr este archivo (usa IF NOT EXISTS / ON CONFLICT).
-- No borra ninguna tabla ni dato existente.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tabla de configuración global (un solo registro, editable desde el panel)
-- ------------------------------------------------------------
create table if not exists configuracion (
  id int primary key default 1,
  cobro_monto_default numeric(10,2) not null default 10.00,
  cobro_responsable_default text not null default 'proveedor'
    check (cobro_responsable_default in ('proveedor','cliente','ambos','a_eleccion')),
  constraint una_sola_fila_configuracion check (id = 1)
);

insert into configuracion (id) values (1) on conflict (id) do nothing;

alter table configuracion enable row level security;

drop policy if exists "leer_configuracion_publica" on configuracion;
create policy "leer_configuracion_publica" on configuracion for select using (true);

drop policy if exists "operador_todo_configuracion" on configuracion;
create policy "operador_todo_configuracion" on configuracion for all to authenticated using (true) with check (true);

-- ------------------------------------------------------------
-- 2. Cobros flexibles: quién paga (proveedor / cliente / ambos / a elección)
--    y montos editables por separado para cada lado, en cualquier momento.
-- ------------------------------------------------------------

-- Renombrar la columna existente para que el nombre sea claro ahora que hay dos montos posibles.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'cobros' and column_name = 'monto_bs'
  ) then
    alter table cobros rename column monto_bs to monto_proveedor;
  end if;
end $$;

alter table cobros
  add column if not exists responsable text not null default 'proveedor'
    check (responsable in ('proveedor','cliente','ambos','a_eleccion')),
  add column if not exists monto_cliente numeric(10,2) not null default 0,
  add column if not exists nota text,
  add column if not exists actualizado_en timestamptz default now();

alter table cobros alter column monto_proveedor set default 10.00;

-- Un solo registro de cobro por solicitud (se edita, no se duplica, cada vez que el operador lo cambia)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'cobros_solicitud_id_key'
  ) then
    alter table cobros add constraint cobros_solicitud_id_key unique (solicitud_id);
  end if;
end $$;

-- ------------------------------------------------------------
-- 3. Trigger simple para mantener actualizado_en al día en cada edición
-- ------------------------------------------------------------
create or replace function tocar_actualizado_en()
returns trigger language plpgsql as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists trg_cobros_actualizado on cobros;
create trigger trg_cobros_actualizado
  before update on cobros
  for each row execute function tocar_actualizado_en();

-- ------------------------------------------------------------
-- Fin de la migración. Verificación rápida:
-- select * from configuracion;
-- select column_name from information_schema.columns where table_name = 'cobros';
-- ------------------------------------------------------------
