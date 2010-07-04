package CubeStats::DB::Log;
our $VERSION = '0.1';

use CubeStats;
use CubeStats::DB;
use CubeStats::DB::Log::Game;
use CubeStats::AC::Log::Line;
use MooseX::AttributeHelpers;
use Data::Dumper;
use File::Spec;

with 'MooseX::Getopt';

has filename => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has id => (
	isa => 'Int',
	is => 'rw',
);

has last_linenumber => (
	isa => 'Str',
	is => 'rw',
	default => sub { 0 },
);

has db => (	
	isa => 'CubeStats::DB',
	is => 'rw',
	default => sub { new CubeStats::DB },
);

has current_game => (
	isa => 'Maybe[CubeStats::DB::Log::Game]',
	is => 'rw',
	clearer => 'clear_game',
);

has 'nicks' => (
	metaclass => 'Collection::Hash',
	is        => 'rw',
	isa       => 'HashRef[Int]',
	default   => sub { {} },
	provides  => {
		exists    => '_nick_has_id',
		keys      => '_get_nicks',
		get       => '_get_nick_id_by_nick',
		set       => '_set_nick_id',
	},
);

has have_game => ( isa => 'Bool', is => 'rw', default => sub { 0 } );
has finished_game => ( isa => 'Bool', is => 'rw', default => sub { 0 } );

sub BUILD {
	my $self = shift;
	my (undef,undef,$plainname) = File::Spec->splitpath( $self->filename );
	my ($log) = $self->db->select("SELECT * FROM Log WHERE Filename = ?",$plainname);
	if ($log) {
		$self->id($log->{ID});
		$self->last_linenumber($log->{Last_Linenumber});
	} else {
		$self->id($self->db->insert("Log",{
			Filename => $plainname,
		}));
	}
	open(LOG, $self->filename) or die("Could not open file ".$self->filename."!");
	my $line;
	while(<LOG>) {
		$line++;
		if ($line > $self->last_linenumber) {
			if (!$self->current_game) {
				$self->start_game;
			}
			chomp($_);
			$self->parse_logline($_);
			$self->last_linenumber($line);
		}
	}
	$self->finish_game;
	$self->save;
	close(LOG);
}

sub save {
	my $self = shift;
	$self->db->update("Log",$self->id,{
		Last_Linenumber => $self->last_linenumber,
	});
}

sub parse_logline {
	my $self = shift;
	my $line = shift;
	if (!$line && $self->finished_game) {
		$self->start_game;
	}
	return if (!$line);
	my $hash = CubeStats::AC::Log::Line->new({ text => $line })->hash;
	my $event = $hash->{event};
	if ($event eq 'GameStart') {
		if ($self->have_game) {
			$self->start_game;
		}
		$self->have_game(1);
	} elsif ($event eq 'GameStatus') {
		$self->have_game(1);
		if ($hash->{finished}) {
			$self->finished_game(1);
		}
	}
	if ($line =~ m!Game start: (.+) on ([^,]+), (\d+) [^,]+, (\d+) [^,]+, mastermode (\d)!) {
		$self->mapmode($2,$1);
	} elsif ($line =~ m!Game status: (.+) on ([^,]+), (\d+) [^,]+, (\w+)!) {
		$self->mapmode($2,$1);
	} elsif ($line =~ m!Game status: (.+) on ([^,]+), game finished, (\w+)!) {
		$self->mapmode($2,$1);
	} elsif ($line =~ m!([^ ]+) fragged his teammate ([^ ]+)!) {
		$self->frag($1,$2,1,0);
	} elsif ($line =~ m!([^ ]+) gibbed his teammate ([^ ]+)!) {
		$self->frag($1,$2,1,1);
	} elsif ($line =~ m!([^ ]+) fragged ([^ ]+)!) {
		$self->frag($1,$2,0,0);
	} elsif ($line =~ m!([^ ]+) gibbed ([^ ]+)!) {
		$self->frag($1,$2,0,1);
	}
	if ($event eq 'Status') {
		if ($hash->{clientcount} eq '0' && $self->have_game) {
			$self->start_game;
		}
	}
}

sub frag {
	my $self = shift;
	my $nick = shift;
	my $victim = shift;
	my $nick_id = $self->get_nick_id($nick);
	my $victim_id = $self->get_nick_id($victim);
	$self->current_game->frag($nick_id,$victim_id,@_);
}

sub get_nick_id {
	my $self = shift;
	my $nick = shift;
	if (!$self->_nick_has_id($nick)) {
		my $nick_id;
		my ($dbnick) = $self->db->select("SELECT * FROM Log_Nick WHERE Nick = ?",$nick);
		if ($dbnick) {
			$nick_id = $dbnick->{ID};
		} else {
			$nick_id = $self->db->insert("Log_Nick",{
				Nick => $nick,
			});
		}
		$self->_set_nick_id($nick,$nick_id);
	}
	$self->_get_nick_id_by_nick($nick);
}

sub finish_game {
	my $self = shift;
	if ($self->current_game) {
		$self->current_game->save;
		$self->clear_game;
	}
	$self->save;
}

sub start_game {
	my $self = shift;
	if ($self->current_game) {
		$self->finish_game;
	}
	$self->have_game(0);
	$self->finished_game(0);
	$self->current_game(new CubeStats::DB::Log::Game({
		log => $self,
	}));
}

sub mapmode {
	my $self = shift;
	my $map = shift;
	my $mode = shift;
	$self->current_game->map($map);
	$self->current_game->mode($mode);
}

sub run {
    $_[0]->new_with_options unless blessed $_[0];
}

__PACKAGE__->run unless caller;

1;
