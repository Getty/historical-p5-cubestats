# The "player" object
package CubeStats::Log::Line::Base::Player;
use Moose;
use MooseX::StrictConstructor;

with	'CubeStats::Log::Line::Base::Player_ID',
	'CubeStats::Log::Line::Base::GamePosition',
	'Games::AssaultCube::Log::Line::Base::TeamInfo';

has 'hp' => (
	isa		=> 'Int',
	is		=> 'ro',
);

has 'armor' => (
	isa		=> 'Int',
	is		=> 'ro',
);

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::Base::Player - The Player object for subclasses

=head1 ABSTRACT

This module provides the Player object for subclasses.

=head1 DESCRIPTION

This module provides the Player object for subclasses. This is the player's information.

=head2 Attributes

Those attributes are part of the object.

=head3 id

The player's ID

=head3 hp

The player's hitpoints

=head3 armor

The player's armor

=head3 pos_x

The X position of the player on the AssaultCube map

=head3 pos_y

The Y position of the player on the AssaultCube map

=head3 pos_z

The Z position of the player on the AssaultCube map

=head3 team

The team id of the player ( defaults to 0 )

=head3 team_name

The team name of the player ( defaults to 0 -> CLA )

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
