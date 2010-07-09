#!/bin/sh

cd ${CUBESTATS_DEPLOY}

# do the basic stuff in parallel

#
# Install g::ac
#
( cd assaultcube_perl && touch Makefile.PL && perl Build.PL && ./Build install && cd .. && rm -rf assaultcube_perl ) &

#
# Install adam-bot-framework
#
( cd adam-bot-framework && touch Makefile.PL && perl Makefile.PL && make install && cd .. && rm -rf adam-bot-framework ) &

#
# Install cubestats_common
#
( cd cubestats_common && touch Makefile.PL && perl Makefile.PL && make install && cd .. && rm -rf cubestats_common ) &

#
# Install moosex_daemoncontroller
#
( cd moosex_daemoncontroller && touch Makefile.PL && perl Makefile.PL && make install && cd .. && rm -rf moosex_daemoncontroller ) &

# now we have to wait until all 3 is done
wait

#
# Install cubestats_server
#
cd cubestats_server
perl ./Makefile.PL
make install
cd ..
rm -rf cubestats_server

