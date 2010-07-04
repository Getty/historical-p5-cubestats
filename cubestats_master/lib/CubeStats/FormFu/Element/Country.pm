package CubeStats::FormFu::Element::Country;

use CubeStats;

extends 'CubeStats::FormFu::Element::SQLSelect';

use Net::Whois::IANA;

sub default_element_sqllabel { "CONCAT('[',ISO3166,'] ',Name)" }
sub default_element_sqlvalue { 'ID' }
sub default_element_sqlwhere { 'Dead = 0' }
sub element_sqltable { 'Country' }

sub default {
	my $self = shift;
	my $whois = new Net::Whois::IANA;
	$whois->whois_query(-ip=>$ENV{REMOTE_ADDR});
	if ($whois->country) {
		my @countries = $self->db->select("SELECT ID FROM Country WHERE ISO3166 = ?",$whois->country);
		if (@countries) {
			return $countries[0]->{ID};
		}
	}
	return 254;
}

1;
