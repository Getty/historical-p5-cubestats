# Build.PL
use strict; use warnings;
use inc::Module::Install;

name ('MooseX-DaemonController');
version_from ('lib/MooseX/DaemonController.pm');
license ('perl');

requires('Moose' => '0.73');
requires('Moose::Role');
requires('Moose::Exporter');
requires('MooseX::Daemonize');
requires('MooseX::Getopt');
requires('MooseX::LogDispatch::Levels');
requires('MooseX::Attribute::ENV');
requires('MooseX::AttributeHelpers');

# std perl stuff
requires('DateTime');
requires('Data::Dumper');
requires('XML::Simple');
requires('Module::Loaded');
requires('Storable');
requires('Struct::Compare');

auto_include();
auto_install();

&WriteAll(); 
