use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/DBIx/CSSQuery.pm';
name 'DBIx-CSSQuery';

requires
    'DBD::SQLite' => 0,
    'Sub::Exporter' => 0,
    'self' => 0.15,
    'DBI' => 0;

build_requires  'Test::More'        => '0.42';

WriteAll;


