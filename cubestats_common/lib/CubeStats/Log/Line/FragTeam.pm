# Declare our package
package CubeStats::Log::Line::FragTeam;

# import the Moose stuff
use Moose;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

extends 'CubeStats::Log::Line::Frag';

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::FragTeam - Describes the FragTeam event in a CSN log line

=head1 ABSTRACT

Describes the FragTeam in a CSN log line

=head1 DESCRIPTION

This module holds the "FragTeam" event data from a CSN log line. Normally, you would not use this class directly
but via the L<CubeStats::Log::Line> class.

This line is emitted when a player frags someone on the same team. ( TK )

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
