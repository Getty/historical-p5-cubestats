# Build.PL
use strict; use warnings;
use inc::Module::Install;

name('CubeStats-Server');
version_from('lib/CubeStats/Server.pm');
license('perl');

requires('Carp');
requires('IO::File');
requires('Tie::Dir');
requires('Date::Format');
requires('MIME::Base64');
requires('Storable');
requires('List::Compare::Functional');
requires('Regexp::Assemble');
requires('Acme::LeetSpeak');
requires('File::Copy');
requires('Log::Dispatch::File');

requires('Net::CIDR::Lite');
requires('Net::IP::Match::Regexp');

# cubestats_common
requires('CubeStats');
requires('Games::AssaultCube');

# POE
requires('POE');
requires('POE::Session');
requires('POE::Wheel::Run');
requires('POE::Filter::Line');
requires('POE::Component::Client::HTTP');
requires('POE::Component::Server::SimpleHTTP');
requires('POE::Component::Server::SimpleContent');
requires('Socket');

# sugar for Getty ;)
requires('Moose');
requires('MooseX::POE');
requires('Moose::Exporter');
requires('MooseX::Getopt');
requires('MooseX::LogDispatch::Levels');
requires('MooseX::Attribute::ENV');
requires('MooseX::AttributeHelpers');
requires('MooseX::StrictConstructor');
requires('MooseX::POE::SweetArgs');
requires('MooseX::StrictConstructor');

# std perl stuff
requires('DateTime');
requires('Data::Dumper');
requires('File::Spec'); 
requires('File::Copy');
requires('XML::Simple');

# web stuff
requires('LWP::UserAgent');
requires('HTTP::Request');

# irc bot
requires('Adam');
requires('POE::Component::IRC::Plugin::AutoJoin');
requires('POE::Component::IRC::Plugin::Console');

auto_include();
auto_install();

&WriteAll(); 
