package CubeStats::Web::Page::Register;

use CubeStats;
extends 'CubeStats::Web::Page';

use CubeStats::Web::Form::Register;

with qw(
	CubeStats::Role::Database
);

sub content_template { 'register.tpl' }

sub exec {

	my $self = shift;

	my $formfu = $self->newformfu('register');

	if ( $formfu->submitted_and_valid ) {
		my $form = new CubeStats::Web::Form::Register($formfu->params);
		$form->dbsave;
		$self->assign('result',$formfu->params);
	} else {
		$self->assign('form',$formfu);
	}

}

__PACKAGE__->meta->make_immutable;

1;
