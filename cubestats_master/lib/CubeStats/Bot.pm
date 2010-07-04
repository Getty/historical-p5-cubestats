package CubeStats::Bot;
our $VERSION = '0.1';

use Moses;
use Data::Dumper;

use POE qw(
	Component::IRC::Plugin::Console
	Component::IRC::Plugin::Trac::RSS
);

nickname 'CSN';

ircname 'http://battlecube.org/wiki/CubeStatsNet/Csn';

sub default_channels {
	my $self = shift;
	my @chans;
	if ($self->cubestats) {
		push @chans, $self->cubestats;
	}
	if ($self->roc) {
		push @chans, $self->roc;
	}
	if ($self->battlecube) {
		push @chans, $self->battlecube;
	}
	return \@chans;
}

sub default_owner { 'Getty!torsten@cubestats.net' };

has control => (
	isa => 'CubeStats::Bot::Control',
	is => 'ro',
	required => 1,
);

has name => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has roc => (
	isa => 'Str',
	is => 'ro',
	default => sub { '' },
);

has battlecube => (
	isa => 'Str',
	is => 'ro',
	default => sub { '' },
);

has cubestats => (
	isa => 'Str',
	is => 'ro',
	default => sub { '#cubestats' },
);

has battlecube_rss => (
	isa => 'Bool',
	is => 'ro',
	default => sub { 0 },
);

has battlecube_rss_url => (
	isa => 'Str',
	is => 'rw',
	default => sub {
		'http://battlecube.org/timeline?blog=on&discussion=on&wiki=on&pastebin=on&ticket=on&changeset=on&milestone=on&max=5&daysback=90&format=rss'
	},
);

has battlecube_rss_latest => (
	isa => 'Str',
	is => 'rw',
	default => sub { '' },
);

has bindport => (
	isa => 'Int',
	is => 'ro',
);

sub custom_plugins {
	my $self = shift;
	my %plugins;
	if ($self->battlecube_rss) {
		$plugins{'TracRSS'} = 'POE::Component::IRC::Plugin::Trac::RSS',
	}
	if ($self->bindport) {
		$plugins{'Console'} = POE::Component::IRC::Plugin::Console->new(
			bindport => $self->bindport, password => 'luckyfotze'
		);
	}
	return \%plugins;
}

sub BUILD {
	my $self = shift;
	$self->control->set_bot($self->name, $self);
}

event irc_tracrss_items => sub {
	my ( $self, $sender, $args ) = @_[ OBJECT, SENDER, ARG0 ];
	my $newest = '';
	my @newrss;
	for my $rss (@_[ARG1..$#_]) {
		my $rss_string = join(' ', $rss);
		$newest = $rss_string if !$newest;
		if ($rss_string eq $self->battlecube_rss_latest) {
			last;
		}
		push @newrss, $rss_string;
	}
	$self->battlecube_rss_latest($newest);
	for my $rss_string (reverse @newrss) {
		$self->control->new_battlecube_rss($rss_string);
	}
};

event irc_tracrss_error => sub {
	my ( $self, $error ) = @_[ OBJECT, ARG1 ];
	$self->error("irc_tracrss_error $error");
};

event irc_001 => sub {
	my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
	if ($self->battlecube_rss) {
		$kernel->delay( 'trac_battlecube_rss' => 30 );
	}
};

event irc_join => sub {
	my ( $kernel, $sender, $nickstr, $chan, $self ) = @_[ KERNEL, SENDER, ARG0, ARG1, OBJECT ];
	$self->control->join($self, $nickstr, $chan);
};

event trac_battlecube_rss => sub {
	my ( $kernel, $sender, $self ) = @_[ KERNEL, SENDER, OBJECT ];
	$kernel->yield( 'get_tracrss', { url => $self->battlecube_rss_url } );
	$kernel->delay( 'trac_battlecube_rss' => 120 );
};

event irc_msg => sub {
	my ( $self, $nickstr, $text ) = @_[ OBJECT, ARG0, ARG2 ];
	my ($nick) = split /!/, $nickstr;
	$self->control->msg($self, $nick, $text);
};

event irc_kick => sub {
	my ( $self, $kickerstr, $chan, $nick, $text ) = @_[ OBJECT, ARG0, ARG1, ARG2, ARG3 ];
	my ( $kicker ) = split /!/, $kickerstr;
	$self->control->kick($self, $kicker, $chan, $nick, $text);
};

event irc_public => sub {
	my ( $self, $nickstr, $chans, $text ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	my ($nick) = split /!/, $nickstr;
	$self->control->pubmsg($self, $nick, $chans, $text);
};

event irc_nick => sub {
	my ( $self, $nickstr, $newnick ) = @_[ OBJECT, ARG0, ARG1 ];
	my ($nick) = split /!/, $nickstr;
	$self->control->nick($self, $nick, $newnick);
};

event irc_part => sub {
	my ( $self, $nickstr, $chan, $text ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	my ($nick) = split /!/, $nickstr;
	$self->control->part($self, $nick, $chan, $text);
};

event irc_quit => sub {
	my ( $self, $nickstr, $text ) = @_[ OBJECT, ARG0, ARG1 ];
	my ($nick) = split /!/, $nickstr;
	$self->control->quit($self, $nick, $text);
};

event irc_ctcp_action => sub {
	my ( $self, $nickstr, $chans, $text ) = @_[ OBJECT, ARG0, ARG1, ARG2 ];
	my ($nick) = split /!/, $nickstr;
	$self->control->action($self, $nick, $chans, $text);
};

no Moses;
1;
__END__

