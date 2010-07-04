package CubeStats::Role::Database::Table;

use CubeStats::Role;

use CubeStats::Meta::Attribute::Trait::Database;

with qw(
	CubeStats::Role::Database
);

has id => (
	traits => [qw/Database/],
	isa => 'Int',
	is => 'rw',
	db_col => 'ID',
);

requires 'db_table';

sub dbsave {
	my $self = shift;
	my %hash;
	
	my %attributes = %{ $self->meta->get_attribute_map };
      
	for my $name ( sort keys %attributes ) {
		my $attribute = $attributes{$name};

		if ($attribute->does('CubeStats::Meta::Attribute::Trait::Database') && $attribute->has_db_col) {
			my $reader = $attribute->get_read_method;
			if ($attribute->has_value($self)) {
				$hash{$attribute->db_col} = $self->$reader;
			}
		}
	}

	if ($self->id) {
		$self->db->update($self->db_table,$self->id,\%hash);
	} else {
		$self->id(
			$self->db->insert($self->db_table,\%hash,$self->can('delayed'))
		);
	}

	return $self->id;
}

sub from_db_row {
	my $self = shift;
	my $row = shift;

	my %attributes = %{ $self->meta->get_attribute_map };
      
	for my $name ( sort keys %attributes ) {
		my $attribute = $attributes{$name};

		if ($attribute->does('CubeStats::Meta::Attribute::Trait::Database') && $attribute->has_db_col) {
			if ($row->{$attribute->db_col}) {
				my $writer = $attribute->get_write_method;
				$self->$writer($row->{$attribute->db_col});
			}
		}
	}
}

sub dbload {
	my $self = shift;
	my $id = shift;

	$self->id($id) if $id;

	my ($row) = $self->db->select("SELECT * FROM ".$self->db_table." WHERE ID = ?",$self->id);
	
	if ($row) {
		$self->from_db_row($row);
		return 1;
	}

	return 0;
}

no CubeStats::Role;

1;
