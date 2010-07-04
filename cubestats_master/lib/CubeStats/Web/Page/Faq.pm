package CubeStats::Web::Page::Faq;

use CubeStats;
extends 'CubeStats::Web::Page';

sub content_template { 'faq.tpl' }

with qw(
	CubeStats::Role::Database
);

sub exec {
	my $self = shift;

	if ($self->script && $self->session->param('user')->{Admin} == 1) {

		my @faq_categories = $self->db->select("
			SELECT ID, Name FROM FAQ_Category
		");

		$self->assign('faq_categories',\@faq_categories);

		my $faq_id = $self->script;
		my $question = $self->cgi->param('question');
		my $answer = $self->cgi->param('answer');
		my $sort = $self->cgi->param('sort');
		my $faq_category_id = $self->cgi->param('faq_category_id');
		my $save = $self->cgi->param('save');

		$self->assign('faq_id',$faq_id);

		if ($question && $answer && $faq_id) {
			my $data = {
				Question => $question,
				Answer => $answer,
				FAQ_Category_ID => $faq_category_id,
			};
			if ($faq_id eq 'new') {
				if ($self->db->insert('FAQ',$data)) {
					$self->assign('success',1);
				}
			} else {
				if ($self->db->update('FAQ',$faq_id,$data)) {
					$self->assign('success',1);
				}
			}
			$self->assign('question',$question);
			$self->assign('answer',$answer);
			$self->assign('sort',$sort);
			$self->assign('faq_category_id',$faq_category_id);
		} else {
			if ($faq_id ne 'new') {
				my ($faq) = $self->db->select("
					SELECT Question, Answer, FAQ_Category_ID, Sort FROM FAQ WHERE ID = ?
				",$faq_id);
				$self->assign('question',$faq->{Question});
				$self->assign('answer',$faq->{Answer});
				$self->assign('sort',$faq->{Sort});
				$self->assign('faq_category_id',$faq->{FAQ_Category_ID});
			}
		}

	} else {

		my @faqs = $self->db->select("
			SELECT FAQ.ID, FAQ.Question, FAQ.Answer, FAQ.Modified, FAQ_Category.Name AS Category_Name FROM FAQ
				INNER JOIN FAQ_Category ON FAQ.FAQ_Category_ID = FAQ_Category.ID
				ORDER BY FAQ_Category.Sort, FAQ.Sort
		");

		$self->assign('faqs',\@faqs);

	}

}

__PACKAGE__->meta->make_immutable;

1;
