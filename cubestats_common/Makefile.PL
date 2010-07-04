# Build.PL
use strict; use warnings;
use inc::Module::Install;

name ('CubeStats');
version_from ('lib/CubeStats.pm');
license ('perl');

requires ('Carp');
requires ('IO::File');
requires ('Tie::Dir');
requires ('Date::Format');
requires ('MIME::Base64');

# sugar for Getty ;)
requires('Moose' => '0.73');	# need latest for sanity
requires('Moose::Role');
requires('Moose::Exporter');

# TODO: checking if these are really required
requires('MooseX::POE' => '0.201');	# need latest for sanity
requires('MooseX::Getopt');
requires('MooseX::LogDispatch::Levels');
requires('MooseX::Attribute::ENV');
requires('MooseX::AttributeHelpers');

# std perl stuff
requires('DateTime');
requires('Data::Dumper');
requires('File::Spec');
requires('File::Copy');
requires('Text::CSV_XS');

auto_include();
auto_install();

&WriteAll(); 
