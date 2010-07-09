#!/bin/sh

LOCALLIB_VERSION=1.003002

#
# Checking for installed local-lib
#
if [ "${MODULEBUILDRC}" == "" ]; then
	#
	# re-download + install?
	#
	cd ${CUBESTATS_CACHE}
	if [ ! -f local-lib-${LOCALLIB_VERSION}.tar.gz ]; then
		wget -O local-lib-${LOCALLIB_VERSION}.tar.gz \
			http://search.cpan.org/CPAN/authors/id/A/AP/APEIRON/local-lib-${LOCALLIB_VERSION}.tar.gz
	fi

	tar xvzf local-lib-${LOCALLIB_VERSION}.tar.gz
	cd local-lib-${LOCALLIB_VERSION}

	perl Makefile.PL --bootstrap
	make test && \
	make install

	cd ${CUBESTATS_CACHE}
	rm -rf local-lib-${LOCALLIB_VERSION}

	echo You need to relogin
	exit 1

fi
