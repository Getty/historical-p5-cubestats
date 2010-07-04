# the generic position role
package CubeStats::Log::Line::Base::GamePosition;
use Moose::Role;

has 'pos_x' => (
	isa		=> 'Num',
	is		=> 'ro',
	required	=> 1,
);

has 'pos_y' => (
	isa		=> 'Num',
	is		=> 'ro',
	required	=> 1,
);

has 'pos_z' => (
	isa		=> 'Num',
	is		=> 'ro',
	required	=> 1,
);

1;
__END__
=head1 NAME

CubeStats::Log::Line::Base::GamePosition - The GamePosition role for subclasses

=head1 ABSTRACT

This module provides the GamePosition role for subclasses.

=head1 DESCRIPTION

This module provides the GamePosition role for subclasses. This is the x, y, z coordinates for events.

=head2 Attributes

Those attributes are part of the role, and will be applied to subclasses that use this.

=head3 pos_x

The X position of the event on the AssaultCube map

=head3 pos_y

The Y position of the event on the AssaultCube map

=head3 pos_z

The Z position of the event on the AssaultCube map

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
