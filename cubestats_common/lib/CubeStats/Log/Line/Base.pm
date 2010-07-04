# Declare our package
package CubeStats::Log::Line::Base;

# import the Moose stuff
use Moose;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

# We extend the regular log stuff
extends 'Games::AssaultCube::Log::Line::Base';

# TODO improve validation for everything here, ha!

has 'logversion' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'timestamp' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'csn' => (
	isa		=> 'Bool',
	is		=> 'ro',
	default		=> 1,
);

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::Base - The base CSNLog line object

=head1 ABSTRACT

This module provides the base log line descriptions all other subclasses inherit from.

=head1 DESCRIPTION

This module provides the base log line descriptions all other subclasses inherit from.

=head2 Attributes

Those attributes are the "generic" ones you can access. Please see the subclasses for additional attributes
you can use.

=head3 line

The raw log line

=head3 logversion

The version of the CSN logformat

=head3 timestamp

The UNIX timestamp

=head3 event

The event specified by the line ( see subclasses for all possible event types )

=head3 csn

This accessor simply returns true. That way you can distinguish between our CSN log types and the regular
log types. Just do a $logline->can( 'csn' )

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
