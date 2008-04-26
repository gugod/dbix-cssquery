package DBIx::CSSQuery;

use warnings;
use strict;
use Carp;
use 5.008000;
use YAML;
use DBI ":sql_types";
use DBIx::CSSQuery::DB;

our $VERSION = '0.0.1';

package DBIx::CSSQuery;

use Sub::Exporter -setup => {
    exports => [qw(db)]
};
use self;

sub new {
    return bless {}, self;
}

my $self;

sub db {
    $self = DBIx::CSSQuery->new() if !$self;
    if (!$self->{db}) {
        $self->{db} = DBIx::CSSQuery::DB->new();
    }

    return $self->{db} if !@_;
    if ($_[0]) {
        $self->{selector} = $_[0];
    }
    return $self;
}

sub each {
    my ($cb) = args;

    my $parsed = _parse_css_selector(self->{selector});
    (self->{sql}, self->{values}) = _build_select_sql_statement($parsed);

    my $dbh = self->{db}->attr("dbh");

    my $sth = $dbh->prepare( self->{sql} );

    for my $i (0 .. $#{self->{values}} ) {
        my $v = $self->{values}->[$i];
        $sth->bind_param($i+1, $v->[0], $v->[1]);
    }

    $sth->execute;
    while (my $record = $sth->fetchrow_hashref) {
        $cb->($record);
    }
}

sub _build_select_sql_statement {
    my ($parsed) = @_;

    my $p = $parsed->[0];

    my @values = ();

    my $from  = " FROM $p->{type} ";
    my $where = " WHERE ";
    if ($p->{attribute} =~ m/ \[ (.+) = (.+) \] /x ) {
        my $field = $1;
        my $val = $2;

        $where .= "$field = ?";
        my $type = SQL_INTEGER;
        if ($val =~ /^'(.+)'$/) {
            $val = $1;
            $type = SQL_STRING;
        }
        push @values, [$val, SQL_INTEGER];
    }

    return "SELECT * $from $where", \@values;
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

DBIx::CSSQuery - [One line description of module's purpose here]


=head1 VERSION

This document describes DBIx::CSSQuery version 0.0.1


=head1 SYNOPSIS

    use DBIx::CSSQuery;


=head1 DESCRIPTION


=head1 INTERFACE 


=over

=item new()

=back

=head1 DIAGNOSTICS

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

DBIx::CSSQuery requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

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

Copyright (c) 2008, Kang-min Liu C<< <gugod@gugod.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


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
