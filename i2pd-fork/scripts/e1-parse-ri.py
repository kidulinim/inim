#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# e1-parse-ri.py -- parse an i2pd router.info binary and show exactly what the
# NetDb floodfill eligibility check (RouterInfo::IsEligibleFloodfill / OID
# parsing) would see: identity, caps, version, published transports.
# Usage: python3 e1-parse-ri.py /tmp/e1-stand/ff1/data/router.info
import struct, sys, zlib, base64

def be16(b, o): return struct.unpack('>H', b[o:o+2])[0]
def be32(b, o): return struct.unpack('>I', b[o:o+4])[0]
def be64(b, o): return struct.unpack('>Q', b[o:o+8])[0]

def extract_string(b, o):
    if o >= len(b): return '', o
    l = b[o]
    s = b[o+1:o+1+l].decode('utf-8', 'replace')
    return s, o + 1 + l

def main(path):
    data = open(path, 'rb').read()
    print('file:', path, 'size:', len(data))
    # identity: default 387 bytes + extended length at offset 385..387
    ext_len = be16(data, 385)
    ident_len = 387 + ext_len
    print('identity full length:', ident_len)

    buf = data[ident_len:]
    ts = be64(buf, 0)
    num = buf[8]
    print('timestamp:', ts, 'numAddresses:', num)
    o = 9
    for i in range(num):
        # cost + date
        cost = buf[o]; o += 1
        addr_date = be64(buf, o); o += 8
        transport_style, o = extract_string(buf, o)
        size = be16(buf, o); o += 2
        end = o + size
        params = []
        r = o
        while r < end:
            if r >= len(buf): break
            k, r = extract_string(buf, r)
            if r >= len(buf): break
            v, r = extract_string(buf, r)
            params.append((k, v))
        o = end
        print(f'  addr[{i}] transport={transport_style!r} cost={cost} params={params}')

    # router properties
    props = []
    while o < len(buf):
        k, o = extract_string(buf, o)
        v, o = extract_string(buf, o)
        props.append((k, v))
        # stop before signature (props end when we've read a field that is not
        # a property -- but i2pd uses remaining bytes after properties; simply
        # read until we run out or see a run of binary)
        if o >= len(buf): break
        # heuristic: after properties there is 2-byte size? i2pd uses ExtractParam
        # until offset >= size; we can't know size here -- break on binary
        if b'\x00' in buf[o:o+1] and False:
            break
    print('router properties:')
    for k, v in props:
        if len(v) <= 120:
            print(f'  {k} = {v}')
        else:
            print(f'  {k} = (len {len(v)}) {v[:100]}...')

if __name__ == '__main__':
    main(sys.argv[1])