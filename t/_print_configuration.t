#!perl

use Test::More;
use Test::Trap;
use strict;

use FindBin qw($Bin);

use Git::Backup;

my @tests = (
    {   count => 1,
        code  => sub {
            my $t = 'set one';

            trap {
                Git::Backup::_print_configuration(
                    {   path             => $Bin,
                        remote           => 'backup',
                        verbose          => 1,
                        test             => 1,
                        'commit-message' => 'updated'
                    }
                );
            };

            is( $trap->stdout(),
                <<SET_ONE, "$t - configuration print is ok" );
Configuration after parsing options:
 path: /Users/nate/projects/git_backup/t
 remote: backup
 database: <none specified>
 database-dir: <none specified>
 prefix: <none specified>
 mysql-defaults: <none specified>
 verbose: true
 test: true
 commit-message: 'updated'
SET_ONE
            }
    },
    {   count => 1,
        code  => sub {
            my $t = 'set two';

            trap {
                Git::Backup::_print_configuration(
                    {   path             => $Bin,
                        remote           => 'other',
                        database         => 'database',
                        'database-dir'   => 'db',
                        prefix           => 'db_',
                        'mysql-defaults' => '/var/defaults',
                        'commit-message' => 'message'
                    }
                );
            };

            is( $trap->stdout(),
                <<SET_ONE, "$t - configuration print is ok" );
Configuration after parsing options:
 path: /Users/nate/projects/git_backup/t
 remote: other
 database: database
 database-dir: db
 prefix: db_
 mysql-defaults: /var/defaults
 verbose: false
 test: false
 commit-message: 'message'
SET_ONE
            }
    },
);

our $tests += $_->{count} for @tests;

plan tests => $tests;

$_->{code}->() for @tests;

