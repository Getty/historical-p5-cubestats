# the "weapon stats" object
package CubeStats::Log::Line::Base::WeaponStats;
use Moose;
use MooseX::StrictConstructor;

use Games::AssaultCube::Utils qw( get_gun_name );

with	'CubeStats::Log::Line::Base::Weapon';

has 'hits' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'misses' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'reloads' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'accuracy' => (
	isa		=> 'Num',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		return ( $self->hits / $self->shots ) * 100;
	},
);

has 'shots' => (
	isa		=> 'Int',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		return $self->hits + $self->misses;
	},
);

sub BUILDARGS {
	my $class = shift;
	my $data = shift;

	# For some reason, AC "doubles" the number of misses for grenades...
	my $gun_name = get_gun_name( $data->{'gun'} );
	if ( defined $gun_name and $gun_name eq 'GRENADE' ) {
		$data->{'misses'} /= 2;

		# TODO verify that we don't need to /=2 for hits too!
	}
	return $data;
}

1;
__END__
=head1 NAME

CubeStats::Log::Line::Base::WeaponStats - The Weapon object for subclasses

=head1 ABSTRACT

This module provides the WeaponStats object for subclasses.

=head1 DESCRIPTION

This module provides the WeaponStats object for subclasses. This is the AssaultCube gun stats.

=head2 Attributes

Those attributes are part of the object.

=head3 gun

The weapon's AssaultCube-specific ID

=head3 gun_name

The weapon's name ( SHOTGUN, SNIPER, etc )

=head3 shots

The number of shots the player made

=head3 hits

The number of hits the player made

=head3 misses

The number of misses the player made

=head3 reloads

The number of reloads the player made

=head3 accuracy

The accuracy of the player wielding this weapon

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
