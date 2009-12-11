#!/usr/bin/perl

use Test::More tests => 2;

use Git::Backup;

ok( !Git::Backup::backup(),               "make sure this is 'covered'" );
ok( !Git::Backup::_print_configuration(), "make sure this is 'covered'" );
