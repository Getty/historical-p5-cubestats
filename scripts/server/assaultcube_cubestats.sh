#!/bin/sh

cd ${CUBESTATS_DEPLOY}

#
# Check for server source
#
if [ ! -f cubestats_assaultcube_source.tar.gz ]; then
    echo $0: Need cubestats_assaultcube_source.tar.gz
    exit 1
fi

#
# Extract ac_server Source
#
echo Extracting ac_server Source...
cd assaultcube/source
mkdir src_cubestats
cd src_cubestats
tar xzf ../../../cubestats_assaultcube_source.tar.gz
cd ../../..
rm cubestats_assaultcube_source.tar.gz

# check if we even need to do it or not?
CURRENT_REV=`strings ${CUBESTATS_ROOT}/bin/ac_server_cubestats | grep Revision | cut -f2 -d" "`
SVN_REV=`cat assaultcube/source/src_cubestats/server.cpp | grep Revision | cut -f4 -d" "`
echo "svn:$SVN_REV cur:$CURRENT_REV"
if [ "$CURRENT_REV" -eq "$SVN_REV" ]; then
	echo "No need to re-compile, same rev $SVN_REV"
else
	#
	# Compile ac_server Source
	#
	echo Compiling enet lib...
	cd assaultcube/source/enet
	./configure
	make -j4 || exit 1
	cd ../../..
	echo Compiling ac_server Source...
	cd assaultcube/source/src_cubestats
	make server -j4 SIGNAL=1 CSN_THREADS=1 || exit 1
	cd ../../..
	mkdir bin
	mv assaultcube/source/src_cubestats/ac_server bin/ac_server_cubestats
fi

# ALL DONE
rm -rf assaultcube/source/src_cubestats
