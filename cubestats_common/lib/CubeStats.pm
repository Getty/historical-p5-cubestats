package CubeStats;
our $VERSION = '0.2';

use Moose ();
use Moose::Exporter;
use Data::Dumper;
use CubeStats::Object;
use DateTime;
use Games::AssaultCube::Utils qw( default_port );

Moose::Exporter->setup_import_methods(
	with_caller => [qw(
		Dumper
		timestamp
		dump
		no2port
	)],
	also => [qw( Moose )],
);

sub no2port {
	shift; my $no = shift;
	return ( ( $no - 1 ) * 10 ) + default_port();
}

sub init_meta {
	shift;
	Moose->init_meta( @_, base_class => 'CubeStats::Object' );
}

sub timestamp {
	#my $dt = from_epoch DateTime( epoch => time );
	#return $dt->strftime('%Y%m%d_%H%M%S');

	# use GMT!
	my @data = gmtime;
	$data[4]++;		# increment month to 1..12 based
	$data[5] += 1900;	# we only get last 2 digits

	return sprintf( "%04d%02d%02d_%02d%02d%02d_GMT", @data[ 5, 4, 3, 2, 1, 0 ] );
}

sub dump {
	print Dumper \@_;
}

1;


