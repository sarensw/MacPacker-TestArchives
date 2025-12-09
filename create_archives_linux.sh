# 
# This script on Ubuntu Linux to create all sorts of (default) archives
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

# lzma
tar --lzma -cf ../defaultArchives/defaultArchive.tlzma *
tar --lzma -cf ../defaultArchives/defaultArchive.tar.lzma *

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

cd ..

