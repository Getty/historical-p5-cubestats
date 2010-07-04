package CubeStats::Role::Web;

use CubeStats::Role;
use CubeStats::Web::CGI;
use HTML::FormFu;

has cgi => (
	isa => 'CubeStats::Web::CGI',
	is => 'rw',
	required => 1,
);

sub session {
	my $self = shift;
	return $self->cgi->session;
}

sub state {
	my $self = shift;
	return $self->cgi->state;
}

sub tt {
	my $self = shift;
	return $self->cgi->tt;
}

sub newform {
	my $self = shift;
	my $form_name = shift;
	my $form_class = 'CubeStats::Web::Form::'.$form_name;
	eval 'use '.$form_class.';'; die $@ if $@;
	my $form = eval 'new '.$form_class.'(@_)'; die $@ if $@;
	return $form;
}

sub newformfu {
	my $self = shift;
	my $form_name = shift;
    my $form = HTML::FormFu->new;
	my $forms_dir = $ENV{'CUBESTATS_ROOT'}.'/forms';
	my $servername = $ENV{'SERVER_NAME'};
	$servername = 'svn.cubestats.net' if $servername == 'dev.cubestats.net';
	$forms_dir = '/home/acube/'.$servername.'/trunk/forms' if $servername ne 'cubestats.net';
    $form->load_config_file($forms_dir.'/'.$form_name.'.yml');
    $form->process($self->cgi->cgi);
	return $form;
}

1;
