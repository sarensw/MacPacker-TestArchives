# 
# This script is to run on macOS to create all sorts of (default) archives
# 
# 1. Run this script from the root of the repo
#
# Note: This script installs a few packages first. If you don't want to do that
#       just comment out the lines. But those packages are required to run the
#       script.
#

cd defaultArchiveContent

# xar
xar -cf ../defaultArchives/defaultArchive.xar --exclude .DS_Store .