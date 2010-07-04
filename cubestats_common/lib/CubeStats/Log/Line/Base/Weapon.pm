# the weapon info role
package CubeStats::Log::Line::Base::Weapon;
use Moose::Role;

use Games::AssaultCube::Utils qw( get_gun_name );

has 'gun' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'gun_name' => (
	isa		=> 'Str',
	is		=> 'ro',
	lazy		=> 1,
	default		=> sub {
		my $self = shift;
		return get_gun_name( $self->gun );
	},
);

1;
__END__
=head1 NAME

CubeStats::Log::Line::Base::Weapon - The Weapon role for subclasses

=head1 ABSTRACT

This module provides the Weapon role for subclasses.

=head1 DESCRIPTION

This module provides the Weapon role for subclasses. This is the AssaultCube gun info.

=head2 Attributes

Those attributes are part of the role, and will be applied to subclasses that use this.

=head3 gun

The weapon's AssaultCube-specific ID

=head3 gun_name

The weapon's name ( SHOTGUN, SNIPER, etc )

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
