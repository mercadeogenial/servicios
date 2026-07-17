// ============================================================
// ServiExpress — utilidades compartidas por los formularios
// Requiere que supabase-config.js ya haya creado window.supabaseClient
// ============================================================
(function () {
  const BUCKET = "serviexpress";
  const MAX_FILE_MB = 5;
  const MAX_FILES = 5;

  // Valida y normaliza un WhatsApp boliviano a formato 591XXXXXXXX.
  // Devuelve null si es inválido.
  function normalizarWhatsapp(raw) {
    if (!raw) return null;
    let d = String(raw).replace(/\D/g, "");
    if (d.length === 11 && d.startsWith("591")) d = d.slice(3);
    if (d.length !== 8 || !["6", "7"].includes(d[0])) return null;
    return "591" + d;
  }

  function slugify(name) {
    return name
      .toLowerCase()
      .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9.]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(-60);
  }

  // Sube una lista de archivos (FileList/array) a Storage y devuelve sus URLs públicas.
  // carpeta: 'solicitudes' | 'trabajos'. onProgress(hechos, total) opcional.
  async function subirFotos(files, carpeta, onProgress) {
    const lista = Array.from(files || []).slice(0, MAX_FILES);
    const urls = [];
    for (let i = 0; i < lista.length; i++) {
      const file = lista[i];
      if (!file.type.startsWith("image/")) {
        throw new Error(`"${file.name}" no es una imagen.`);
      }
      if (file.size > MAX_FILE_MB * 1024 * 1024) {
        throw new Error(`"${file.name}" supera los ${MAX_FILE_MB} MB.`);
      }
      const path = `${carpeta}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}-${slugify(file.name)}`;
      const { error } = await window.supabaseClient.storage
        .from(BUCKET)
        .upload(path, file, { cacheControl: "3600", upsert: false });
      if (error) throw new Error("No se pudo subir la foto: " + error.message);
      const { data } = window.supabaseClient.storage.from(BUCKET).getPublicUrl(path);
      urls.push(data.publicUrl);
      if (onProgress) onProgress(i + 1, lista.length);
    }
    return urls;
  }

  window.ServiExpress = { normalizarWhatsapp, subirFotos, MAX_FILES, MAX_FILE_MB };
})();
