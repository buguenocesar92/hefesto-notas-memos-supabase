# Aceptación en servidor
- docker compose config --quiet y preflight con CA/TLS verify-full.
- Migraciones usando rol memos_app sin superusuario en Supabase16/17.
- Propietario por túnel; registro cerrado; modo privado.
- Dos usuarios: permisos de notas y espacios; visitante sin sesión no lee notas privadas.
- Adjuntos locales y/o en base persisten tras reinicio; URL privada no accesible sin autorización.
- Compartir nota de prueba y revocar enlace; verificar efecto sin sesión.
- Crear, editar, archivar/eliminar según interfaz, buscar y etiquetar.
- Backup/restauración en proyecto y volumen nuevos preserva notas, archivos y acceso.
- Actualización ensayada en copia aislada; no saltar versiones sin revisar notas upstream.

Validación local: YAML, Python, shell, .env0600 sin sobrescritura y ZIP. No ejecución real del producto en este entorno.
