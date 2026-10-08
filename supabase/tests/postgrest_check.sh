#!/usr/bin/env bash
# Sends the queries the app makes (home screen bills, saved groups) to a real PostgREST over the
# real schema and seed. This catches what SQL tests cannot: PostgREST refusing an embedded query
# as ambiguous (PGRST201). That is exactly why the home screen once said "could not load".
#
#   POSTGREST=/path/to/postgrest supabase/tests/postgrest_check.sh
# Get the binary from https://github.com/PostgREST/postgrest/releases (linux-static-x64).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${POSTGREST:?set POSTGREST to the postgrest binary}"
bin=$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)
dir=$(mktemp -d); chmod 777 "$dir"
as_pg() { if [ "$(id -u)" = 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi; }
as_pg "$bin/initdb" -D "$dir/data" -A trust >/dev/null
as_pg "$bin/pg_ctl" -D "$dir/data" -o "-p 54397 -k $dir -c listen_addresses=127.0.0.1" -l "$dir/log" -w start >/dev/null
trap 'kill ${pid:-0} 2>/dev/null || true; as_pg "$bin/pg_ctl" -D "$dir/data" -m immediate stop >/dev/null 2>&1; rm -rf "$dir"' EXIT
url="postgresql://postgres@127.0.0.1:54397/postgres"
psql "$url" -q -v ON_ERROR_STOP=1 -f "$here/shim.sql" >/dev/null 2>&1
psql "$url" -q -v ON_ERROR_STOP=1 -f "$here/../setup_all.sql" >/dev/null
psql "$url" -q -v ON_ERROR_STOP=1 -f "$here/../seed.sql" >/dev/null
psql "$url" -q -c "create role authenticator login noinherit; grant anon, authenticated to authenticator;" >/dev/null
cat > "$dir/pgrst.conf" <<C
db-uri = "postgresql://authenticator@127.0.0.1:54397/postgres"
db-schemas = "public"
db-anon-role = "anon"
server-port = 3397
jwt-secret = "reallyreallyreallyreallyverysafe"
C
"$POSTGREST" "$dir/pgrst.conf" >"$dir/pgrst.log" 2>&1 & pid=$!
sleep 3
jwt=$(python3 - <<'P'
import hmac, hashlib, base64, json, time
b = lambda x: base64.urlsafe_b64encode(x).rstrip(b'=')
h = b(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
p = b(json.dumps({"role": "authenticated", "sub": "00000000-0000-0000-0000-0000000d3e30", "exp": int(time.time()) + 3600}).encode())
print((h + b"." + p + b"." + b(hmac.new(b"reallyreallyreallyreallyverysafe", h + b"." + p, hashlib.sha256).digest())).decode())
P
)
host=00000000-0000-0000-0000-0000000d3e30
bills='id,place,total,status,billed_at,bill_participants!bill_participants_bill_id_fkey(id,name,is_host,user_id),shares(participant_id,total),settlements(participant_id,method,paid_amount,owed_amount,last_reminded_at)'
groups='id,name,group_members(friends(id,name,phone,avatar_color))'
fail=0
check() { # name url
  out=$(curl -s -H "Authorization: Bearer $jwt" "$2")
  if echo "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d, list) and len(d) > 0 else 1)"; then
    echo "ok   $1"
  else
    echo "FAIL $1: ${out:0:300}"; fail=1
  fi
}
check "home screen bills" "http://127.0.0.1:3397/bills?select=$bills&created_by=eq.$host&status=neq.draft&order=billed_at.desc&limit=200"
check "saved groups" "http://127.0.0.1:3397/groups?select=$groups&order=created_at"
exit $fail
