# 
# This script on Ubuntu Linux to create all sorts of (default) archives
# 
# Run this script from the root of the repo
#

cd defaultArchiveContent

sudo apt install tar gzip bzip2 xz-utils zstd lz4 lzip lzop ncompress brotli

# raw
tar -cf ../defaultArchives/defaultArchive.tar .

# gzip
tar -czf ../defaultArchives/defaultArchive.tgz .
tar -czf ../defaultArchives/defaultArchive.tar.gz .

# bzip2
tar -cjf ../defaultArchives/defaultArchive.tbz2 .
tar -cjf ../defaultArchives/defaultArchive.tbz .
tar -cjf ../defaultArchives/defaultArchive.tar.bz2 .

# xz
tar -cJf ../defaultArchives/defaultArchive.txz .
tar -cJf ../defaultArchives/defaultArchive.tar.xz .

# zst
tar --zstd -cf ../defaultArchives/defaultArchive.tar.zst .
tar --zstd -cf ../defaultArchives/defaultArchive.tzst .

# lz4
tar --use-compress-program=lz4 -cf ../defaultArchives/defaultArchive.tar.lz4 .
tar --use-compress-program=lz4 -cf ../defaultArchives/defaultArchive.tlz4 .

# lzip
tar --lzip -cf ../defaultArchives/defaultArchive.tar.lz .
tar --lzip -cf ../defaultArchives/defaultArchive.tlz .

# lzma
tar --lzma -cf ../defaultArchives/defaultArchive.tlzma .
tar --lzma -cf ../defaultArchives/defaultArchive.tar.lzma .

# lzop
tar --lzop -cf ../defaultArchives/defaultArchive.tlzo .
tar --lzop -cf ../defaultArchives/defaultArchive.tar.lzo .

# brotli
tar --use-compress-program=brotli -cf ../defaultArchives/defaultArchive.tbr .
tar --use-compress-program=brotli -cf ../defaultArchives/defaultArchive.tar.br .

cd ..

