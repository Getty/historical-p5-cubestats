#!/usr/bin/perl
use strict; use warnings;

# ARGV[0] is the serverroot
# ARGV[1] is the server binary
# rest of args is passed to the ac_server process
chdir( $ARGV[0] ) or die "unable to chdir: $!";
exec( $ARGV[1], @ARGV[ 2 .. $#ARGV ] ) or die "unable to launch ac_server: $!";
