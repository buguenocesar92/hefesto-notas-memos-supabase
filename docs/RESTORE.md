# Restauración y traspaso
1. Destino nuevo aislado con misma versión0.31.0, Supabase nuevo y VOLUME_PREFIX diferente. No iniciar app aún. Conservar origen intacto.
2. Preparar SQL, CA y .env de destino. Recuperar configuración del respaldo confiable, cambiar solo conexión/dominio/volúmenes según destino. Las claves de sesión/configuración nativas están en dump: no regenerarlas manualmente.
3. `docker compose -f compose.yaml -f compose.bootstrap.yaml run --rm preflight`. Override permite base vacía durante preparación; sigue validando permisos/CA.
4. `python3 scripts/restore_db.py /ruta/respaldo` exige public vacío. `python3 scripts/restore_files.py /ruta/respaldo` exige volumen vacío y valida hash/rutas antes de extraer; asigna UID10001.
5. Ensayo mediante bootstrap privado. Si el origen activó SMTP, IA, webhooks u otros proveedores, bloquear en firewall de ensayo sus destinos antes de iniciar: permitir únicamente base Supabase y el túnel de administración. Este kit no incluye una política de firewall por IP, ya que depende de la red del destino.
6. Probar login, dos usuarios, notas, espacios, adjuntos y compartir/revocar. No reconectar integraciones del origen durante ensayo. Conservar IDs y referencias de archivos; no copiar notas por SQL aislado.
7. Corte: pausar escrituras, backup final, repetir en destino vacío, mantener dominio si es posible, cambiar proxy/DNS y verificar. Revocar tokens cuando cambie el responsable. Retirar origen tras aceptación.

Hash detecta corrupción, no autentica fuente. Restauración parcial fallida: empezar en destino nuevo, sin sobrescribir datos existentes. Respaldos PostgreSQL no incluyen configuración gestionada Supabase.

Odoo/Wiki: entregar notas exportadas o referencias, o desarrollar adaptador API según modelo destino. Preservar autor, fechas, etiquetas, adjuntos y permisos. Este kit no instala módulo Odoo ni migración automática de permisos. Revisar exportaciones nativas disponibles en la versión; validar una muestra antes de migrar todo.
