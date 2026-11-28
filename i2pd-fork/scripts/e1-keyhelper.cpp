// e1-keyhelper.cpp — E-1 key/b33/create-session helper (INIM, test-network only).
// Modes:
//   gen [path]              generate EdDSA+X25519 keys file (base64, one line)
//   derive <keys-file>      print derived E-1 material CSV (one line):
//                           <keys-b64>;<pub-ident-b64>;<auth_pub_b64>;<auth_priv_b64>;<b33>;<blinded_ident_b64>
//   build-session <keys-file> [options-kv]
//                           build+sign I2CP CreateSession payload, print <hex-payload>
//   build-ls2 <keys-file>   build minimal unpublished standard LS2 (store type 3,
//                           0 key sections, 0 leases) signed per LeaseSet2 rules
//                           (signature covers 0x03 || body). Print hex of the full
//                           CreateLeaseSet2 message payload minus sessionID:
//                           [0x03 storeType][LS2 body][signature][0x00 numPrivateKeys]
//   sign <keys-file> <hex>  sign hex buffer with keys' signature, print <hex-signature>
//
// Build: g++ -std=c++20 -I<i2pd-src>/libi2pd e1-keyhelper.cpp <i2pd-src>/libi2pd.a \
//        -lssl -lcrypto -lz -lboost_program_options -lpthread -o e1-keyhelper
#include "Identity.h"
#include "Blinding.h"
#include "Crypto.h"
#include <cstdio>
#include <cstring>
#include <ctime>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static std::string B64 (const uint8_t * p, size_t n)
{
    return i2p::data::ByteStreamToBase64 (p, n);
}

static std::string Hex (const uint8_t * p, size_t n)
{
    static const char * d = "0123456789abcdef";
    std::string r; r.reserve (n * 2);
    for (size_t i = 0; i < n; i++) { r += d[p[i] >> 4]; r += d[p[i] & 15]; }
    return r;
}

static bool Unhex (const std::string & s, std::vector<uint8_t> & out)
{
    if (s.size () % 2) return false;
    out.clear (); out.reserve (s.size () / 2);
    for (size_t i = 0; i < s.size (); i += 2)
    {
        unsigned v = 0;
        for (int k = 0; k < 2; k++)
        {
            char c = s[i + k];
            v <<= 4;
            if (c >= '0' && c <= '9') v |= c - '0';
            else if (c >= 'a' && c <= 'f') v |= c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') v |= c - 'A' + 10;
            else return false;
        }
        out.push_back ((uint8_t)v);
    }
    return true;
}

static bool LoadKeys (const char * path, i2p::data::PrivateKeys & keys)
{
    // i2pd LoadPrivateKeys reads the RAW binary PrivateKeys::ToBuffer format,
    // not base64 -- see ClientContext::LoadPrivateKeys.
    std::ifstream f (path, std::ios::binary);
    if (!f.is_open ()) return false;
    f.seekg (0, std::ios::end);
    size_t len = (size_t)f.tellg ();
    f.seekg (0);
    std::vector<uint8_t> buf (len);
    f.read ((char *)buf.data (), len);
    return keys.FromBuffer (buf.data (), len) > 0;
}

int main (int argc, char * argv[])
{
    if (argc < 2) { fprintf (stderr, "usage: e1-keyhelper <mode> [...]\n"); return 1; }
    std::string mode = argv[1];

    if (mode == "gen")
    {
        std::string out = argc > 2 ? argv[2] : "/tmp/e1-keyhelper.keys";
        auto keys = i2p::data::PrivateKeys::CreateRandomKeys (
            i2p::data::SIGNING_KEY_TYPE_EDDSA_SHA512_ED25519,
            i2p::data::CRYPTO_KEY_TYPE_ECIES_X25519_AEAD);
        // RAW binary ToBuffer format (what LoadPrivateKeys expects on disk)
        std::vector<uint8_t> buf (keys.GetFullLen ());
        size_t l = keys.ToBuffer (buf.data (), buf.size ());
        std::ofstream f (out, std::ios::binary);
        f.write ((const char *)buf.data (), l);
        printf ("%s\n", keys.ToBase64 ().c_str ());
        return 0;
    }

    if (argc < 3) { fprintf (stderr, "missing keys-file\n"); return 1; }
    i2p::data::PrivateKeys keys;
    if (!LoadKeys (argv[2], keys)) { fprintf (stderr, "bad keys file\n"); return 1; }

    if (mode == "derive")
    {
        auto identity = keys.GetPublic ();
        i2p::data::BlindedPublicKey blinded (identity, true /* clientAuth */);
        auto blindedIdent = blinded.GetIdentHash ();
        i2p::crypto::X25519Keys dh;
        dh.GenerateKeys ();
        uint8_t priv[32]; dh.GetPrivateKey (priv);
        std::vector<uint8_t> identBuf (identity->GetFullLen ());
        identity->ToBuffer (identBuf.data (), identBuf.size ());
        printf ("%s;%s;%s;%s;%s;%s\n",
            keys.ToBase64 ().c_str (),
            B64 (identBuf.data (), identBuf.size ()).c_str (),
            B64 (dh.GetPublicKey (), 32).c_str (),
            B64 (priv, 32).c_str (),
            blinded.ToB33 ().c_str (),
            B64 (blindedIdent, 32).c_str ());
        return 0;
    }

    if (mode == "sign")
    {
        if (argc < 4) { fprintf (stderr, "missing hex\n"); return 1; }
        std::vector<uint8_t> buf;
        if (!Unhex (argv[3], buf)) { fprintf (stderr, "bad hex\n"); return 1; }
        std::vector<uint8_t> sig (keys.GetSignatureLen ());
        keys.Sign (buf.data (), buf.size (), sig.data ());
        printf ("%s\n", Hex (sig.data (), sig.size ()).c_str ());
        return 0;
    }

    if (mode == "build-ls2")
    {
        // Minimal unpublished standard LS2 (store type 3): 0 key sections,
        // 0 leases. Layout per LeaseSet2::ReadFromBuffer:
        //   [identity][published 4B][expires 2B][flags 2B][propsLen 2B=0]
        //   [numKeySections 1B=0][numLeases 1B=0] / signature covers 0x03||body
        auto identity = keys.GetPublic ();
        uint32_t published = (uint32_t)time (nullptr);
        uint16_t expires = 600; // must stay under LeaseSet2 future-time threshold
        uint16_t flags = 0x0002; // LEASESET2_FLAG_UNPUBLISHED_LEASESET
        std::vector<uint8_t> body (identity->GetFullLen ());
        identity->ToBuffer (body.data (), body.size ());
        body.push_back ((uint8_t)(published >> 24));
        body.push_back ((uint8_t)(published >> 16));
        body.push_back ((uint8_t)(published >> 8));
        body.push_back ((uint8_t)published);
        body.push_back ((uint8_t)(expires >> 8));
        body.push_back ((uint8_t)expires);
        body.push_back ((uint8_t)(flags >> 8));
        body.push_back ((uint8_t)flags);
        body.push_back (0); body.push_back (0); // properties len
        body.push_back (0); // num key sections
        body.push_back (0); // num leases
        // signature covers storeType || body (LeaseSet2::VerifySignature)
        std::vector<uint8_t> signbuf;
        signbuf.push_back (0x03);
        signbuf.insert (signbuf.end (), body.begin (), body.end ());
        std::vector<uint8_t> sig (keys.GetSignatureLen ());
        keys.Sign (signbuf.data (), (int)signbuf.size (), sig.data ());
        std::vector<uint8_t> msg;
        msg.push_back (0x03); // storeType field of CreateLeaseSet2 payload
        msg.insert (msg.end (), body.begin (), body.end ());
        msg.insert (msg.end (), sig.begin (), sig.end ());
        msg.push_back (0); // numPrivateKeys = 0
        printf ("%s\n", Hex (msg.data (), msg.size ()).c_str ());
        return 0;
    }

    if (mode == "build-session")
    {
        std::string opts = argc > 3 ? argv[3] : "";
        auto identity = keys.GetPublic ();
        std::vector<uint8_t> obj (identity->GetFullLen ());
        identity->ToBuffer (obj.data (), obj.size ());
        // options:  2-byte size, then "key\\0=value;" pairs
        std::vector<uint8_t> optbuf;
        if (!opts.empty ())
        {
            std::stringstream ss (opts);
            std::string kv;
            while (std::getline (ss, kv, ';'))
            {
                if (kv.empty ()) continue;
                // Mapping wire format: [1B keylen]key[=][1B vallen]value[;] ---
                // see Mapping::ExtractString/FromBuffer (i2pd/util.cpp).
                auto eq = kv.find ('=');
                if (eq == std::string::npos) continue;
                std::string k = kv.substr (0, eq), v = kv.substr (eq + 1);
                optbuf.push_back ((uint8_t)k.size ());
                optbuf.insert (optbuf.end (), k.begin (), k.end ());
                optbuf.push_back ('=');
                optbuf.push_back ((uint8_t)v.size ());
                optbuf.insert (optbuf.end (), v.begin (), v.end ());
                optbuf.push_back (';');
            }
        }
        std::vector<uint8_t> full;
        full.insert (full.end (), obj.begin (), obj.end ());
        full.push_back ((uint8_t)(optbuf.size () >> 8));
        full.push_back ((uint8_t)(optbuf.size () & 0xFF));
        full.insert (full.end (), optbuf.begin (), optbuf.end ());
        // 8-byte date (now)
        for (int i = 0; i < 8; i++) full.push_back (0); // date tampered later if desired; zero ok
        std::vector<uint8_t> sig (keys.GetSignatureLen ());
        keys.Sign (full.data (), full.size (), sig.data ());
        full.insert (full.end (), sig.begin (), sig.end ());
        printf ("%s\n", Hex (full.data (), full.size ()).c_str ());
        return 0;
    }

    fprintf (stderr, "unknown mode %s\n", mode.c_str ());
    return 1;
}