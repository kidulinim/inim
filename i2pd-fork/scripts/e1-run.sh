#!/usr/bin/env bash
# e1-run.sh — run E-1 cases on the loopback stand (INIM, test-network ONLY).
# Review round 8 item 7: one script runs the whole stand in one CI step, logs
# under $WDIR/e1-logs/ (workflow copies them to runs/<sha>/e1/).
# Usage: bash i2pd-fork/scripts/e1-run.sh [case1|case2|case3|case4|case5|case6|case7|all]
set +e

HERE=$(cd "$(dirname "$0")" && pwd)
WDIR="${WDIR:-/tmp/e1-stand}"
E1MAT="${E1MAT:-/tmp/e1-mat}"   # materials (keys/tunnels) survive e1-stand's rm -rf
I2PD_SRC="${I2PD_SRC:-/home/i2pd-src}"
I2PD="${I2PD:-$I2PD_SRC/i2pd}"
CASE="${1:-case1}"
HELPER="$E1MAT/e1-keyhelper"
LOGDIR="$E1MAT/e1-logs"

mkdir -p "$E1MAT" "$LOGDIR"
echo "[e1-run] building e1-keyhelper"
g++ -std=c++20 -I"$I2PD_SRC/libi2pd" -Wl,--unresolved-symbols=ignore-in-object-files \
    "$HERE/e1-keyhelper.cpp" "$I2PD_SRC/libi2pd.a" \
    -lssl -lcrypto -lz -lboost_program_options -lpthread -o "$HELPER" || {
  echo "helper build FAILED"; exit 1; }

echo "[e1-run] generating server keys"
"$HELPER" gen "$E1MAT/srv.keys" > /dev/null || { echo "srv keygen FAILED"; exit 1; }
SRV_RAW=$("$HELPER" derive "$E1MAT/srv.keys")
IFS=';' read -r SRV_K64 SRV_PUB SRV_AUTH_PUB SRV_AUTH_PRIV SRV_B33 SRV_BLINDED <<< "$SRV_RAW"
echo "[e1-run] srv b33=$SRV_B33 blinded_ident=$SRV_BLINDED"

# Server tunnel (srv): publishes an ENCRYPTED LeaseSet2 (type 5) with DH
# per-client auth. The client-auth public key (SRV_AUTH_PUB) is encoded as
# "name:base64" per ClientDestination::ReadAuthKey.
cat > "$E1MAT/srv-tunnels.conf" <<TUN
[e1srv]
type = server
host = 127.0.0.1
port = 65535
keys = srv.destkeys
signaturetype = 7
cryptotype = 4
i2cp.leaseSetType = 5
i2cp.leaseSetAuthType = 1
i2cp.leaseSetClient.dh.000 = 0:$SRV_AUTH_PUB
TUN
cp "$E1MAT/srv.keys" "$E1MAT/srv.destkeys"

# Client (cli): key-ring preload for experiment E-1 (INIM_TEST_HOOKS). Case 1
# key = the exact X25519 private key whose public half the server authorises.
case "$CASE" in
  case1) KEYRING_BODY="[{ \"blinded_ident_b64\": \"$SRV_BLINDED\", \"key_b64\": \"$SRV_AUTH_PRIV\", \"peer_static_keys_b64\": [] }]";;
  case2) KEYRING_BODY="[{ \"blinded_ident_b64\": \"$SRV_BLINDED\", \"key_b64\": \"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\", \"peer_static_keys_b64\": [] }]";;
  case3) KEYRING_BODY="[]";;
  *)     KEYRING_BODY="[{ \"blinded_ident_b64\": \"$SRV_BLINDED\", \"key_b64\": \"$SRV_AUTH_PRIV\", \"peer_static_keys_b64\": [] }]";;
esac
{
  echo "$KEYRING_BODY"
} > "$E1MAT/keyring.json"
cat "$E1MAT/keyring.json"
echo "[e1-run] server tunnel + keyring ($CASE) generated"

echo "[e1-run] starting stand (e1-stand.sh)"
bash "$HERE/e1-stand.sh" start 2>&1 | tee "$LOGDIR/stand.txt"
STAND_RC=${PIPESTATUS[0]}
if [ "$STAND_RC" != "0" ]; then
  echo "[e1-run] E1_STAND_FAILED (rc=$STAND_RC) — Mesh not established. Aborting $CASE."
  echo "E1_CASE_${CASE^^}_RC=2"
  exit 2
fi

echo "[e1-run] waiting for server destination to publish encrypted LeaseSet2 ..."
# e1-stand already waited for the mesh; here we additionally wait until the
# server destination really publishes its encrypted LeaseSet2 (visible in the
# srv log). Bounded wait with progress, not a blind sleep.
pub_wait=0
while [ $pub_wait -lt 60 ]; do
  if grep -aq "Published LeaseSet verified" "$WDIR/srv.stdout" 2>/dev/null; then
    echo "[e1-run] LeaseSet2 published and verified (${pub_wait}s)"
    break
  fi
  if grep -aq "Can't publish LeaseSet" "$WDIR/srv.stdout" 2>/dev/null; then
    echo "[e1-run] srv reports publish failure, continuing anyway (${pub_wait}s)"
    break
  fi
  sleep 5
  pub_wait=$((pub_wait + 5))
  echo "[e1-run] publish wait: ${pub_wait}s"
done

echo
echo "[e1-run] run probe: $CASE"
# HostLookup name form: <b33>.b32.i2p — AddressBook::GetAddress strips the
# suffix and parses the rest as a blinded address (B33_ADDRESS_THRESHOLD=52
# chars; base32 b33 is 56 chars, so it takes the blinded path).
python3 "$HERE/e1-probe.py" "$CASE" 127.0.0.1 7654 "${SRV_B33}.b32.i2p" "$HELPER" "$E1MAT/srv.keys" \
  2>&1 | tee "$LOGDIR/$CASE.txt"
PROBE_RC=${PIPESTATUS[0]}

echo "[e1-run] stop stand"
bash "$HERE/e1-stand.sh" stop 2>&1 | tee -a "$LOGDIR/stand.txt"

echo "[e1-run] collect logs"
for r in ff1 ff2 srv cli; do
  cp "$WDIR/$r.stdout" "$LOGDIR/$r.log" 2>/dev/null
done

echo "[e1-run] case $CASE done rc=$PROBE_RC"
echo "E1_CASE_${CASE^^}_RC=$PROBE_RC"
exit $PROBE_RC