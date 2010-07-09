#!/bin/sh

cd ${CUBESTATS_DEPLOY}

if [ ! -d ~/.cpan ]; then mkdir ~/.cpan ; fi
if [ ! -d ~/.cpan/CPAN ]; then mkdir ~/.cpan/CPAN ; fi
cp config/CPAN_MyConfig.pm ~/.cpan/CPAN/MyConfig.pm
