package CubeStats::AC::Log::Line;
our $VERSION = '0.1';

use CubeStats;
use DateTime;

with 'MooseX::LogDispatch::Levels';

has text => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has hash => (
	isa => 'HashRef',
	is => 'rw',
);

sub BUILD {
	my $self = shift;
	$self->parse_text;
}

sub create_logevent {
	my $self = shift;
	my $event = shift;
	my $hash = shift;
	$hash->{event} = $event;
	$self->hash($hash);
}

sub parse_text {
	my $self = shift;
	my $text = $self->text;
	return if (!$text);
	if ($text =~ m!^\[([\d\.]*)\] (.*)$!) {
		my $ip = $1;
		my $etext = $2;
		if ($ip) {
			if ($etext eq 'client connected') {
				return $self->create_logevent('ClientConnected',{
					ip => $ip,
				});
			} elsif ($etext =~ m!^disconnected client ([^ ]+)$!) {
				return $self->create_logevent('DisconnectedClient',{
					ip => $ip,
					nick => $1,
				});
			} elsif ($etext =~ m!^disconnecting client ([^ ]*) \([^\)]+\)$!) {
				return $self->create_logevent('DisconnectedClientWithReason',{
					ip => $ip,
					nick => $1,
					text => $2,
				});
			} elsif ($etext =~ m!^([^ ]+) fragged his teammate ([^ ]+)$!) {
				return $self->create_logevent('FraggedTeam',{
					nick => $1,
					victim_nick => $2,
					ip => $ip,
				});
			} elsif ($etext =~ m!^([^ ]+) gibbed his teammate ([^ ]+)$!) {
				return $self->create_logevent('GibbedTeam',{
					nick => $1,
					victim_nick => $2,
					ip => $ip,
				});
			} elsif ($etext =~ m!^([^ ]+) fragged ([^ ]+)$!) {
				return $self->create_logevent('Fragged',{
					nick => $1,
					victim_nick => $2,
					ip => $ip,
				});
			} elsif ($etext =~ m!^([^ ]+) gibbed ([^ ]+)$!) {
				return $self->create_logevent('Gibbed',{
					nick => $1,
					victim_nick => $2,
					ip => $ip,
				});
			} elsif ($etext =~ m!^([^ ]+) says: \'(.+)\'$!) {
				return $self->create_logevent('Says',{
					nick => $1,
					text => $2,
					ip => $ip,
				});
			} else {
				return $self->create_logevent('UnknownWithIP',{
					text => $etext,
					ip => $ip,
				});
			}
		} else {
			return $self->create_logevent('Unknown',{
				text => $text,
			});
		}
        } elsif ($text =~ m!^loaded map ([^,]+), (\d+) !) {
		return $self->create_logevent('LoadedMap',{
			map => $1,
			bytes => $2,
		});
        } elsif ($text =~ m!^Game status: (.+) on ([^,]+), (\d+) [^,]+, (\w+)!) {
		return $self->create_logevent('GameStatus',{
			mode => $1,
			map => $2,
			minutes => $3,
			mastermode => $self->get_mastermode($4),
		});
        } elsif ($text =~ m!^Game status: (.+) on ([^,]+), game finished, (\w+)!) {
		return $self->create_logevent('GameStatus',{
			mode => $1,
			map => $2,
			minutes => 0,
			mastermode => $self->get_mastermode($3),
			finished => 1,
		});
	} elsif ($text =~ m!^Game start: (.+) on ([^,]+), (\d+) [^,]+, (\d+) [^,]+, mastermode (\d)!) {
		return $self->create_logevent('GameStart',{
			mode => $1,
			map => $2,
			clientcount => $3,
			minutes => $4,
			mastermode => $5,
		});
        } elsif ($text =~ m!^read (\d+) \((\d+)\) blacklist entries from (.+)$!) {
		return $self->create_logevent('BlacklistEntries',{
			blacklistcount => $1,
			blacklistcount_secondary => $2,
			configfile => $3,
		});
        } elsif ($text =~ m!^read (\d*) admin passwords from (.*)$!) {
		return $self->create_logevent('AdminPasswords',{
			adminpasswordcount => $1,
			configfile => $2,
		});
        } elsif ($text =~ m!^sending request to masterserver.cubers.net...!) {
		return $self->create_logevent('MasterserverRequest',{});
        } elsif ($text =~ m!^masterserver reply: (.*)$!) {
		return $self->create_logevent('MasterserverReply',{
			text => $1,
		});
        } elsif ($text =~ m!^Status at (\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+): (\d+) remote clients, ([\d\.]+) send, ([\d\.]+) rec!) {
		my $datetime = new DateTime(
			year	=> $3,
			month	=> $2,
			day	=> $1,
			hour	=> $4,
			minute	=> $5,
			second	=> $6,
		);
		return $self->create_logevent('Status',{
			datetime => $datetime,
			clientcount => $7,
			send => $8,
			rec => $9,
		});
	} elsif ($text =~ m!^ *(\d+) ([^ ]+) +(\w+) +(\d+) +(\d+) +(\w+) +([\d\.]+)!) {
		my $ip = $7;
		return $self->create_logevent('ClientStatus',{
			cn => $1,
			nick => $2,
			team => $self->get_team($3),
			frags => $4,
			death => $5,
			role => $self->get_role($6),
			ip => $ip,
		});
	} elsif ($text =~ m!^ *(\d+) ([^ ]+) +(\d+) +(\d+) +(\w+) +([\d\.]+)!) {
		my $ip = $6;
		return $self->create_logevent('ClientStatus',{
			cn => $1,
			nick => $2,
			frags => $3,
			death => $4,
			role => $self->get_role($5),
			ip => $ip,
		});
	} else {
		return $self->create_logevent('Unknown',{
			text => $text,
		});
	}
}

sub get_team {
	my $self = shift;
	my $team = shift;
	if ($team eq 'CLA') {
		return 1;
	} elsif ($team eq 'RVSF') {
		return 2;
	}
	return 0;
}

sub get_role {
	my $self = shift;
	my $role = shift;
	if ($role eq 'admin') {
		return 1;
	}
	return 0;
}

sub get_mastermode {
	my $self = shift;
	my $mastermode = shift;
	if ($mastermode eq 'open') {
		return 0;
	}
	return 1;
}

__PACKAGE__->meta->make_immutable;

1;
