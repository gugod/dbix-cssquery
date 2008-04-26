
use strict;
use warnings;
use Test::More;
use self;

use DBI ':sql_types';

use DBIx::CSSQuery 'db';

plan tests => 1;

my $dbh = DBI->connect("dbi:SQLite:dbname=t/read.sqlite3", "", "");

my $sth = $dbh->prepare("SELECT * FROM posts WHERE id = ?");
$sth->bind_param(1, 1, SQL_INTEGER);

$sth->execute;

my $post = $sth->fetchrow_hashref();

db->attr(dbh => $dbh);

db("posts[id=1]")->each(
    sub{
        is_deeply($_[0], $post);
    }
);
