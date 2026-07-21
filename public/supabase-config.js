// ============================================================
// CONFIGURACIÓN DE SUPABASE
// Se obtienen en: Supabase → tu proyecto → Project Settings → API
// La clave "anon" es pública por diseño (va en el frontend); el acceso
// real se controla con las políticas RLS definidas en schema.sql.
// ============================================================
//const SUPABASE_URL = "https://vpogkbrgjqfqejhrwxdm.supabase.co";
//const SUPABASE_ANON_KEY = "sb_publishable_STnvZhg5aIvcha903fVXFw_zQfZi4lr";

//const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);



// public/supabase-config.js
// SOLO esto. Nada más. Reemplaza con tus datos reales de Supabase.

window.SUPABASE_URL = 'https://vpogkbrgjqfqejhrwxdm.supabase.co'; 
window.SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sb_publishable_STnvZhg5aIvcha903fVXFw_zQfZi4lr';
