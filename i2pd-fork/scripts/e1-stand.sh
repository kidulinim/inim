#!/usr/bin/env bash
# e1-stand.sh — E-1 loopback I2P test network for INIM (review round 8,
# items 6-8). Minimal topography per the reviewer's template: 2 floodfill
# routers + 1 server router (Secret Destination holder) + 1 client router
# (i2cp.enabled=true, drives the 7 cases of docs/plans/e1-test-matrix.md).
#
# Single config template for every router -- only role markers differ:
#   netid=77             shared test net
#   reservedrange=false  <-- CRITICAL (review round 8 item 6): with the
#        default true i2pd drops RouterInfo with loopback/private addresses
#        and the stand shows "no peers available" on every tunnel attempt.
#   reseed.zipfile + reseed.verify=false  bootstrap from own router.infos
#   ntcp2.enabled=true, ssu2.enabled=false, nat=false
#   http / proxies / sam / bob / i2pcontrol / upnp disabled
#   floodfill=true for ff1, ff2 only
#   i2cp.enabled=true for cli only (the E-1 probe connects to it)
#
# Configs are generated ONCE and never rewritten across launches (i2pd
# regenerates router.info if the config mutates, breaking the peer list).
# Idle timeout/informative reporting: the wait loop prints progress every
# 10 seconds (repeat identical lines are a report bug, not script behaviour).
#
# Usage:  bash i2pd-fork/scripts/e1-stand.sh [start|status|stop|logs]
# Env:    WDIR (default /tmp/e1-stand), NETID (default 77),
#         I2PD (default /home/i2pd-src/i2pd), WAIT (default 45 seconds)
set +e

I2PD="${I2PD:-/home/i2pd-src/i2pd}"
WDIR="${WDIR:-/tmp/e1-stand}"
NETID="${NETID:-77}"
WAIT="${WAIT:-45}"

# name:port:floodfill:i2cp
ROUTERS="ff1:20111:true:false ff2:20112:true:false srv:20113:false:false cli:20114:false:true"

echo "[e1-stand] WDIR=$WDIR NETID=$NETID I2PD=$I2PD"
export WDIR NETID

gen_conf() {
  local name="$1" port="$2" floodfill="$3" i2cp="$4"
  mkdir -p "$WDIR/$name/data"
  touch "$WDIR/$name/tunnels.conf"
  cat > "$WDIR/$name/i2pd.conf" <<CONF
log = stdout
loglevel = info
port = $port
host = 127.0.0.1
netid = $NETID
reservedrange = false
bandwidth = X
share = 100
nat = false
exploratory.inbound.length = 1
exploratory.outbound.length = 1
reseed.verify = false
reseed.urls =
reseed.zipfile = $WDIR/reseed.zip
ntcp2.enabled = true
ntcp2.published = true
ssu2.enabled = false
httpproxy.enabled = false
socksproxy.enabled = false
sam.enabled = false
bob.enabled = false
i2cp.enabled = $i2cp
i2pcontrol.enabled = false
upnp.enabled = false
http.enabled = false
floodfill = $floodfill
CONF
}

launch() {
  local name="$1"
  "$I2PD" --conf="$WDIR/$name/i2pd.conf" --tunconf="$WDIR/$name/tunnels.conf" \
         --datadir="$WDIR/$name/data" > "$WDIR/$name.stdout" 2>&1 &
  echo $! > "$WDIR/$name.pid"
  echo "[e1-stand]   launched $name (pid $(cat "$WDIR/$name.pid"))"
}

start() {
  mkdir -p "$WDIR"

  for spec in $ROUTERS; do
    name=${spec%%:*}; rest=${spec#*:}; port=${rest%%:*}; rest=${rest#*:}
    ff=${rest%%:*}; i2cp=${rest#*:}
    gen_conf "$name" "$port" "$ff" "$i2cp"
  done

  echo "[e1-stand] phase 1: generate identities (config is never rewritten after this)"
  for spec in $ROUTERS; do
    name=${spec%%:*}
    launch "$name"
  done
  # progress line every 10 s -- never repeat the same line silently
  local waited=0
  while [ $waited -lt 25 ]; do
    sleep 10
    waited=$((waited + 10))
    local ready=0
    for spec in $ROUTERS; do
      name=${spec%%:*}
      [ -f "$WDIR/$name/data/router.info" ] && ready=$((ready + 1))
    done
    echo "[e1-stand] identity gen: $ready/4 router.info present (${waited}s)"
  done

  for spec in $ROUTERS; do
    name=${spec%%:*}
    kill "$(cat "$WDIR/$name.pid")" 2>/dev/null
  done
  sleep 3

  echo "[e1-stand] phase 2: build reseed.zip from floodfills' router.info"
  python3 - <<'PY'
import zipfile, os
w = os.environ.get('WDIR', '/tmp/e1-stand')
zp = os.path.join(w, 'reseed.zip')
with zipfile.ZipFile(zp, 'w', zipfile.ZIP_DEFLATED) as z:
    for n in ['ff1', 'ff2']:
        p = os.path.join(w, n, 'data', 'router.info')
        if os.path.exists(p):
            z.write(p, n + '.router.info')
            print('  added', p)
print('reseed.zip size:', os.path.getsize(zp))
PY

  echo "[e1-stand] phase 3: relaunch all routers (identical configs) with reseed.zip present"
  for spec in $ROUTERS; do
    name=${spec%%:*}
    launch "$name"
  done

  waited=0
  while [ $waited -lt "$WAIT" ]; do
    sleep 10
    waited=$((waited + 10))
    local sessions
    sessions=$(cat "$WDIR"/*.stdout 2>/dev/null | grep -aci 'NTCP2.*established\|transports.*connected\|New NTCP2' )
    echo "[e1-stand] mesh wait: NTCP2 session lines across logs = $sessions (${waited}/${WAIT}s)"
  done

  echo "[e1-stand] adjacency check (transport session mentions per router):"
  for spec in $ROUTERS; do
    name=${spec%%:*}
    echo "--- $name ---"
    grep -aiE "transports|ntcp2|connected|peer" "$WDIR/$name.stdout" | tail -5
  done
  echo "E1_STAND_READY"
}

status() {
  for spec in $ROUTERS; do
    name=${spec%%:*}
    local pid
    pid=$(cat "$WDIR/$name.pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "[e1-stand] $name: running (pid $pid)"
    else
      echo "[e1-stand] $name: stopped"
    fi
  done
}

stop() {
  for spec in $ROUTERS; do
    name=${spec%%:*}
    local pid
    pid=$(cat "$WDIR/$name.pid" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null && echo "[e1-stand] stopped $name"
  done
}

logs() {
  for spec in $ROUTERS; do
    name=${spec%%:*}
    echo "=================== $name ==================="
    tail -20 "$WDIR/$name.stdout" 2>/dev/null
  done
}

case "${1:-start}" in
  start)  start ;;
  status) status ;;
  stop)   stop ;;
  logs)   logs ;;
  *)      echo "usage: $0 [start|status|stop|logs]"; exit 1 ;;
esac