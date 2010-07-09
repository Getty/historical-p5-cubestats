#!/bin/sh

LOCALLIB_VERSION=1.003001
CACHE="${HOME}/.cubestatsserver_cache"

cd ~

#
# Check for cache directory
#
if [ ! -d ${CACHE} ]; then
	mkdir ${CACHE}
fi

#
# enter cache
#
cd ${CACHE}

#
# re-download + install?
#
if [ ! -f local-lib-${LOCALLIB_VERSION}.tar.gz ]; then
	wget -O local-lib-${LOCALLIB_VERSION}.tar.gz \
		http://search.cpan.org/CPAN/authors/id/A/AP/APEIRON/local-lib-${LOCALLIB_VERSION}.tar.gz

	tar xvzf local-lib-${LOCALLIB_VERSION}.tar.gz
	cd local-lib-${LOCALLIB_VERSION}

	perl Makefile.PL --bootstrap
	make test && \
		make install && \
		echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc

	cd ${CACHE}
	rm -rf local-lib-${LOCALLIB_VERSION}
fi
