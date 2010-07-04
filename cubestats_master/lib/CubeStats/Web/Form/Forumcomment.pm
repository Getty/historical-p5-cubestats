package CubeStats::Web::Form::Forumcomment;

use CubeStats;

with qw(
	CubeStats::Role::Database::Table
);

sub db_table { 'Forum_Category_Topic_Comment' }
sub delayed { 1 }

has user_id => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Int',
	db_col	=> 'User_ID',
);

has forum_category_topic_id => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Int',
	db_col	=> 'Forum_Category_Topic_ID',
);

has description => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'Description',
);

after 'dbsave' => sub {
	my $self = shift;
	$self->db->update('Forum_Category_Topic',$self->forum_category_topic_id,{});
};

1;
