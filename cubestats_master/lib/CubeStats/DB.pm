package CubeStats::DB;

use CubeStats;
use Data::Dumper;
use MooseX::Attribute::ENV;
use CubeStats::DB::InsertHash;
use DBI;

# caching for our selects :)
use Digest::SHA qw( sha256_base64 );	# do we need 512? ahaha
use Cache::File;
use Storable qw( nfreeze thaw );

my $_dbh;
my $cache;

has dbh => (
	isa => 'DBI::db',
	is => 'rw',
);

has dsn => (
	isa => 'Str',
	is => 'rw',
);

has db => (
	isa => 'Str',
	is => 'rw',
	traits => ['ENV'],
	env_key => 'CUBESTATS_DB',
	default => sub { 'cubestats' },
);

has db_driver => (
	isa => 'Str',
	is => 'rw',
	traits => ['ENV'],
	env_key => 'CUBESTATS_DB_DRIVER',
	default => sub { 'DBI:mysql' },
);

has db_host => (
	isa => 'Str',
	is => 'rw',
	traits => ['ENV'],
	env_key => 'CUBESTATS_DB_HOST',
	default => sub { 'localhost' },
);

has db_user => (
	isa => 'Str',
	is => 'rw',
	traits => ['ENV'],
	env_key => 'CUBESTATS_DB_USER',
	default => sub { 'cubestats' },
);

has db_pass => (
	isa => 'Str',
	is => 'rw',
	traits => ['ENV'],
	env_key => 'CUBESTATS_DB_PASS',
	default => sub { 'cubestats' },
);

sub BUILD {
	my $self = shift;
	$cache = Cache::File->new(
		cache_root		=> '/tmp/' . ( defined $ENV{SERVER_NAME} ? $ENV{SERVER_NAME} : 'dev' ) . '-cache',
		size_limit		=> 1024 * 1024 * 10,	# in bytes...
		removal_strategy	=> 'Cache::RemovalStrategy::LRU',
		lock_level		=> Cache::File::LOCK_LOCAL(),
	) if !$cache;
	$self->dsn(
		$self->db_driver.':'.
		'database='.$self->db.':'.
		'host='.$self->db_host
	);
	if (!$_dbh) {
		$_dbh = DBI::->connect(
			$self->dsn,
			$self->db_user,
			$self->db_pass,
			{ 'RaiseError' => 1, 'AutoCommit' => 1 }
		) or die $DBI::err.": ".$DBI::errstr;
	}
	$self->dbh($_dbh);
}

sub insert {
	my $self = shift;
	my $table = shift;
	my $hash = shift;
	my $delayed = shift;
	return CubeStats::DB::InsertHash->insert($hash,$table,$self->dbh,$delayed);
}

sub update {
	my $self = shift;
	my $table = shift;
	my $id = shift;
	my $hash = shift;
	return CubeStats::DB::InsertHash->update($hash,[$id],'ID = ?',$table,$self->dbh);
}

sub execute {
	my $self = shift;
	my $query = shift;
	my $sth = $self->dbh->prepare($query);
	return $sth->execute(@_);
}

sub select_cached {
	my $self = shift;
	my $ttl = shift;
	my $query = shift;

	# ttl < 0 means don't cache
	# ttl == 0 means cache forever
	# ttl > 0 means seconds to cache
	if ( $ttl < 0 ) {
		return $self->execute( $query, @_ );
	}

	# check for cached version?
	my $query_hashed = sha256_base64( $query, @_ );
	my $cached = $cache->get( $query_hashed );
	if ( ! defined $cached ) {
		my @result = $self->select($query, @_);
		# store it in the cache!
		$cache->set( $query_hashed, nfreeze( \@result ), $ttl != 0 ? "$ttl sec" : "never" );
		return @result;
	} else {
		return @{ thaw( $cached ) };
	}
}

sub select {
	my $self = shift;
	my $query = shift;
	warn $query;
	my $sth = $self->dbh->prepare($query);
	$sth->execute(@_);
	my @result;
	while (my $hash = $sth->fetchrow_hashref) {
		push @result, $hash;
	}
	return @result;
}

sub selectref {
	my $self = shift;
	my @result = $self->select(@_);
	return \@result;
}

sub selectref_cached {
	my $self = shift;
	my @result = $self->select_cached( @_ );
	return \@result;
}

__PACKAGE__->meta->make_immutable;

1;
