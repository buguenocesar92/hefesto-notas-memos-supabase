# Hefesto Notas · Memos 0.31.0 + Supabase

Notas Markdown, bitácoras y conocimiento de trabajo con interfaz nativa Memos. Kit de infraestructura: despliegue Docker/Coolify, alta privada, conexión PostgreSQL TLS, respaldo y restauración. No incluye servicio desplegado.

## Stack
Memos0.31.0 oficial fijado por digest; Supabase PostgreSQL16/17 dedicado para notas, usuarios y configuración. Volumen local /var/opt/memos para archivos. El producto permite almacenamiento de adjuntos en base o local: este kit respalda ambos. No configurar S3/R2 sin ampliar respaldo y traspaso.

No usa Supabase Auth ni Data API. Credencial de DB en .env fuera de Git; claves de sesión y ciertos ajustes del producto se guardan nativamente en su base. No se trasladan esos secretos a .env mediante cambios incompatibles. No se configura IA, SMTP, SSO ni webhooks externos.

## Instalación privada
Requisitos: Docker Engine, Compose v2, Python3.11+, proyecto Supabase vacío y exclusivo, conexión5432, dominio y proxy HTTPS. Inicio orientativo: 1CPU/1GB para app; medir carga de adjuntos y usuarios. Base gestionada se dimensiona por separado.

1. `python3 scripts/configure.py`. Editar .env, conservar modo0600. Mantener DB_PASSWORD hexadecimal generado para DSN sin escapes.
2. Ejecutar sql/01-supabase-app.sql como postgres en SQL Editor. Asignar la clave al rol con `\password memos_app` en psql administrativo.
3. Desactivar Data API. Descargar CA oficial a certs/ca.crt. Preferir DB_HOST directo5432. Si necesita IPv4, Session Pooler5432 con DB_USER=memos_app.REFERENCIA. No Transaction Pooler6543. Confirmar variables SUPABASE_* tras realizar estas tareas.
4. `docker compose -f compose.yaml -f compose.bootstrap.yaml up -d`. Memos inicializa/migra esquema. Solo se publica localhost8105.
5. Abrir http://localhost:8105 o usar túnel `ssh -L 8105:127.0.0.1:8105 usuario@servidor`. Crear propietario con clave propia. No existe contraseña compartida.
6. En ajustes de instancia deshabilitar registro de usuarios, mantener acceso PRIVATE y revisar espacios/visibilidad. Crear usuarios necesarios desde administración. Mantener autenticación por contraseña mientras no exista un SSO comprobado.
7. Elegir almacenamiento de adjuntos local o base; límite inicial sugerido10MB. Crear una nota privada desde examples y adjuntar archivo sin datos reales. Probar búsqueda/etiquetas.
8. `docker compose -f compose.yaml -f compose.bootstrap.yaml down` sin -v. Definir PUBLIC_URL HTTPS. `docker compose up -d`.
9. Coolify: importar compose.yaml, ops y certs junto con variables; dominio HTTPS al servicio app5230. No importar bootstrap para exposición pública. Proxy debe conservar Host y cabeceras HTTPS; no publicar puerto directamente.
10. Preflight exige propietario activo, registro cerrado y modo privado. Si falla, corregir desde bootstrap privado. Es un control al desplegar; no impide cambios posteriores del administrador ni reemplaza pruebas de permisos.

## Privacidad
Modo privado no anula enlaces de notas compartidas explícitamente. Revisar visibilidad al crear/editar y probar URLs en ventana sin sesión. Usar cuentas normales para trabajo diario y propietario solo para administración. No se promete cifrado extremo a extremo: quien administra base/host puede acceder al contenido.

No habilitar acceso general a redes privadas para webhooks. Adjuntos de prueba deben pertenecer a notas y compartir sus restricciones; comprobar acceso anónimo antes de usar contenido sensible. Una instancia por cliente simplifica separación y entrega.

## Respaldos
`python3 scripts/backup.py` detiene app, crea public.dump, copia volumen completo y configuración, calcula hashes y reinicia si estaba activa. Ejecutar sobre compose base después de finalizar importaciones. Copia PostgreSQL + volumen del mismo momento, no por separado.

Respaldos contienen usuarios, tokens, notas, archivos y claves. Cifrarlos y mantener copia fuera del VPS. Restauración en docs/RESTORE.md. No ejecutar versiones diferentes contra la misma base.

Estado: revisión estática del kit; falta ejecutar Docker, migraciones, flujos de notas/adjuntos y restauración real. No se han creado cuentas externas ni enviado datos.

## Despliegue en Coolify (MVP Hefesto)

Coolify enruta el dominio vía Traefik; el compose no publica puertos ni fija `container_name`. El kit no valida el host, así que el host interno del Postgres compartido se acepta tal cual.

Variables nuevas (defaults mantienen el uso original):

- `DB_NAME` (default `postgres`): nombre de la base en el Postgres compartido; cada app usa su propia base (`mvp_<slug>`) para no chocar con otras apps en la misma instancia.
- `DB_SSLMODE` (default `verify-full`): modo TLS del `psql` y del DSN. Con `verify-full` o `verify-ca` el certificado `certs/ca.crt` es obligatorio y `ops/preflight.sh` lo valida. Con otro valor (`require`, `disable`), la CA no es obligatoria y el DSN sigue aceptando conexión.
- `DB_SSLROOTCERT` (default `/certs/ca.crt`): ruta del CA bundle que `psql` y el DSN usan al negociar TLS. Si se define como cadena vacía, no se envía CA al cliente (válido con `DB_SSLMODE` distinto de `verify-ca`/`verify-full`).

Pasos operativos en Coolify antes del primer arranque:

1. Crear la base `mvp_<slug>` en el Postgres compartido y correr `sql/01-supabase-app.sql` **dentro de esa base** como superusuario. Crea `memos_app` y le otorga `CONNECT` y `USAGE, CREATE` sobre `public` (en PG15+ el esquema `public` ya no trae `CREATE` por defecto; el preflight de `ops/preflight.sql:7` lo exige).
2. Definir `DB_USER=memos_app`. El preflight de `ops/preflight.sql:6` rechaza otros usuarios.
3. Fijar las variables de proyecto dedicado: `SUPABASE_DEDICATED_CONFIRMED=true` y `SUPABASE_DATA_API_DISABLED=true`. El preflight aborta si no están.
4. Antes de publicar, completar el alta privada (propietario HOST activo, registro cerrado, modo privado). El preflight de `ops/production.sql` aborta si falta; corregir desde el bootstrap privado, no modificando el SQL.
5. La base propia evita el choque de `public."user"` con otras apps (por ejemplo, umami) que también usan ese nombre de tabla en `public`.
6. Fijar `VOLUME_PREFIX` por app para que el volumen `${VOLUME_PREFIX:-hefesto-notas}-files` no se superponga entre despliegues del mismo kit.

El chequeo de Coolify vive en `scripts/coolify-check.sh`: renderiza `compose.yaml` con un `.env` ficticio y valida que no se expone el host, que no hay `name:` fijo y que `DB_NAME`/`DB_SSLMODE`/`DB_SSLROOTCERT` se propagan al render.
