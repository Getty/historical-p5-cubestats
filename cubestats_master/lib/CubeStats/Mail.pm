package CubeStats::Mail;

use CubeStats;

use Email::Send;

use Sub::Exporter
	-setup => { exports => [ qw(sendmail) ] };

sub sendmail {
	my $from = shift;
	my $to = shift;
	my $subject = shift;
	my $text = shift;
	my $header = <<"__HEADER__";
To: $to
From: $from
Subject: $subject
__HEADER__
	my $message = $header.$text;
	my $sender = Email::Send->new({ mailer => 'SMTP' });
	$sender->mailer_args([Host => 'mail']);
	return $sender->send($message);
}

1;
