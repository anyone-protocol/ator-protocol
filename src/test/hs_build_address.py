# Future imports for Python 2.7, mandatory in 3.0
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

import sys
import hashlib
import struct
import base64

# Python 3.6+, the SHA3 is available in hashlib natively. Else this requires
# the pysha3 package (pip install pysha3).
TEST_INPUT = b"Hello World"
if sys.version_info < (3, 6):
    import sha3
    m = sha3.sha3_256(TEST_INPUT)
else:
    m = hashlib.sha3_256(TEST_INPUT)

# Test vector to make sure the right sha3 version will be used. pysha3 < 1.0
# used the old Keccak implementation. During the finalization of SHA3, NIST
# changed the delimiter suffix from 0x01 to 0x06. The Keccak sponge function
# stayed the same. pysha3 1.0 provides the previous Keccak hash, too.
TEST_VALUE = "e167f68d6563d75bb25f3aa49c29ef612d41352dc00606de7cbd630bb2665f51"
if TEST_VALUE != m.hexdigest():
    print("pysha3 version is < 1.0. Please install from:")
    print("https://github.com/tiran/pysha3")
    sys.exit(1)

# Checksum is built like so:
#   CHECKSUM = SHA3(".anon checksum" || PUBKEY || VERSION)
PREFIX = ".anon checksum".encode()
# 32 bytes ed25519 pubkey from first test vector of
# https://tools.ietf.org/html/draft-josefsson-eddsa-ed25519-02#section-6
PUBKEY_STRING = "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
if sys.version_info < (3, 0):
    PUBKEY = PUBKEY_STRING.decode('hex')
else:
    PUBKEY = bytes.fromhex(PUBKEY_STRING)
# Version 3 is proposal224
VERSION = 3

data = struct.pack('14s32sb', PREFIX, PUBKEY, VERSION)
checksum = hashlib.sha3_256(data).digest()

# Onion address is built like so:
#   onion_address = base32(PUBKEY || CHECKSUM || VERSION) + ".anon"
address = struct.pack('!32s2sb', PUBKEY, checksum, VERSION)
onion_addr = base64.b32encode(address).decode().lower()

print("%s" % (onion_addr))
