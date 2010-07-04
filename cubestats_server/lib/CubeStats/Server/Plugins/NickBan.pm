# Declare our package
package CubeStats::Server::Plugins::NickBan;

use CubeStats;
use MooseX::POE::SweetArgs;
use MooseX::StrictConstructor;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.02';

use Regexp::Assemble;
use Acme::LeetSpeak;

has 'server' => (
	isa		=> 'CubeStats::Server',
	is		=> 'ro',
	required	=> 1,
	weaken		=> 1,
);

has file => ( isa => 'Str', is => 'ro', lazy => 1,
	default => sub {
		my $self = shift;
		return $self->server->serverroot . '/config/banned_nicks.cfg' } );
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
	$poe_kernel->yield( 'watch_nickban' );

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

my $nickban_printedwarning = 0;

event watch_nickban => sub {
	my $self = shift;

	my $file = $self->file;

	if ( -e $file ) {
		my $mtime = ( stat( _ ) )[9];
		if ( $mtime > $self->file_ts ) {
			# load it in!
			$self->server->debug( "reloading nickban file: $file" );
			$self->file_ts( $mtime );
			open( my $fh, '<', $file );
			if ( defined $fh ) {
				my @data = <$fh>;
				close( $fh );
				$self->server->nickban( undef );

				my $regexp_assemble = Regexp::Assemble->new(
					flags	=> 'i',
					chomp	=> 0,
				);

				foreach my $l ( @data ) {
					chomp $l;
					next if length( $l ) == 0;
					next if $l =~ /^\s?\#/;

					# convert it into a regexp, and add it to the master
					$l =~ s/([^a-z])/quotemeta($1)/gei;
					$l =~ s/([a-z])/convert_char($1)/gei;
					eval { $regexp_assemble->add( $l ) };
					if ( $@ ) {
						$self->server->debug( "failure parsing $l: $@" );
					}
				}

				if ( $regexp_assemble->stats_add ) {
					eval { $self->server->nickban( $regexp_assemble->re ) };
					if ( $@ ) {
						$self->server->debug( "failure assembling nickban regexp: $@" );
						$self->server->nickban( undef );
					}
				}

				$self->server->info( "reloaded '$file' with " . ( defined $self->server->nickban ? $regexp_assemble->stats_add : 0 ) . " Nicks" );
			} else {
				$self->server->info( "unable to open nickban file: $!" );
			}
		}
	} else {
		# reset to empty, for security
		if ( $nickban_printedwarning++ == 0 ) {
			$self->server->debug( "nickban config(" . $self->file . ") not found" );
		}
		$self->server->nickban( undef );
	}

	# recheck every minute
	$poe_kernel->delay( 'watch_nickban' => 60 );

	return;
};

sub convert_char {
	my $char = shift;

	# okay, is this a char we have a mapping of?
	if ( exists $Acme::LeetSpeak::LEET_CHAR_MAP{ $char } ) {
		my $str;
		foreach my $map ( @{ $Acme::LeetSpeak::LEET_CHAR_MAP{ $char } } ) {
			if ( ! defined $str ) {
				$str = '(?i:' . quotemeta($map);
			} else {
				$str .= '|' . quotemeta($map);
			}
		}
		$str .= '|' . $char . ')+';
		return $str;
	} else {
		# just return it...
		return $char;
	}
}

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
