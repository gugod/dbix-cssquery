use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/DBIx/CSSQuery.pm';
name 'DBIx-CSSQuery';

build_requires  'Test::More'        => '0.42';

WriteAll;


