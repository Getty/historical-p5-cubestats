package CubeStats::Web::Form::Forumtopic;

use CubeStats;

with qw(
	CubeStats::Role::Database::Table
);

sub db_table { 'Forum_Category_Topic' }
sub delayed { 1 }

has user_id => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Int',
	db_col	=> 'User_ID',
);

has forum_category_id => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Int',
	db_col	=> 'Forum_Category_ID',
);

has name => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'Name',
);

has description => (
	traits	=> [qw/Database/],
	is		=> 'rw',
	isa		=> 'Str',
	db_col	=> 'Description',
);

after 'dbsave' => sub {
	my $self = shift;
	$self->db->update('Forum_Category',$self->forum_category_id,{});
};

1;
