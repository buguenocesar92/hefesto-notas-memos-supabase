#!/usr/bin/env bash
# Verifica que compose.yaml cumpla el contrato Coolify del kit:
#   1) Servicios sin profiles no exponen poder sobre el host (ports, container_name,
#      privileged, cap_add, devices, network_mode/pid/ipc host, security_opt unconfined,
#      binds fuera del repo o docker.sock).
#   2) Sin name fijo en raíz ni redes; volúmenes sin name fijo (sólo ${VOLUME_PREFIX}
#      con default).
#   3) supabase-pg: DB_NAME y DB_SSLMODE se respetan en MEMOS_DSN y PG*.
#
# Salida 0 = cumple. 2 = falta prerequisito. 1 = no cumple.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v docker >/dev/null 2>&1 || { echo "Falta docker" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "Falta jq" >&2; exit 2; }

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  echo "FALLO: $1" >&2
  exit 1
}

# Extrae nombres de variables ${VAR...} de un archivo (mayúsculas/guión bajo).
extract_vars() {
  local file="$1"
  grep -oE '\$\{[A-Z_][A-Z0-9_]*' "$file" | sed 's/^\${//' | sort -u
}

# Escribe un .env ficticio (no secretos) en $1 para cada variable dada.
fake_env() {
  local out="$1"; shift
  : > "$out"
  for v in "$@"; do
    case "$v" in
      DB_HOST|PUBLIC_URL|SUPABASE_URL)
        echo "$v=https://ejemplo.invalid" >> "$out" ;;
      *)
        echo "$v=x1234567890abcdef" >> "$out" ;;
    esac
  done
}

# Renderiza compose.yaml con el env dado. Devuelve JSON por stdout.
# docker a veces antepone "WARNING:" al JSON por su config global; se filtra.
render() {
  local envfile="$1"
  local raw
  if ! raw=$(docker compose --project-directory "$ROOT" --env-file "$envfile" \
                -f "$ROOT/compose.yaml" config --format json 2>&1); then
    printf '%s\n' "$raw" >&2
    fail "docker compose config falló"
  fi
  printf '%s' "$raw" | grep -v '^WARNING:'
}

# Chequeo de fuente: volumen sin name fijo (sólo plantillas con ${).
check_source_volume_names() {
  awk '
    BEGIN { in_vol = 0 }
    /^volumes:/ { in_vol = 1; next }
    in_vol && /^[^[:space:]]/ { in_vol = 0 }
    in_vol && /^[[:space:]]+name:[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]+name:[[:space:]]+/, "", line)
      if (line !~ /\$/) {
        print "volumen con name fijo: " line > "/dev/stderr"
        exit 1
      }
    }
  ' "$ROOT/compose.yaml"
}

# Contrato 1: servicios sin profiles no exponen poder sobre el host.
check_contract_1() {
  local json="$1"
  local svcs
  svcs=$(printf '%s' "$json" | jq -r \
    '.services | to_entries[] | select((.value.profiles // []) | length == 0) | .key')
  for svc in $svcs; do
    local probe
    probe=$(printf '%s' "$json" | jq -r --arg s "$svc" '
      .services[$s] as $svc |
      (
        (if ($svc.ports // null) != null then "ports" else empty end),
        (if ($svc.container_name // null) != null then "container_name" else empty end),
        (if $svc.privileged == true then "privileged" else empty end),
        (if ($svc.cap_add // null) != null then "cap_add" else empty end),
        (if ($svc.devices // null) != null then "devices" else empty end),
        (if $svc.network_mode == "host" then "network_mode:host" else empty end),
        (if $svc.pid == "host" then "pid:host" else empty end),
        (if $svc.ipc == "host" then "ipc:host" else empty end),
        (if (($svc.security_opt // []) | any(.[]; test("unconfined"))) then "security_opt:unconfined" else empty end)
      )
    ')
    [ -z "$probe" ] || fail "$svc: expone $probe"

    # Binds absolutos fuera del repo o a docker.sock.
    local bad_binds
    bad_binds=$(printf '%s' "$json" | jq -r --arg s "$svc" --arg root "$ROOT" '
      (.services[$s].volumes // [])[]
      | select(.type == "bind")
      | .source
      | select(
          (test("docker\\.sock$"))
          or
          ((startswith("/")) and ((startswith($root)) | not))
        )
    ')
    while IFS= read -r src; do
      [ -z "$src" ] && continue
      case "$src" in
        *docker.sock) fail "$svc: monta docker.sock ($src)" ;;
        *)            fail "$svc: bind absoluto fuera del repo ($src)" ;;
      esac
    done <<< "$bad_binds"
  done
}

# Contrato 2: sin name fijo en raíz ni redes (fuente). Volúmenes en fuente aparte.
check_contract_2() {
  if grep -qE '^name:' "$ROOT/compose.yaml"; then
    fail "compose.yaml: raíz tiene 'name:' fijo (Coolify pone el nombre)"
  fi
  if awk '
      BEGIN { in_net = 0 }
      /^networks:/ { in_net = 1; next }
      in_net && /^[^[:space:]]/ { in_net = 0 }
      in_net && /^[[:space:]]+name:/ { found = 1 }
      END { exit !found }
    ' "$ROOT/compose.yaml"; then
    fail "compose.yaml: red con 'name:' fijo (Coolify pone el nombre)"
  fi
  check_source_volume_names || fail "volumen con name fijo"
}

# Contrato 3 (supabase-pg): DB_NAME y DB_SSLMODE propagados al render.
check_contract_supabase_pg() {
  local json="$1"
  local dsn pgdb pgssl
  dsn=$(printf '%s' "$json" | jq -r '.services.app.environment.MEMOS_DSN // ""')
  pgdb=$(printf '%s' "$json" | jq -r '.services.preflight.environment.PGDATABASE // ""')
  pgssl=$(printf '%s' "$json" | jq -r '.services.preflight.environment.PGSSLMODE // ""')

  case "$dsn" in *mvp_prueba*) ;; *) fail "app.MEMOS_DSN: no contiene DB_NAME=mvp_prueba (render=$dsn)" ;; esac
  case "$dsn" in *"sslmode=disable"*) ;; *) fail "app.MEMOS_DSN: no contiene sslmode=disable (render=$dsn)" ;; esac
  [ "$pgdb" = "mvp_prueba" ] || fail "preflight.PGDATABASE: no es mvp_prueba (render=$pgdb)"
  [ "$pgssl" = "disable" ]  || fail "preflight.PGSSLMODE: no es disable (render=$pgssl)"
}

# --- Ejecución --------------------------------------------------------------

VARS="$(extract_vars compose.yaml)"

# Render 1: defaults (comportamiento original).
ENV_BASE="$TMPDIR/env-base"
fake_env "$ENV_BASE" $VARS
JSON_BASE="$(render "$ENV_BASE")"
[ -n "$JSON_BASE" ] || fail "render base vacío"

check_contract_1 "$JSON_BASE"
check_contract_2

# Render 2: supabase-pg con DB_NAME=mvp_prueba y DB_SSLMODE=disable.
ENV_PG="$TMPDIR/env-pg"
fake_env "$ENV_PG" $VARS
echo "DB_NAME=mvp_prueba" >> "$ENV_PG"
echo "DB_SSLMODE=disable" >> "$ENV_PG"
JSON_PG="$(render "$ENV_PG")"
[ -n "$JSON_PG" ] || fail "render pg vacío"

check_contract_supabase_pg "$JSON_PG"

# Con DB_SSLROOTCERT vacío, el DSN no debe arrastrar /certs/ca.crt:
# el contrato 3 dice que si sslmode no es verify-full la CA no es obligatoria.
ENV_PG_NOROOT="$TMPDIR/env-pg-noroot"
fake_env "$ENV_PG_NOROOT" $VARS
echo "DB_NAME=mvp_prueba" >> "$ENV_PG_NOROOT"
echo "DB_SSLMODE=disable" >> "$ENV_PG_NOROOT"
echo "DB_SSLROOTCERT=" >> "$ENV_PG_NOROOT"
JSON_PG_NOROOT="$(render "$ENV_PG_NOROOT")"
[ -n "$JSON_PG_NOROOT" ] || fail "render pg-noroot vacío"
DSN_NOROOT="$(printf '%s' "$JSON_PG_NOROOT" | jq -r '.services.app.environment.MEMOS_DSN // ""')"
case "$DSN_NOROOT" in
  *"/certs/ca.crt"*) fail "app.MEMOS_DSN arrastra /certs/ca.crt con DB_SSLROOTCERT vacío (render=$DSN_NOROOT)" ;;
esac

echo "OK: coolify-check cumplido"