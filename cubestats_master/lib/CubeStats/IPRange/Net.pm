package CubeStats::IPRange::Net;

use CubeStats;
use Net::Whois::IANA;
use NetAddr::IP;
use Net::IP;

with qw(
	CubeStats::Role::Database::Table
);

sub db_table { 'IPRange_Net' }

has id => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Int',
	db_col  => 'ID',
);

has country_id => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Int',
	db_col  => 'Country_ID',
);

has netname => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Str',
	db_col  => 'Netname',
);

has fullinfo => (
	traits  => [qw/Database/],
	is              => 'rw',
	isa             => 'Str',
	db_col  => 'Fullinfo',
);

sub new_from_ip {
	shift; my $ip = shift;
	my $whois = new Net::Whois::IANA;
	$whois->whois_query(-ip=>$ip);
	my %vars;
	for my $var qw( netname fullinfo ) {
		$vars{$var} = $whois->$var;
	}
	if ($whois->country) {
		my @countries = CubeStats::DB->new->select("SELECT ID FROM Country WHERE ISO3166 = ?",$whois->country);
		if (@countries) {
			$vars{country_id} = $countries[0]->{ID};
		}
	}
	for my $cidr (@{$whois->cidr}) {
		my $range = NetAddr::IP::Lite->new($cidr)->range;
		if ($range =~ m/([\d\.]*) - ([\d\.]*)/) {
			print new Net::IP($1)->intip."\n";
			print new Net::IP($2)->intip."\n";
		}
		print $range."\n";
	}
	return new CubeStats::IPRange::Net(\%vars);
}

1;
