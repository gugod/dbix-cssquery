package DBIx::CSSQuery;
use strict;
use 5.008;
use DBI ":sql_types";
use DBIx::CSSQuery::DB;

our $VERSION = '0.02';

use Sub::Exporter -setup => {
    exports => [qw(db)]
};

{
    my $db;
    sub db {
        my @args = @_;
        $db = DBIx::CSSQuery->new() if !$db;

        if (!$db->{db}) {
            $db->{db} = DBIx::CSSQuery::DB->new();
        }

        return $db->{db} if !@args;
        if ($args[0]) {
            $db->{selector} = $args[0];
        }
        return $db;
    }
}

use self;

sub new {
    return bless {
        sql_params => {
            order => "ORDER BY id ASC",
            limit => undef
        }
    }, $self;
}

sub get {
    my ($index) = @args;
    my $record;

    $self->each(
        sql_params => {
            limit => "$index,1"
        },
        callback => sub {
            $record = $_[0]
        }
    );

    return $record
}

sub size {
    my $parsed = _parse_css_selector($self->{selector});
    my ($sql, $values) = _build_select_sql_statement($parsed, {
        select => "count(*)"
    });
    my $dbh = $self->{db}->attr("dbh");

    my $sth = $dbh->prepare( $sql );
    for my $i (0 .. $#{$values} ) {
        my $v = $values->[$i];
        $sth->bind_param($i+1, $v->[0], $v->[1]);
    }

    $sth->execute;
    my $record = $sth->fetchrow_hashref;
    return $record->{'count(*)'};
}

sub last {
    $self->{sql_params}{order} =~ s/ASC/DESC/;
    $self->{sql_params}{limit} = "0,1";
    return $self;
}

sub each {
    my %params;
    if (@args == 0) {
        return $self;
    }

    if (ref($args[0]) eq 'CODE') {
        $params{callback}= $args[0];
    }
    else {
        %params = @args;
    }

    my $cb = $params{callback};
    return $self unless defined $cb;

    my $parsed = _parse_css_selector($self->{selector});

    for(keys %{$self->{sql_params}}) {
        $params{sql_params}{$_} = $self->{sql_params}{$_};
    }

    my ($sql, $values) = _build_select_sql_statement($parsed, $params{sql_params});

    my $dbh = $self->{db}->attr("dbh");

    my $sth = $dbh->prepare( $sql );

    for my $i (0 .. $#{$values} ) {
        my $v = $values->[$i];
        $sth->bind_param($i+1, $v->[0], $v->[1]);
    }

    $sth->execute;
    while (my $record = $sth->fetchrow_hashref) {
        $cb->($record);
    }

    return $self;
}

sub _build_select_sql_statement {
    my ($parsed, $params) = @_;

    my $p = $parsed->[0];

    my @values = ();

    my $from  = " FROM $p->{type} ";
    my $where = "";
    if ($p->{attribute} =~ m/ \[ (.+) = (.+) \] /x ) {
        $where = " WHERE ";
        my $field = $1;
        my $val = $2;

        $where .= "$field = ?";
        my $type = SQL_INTEGER;
        if ($val =~ /^'(.+)'$/) {
            $val = $1;
            $type = SQL_VARCHAR;
        }
        push @values, [$val, SQL_INTEGER];
    }

    $params = {} if !defined($params);
    my $limit = defined($params->{limit}) ? " LIMIT $params->{limit}" : "";

    my $select = "SELECT * ";
    $select = "SELECT $params->{'select'} " if $params->{'select'};

    my $order = "ORDER BY id ASC";
    $order = " " . $params->{'order'} if $params->{'order'};

    print "${select}${from} ${where} ${order} ${limit}\n";
    return "${select}${from} ${where} ${order} ${limit}", \@values;
}

sub _parse_css_selector {
    my $selector = shift;
    my @sel =
        map { _parse_simple_css_selector($_) }
        split(/ /, $selector);
    return \@sel;
}

sub _parse_simple_css_selector {
    my $selector = shift;
    my $word = qr/[_a-z0-9]+/o;
    my $parsed = {
        type => "",
        class => "",
        id => "",
        attribute => "",
        special => ""
    };

    $selector =~ m{^(\*|$word)};
    $parsed->{type} = $1;

    while ( $selector =~ m{
                              \G
                              ( \#$word ) |                # ID
                              ( (?:\[ .+ \] )+ ) |         # attribute
                              ( (?:\.$word  )+ ) |         # class names
                              ( (?::$word(?: \(.+\))?)+ )  # special
                      }gx) {
        $parsed->{id} .= $1 ||"";
        $parsed->{attribute} .= $2 ||"";
        $parsed->{class} .= $3 ||"";
        $parsed->{special} .= $4 ||"";
    }

    return $parsed;
}

1;
__END__

=head1 NAME

DBIx::CSSQuery - A Perl DBI extension module to let you fetch data with CSS query syntax.

=head1 VERSION

This document describes DBIx::CSSQuery version 0.0.1

=head1 SYNOPSIS

    use DBIx::CSSQuery;

    # setup
    db->attr(dbh => DBI->connect(...));


    # fetch all posts and do something with them
    db("posts")->each(sub {
        print $_[0]->{body};
    });

    # fetch one post as a hash
    my $post = db("posts[id=1]")->get(0);

=head1 DESCRIPTION


DBIx::CSSQuery is, currently, a proof of concept for what can be done
with CSS query. For example, here's how you retrieve a collection of
all records from table "posts":

    db("posts")

Also, here's how to iterate over a collection:

    db("posts")->each(sub {
        my $item = shift;

        print $item->{body};
    });

It's also yet-another DBI abstraction layer of Perl module.

=head1 INTERFACE

=over

=item db([ $selector ])

This method is exported to your namespace by default.

If selector is not given, it returns an C<DBIx::CSSQuery::DB>
object. It is required to set dbh attribute on this object before
doing queries. Setting dbh is just thiS:

    db->attr( dbh => DBI->connect($dsn) );

Only after this is done, you may pass $selector into C<db>, do some
query:

    db("posts[id=1]")

At this moment, only very limited selector syntax is
supported. Conceptually, tags are mapped to table names, attributes
are mapped to table columns. So previous query is the same as this sql
query:

    SELECT * FROM posts WHERE id = 1;

At this point, if the column type is string, it needs to be
single-quoted, like C<posts[subject='hi']>. If it's integer, it must
not be quoted, like the example above. Hopefully this can be
automatically detected on the backend so the selector syntax an be
less strict.

=item new()

Object constructor. However, you should use the exported C<db>
function instead.

=item get( $index )

Retrieve a single record from the retrieved collection. Returns a hash.
The value of C<$index> starts from zero.

=item size

Return the total number of records in the current collection.

=item last

Narrow the current collection to contain only the last record. The return
value is stiall collection that you will need to call 'each' or 'get' the o

=item each( $callback )

Iterate over the collection. for each record, C<$callback> is called
with the record passed in as its first argument.

=back

=head1 DEPENDENCIES

L<self>, L<Sub::Exporter>

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-dbix-cssquery@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Kang-min Liu  C<< <gugod@gugod.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Kang-min Liu C<< <gugod@gugod.org> >>. 

This software is released under the MIT license cited below.

=head1 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject
to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

