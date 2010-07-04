# Declare our package
package CubeStats::Server::Plugins::ClanList;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use Net::CIDR::Lite;
use Net::IP::Match::Regexp qw( create_iprange_regexp );

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has file => ( isa => 'Str', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return $self->server->serverroot . '/config/bs_memberlist.cfg' } );
has file_ts => ( isa => 'Int', is => 'rw',
	default => 0 );

sub BUILDARGS {
	my $class = shift;

	# Normally, we would be created by CubeStats::Server and contain 1 arg
	if ( @_ == 1 && ref $_[0] ) {
		if ( ref( $_[0] ) eq 'CubeStats::Server' ) {
			return {
				server	=> $_[0],
			};
		} else {
			die "unknown arguments";
		}
	} else {
		return $class->SUPER::BUILDARGS(@_);
	}
}

sub STARTALL {
	my $self = shift;

	$self->server->info( "in STARTALL" );

	# okay, fire up the server!
	$poe_kernel->yield( 'watch_bs_clanlist' );

	return;
}

event '_child' => sub {
	return;
};

event '_parent' => sub {
	return;
};

sub STOPALL {
	my $self = shift;

	$self->server->info( "in STOPALL" );

	return;
}

my $clanlist_printedwarning = 0;

event watch_bs_clanlist => sub{
	my $self = shift;

	my $file = $self->file;

	if ( -e $file ) {
		my $mtime = ( stat( _ ) )[9];
		if ( $mtime > $self->file_ts ) {
			# load it in!
			$self->server->debug( "reloading clanlist file: $file" );
			$self->file_ts( $mtime );
			open( my $fh, '<', $file );
			if ( defined $fh ) {
				my @data = <$fh>;
				close( $fh );
				%{ $self->server->bs_clanlist } = ();

				foreach my $l ( @data ) {
					chomp $l;
					next if length( $l ) == 0;
					next if $l =~ /^\s?\#/;

					# does this nick have IP protection?
					if ( $l =~ /^([^\s+]+)\s+(.+)$/ ) {
						my( $nick, $ip ) = ( lc( $1 ), $2 );
						$ip = [ split( ' ', $ip ) ];

						# convert ip data
						my $cidr = Net::CIDR::Lite->new;
						foreach my $i ( @$ip ) {
							# skip bad stuff
							next if $i !~ /^[\d\-\/\.]+$/;

							eval {
								$cidr->add_any( $i );
							};
							if ( $@ ) {
								$self->server->info( "bad line in clanlist file: '$l' -> '$i' error($@)" );
								next;
							}
						}
						my $list = $cidr->list;
						if ( scalar @$list ) {
							eval {
								$self->server->bs_clanlist->{ $nick } = create_iprange_regexp( @$list );
							};
							if ( $@ ) {
								$self->server->info( "unable to create regexp for '$l' => $@" );
								$self->server->bs_clanlist->{ $nick } = undef;
							}
						} else {
							$self->server->bs_clanlist->{ $nick } = undef;
						}
					} else {
						$self->server->bs_clanlist->{ lc( $l ) } = undef;
					}
				}

				# load the "defaults"
				$self->server->bs_clanlist->{getler} = undef if not exists $self->server->bs_clanlist->{getler};
				$self->server->bs_clanlist->{apocalypse} = undef if not exists $self->server->bs_clanlist->{apocalypse};

				$self->server->info( "reloaded '$file' with " . scalar( keys %{ $self->server->bs_clanlist } ) . " Nicks" );
			} else {
				$self->server->info( "unable to open clanlist file: $!" );
			}
		}
	} else {
		# reset to empty, for security
		if ( $clanlist_printedwarning++ == 0 ) {
			$self->server->debug( "clanlist config(" . $self->file . ") not found" );
		}
		%{ $self->server->bs_clanlist } = ();

		# load the "defaults"
		$self->server->bs_clanlist->{getler} = undef;
		$self->server->bs_clanlist->{apocalypse} = undef;
	}

	# recheck every minute
	$poe_kernel->delay( 'watch_bs_clanlist' => 60 );

	return;
};

sub shutdown {
	my $self = shift;
	$poe_kernel->post( $self->get_session_id, 'SHUTDOWN' );

	return;
}

event 'SHUTDOWN' => sub {
	my $self = shift;

	$self->server->info( "shutting down..." );

	$poe_kernel->alarm_remove_all;

	return;
};

# from Moose::Manual::BestPractices
no MooseX::POE;
__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME
