# the generic ID role
package CubeStats::Log::Line::Base::Player_ID;
use Moose::Role;

has 'id' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

1;
__END__
=head1 NAME

CubeStats::Log::Line::Base::Player_ID - The Player ID role for subclasses

=head1 ABSTRACT

This module provides the Player ID role for subclasses.

=head1 DESCRIPTION

This module provides the Player ID role for subclasses. This is the CSN-specific ID per player.

=head2 Attributes

Those attributes are part of the role, and will be applied to subclasses that use this.

=head3 id

The player's ID

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
