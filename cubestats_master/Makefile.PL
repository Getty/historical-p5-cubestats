# Build.PL
use strict; use warnings;
use inc::Module::Install;

name ('CubeStats-Master');
version_from ('lib/CubeStats/Web/MasterController.pm');
license ('perl');

requires ('Carp');
requires ('IO::File');
requires ('Tie::Dir');
requires ('Date::Format');
requires ('MIME::Base64');
requires ('Regexp::Common::net');

# for DB caching
requires('Digest::SHA');
requires('Cache::File');
requires('Storable');

# cubestats_common
requires('CubeStats');
requires('Games::AssaultCube');

# POE
requires('POE');
requires('POE::Session');
requires('POE::Wheel::Run');
requires('POE::Filter::Line');
requires('POE::Wheel::UDP');
requires('POE::Filter::Stream');

# removed some Moose requirements cause of CubeStats also include them (double handling)
requires('MooseX::POE');
requires('MooseX::Getopt');
requires('MooseX::LogDispatch::Levels');
requires('MooseX::Attribute::ENV');
requires('MooseX::AttributeHelpers');
requires('MooseX::Daemonize');
#requires('MooseX::StrictConstructor');

# std perl stuff
requires('DBI');
requires('DateTime');
requires('Data::Dumper');
requires('File::Copy');
requires('File::Find::Rule');
requires('File::Spec');
requires('File::Util');
requires('Module::Pluggable');
requires('Net::SSH2');
requires('Sys::Load');
requires('Text::CSV_XS');
requires('XML::Simple');

# web stuff
requires('LWP::UserAgent');
requires('HTTP::Request');
requires('CGI::Session');
requires('CGI::State');
requires('Template');
requires('HTML::FormFu');
requires('Email::Send');
requires('Template::Plugin::HTML::BBCode');
requires('CGI::Fast');
requires('Net::Whois::IANA');
requires('Net::IP');
requires('NetAddr::IP');
requires('NetAddr::IP::Util');
requires('Net::Netmask');

# irc bot
requires('Adam');
requires('POE::Component::IRC::Plugin::AutoJoin');
requires('POE::Component::IRC::Plugin::Console');
requires('POE::Component::IRC::Plugin::Trac::RSS');

auto_include();
auto_install();

&WriteAll(); 
