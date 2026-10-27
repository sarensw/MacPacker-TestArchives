# 
# This script is to run on Ubuntu Linux to create all sorts of (default) archives
# 
# 1. Run this script from the root of the repo
#
# Note: This script installs a few packages first. If you don't want to do that
#       just comment out the lines. But those packages are required to run the
#       script.
#

cd defaultArchiveContent

sudo apt install tar gzip bzip2 xz-utils zstd lz4 lzip lzop ncompress brotli arj ruby-full rpm
sudo gem install fpm

# raw
tar -cf ../defaultArchives/defaultArchive.tar *

# raw, of "." (tar -C dir .): every entry under "./", "./" itself included,
# the way dpkg-deb writes a deb's data.tar
tar --sort=name --owner=root --group=root -cf ../defaultArchives/defaultArchive-dotslash.tar .

# gzip
tar -czf ../defaultArchives/defaultArchive.tgz *
tar -czf ../defaultArchives/defaultArchive.tar.gz *

# bzip2
tar -cjf ../defaultArchives/defaultArchive.tbz2 *
tar -cjf ../defaultArchives/defaultArchive.tbz *
tar -cjf ../defaultArchives/defaultArchive.tar.bz2 *

# xz
tar -cJf ../defaultArchives/defaultArchive.txz *
tar -cJf ../defaultArchives/defaultArchive.tar.xz *

# zst
tar --zstd -cf ../defaultArchives/defaultArchive.tar.zst *
tar --zstd -cf ../defaultArchives/defaultArchive.tzst *

# lz4
tar --use-compress-program=lz4 -cf ../defaultArchives/defaultArchive.tar.lz4 *
tar --use-compress-program=lz4 -cf ../defaultArchives/defaultArchive.tlz4 *

# lzip
tar --lzip -cf ../defaultArchives/defaultArchive.tar.lz *
tar --lzip -cf ../defaultArchives/defaultArchive.tlz *

# lzma (piped: GNU tar's --lzma writes xz on Debian and Ubuntu)
tar -cf - * | lzma -c > ../defaultArchives/defaultArchive.tlzma
tar -cf - * | lzma -c > ../defaultArchives/defaultArchive.tar.lzma

# lzop
tar --lzop -cf ../defaultArchives/defaultArchive.tlzo *
tar --lzop -cf ../defaultArchives/defaultArchive.tar.lzo *

# brotli
tar --use-compress-program=brotli -cf ../defaultArchives/defaultArchive.tbr *
tar --use-compress-program=brotli -cf ../defaultArchives/defaultArchive.tar.br *

# arj
rm ../defaultArchives/defaultArchive.arj
arj a -r ../defaultArchives/defaultArchive.arj **/*.* *.*

# rpm & deb (debian file is in lowercase for compatibility reasons)
fpm -s dir -t rpm -n defaultArchive -v 1.0 ./
fpm -s dir -t deb -n defaultarchive -v 1.0 ./

# deb as dpkg-deb writes it. fpm above names the members GNU-style
# ("debian-binary/"), and 7-Zip opens that as a plain ar, not as a deb
mkdir -p ../dpkg-root/DEBIAN
cp -a folder "hello world.txt" ../dpkg-root/
printf 'Package: defaultarchive\nVersion: 1.0\nArchitecture: all\nMaintainer: MacPacker Test Archives <test@example.invalid>\nDescription: MacPacker test archive\n' > ../dpkg-root/DEBIAN/control
dpkg-deb --root-owner-group --build ../dpkg-root ../defaultArchives/defaultarchive-dpkg.deb
rm -rf ../dpkg-root

# squashfs
mksquashfs folder "hello world.txt" ../defaultArchives/defaultArchive.squashfs -noappend -comp xz -all-root

# compressed/: one file through each compressor, without a tar. None of them
# stores the file's name: gzip only optionally, and -n leaves it out
gzip -nc "hello world.txt" > "../compressed/hello world.txt.gz"
bzip2 -c "hello world.txt" > "../compressed/hello world.txt.bz2"
xz -c "hello world.txt" > "../compressed/hello world.txt.xz"
lzma -c "hello world.txt" > "../compressed/hello world.txt.lzma"
compress -c "hello world.txt" > "../compressed/hello world.txt.Z"

cd ..

