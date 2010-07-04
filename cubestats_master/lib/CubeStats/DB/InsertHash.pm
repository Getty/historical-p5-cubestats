package CubeStats::DB::InsertHash;
$VERSION = 0.01;

use CubeStats;

use Carp qw(carp croak);

use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw(quote quote_char quote_func
                             dbh table where
                            ));
sub new {
    my ($class, %arg) = @_;
    $arg{quote_char} ||= '`';

    return $class->SUPER::new(\%arg);
}

sub insert {
    my ($self, $data, $table, $dbh, $delayed) = @_;

    # object defaults
    if (ref $self) {
        $table ||= $self->table;
        $dbh   ||= $self->dbh;
    }

    # warnings/errors
    unless (%$data) {
        carp 'No data (empty hash)';
        return;
    }
    croak 'No table name' unless $table;
    croak 'No DBI handle' unless $dbh;

    # sort by hash key (predictable results)
    my @column = sort keys %$data;
    my @value  = map { $data->{$_} } @column;

    # quote column names?
    if (ref $self and ($self->quote or $self->quote_func)) {
        foreach my $col (@column) {
            next unless $self->quote or $self->quote_func->($col);
            $col = $self->quote_char . $col . $self->quote_char;
        }
    }

    my $sql = 'INSERT ';
	$sql .= 'DELAYED ' if $delayed;
	$sql .= 'INTO '.$table.' (';
    $sql .= join(', ', @column).') VALUES (';
    $sql .= join(', ', ('?') x (scalar @column)).')';

	warn $sql;

    $dbh->do($sql, {}, @value);

    return $dbh->last_insert_id(undef, undef, $table, undef);
}

sub update {
    my ($self, $data, $vars, $where, $table, $dbh) = @_;
    my @vars = ($vars ? @$vars : ());

    # object defaults
    if (ref $self) {
        $where ||= $self->where;
        $table ||= $self->table;
        $dbh   ||= $self->dbh;
    }

    unless (%$data) {
        carp 'No data (empty hash)';
        return;
    }
    croak 'No where clause' unless $where;
    croak 'No table name'   unless $table;
    croak 'No DBI handle'   unless $dbh;

    # sort by hash key (predictable results)
    my @column = sort keys %$data;
    my @value  = map { $data->{$_} } @column;

    # quote column names?
    if (ref $self and ($self->quote or $self->quote_func)) {
        foreach my $col (@column) {
            next unless $self->quote or $self->quote_func->($col);
            $col = $self->quote_char . $col . $self->quote_char;
        }
    }

    my $sql = 'UPDATE '.$table.' SET ';
    $sql .= join(', ', map { "$_ = ?" } @column).' WHERE '.$where;

	warn $sql;

    return $dbh->do($sql, {}, @value, @vars);
}

1;
