# Declare our package
package CubeStats::Log::Line::LoadMapRotMap;

# import the Moose stuff
use Moose;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.01';

extends 'CubeStats::Log::Line::Base';

has 'map' => (
	isa		=> 'Str',
	is		=> 'ro',
	required	=> 1,
);

has 'minutes' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'vote' => (
	isa		=> 'Bool',
	is		=> 'ro',
	required	=> 1,
);

has 'minplayers' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'maxplayers' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

has 'skiplines' => (
	isa		=> 'Int',
	is		=> 'ro',
	required	=> 1,
);

sub BUILDARGS {
	my $class = shift;
	my $args = shift;

	# We transform the data key to our own stuff
	my $data = delete $args->{'data'};
	if ( scalar @$data != 7 ) {
		die "Insufficient data";
	} else {
		# <logtype logver timestamp> LoadMapRotMap mapname mode minutes vote minplayer maxplayer skiplines
		$args->{'map'} = $data->[0];
		$args->{'mode'} = $data->[1];
		$args->{'minutes'} = $data->[2];
		$args->{'vote'} = $data->[3];
		$args->{'minplayers'} = $data->[4];
		$args->{'maxplayers'} = $data->[5];
		$args->{'skiplines'} = $data->[6];

		# all done!
		return $args;
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

CubeStats::Log::Line::LoadMapRotMap - Describes the LoadMapRotMap event in a CSN log line

=head1 ABSTRACT

Describes the LoadMapRotMap event in a CSN log line

=head1 DESCRIPTION

This module holds the "LoadMapRotMap" event data from a CSN log line. Normally, you would not use this class directly
but via the L<CubeStats::Log::Line> class.

This line is emitted when the server loads a line in the MapRot config

=head2 Attributes

Those attributes hold information about the event. As this class extends the L<CubeStats::Log::Line::Base>
class, you can also use it's attributes too.

=head3 map

The mapname specified by this object

=head3 minutes

The number of minutes the server should play

=head3 vote

A boolean value indicating if the users can vote on this maprot

=head3 minplayers

The minimum number of players to satisfy this map in the maprot

=head3 maxplayers

The maximum number of players to satisfy this map in the maprot

=head3 skiplines

The number of lines we should skip in the maprot when we finish this map

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

Props goes to the BS clan for the support!

This project is sponsored by L<http://cubestats.net>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
