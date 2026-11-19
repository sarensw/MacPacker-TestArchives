#!/bin/bash
# GameCube GCM (scripts/write_gcm.py), Quake PAK (scripts/write_pak.py), Parallels .hdd bundle (qemu-img + DiskDescriptor.xml).
# usage: ubuntu_batch8.sh <repo root> <out dir>
set -euo pipefail
REPO=$(realpath "$1"); OUT=$(realpath -m "$2"); D="$OUT/defaultArchives"; mkdir -p "$D"
python3 -I "$REPO/scripts/write_gcm.py" "$REPO/defaultArchiveContent" "$D/defaultArchive.gcm"
python3 -I "$REPO/scripts/write_pak.py" "$REPO/defaultArchiveContent" "$D/defaultArchive.pak"
# Parallels bundle: a folder holding DiskDescriptor.xml and the expanding image (format as in QEMU docs/interop/parallels.txt
# and Parallels' own bundles); the image is defaultArchive.fat converted with qemu-img
B="$OUT/parallels/defaultArchive.hdd"; mkdir -p "$B"
G="{5fbaabe3-6958-40ff-92a7-860e329aab41}"
qemu-img convert -f raw -O parallels "$REPO/defaultArchives/defaultArchive.fat" "$B/defaultArchive.hdd.0.$G.hds"
S=$(( $(stat -c%s "$REPO/defaultArchives/defaultArchive.fat") / 512 ))
cat > "$B/DiskDescriptor.xml" <<X
<?xml version='1.0' encoding='UTF-8'?>
<Parallels_disk_image Version="1.0">
    <Disk_Parameters>
        <Disk_size>$S</Disk_size>
        <Cylinders>$((S / 16 / 32))</Cylinders>
        <PhysicalSectorSize>512</PhysicalSectorSize>
        <Heads>16</Heads>
        <Sectors>32</Sectors>
        <Padding>0</Padding>
        <Encryption>
            <Engine>{00000000-0000-0000-0000-000000000000}</Engine>
            <Data></Data>
        </Encryption>
        <UID>{8f7d5a1e-4b2c-4d3e-9f10-112233445566}</UID>
        <Name>defaultArchive</Name>
        <Miscellaneous>
            <CompatLevel>level2</CompatLevel>
            <Bootable>0</Bootable>
        </Miscellaneous>
    </Disk_Parameters>
    <StorageData>
        <Storage>
            <Start>0</Start>
            <End>$S</End>
            <Blocksize>2048</Blocksize>
            <Image>
                <GUID>$G</GUID>
                <Type>Compressed</Type>
                <File>defaultArchive.hdd.0.$G.hds</File>
            </Image>
        </Storage>
    </StorageData>
    <Snapshots>
        <Shot>
            <GUID>$G</GUID>
            <ParentGUID>{00000000-0000-0000-0000-000000000000}</ParentGUID>
        </Shot>
    </Snapshots>
</Parallels_disk_image>
X
echo DONE
