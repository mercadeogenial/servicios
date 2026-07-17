// ============================================================
// CONFIGURACIÓN DE SUPABASE — completar con tus datos reales
// Se obtienen en: Supabase → tu proyecto → Project Settings → API
// ============================================================
const SUPABASE_URL = "https://TU-PROYECTO.supabase.co";
const SUPABASE_ANON_KEY = "TU-CLAVE-ANON-PUBLICA";

// Esta clave "anon" es segura de exponer en el frontend — está diseñada para eso.
// El acceso real se controla con las políticas RLS definidas en schema.sql.

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
