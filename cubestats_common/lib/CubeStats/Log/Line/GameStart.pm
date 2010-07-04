# Declare our package
package CubeStats::Log::Line::GameStart;

# import the Moose stuff
use Moose;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

extends 'CubeStats::Log::Line::Base';

has 'map' => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has 'mode' => (
	is => 'ro',
	isa => 'Int',
	required => 1,
);

has 'minutes' => (
	is => 'ro',
	isa => 'Int',
	required => 1,
);

has 'mastermode' => (
	is => 'ro',
	isa => 'Int',
	required => 1,
);

has 'prepared' => (
	is => 'ro',
	isa => 'Int',
	required => 1,
);

sub BUILDARGS {
	my $class = shift;
	my $args = shift;

	# We transform the data key to our own stuff
	my $data = delete $args->{'data'};
	if ( scalar @$data != 5 ) {
		die "Insufficient data";
	} else {
		# <logtype logver timestamp>
		$args->{'map'} = $data->[0];
		$args->{'mode'} = $data->[1];
		$args->{'minutes'} = $data->[2];
		$args->{'mastermode'} = $data->[3];
		$args->{'prepared'} = $data->[4];

		# all done!
		return $args;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::GameStart

=head1 ABSTRACT


=head1 DESCRIPTION

This module holds the "GameStart" event data from a CSN log line. Normally, you would not use this class directly
but via the L<CubeStats::Log::Line> class.

=head2 Attributes

Those attributes hold information about the event. As this class extends the L<CubeStats::Log::Line::Base>
class, you can also use it's attributes too.

TODO

=head1 AUTHOR

Torsten Raudssus E<lt>torsten@raudssus.deE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Torsten Raudssus

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
