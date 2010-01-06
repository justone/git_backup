#!/usr/bin/perl

use Test::More tests => 1;

use Git::Backup;

ok( !Git::Backup::backup(), "make sure this is 'covered'" );
