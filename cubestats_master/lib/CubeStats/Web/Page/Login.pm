package CubeStats::Web::Page::Login;

use CubeStats;
extends 'CubeStats::Web::Page';
use Net::Netmask qw( quad2int );

sub content_template { 'login.tpl' }

with qw(
    CubeStats::Role::Database
);

sub exec {
	my $self = shift;

	my $user = $self->session->param('user');

	if ($user) {
		$self->assign('user',$user);
		$self->assign('username',$user->{Username});
		return;
	}

	my $username = $self->cgi->param('username');
	my $password = $self->cgi->param('password');
	my $token = $self->cgi->param('token');

	$self->assign('username',$username);

	if ($username and $password) {
		my $user;
		if ($token) {
			($user) = $self->db->select("SELECT * FROM User WHERE Username = ? AND Password = ? AND EmailToken = ?",$username,$password,$token);
		} else {
			($user) = $self->db->select("SELECT * FROM User WHERE Username = ? AND Password = ? AND EmailToken = ''",$username,$password);
		}
		if ($user) {
			$self->session->param('user',$user);
			if ($token) {
				$self->db->update('User',$user->{ID},{ EmailToken => '' });
			}
			$self->db->insert('User_IP',{
				IP => quad2int($ENV{REMOTE_ADDR}),
				User_ID => $user->{ID},
			});
			$self->assign('login_successful',1);
		} else {
			$self->assign('login_failed',1);
		}
	}

}

1;
