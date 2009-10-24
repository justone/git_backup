#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok('Git::Backup');
}

diag("Testing Git::Backup $Git::Backup::VERSION, Perl $], $^X");
