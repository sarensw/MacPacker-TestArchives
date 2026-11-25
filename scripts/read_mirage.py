# Reads a disc image with libmirage (CDEmu) through GObject introspection and writes the data sectors of track 1.
# Built on Ubuntu 24.04 arm64: git clone https://github.com/cdemu/cdemu (3b3bb8ca, libmirage 3.3.3), libgcrypt20-dev for MDX, cmake + make install.
# Run with GI_TYPELIB_PATH=/usr/local/lib/aarch64-linux-gnu/girepository-1.0 LD_LIBRARY_PATH=/usr/local/lib. Output includes the 150-sector pregap.
# usage: dump.py <image> <out.iso> [password]  -- reads all sectors of the first data track via libmirage
import sys, gi
gi.require_version('Mirage', '3.2'); from gi.repository import Mirage, GLib
Mirage.initialize()
ctx = Mirage.Context()
if len(sys.argv) > 3:
    pw = sys.argv[3]
    ctx.set_password_function(lambda *a: pw)
disc = ctx.load_image([sys.argv[1]])
print('parser medium', disc.get_medium_type(), 'sessions', disc.get_number_of_sessions(), 'tracks', disc.get_number_of_tracks())
t = disc.get_track_by_index(0)
print('track mode', t.get_sector_type(), 'length', t.layout_get_length())
out = bytearray()
start = t.layout_get_start_sector()
for i in range(t.layout_get_length()):
    s = disc.get_sector(start + i)
    ok, data = s.get_data()
    out += bytes(data)
open(sys.argv[2], 'wb').write(out); print('wrote', len(out))
