package CubeStats::IPRange;

with qw(
	CubeStats::Role::Database::Table
);

sub db_table { 'IPRange' }

has id => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Int',
	db_col  => 'ID',
);

has from_ip => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Int',
	db_col  => 'FromIP',
);

has to_ip => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Int',
	db_col  => 'ToIP',
);

has iprange_net_id => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Int',
	db_col  => 'IPRange_Net_ID',
);

1;
