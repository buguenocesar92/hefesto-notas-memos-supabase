#!/bin/sh
set -eu
[ "$SUPABASE_DEDICATED_CONFIRMED" = true ] || { echo 'Confirme proyecto Supabase exclusivo'; exit 1; }
[ "$SUPABASE_DATA_API_DISABLED" = true ] || { echo 'Desactive Data API y confirme variable'; exit 1; }
# CA obligatoria solo con sslmode=verify-full (default). Con DB_SSLMODE distinto,
# el kit no debe abortar por la ausencia del certificado: la CA no es obligatoria.
if [ "${DB_SSLMODE:-verify-full}" = verify-full ]; then
  [ -s "$PGSSLROOTCERT" ] || { echo 'Falta certificado CA'; exit 1; }
fi
export PGCONNECT_TIMEOUT=15
psql --no-psqlrc -v ON_ERROR_STOP=1 -f /opt/hefesto/preflight.sql

if [ "${BOOTSTRAP_MODE:-false}" != true ]; then
  psql --no-psqlrc -v ON_ERROR_STOP=1 -f /opt/hefesto/production.sql
fi
