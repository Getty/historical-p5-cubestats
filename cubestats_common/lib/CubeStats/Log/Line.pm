# Declare our package
package CubeStats::Log::Line;

# import the Moose stuff
use Moose;
use MooseX::StrictConstructor;

# We use a csv-style format for our data
use Text::CSV_XS;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

has 'csv' => (
	isa		=> 'Text::CSV_XS',
	is		=> 'ro',
	default		=> sub {
		# Instantitate the CSV parser for our usage
		return Text::CSV_XS->new( {
			sep_char	=> ' ',
			quote_char	=> "'",
		} );
	},
);

# CSN logs look like this: <AC $version $timestamp> $event @data
sub parse {
	my( $self, $line ) = @_;
	if ( substr( $line, 0, 3 ) ne '<AC' ) {
		return;
	} else {
		# yay, parse our own line!
		if ( $line =~ /^\<AC\s+(\d+)\s+(\d+)\>\s+(\w+)\s+(.+)$/ ) {
			my( $logversion, $timestamp, $event ) = ( $1, $2, $3 );
			if( $self->csv->parse( $4 ) ) {
				my @data = $self->csv->fields();

				# Hand it off to the subclass!
				eval "require CubeStats::Log::Line::$event";
				if ( $@ ) {
					die "Unable to load our subclass: $@";
				}

				# create the object!
				return "CubeStats::Log::Line::$event"->new( {
					line		=> $line,
					logversion	=> $logversion,
					timestamp	=> $timestamp,
					event		=> $event,
					data		=> \@data,
				} );
			} else {
				# Hmpf, our own prefix and yet failed to parse...
				die "Unable to parse line: $line";
			}
		} else {
			# unknown line...
			return;
		}
	}
}

# from Moose::Manual::BestPractices
no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line - Parses a CSN-style AssaultCube server log line

=head1 SYNOPSIS

	use Games::AssaultCube::Log::Line;
	use CubeStats::Log::Line;
	my $csnlog = CubeStats::Log::Line->new();
	open( my $fh, "<", "logfile.log" ) or die "Unable to open logfile: $!";
	while ( my $line = <$fh> ) {
		$line =~ s/(?:\n|\r)+//;
		next if ! length $line;
		my $log = Games::AssaultCube::Log::Line->new( $line, $csnlog );

		# play with the data
		print "LOG: " . $log->event . " happened\n";
	}
	close( $fh ) or die "Unable to close logfile: $!";

=head1 ABSTRACT

Parses a CSN-style AssaultCube server log line

=head1 DESCRIPTION

This module takes care of the "CSN" style extended logformat for the AssaultCube server. As usual, please
see the L<Games::AssaultCube::Log::Line> module for general usage of this class.

=head2 Constructor

The constructor accepts no options at this time.

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
