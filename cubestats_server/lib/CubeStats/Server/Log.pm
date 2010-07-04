package CubeStats::Server::Log;

$|=0;

use CubeStats;
use CubeStats::Server::Log;
use Data::Dumper;
use File::Copy;

with 'MooseX::LogDispatch::Levels';

has file => (
	isa => 'Str',
	is => 'rw',
);

has no => (
	isa => 'Int',
	is => 'ro',
	required => 1,
);

has path => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

sub BUILD {
	my $self = shift;
	$self->file( 'csn.'.$self->no.'.'.$self->timestamp.'.log' );
}

sub write {
	my $self = shift;
	my $line = shift;
	my $fullfile = $self->path.'/'.$self->file;
	open my $fh, ">>", $fullfile or die("Could not open file ".$fullfile.": $!");
	print { $fh } $line."\n";
	close $fh;
}

sub mv {
	my $self = shift;
	my $path = shift;
	my $oldfile = $self->path.'/'.$self->file;
	my $newfile = $path.'/'.$self->file;
	move($oldfile, $newfile);
	$self->path($path);
}

1;
