use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/DBIx/CSSQuery.pm';
name 'DBIx-CSSQuery';

requires
    'common::sense' => '3.0',
    'DBD::SQLite' => 0,
    'Sub::Exporter' => 0,
    'self' => '0.32',
    'DBI' => 0;

build_requires  'Test::More'        => '0.42';

extra_tests;
WriteAll;


