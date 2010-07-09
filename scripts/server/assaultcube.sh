#!/bin/sh

cd ${CUBESTATS_DEPLOY}

#
# Download AssaultCube
#
if [ ! -f "${CUBESTATS_CACHE}/assaultcube${ASSAULTCUBE_VERSION}.tar.bz2" ]; then
	echo Downloading AssaultCube ${ASSAULTCUBE_VERSION}...
	wget -O ${CUBESTATS_CACHE}/assaultcube${ASSAULTCUBE_VERSION}.tar.bz2 ${ASSAULTCUBE_URL}
fi
echo Extracting AssaultCube ${ASSAULTCUBE_VERSION}...
tar xjf "${CUBESTATS_CACHE}/assaultcube${ASSAULTCUBE_VERSION}.tar.bz2"
mv ${ASSAULTCUBE_DIR} assaultcube

# Workaround for 1.0.3 Update
if [ ! -f "${CUBESTATS_CACHE}/assaultcube1.0.3_update.tar.bz2" ]; then
	echo Downloading AssaultCube 1.0.3 Update ...
	wget -O ${CUBESTATS_CACHE}/assaultcube1.0.3_update.tar.bz2 \
		http://switch.dl.sourceforge.net/sourceforge/actiongame/AssaultCube_v1.0.3-Update.tar.bz2
fi
echo Extracting AssaultCube 1.0.3 Update ...
cd ${CUBESTATS_DEPLOY}/assaultcube
tar xjf "${CUBESTATS_CACHE}/assaultcube1.0.3_update.tar.bz2"
cd ${CUBESTATS_DEPLOY}

