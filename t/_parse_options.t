#!perl

use Test::More;
use Test::Trap;
use strict;

use FindBin qw($Bin);

#require "$Bin/helper.pl";

use Git::Backup;
use Test::MockModule;

my $pu_module = Test::MockModule->new('Git::Backup');
my $pod2usage_args;
$pu_module->mock( 'pod2usage',
    sub { $pod2usage_args = \@_; die "pod2usage called\n"; } );
my $DumpFile_args;
$pu_module->mock( 'DumpFile', sub { $DumpFile_args = \@_; } );
my $_print_configuration_args;
$pu_module->mock( '_print_configuration',
    sub { $_print_configuration_args = \@_; } );

my @tests = (
    {   count => 3,
        code  => sub {
            my $t = 'no options, no .git_backuprc';

            eval { Git::Backup::_parse_options( {} ); };

            ok( $@, "$t - command exited" );
            ok( $@ =~ /pod2usage called/, "$t - pod2usage called" );
            is_deeply( $pod2usage_args, [2], "$t - pod2usage args ok" );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'no options, .git_backuprc exists';

            # change dir to somewhere that has a .git_backuprc
            chdir("$Bin/test_dir");

            my $config = Git::Backup::_parse_options( {} );

            ok( $config, "$t - config returned successfully" );
            is( $config->{path}, "$Bin/test_dir", "$t - path set properly" );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'only path passed';

            my $config = Git::Backup::_parse_options( { path => $Bin } );

            ok( $config, "$t - config returned successfully" );
            is( $config->{path}, "$Bin", "$t - path set properly" );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'defaults';

            my $config;

            $config = Git::Backup::_parse_options( { path => $Bin } );

            is_deeply(
                $config,
                {   'path'           => "$Bin",
                    'remote'         => 'backup',
                    'commit-message' => 'updated',
                    'database-dir'   => '',
                    'push'           => 1,
                },
                "$t - config populated properly"
            );

            $config = Git::Backup::_parse_options(
                {   path             => $Bin,
                    remote           => 'other',
                    'commit-message' => 'new stuff',
                    'database-dir'   => 'db',
                    'push'           => 0,
                }
            );

            is_deeply(
                $config,
                {   'path'           => "$Bin",
                    'remote'         => 'other',
                    'commit-message' => 'new stuff',
                    'database-dir'   => 'db',
                    'push'           => 0,
                },
                "$t - doesn't override passed values"
            );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'load from .git_backuprc';

            my $config;

            $config
                = Git::Backup::_parse_options( { path => "$Bin/test_dir" } );

            is_deeply(
                $config,
                {   'path'           => "$Bin/test_dir",
                    'remote'         => 'backup',
                    'commit-message' => 'updated',
                    'database-dir'   => 'db',
                    'database'       => 'wpdb',
                    'push'           => 1,
                },
                "$t - values are populated from config file"
            );

            $config = Git::Backup::_parse_options(
                {   path           => "$Bin/test_dir",
                    database       => 'otherdb',
                    'database-dir' => 'dbbackup'
                }
            );

            is_deeply(
                $config,
                {   'path'           => "$Bin/test_dir",
                    'remote'         => 'backup',
                    'commit-message' => 'updated',
                    'database-dir'   => 'dbbackup',
                    'database'       => 'otherdb',
                    'push'           => 1,
                },
                "$t - specified values override config file"
            );
            }
    },
    {   count => 2,
        code  => sub {
            my $t = 'write out to .git_backuprc';

            my $config;

            $config = trap {
                Git::Backup::_parse_options(
                    { path => "$Bin", 'write-config' => 1 } );
            };

            is( $trap->exit(), 0, "$t - code exits ok" );
            is_deeply(
                $DumpFile_args,
                [ "$Bin/.git_backuprc", { path => "$Bin" } ],
                "$t - DumpFile args ok"
            );
            }
    },
    {   count => 1,
        code  => sub {
            my $t = 'verbose causes configuration to print';

            $_print_configuration_args = undef;
            my $config = Git::Backup::_parse_options(
                { path => $Bin, verbose => 1 } );

            ok( $_print_configuration_args,
                "$t - _print_configuration called"
            );
            }
    },
);

our $tests += $_->{count} for @tests;

plan tests => $tests;

$_->{code}->() for @tests;

