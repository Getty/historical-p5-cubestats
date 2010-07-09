#!/usr/bin/perl
use strict; use warnings;

# load our stuff
use Archive::Zip qw( :ERROR_CODES );

# remove the old archive if it exists
if ( -f 'ac_server' ) {
	unlink 'ac_server' or die 'unable to remove old PAR';
}

# make the PAR archive
my $status = system( 'pp', '--lib', 'perl/lib/', '-M', 'CubeStats::Server', '-o', 'ac_server', 'perl/lib/CubeStats/Server.pm' );
die "unable to make PAR: $?" if $status != 0;

# clean it up!
my $zip = Archive::Zip->new;
if ( $zip->read( 'ac_server' ) != AZ_OK ) {
	die "unable to load PAR file";
}

# our list of hated dependencies
my @baddeps = qw( Tk Wx Gtk Glib Prima EV Event_Lib Event );
foreach my $bad ( @baddeps ) {
	foreach my $path ( qw( lib lib/auto lib/POE/Loop ) ) {
		# get rid of those members
		foreach my $m ( $zip->membersMatching( $path . '/' . $bad . '.*' ) ) {
			$zip->removeMember( $m ) or die "unable to remove member: " . $m->fileName;
		}
	}
}

# re-write the zip!
if ( $zip->overwrite() != AZ_OK ) {
	die "unable to overwrite PAR file";
}

# make it executable
chmod( oct( '755' ), 'ac_server' ) or die "unable to chmod PAR: $!";
