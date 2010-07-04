# Declare our package
package CubeStats::Log::Line::ClientError;

# import the Moose stuff
use Moose;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

extends 'CubeStats::Log::Line::Base';

with	'CubeStats::Log::Line::Base::Player_ID';

has 'errortype' => (
	isa		=> 'Str',
	is		=> 'ro',
	required	=> 1,
);

has 'error' => (
	isa		=> 'Str',
	is		=> 'ro',
	required	=> 1,
);

sub BUILDARGS {
	my $class = shift;
	my $args = shift;

	# We transform the data key to our own stuff
	my $data = delete $args->{'data'};
	if ( scalar @$data != 3 ) {
		die "Insufficient data";
	} else {
		# <logtype logver timestamp> event id errortype error
		$args->{'id'} = $data->[0];
		$args->{'errortype'} = $data->[1];
		$args->{'error'} = $data->[2];

		# all done!
		return $args;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::ClientError - Describes the ClientError event in a CSN log line

=head1 ABSTRACT

Describes the ClientError event in a CSN log line

=head1 DESCRIPTION

This module holds the "ClientError" event data from a CSN log line. Normally, you would not use this class directly
but via the L<CubeStats::Log::Line> class.

This line is emitted when a player tries to do something on the server that is an error.

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
