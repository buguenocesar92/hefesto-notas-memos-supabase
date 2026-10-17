# Fuentes oficiales · 2026-10-16
https://usememos.com/docs/deploy/docker
https://usememos.com/docs/configuration/environment-variables
https://usememos.com/docs/configuration/database
https://github.com/usememos/memos/tree/v0.31.0
https://github.com/usememos/memos/blob/v0.31.0/scripts/Dockerfile
https://github.com/usememos/memos/blob/v0.31.0/scripts/entrypoint.sh
https://github.com/usememos/memos/blob/v0.31.0/store/db/postgres/postgres.go
https://github.com/usememos/memos/blob/v0.31.0/proto/store/instance_setting.proto
https://github.com/usememos/memos/blob/v0.31.0/store/instance_setting.go
https://hub.docker.com/v2/repositories/neosmemo/memos/tags/0.31.0

Imagen app fijada por digest. postgres:17-alpine es herramienta auxiliar con etiqueta mayor: fijar digest por arquitectura en release operativo. Compatibilidad deducida de soporte PostgreSQL y configuración lib/pq; aceptación real contra Supabase pendiente.
