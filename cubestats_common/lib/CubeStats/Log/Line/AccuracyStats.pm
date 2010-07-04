# Declare our package
package CubeStats::Log::Line::AccuracyStats;

# import the Moose stuff
use Moose;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

use CubeStats::Log::Line::Base::WeaponStats;

extends 'CubeStats::Log::Line::Base';

with	'CubeStats::Log::Line::Base::Player_ID';

has 'weapons' => (
	isa		=> 'ArrayRef[CubeStats::Log::Line::Base::WeaponStats]',
	is		=> 'ro',
	default		=> sub { [] },
);

has 'total_accuracy' => (
	isa		=> 'Num',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		my( $total_hits, $total_misses );
		$total_hits = $total_misses = 0;
		foreach my $w ( @{ $self->weapons } ) {
			$total_hits += $w->hits;
			$total_misses += $w->misses;
		};
		return ( $total_hits / ( $total_hits + $total_misses ) ) * 100;
	},
);

sub BUILDARGS {
	my $class = shift;
	my $args = shift;

	# We transform the data key to our own stuff
	my $data = delete $args->{'data'};
	if ( scalar @$data < 2 ) {
		die "Insufficient data";
	} else {
		# <logtype logver timestamp> event id @weapdata
		$args->{'id'} = shift @$data;

		# weapdata is: 'id hits misses reloads'
		my @weapons;
		foreach my $w ( @$data ) {
			my @stats = split( ' ', $w );
			my $weapon = CubeStats::Log::Line::Base::WeaponStats->new({
				'gun'		=> $stats[0],
				'hits'		=> $stats[1],
				'misses'	=> $stats[2],
				'reloads'	=> $stats[3],
			});
			push( @weapons, $weapon );
		}
		$args->{'weapons'} = \@weapons;

		# all done!
		return $args;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::AccuracyStats - Describes the AccuracyStats event in a CSN log line

=head1 ABSTRACT

Describes the AccuracyStats event in a CSN log line

=head1 DESCRIPTION

This module holds the "AccuracyStats" event data from a CSN log line. Normally, you would not use this class directly
but via the L<CubeStats::Log::Line> class.

This line is emitted when a player disconnects, and the weapon stats is logged.

=head2 Attributes

Those attributes hold information about the event. As this class extends the L<CubeStats::Log::Line::Base>
class, you can also use it's attributes too.

TODO

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
