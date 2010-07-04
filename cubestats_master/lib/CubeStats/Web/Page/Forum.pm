package CubeStats::Web::Page::Forum;

use CubeStats;
extends 'CubeStats::Web::Page';

use CubeStats::Web::Form::Forumtopic;
use CubeStats::Web::Form::Forumcomment;

with qw(
    CubeStats::Role::Database
	CubeStats::Role::Web
);

has forum_template => (
	isa => 'Str',
	is => 'rw',
);

sub content_template {
	my $self = shift;
	return "forum/".$self->forum_template.".tpl";
}

sub exec {
	my $self = shift;

#	$self->assign('wide',1);

	my @script_parts = split('/',$self->script);

	my $category_id = shift @script_parts;
	my $topic_id = shift @script_parts;
	if ($topic_id eq 'New') {
		return $self->new_topic($category_id);
	}
	my $page_id = shift @script_parts;
	if ($page_id eq 'New') {
		return $self->new_comment($topic_id);
	}

	$page_id = 1 if !$page_id;

	if ($topic_id) {
		return $self->topic($topic_id,$page_id);
	} elsif ($category_id) {
		return $self->category($category_id);
	}

	return $self->forums();

}

sub forums {
	my $self = shift;
	$self->forum_template('forums');
	$self->assign('categories',$self->db->selectref("

	SELECT

	  Forum_Category.ID AS Forum_Category_ID,
	  Forum_Category.Name AS Forum_Category_Name,
	  Forum_Category.Modified AS Forum_Category_Modified,
	  Forum_Category.Description AS Forum_Category_Description,
	  Forum.Name AS Forum_Name,
	  COUNT(DISTINCT Forum_Category_Topic.ID) AS Forum_Category_Topic_Count,
	  COUNT(DISTINCT Forum_Category_Topic_Comment.ID) AS Forum_Category_Comment_Count

	  FROM       Forum_Category
	  INNER JOIN Forum ON Forum.ID = Forum_Category.Forum_ID
	  LEFT  JOIN Forum_Category_Topic ON Forum_Category.ID = Forum_Category_Topic.Forum_Category_ID
	  LEFT  JOIN Forum_Category_Topic_Comment ON Forum_Category_Topic.ID = Forum_Category_Topic_Comment.Forum_Category_Topic_ID
	  GROUP BY Forum_Category.ID
	  ORDER BY Forum.Sort, Forum_Category.Sort

	"));
}

sub load_category {
	my $self = shift;
	my $category_id = shift;
	my @categories = $self->db->select("
		SELECT
			Forum_Category.Name AS Forum_Category_Name,
			Forum_Category.ID AS Forum_Category_ID
		FROM Forum_Category
		WHERE ID = ?
	",$category_id);

	if (!@categories) {
		return;
	}

	$self->assign('category',$categories[0]);
}

sub category {
	my $self = shift;
	my $category_id = shift;
	$self->forum_template('category');
	$self->load_category($category_id);
	$self->assign('topics',$self->db->selectref("

	SELECT

	  Forum_Category_Topic.ID AS Forum_Category_Topic_ID,
	  Forum_Category_Topic.Name AS Forum_Category_Topic_Name,
	  Forum_Category_Topic.Modified AS Forum_Category_Topic_Modified,
	  Forum_Category_Topic.Description AS Forum_Category_Topic_Description,
	  COUNT(Forum_Category_Topic_Comment.ID) AS Forum_Category_Topic_Comment_Count,
	  User.ID AS User_ID,
	  User.Username AS Username,
	  Country.ISO3166 AS ISO3166

	  FROM       Forum_Category_Topic
	  INNER JOIN Forum_Category ON Forum_Category.ID = Forum_Category_Topic.Forum_Category_ID
	  INNER JOIN User ON User.ID = Forum_Category_Topic.User_ID
	  LEFT  JOIN Forum_Category_Topic_Comment ON Forum_Category_Topic.ID = Forum_Category_Topic_Comment.Forum_Category_Topic_ID
	  INNER JOIN Country ON User.Country_ID = Country.ID
	  WHERE Forum_Category_Topic.Forum_Category_ID = ?
	  GROUP BY Forum_Category_Topic.ID
	  ORDER BY Forum_Category_Topic.Modified DESC

	",$category_id));
}

sub new_topic {
	my $self = shift;
	my $category_id = shift;

	$self->assign('new_topic',1);

    my $formfu = $self->newformfu('forumtopic');
	$formfu->action($ENV{SCRIPT_NAME});

    if ( $formfu->submitted_and_valid ) {
		$self->assign('new_topic',0);
		my $params = $formfu->params;
		$params->{forum_category_id} = $category_id;
		$params->{user_id} = $self->session->param('user')->{ID};
        $self->assign('result',$params);
		my @topics = defined $self->session->param('new_topics') ? @{ $self->session->param('new_topics') } : ();
		if (grep $_ eq $params->{name}, @topics) {
			$self->assign('repost',1);
		} else {
	        my $form = new CubeStats::Web::Form::Forumtopic($params);
	        $form->dbsave;
			push @topics, $params->{name};
			$self->session->param('new_topics',\@topics);
		}
    } else {
        $self->assign('form',$formfu);
    }

	$self->category($category_id);

}

sub load_topic {
	my $self = shift;
	my $topic_id = shift;
	my @topics = $self->db->select("
		SELECT
			Forum_Category.Name AS Forum_Category_Name,
			Forum_Category.ID AS Forum_Category_ID,
			Forum_Category_Topic.ID AS Forum_Category_Topic_ID,
			Forum_Category_Topic.Name AS Forum_Category_Topic_Name,
			Forum_Category_Topic.Description AS Forum_Category_Topic_Description,
			Forum_Category_Topic.Modified AS Forum_Category_Topic_Modified,
			User.ID AS User_ID,
			User.Username AS Username,
			Country.ISO3166 AS ISO3166
		FROM Forum_Category_Topic
		INNER JOIN Forum_Category ON Forum_Category.ID = Forum_Category_Topic.Forum_Category_ID
		INNER JOIN User ON User.ID = Forum_Category_Topic.User_ID
		INNER JOIN Country ON User.Country_ID = Country.ID
		WHERE Forum_Category_Topic.ID = ?
	",$topic_id);

	if (!@topics) {
		return;
	}

	$self->assign('topic',$topics[0]);
}

sub topic {
	my $self = shift;
	my $topic_id = shift;
	$self->forum_template('topic');
	$self->load_topic($topic_id);
	$self->assign('comments',$self->db->selectref("

	SELECT

	  Forum_Category_Topic_Comment.ID AS Forum_Category_Topic_Comment_ID,
	  Forum_Category_Topic_Comment.Modified AS Forum_Category_Topic_Comment_Modified,
	  Forum_Category_Topic_Comment.Description AS Forum_Category_Topic_Comment_Description,
	  User.ID AS User_ID,
	  User.Username AS Username,
	  Country.ISO3166 AS ISO3166

	  FROM       Forum_Category_Topic_Comment
	  INNER JOIN User ON User.ID = Forum_Category_Topic_Comment.User_ID
	  INNER JOIN Country ON User.Country_ID = Country.ID
	  WHERE Forum_Category_Topic_Comment.Forum_Category_Topic_ID = ?
	  ORDER BY Forum_Category_Topic_Comment.Modified DESC

	",$topic_id));
}

sub new_comment {
	my $self = shift;
	my $topic_id = shift;

	$self->assign('new_comment',1);

    my $formfu = $self->newformfu('forumcomment');
	$formfu->action($ENV{SCRIPT_NAME});

    if ( $formfu->submitted_and_valid ) {
		my $params = $formfu->params;
		$self->assign('new_comment',0);
		$params->{forum_category_topic_id} = $topic_id;
		$params->{user_id} = $self->session->param('user')->{ID};
        $self->assign('result',$params);
		my @comments = defined $self->session->param('new_comments') ? @{ $self->session->param('new_comments') } : ();
		if (grep $_ eq $params->{description}, @comments) {
			$self->assign('repost',1);
		} else {
	        my $form = new CubeStats::Web::Form::Forumcomment($params);
	        $form->dbsave;
			push @comments, $params->{description};
	        $self->session->param('new_comments',\@comments);
		}
    } else {
        $self->assign('form',$formfu);
    }

	$self->topic($topic_id);

}

__PACKAGE__->meta->make_immutable;

1;
