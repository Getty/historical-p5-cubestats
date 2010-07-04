# Declare our package
package CubeStats::Log::Line::Frag;

# import the Moose stuff
use Moose;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

extends 'CubeStats::Log::Line::Base';
use CubeStats::Log::Line::Base::Player;

with	'CubeStats::Log::Line::Base::Weapon';

has 'killer' => (
	isa		=> 'CubeStats::Log::Line::Base::Player',
	is		=> 'ro',
	required	=> 1,
);

has 'victim' => (
	isa		=> 'CubeStats::Log::Line::Base::Player',
	is		=> 'ro',
	required	=> 1,
);

has 'tk' => (
	isa		=> 'Bool',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		if ( $self->event =~ /Team$/ ) {
			return 1;
		} else {
			return 0;
		}
	},
);

has 'gib' => (
	isa		=> 'Bool',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		if ( $self->event =~ /^Gib/ ) {
			return 1;
		} else {
			return 0;
		}
	},
);

has 'score' => (
	isa		=> 'Int',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		if ( $self->tk ) {
			if ( $self->gib ) {
				return -2;
			} else {
				return -1;
			}
		} else {
			if ( $self->gib ) {
				return 2;
			} else {
				return 1;
			}
		}
	},
);

sub BUILDARGS {
	my $class = shift;
	my $args = shift;

	# We transform the data key to our own stuff
	my $data = delete $args->{'data'};
	if ( ! (scalar @$data == 6 or scalar @$data == 8 ) ) {
		die "Insufficient data";
	} else {
		# <logtype logver timestamp> event killer_id victim_id guntype "killer_hp/killer_armor" "killer_x killer_y killer_z" "victim_x victim_y victim_z" "killer_team_id" "victim_team_id"
		my @killer_life = split( '/', $data->[3] );
		my @killer_xyz = split( ' ', $data->[4] );
		my @victim_xyz = split( ' ', $data->[5] );

		# construct the killer/victim objects
		$args->{'killer'} = CubeStats::Log::Line::Base::Player->new( {
			id	=> $data->[0],
			hp	=> $killer_life[0],
			armor	=> $killer_life[1],
			pos_x	=> $killer_xyz[0],
			pos_y	=> $killer_xyz[1],
			pos_z	=> $killer_xyz[2],
			team	=> ( defined $data->[6] ? $data->[6] : 0 ),
		} );
		$args->{'victim'} = CubeStats::Log::Line::Base::Player->new( {
			id	=> $data->[1],
			pos_x	=> $victim_xyz[0],
			pos_y	=> $victim_xyz[1],
			pos_z	=> $victim_xyz[2],
			team	=> ( defined $data->[7] ? $data->[7] : 0 ),
		} );

		# rest of the data
		$args->{'gun'} = $data->[2];

		# all done!
		return $args;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::Frag - Describes the Frag event in a CSN log line

=head1 ABSTRACT

Describes the Frag event in a CSN log line

=head1 DESCRIPTION

This module holds the "Frag" event data from a CSN log line. Normally, you would not use this class directly
but via the L<CubeStats::Log::Line> class.

This line is emitted when a player frags someone on the other team or in a DM game.

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
