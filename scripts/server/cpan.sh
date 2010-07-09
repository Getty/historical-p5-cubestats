#!/bin/sh
#
# install Modules required for Makefile.PLs
#

# reload the index
perl -MCPAN -e "CPAN::Index->force_reload"

PERL_MM_USE_DEFAULT=1 perl -MCPAN -e "install Compress::Raw::Bzip2, Bundle::CPAN, CPAN::SQLite, CPAN, YAML::Tiny, inc::Module::Install, Class::MOP, Moose, MooseX::StrictConstructor, IO::Socket, LWP::UserAgent, HTTP::Request, DateTime"
