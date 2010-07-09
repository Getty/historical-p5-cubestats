#!/bin/sh
#
# Sample Script for deploying a master cubestats
#

PROD=~/cubestats_prod_deploy
SVN=http://svn.cubestats.net/trunk/
DIR=trunk

. ~/bin/env_cubestats.sh

rm -rf ${PROD}
svn export ${SVN} ${PROD}

~/bin/deploy_cubestats_install_perllibs.sh ${PROD}

