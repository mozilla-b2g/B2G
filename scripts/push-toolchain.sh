#!/bin/bash
# This simple script knows how to take a toolchain, add the packaging
# jazz needed to get it onto TBPL builders and show the commands that
# will upload.  This script requires ssh access to the remote host
# and generates a file that needs to be landed into mozilla-central
set -e

cd ..

# if [ -z $REMOTE_HOST ] ; then REMOTE_HOST=runtime-binaries.pvt.build.mozilla.com ; fi
if [ -z $REMOTE_HOST ] ; then REMOTE_HOST=relengweb1.dmz.scl3.mozilla.com ; fi
if [ -z $REMOTE_PATH ] ; then REMOTE_PATH=/var/www/html/runtime-binaries/tooltool/ ; fi
if [ -z $ALGORITHM ] ; then ALGORITHM=sha512 ; fi
if [ -z $VERSION ] ; then 
    echo "ERROR: must specify a version"
    exit 1
fi
if [ ! -f gonk-toolchain-$VERSION.tar.bz2 ] ; then
    echo "ERROR: missing the toolchain file"
    pwd && ls
    exit 1
fi

cat > setup.sh << EOF
#!/bin/bash
# This script knows how to set up a gonk toolchain in a given builder's
# directory.
set -xe
rm -rf gonk-toolchain
tar jxf gonk-toolchain-$VERSION.tar.bz2
mv gonk-toolchain-$VERSION gonk-toolchain
EOF

if [ ! -f tooltool/tooltool.py ] ; then
    git clone github.com:jhford/tooltool
else
    (cd tooltool && git fetch && git merge origin/master)
fi
rm -f new.manifest
python tooltool/tooltool.py -d $ALGORITHM -m new.manifest add gonk-toolchain-$VERSION.tar.bz2 setup.sh

toolchainh=$(openssl dgst -$ALGORITHM < gonk-toolchain-$VERSION.tar.bz2 | sed "s/^(stdin)= //")
setuph=$(openssl dgst -$ALGORITHM < setup.sh | sed "s/^(stdin)= //")

echo "These commands will upload the toolchain to the tool server"
echo "scp $PWD/gonk-toolchain-$VERSION.tar.bz2 $REMOTE_HOST:$REMOTE_PATH/$ALGORITHM/$toolchainh"
echo "scp $PWD/setup.sh $REMOTE_HOST:$REMOTE_PATH/$ALGORITHM/$setuph"
echo "ssh $REMOTE_HOST chmod 644 $REMOTE_PATH/$ALGORITHM/$setuph $REMOTE_PATH/$ALGORITHM/$toolchainh"

echo "The file \"new.manifest\" contains a manifest that points to your toolchain"
echo "It need to be landed in b2g/config/tooltool-manifests/ with a filename that matches"
echo "what releng tells you.  Currently, ics.manifest"
echo "Contents:"
echo =====
cat new.manifest
echo =====
