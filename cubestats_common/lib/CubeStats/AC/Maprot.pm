package CubeStats::AC::Maprot;

use CubeStats;
use CubeStats::AC::Maprot::Map;

has maps => (
	is => 'rw',
	isa => 'ArrayRef[CubeStats::AC::Maprot::Map]',
);

has filename => (
	is => 'rw',
	isa => 'Str',
);

sub load_file {
	my $self = shift;
	open(MAPROT, $self->filename) || die("Could not open file!");
	my @maplines=<MAPROT>;
	close(MAPROT);
	my @maps;
	for my $line (@maplines) {
		$line =~ s/[ \t\r\n]//g;
		next if !$line;
		next if ($line =~ /^\/\//);
		my @vars = split(':',$line);
		my %mapargs;
		$mapargs{map} = $vars[0];
		$mapargs{mode} = $vars[1];
		$mapargs{minutes} = $vars[2];
		$mapargs{allowvote} = $vars[3];
		$mapargs{minplayer} = $vars[4] if exists $vars[4];
		$mapargs{maxplayer} = $vars[5] if exists $vars[5];
		$mapargs{skiplines} = $vars[6] if exists $vars[6];
		push @maps, new CubeStats::AC::Maprot::Map(\%mapargs);
	}
	$self->maps(\@maps);
}

sub save_file {
	my $self = shift;
	my @maps = @{$self->maps};
	open(MAPROT, ">".$self->filename) || die("Could not open file!");
	for my $map (@maps) {
		my $maprow = $map->map.":".$map->mode.":".$map->minutes.":".$map->allowvote;
		if ($map->has_minplayer) {
			$maprow .= ":".$map->minplayer;
			if ($map->has_maxplayer) {
				$maprow .= ":".$map->maxplayer;
				if ($map->has_skiplines) {
					$maprow .= ":".$map->skiplines;
				}
			}
		}
		print MAPROT $maprow."\n";
	}
	print MAPROT "// ";
	print MAPROT rand(1000000);
	print MAPROT "\n";
	print MAPROT "// ";
	print MAPROT rand(1000000);
	print MAPROT "\n";
	close(MAPROT);
}

1;
