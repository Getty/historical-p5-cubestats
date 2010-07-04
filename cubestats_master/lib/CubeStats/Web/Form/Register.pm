package CubeStats::Web::Form::Register;

use CubeStats;
use Digest::MD5 qw(md5_hex);
use CubeStats::Mail qw(sendmail);
use CubeStats::DB;

with qw(
	CubeStats::Role::Database::Table
);

sub db_table { 'User' }

has username => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'Username',
);

sub check_username {
	my $username = shift;
	my @users = CubeStats::DB->new->select("SELECT ID FROM User WHERE Username = ?",$username);
	if (@users) {
		return 0;
	}
	return 1;
}

has email => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'Email',
);

sub check_email {
	my $email = shift;
	my @emails = CubeStats::DB->new->select("SELECT ID FROM User WHERE Email = ?",$email);
	if (@emails) {
		return 0;
	}
	return 1;
}

has emailtoken => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'EmailToken',
);

has country_id => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Int',
	db_col	=> 'Country_ID',
);

has password => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'Password',
);

before 'dbsave' => sub {
	my $self = shift;
	$self->emailtoken(md5_hex(rand(1000000)));
	my $token = $self->emailtoken;
	my $host = $ENV{SERVER_NAME};
	my $username = $self->username;
	my $email = $self->email;
	my $mailtext = <<"__MAIL__";
Hello $username,

Welcome to the CubeStats.Net Community, and thank you for registering. Right now we
do not have a list of all the features available for you on CubeStats.Net because
most of them are still in-development, however a list will be available shortly. But
first, please finish your registration!

To finish your registration please click on the link to confirm your email address. 
You will then be redirected to cubestats.net confirmation page, and there will be
display boxes for your username, token, and password.

http://$host/Login/?token=$token

Please then login to your account, using your username and password you just created. 

Once again, thank you for registering at CubeStats.Net!
__MAIL__
	sendmail('registration@cubestats.net',$email,'[CubeStats.Net] Welcome To The Community '.$username,$mailtext);
};

1;
