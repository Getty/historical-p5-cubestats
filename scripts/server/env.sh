#
# inline script for setting up a cubestats environment
#

export CUBESTATS_DEPLOY="${HOME}/deploy_cubestats"
export CUBESTATS_ROOT="${HOME}/cubestats"
export CUBESTATS_CACHE="${HOME}/.cubestats_cache"

export ASSAULTCUBE_VERSION=1.0.2
export ASSAULTCUBE_VERSION_INT=1030
export ASSAULTCUBE_URL=http://heanet.dl.sourceforge.net/sourceforge/actiongame/AssaultCube_v${ASSAULTCUBE_VERSION}.tar.bz2
export ASSAULTCUBE_DIR=AssaultCube_v${ASSAULTCUBE_VERSION}

eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
