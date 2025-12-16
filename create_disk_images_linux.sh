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

sudo apt install mtools qemu-utils

# create a small raw disk
truncate -s 16M test.fat

# format it as FAT
mformat -i test.fat -F ::

# create directory
mmd -i test.fat ::/folder

# copy files
mcopy -i test.fat "hello world.txt" ::/
mcopy -i test.fat folder/* ::/folder/

# create images
qemu-img convert -f raw -O qcow2 test.fat ../defaultArchives/defaultArchive.qcow2
qemu-img convert -f raw -O vdi   test.fat ../defaultArchives/defaultArchive.vdi
qemu-img convert -f raw -O vmdk  test.fat ../defaultArchives/defaultArchive.vmdk
qemu-img convert -f raw -O vpc   test.fat ../defaultArchives/defaultArchive.vhd
qemu-img convert -f raw -O vhdx  test.fat ../defaultArchives/defaultArchive.vhdx

file test.fat
mv test.fat ../defaultArchives/defaultArchive.fat

cd ..

