#!/usr/bin/perl

use Test::More;

use Git::Backup;
use Test::MockModule;

my $gb_module = Test::MockModule->new('Git::Backup');
my $backup_args;
$gb_module->mock( 'backup', sub { $backup_args = \@_ } );

my $pu_module = Test::MockModule->new('Git::Backup');
my $pod2usage_args;
$pu_module->mock( 'pod2usage',
    sub { $pod2usage_args = \@_; die "pod2usage called\n"; } );

my @tests = (
    {   count => 1 * 2,
        code  => sub {
            our $t = 'simplest';

            sub test_simplest {
                Git::Backup::backup_cmd_line();

                is_deeply(
                    $backup_args,
                    [ { path => '/test/path' } ],
                    "$t - config is correct"
                );
            }

            @ARGV = qw(--path /test/path);
            test_simplest();
            @ARGV = qw(-p /test/path);
            test_simplest();
            }
    },
    {   count => 3,
        code  => sub {
            our $t = 'missing path';

            @ARGV = qw(--path);

            eval { Git::Backup::backup_cmd_line(); };

            ok( $@, "$t - command exited" );
            ok( $@ =~ /pod2usage called/, "$t - pod2usage called" );
            is_deeply( $pod2usage_args, [2], "$t - pod2usage args ok" );
            }
    },
    {   count => 3,
        code  => sub {
            my $t = 'no args';

            @ARGV = qw();

            eval { Git::Backup::backup_cmd_line(); };

            ok( $@, "$t - command exited" );
            ok( $@ =~ /pod2usage called/, "$t - pod2usage called" );
            is_deeply( $pod2usage_args, [2], "$t - pod2usage args ok" );
            }
    },
    {   count => 3 * 3,
        code  => sub {
            our $t = 'help';

            sub test_help {
                eval { Git::Backup::backup_cmd_line(); };

                ok( $@, "$t - command exited" );
                ok( $@ =~ /pod2usage called/, "$t - pod2usage called" );
                is_deeply( $pod2usage_args, [1], "$t - pod2usage args ok" );
            }

            @ARGV = qw(--help);
            test_help();
            @ARGV = qw(-h);
            test_help();
            @ARGV = qw(-?);
            test_help();
            }
    },
    {   count => 3,
        code  => sub {
            my $t = 'man';

            @ARGV = qw(--man);

            eval { Git::Backup::backup_cmd_line(); };

            ok( $@, "$t - command exited" );
            ok( $@ =~ /pod2usage called/, "$t - pod2usage called" );
            is_deeply(
                $pod2usage_args,
                [ -exitstatus => 0, -verbose => 2 ],
                "$t - pod2usage args ok"
            );
            }
    },
    {   count => 1 * 2,
        code  => sub {
            our $t = 'main options';

            sub test_main_options {
                Git::Backup::backup_cmd_line();

                is_deeply(
                    $backup_args,
                    [   {   'path'           => '/test/path',
                            'remote'         => 'remote',
                            'database-dir'   => 'db',
                            'commit-message' => 'commit',
                            'mysql-defaults' => 'mydefaults',
                            'database'       => 'mydb',
                            'prefix'         => 'prefix',
                            'test'           => 1,
                            'verbose'        => 1,
                        }
                    ],
                    "$t - config is correct"
                );
            }

            @ARGV = qw(
                --path /test/path
                --remote remote
                --database-dir db
                --commit-message commit
                --mysql-defaults mydefaults
                --database mydb
                --prefix prefix
                --test
                --verbose
            );
            test_main_options();

            @ARGV = qw(
                -p /test/path
                -r remote
                -f db
                -c commit
                -x mydefaults
                -d mydb
                -o prefix
                -t
                -v
            );
            test_main_options();
            }
    },
);

our $tests += $_->{count} for @tests;
plan tests => $tests;

$_->{code}->() for @tests;
