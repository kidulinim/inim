#!/usr/bin/env python3
"""e1-probe.py — E-1 I2CP probe (INIM, test-network ONLY).

Drives the client side of experiment E-1 against a running i2pd client router
(variant: 2 test-network-only). Uses only Python stdlib -- no external deps.

Modes:
  case1  <host> <port> <b33name> <helper> <keysfile> [--wait W]
         CreateSession on the client router, then HostLookup of the b33 name.
         Passes if HostReply carries an identity; fail-closed otherwise.

Usage:
  python3 e1-probe.py case1 127.0.0.1 20214 myserver.b32.i2p \
      /tmp/e1-keyhelper /tmp/cli-keys

Wire protocol (I2CP):
  [1B 0x2A protocol-byte] once on connect
  frame: [4B big-endian payload-len][1B type][payload]
"""
import socket, struct, subprocess, sys, time

PROTO_BYTE = 0x2A
T_GET_DATE = 32
T_SET_DATE = 33
T_CREATE_SESSION = 1
T_SESSION_STATUS = 20
T_HOST_LOOKUP = 38
T_HOST_REPLY = 39
T_SEND_MESSAGE = 5
T_MESSAGE_STATUS = 22
T_REQUEST_VARIABLE_LEASESET = 37
T_CREATE_LEASESET2 = 41

SESSION_REFUSED = 4
SESSION_CREATED = 1
HOST_REPLY_OK = 0

def frame(msg_type: int, payload: bytes) -> bytes:
    return struct.pack(">IB", len(payload), msg_type) + payload

def read_frame(s: socket.socket, timeout=15):
    s.settimeout(timeout)
    hdr = b""
    while len(hdr) < 5:
        chunk = s.recv(5 - len(hdr))
        if not chunk:
            return None, None
        hdr += chunk
    plen, mtype = struct.unpack(">IB", hdr)
    payload = b""
    while len(payload) < plen:
        chunk = s.recv(plen - len(payload))
        if not chunk:
            break
        payload += chunk
    return mtype, payload

def hex2bytes(s: str) -> bytes:
    return bytes.fromhex(s)

def fields_from_derive(helper: str, keysfile: str):
    out = subprocess.check_output([helper, "derive", keysfile]).decode().strip()
    vals = out.split(";")
    keys_b64, pubident_b64, auth_pub, auth_priv, b33, blinded_ident = vals
    return keys_b64, pubident_b64, auth_pub, auth_priv, b33, blinded_ident

def build_create_session(helper: str, keysfile: str, opts: str) -> bytes:
    out = subprocess.check_output([helper, "build-session", keysfile, opts])
    return hex2bytes(out.decode().strip())

def build_ls2_payload(helper: str, keysfile: str) -> bytes:
    out = subprocess.check_output([helper, "build-ls2", keysfile])
    return hex2bytes(out.decode().strip())

def run_case1(host, port, b33name, helper, keysfile, wait_secs=30):
    """Test case 1: correct key registered -> HostLookup resolves.

    The I2CP destination is not "ready" (no tunnels) the instant the session
    is created, so RequestDestinationWithEncryptedLeaseSet fails closed and
    returns a null HostReply immediately. This probe therefore RE-issues
    HostLookup every few seconds until the lease-set lookup succeeds or the
    budget runs out -- matching a real client that retries on NoLeaseSet.
    """
    print(f"E-1 case 1: host={host} port={port} b33={b33name} budget={wait_secs}s")
    session = socket.create_connection((host, port), timeout=5)
    session.sendall(bytes([PROTO_BYTE]))

    # GetDate -> expect SetDate
    session.sendall(frame(T_GET_DATE, b""))
    mtype, payload = read_frame(session)
    print(f"  <- SetDate type={mtype} len={len(payload) if payload else 0}")

    # CreateSession
    opts = "i2cp.leaseSetType=5"
    cs_payload = build_create_session(helper, keysfile, opts)
    session.sendall(frame(T_CREATE_SESSION, cs_payload))
    mtype, payload = read_frame(session)
    status = payload[2] if payload and len(payload) >= 3 and mtype == T_SESSION_STATUS else None
    session_id = struct.unpack(">H", payload[:2])[0] if payload and len(payload) >= 2 else 0xFFFF
    print(f"  <- SessionStatus type={mtype} status={status} (/ {SESSION_CREATED}) sessionID={session_id}")
    if status != SESSION_CREATED:
        print("  FAIL: session not created")
        return 1

    # minimal unpublished LS2 (store type 3) to answer RequestVariableLeaseSet
    ls2_payload = build_ls2_payload(helper, keysfile)
    print(f"  built minimal LS2 payload len={len(ls2_payload)} (store type 3, unpublished)")

    name_bytes = b33name.encode()
    deadline = time.time() + wait_secs
    attempt = 0
    while time.time() < deadline:
        attempt += 1
        request_id = (int(time.time()) + attempt) & 0xFFFFFFFF
        timeout_ms = 8000
        hl = bytearray()
        hl += struct.pack(">H", 0xFFFF)          # sessionID = -1 (any)
        hl += struct.pack(">I", request_id)      # requestID
        hl += struct.pack(">I", timeout_ms)      # timeout
        hl.append(1)                              # type=address
        hl.append(len(name_bytes))
        hl += name_bytes
        print(f"  -> HostLookup #{attempt} (reqId={request_id})")
        session.sendall(frame(T_HOST_LOOKUP, bytes(hl)))
        got_reply = False
        while not got_reply and time.time() < deadline:
            try:
                mtype, payload = read_frame(session, timeout=10)
            except socket.timeout:
                break
            if mtype == T_REQUEST_VARIABLE_LEASESET:
                # router asks this session's destination for its LeaseSet --
                # answer with the minimal unpublished LS2 (store type 3)
                cl2 = struct.pack(">H", session_id) + ls2_payload
                session.sendall(frame(T_CREATE_LEASESET2, cl2))
                print(f"  -> CreateLeaseSet2 (type 41) len={len(cl2)} in reply to RequestVariableLeaseSet")
                continue
            if mtype == T_HOST_REPLY and payload:
                got_reply = True
                result_code = payload[6] if len(payload) >= 7 else -1
                ident = payload[7:] if len(payload) > 7 else b""
                print(f"  <- HostReply result={result_code} ident_len={len(ident)}")
                if result_code == HOST_REPLY_OK and len(ident) > 0:
                    print("  PASS: HostReply returned identity")
                    return 0
        if got_reply:
            time.sleep(5)  # destination may still be building tunnels; retry
        else:
            time.sleep(3)
    print("  FAIL: no successful HostReply within budget")
    return 1

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "case1":
        rc = run_case1(
            sys.argv[2], int(sys.argv[3]), sys.argv[4],
            sys.argv[5], sys.argv[6],
            int(sys.argv[7]) if len(sys.argv) > 7 else 60,
        )
        sys.exit(rc)
    else:
        print(__doc__)
        sys.exit(1)