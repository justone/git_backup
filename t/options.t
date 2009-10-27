#!/usr/bin/perl

use Test::More;

use Git::Backup;
use Test::MockModule;

my $gb_module = Test::MockModule->new('Git::Backup');
my $backup_args;
$gb_module->mock( 'backup', sub { $backup_args = \@_ } );

my $pu_module = Test::MockModule->new('Git::Backup');
$pu_module->mock( 'pod2usage', sub { die "pod2usage called with $_[0]\n"; } );

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
    {   count => 2,
        code  => sub {
            my $t = 'no args';

            @ARGV = qw();

            eval { Git::Backup::backup_cmd_line(); };

            ok( $@, "$t - command exited" );
            ok( $@ =~ /pod2usage called with 2/, "$t - pod2usage called" );
            }
    },
    {   count => 2 * 3,
        code  => sub {
            our $t = 'help';

            sub test_help {
                eval { Git::Backup::backup_cmd_line(); };

                ok( $@, "$t - command exited" );
                ok( $@ =~ /pod2usage called with 1/,
                    "$t - pod2usage called" );
            }

            @ARGV = qw(--help);
            test_help();
            @ARGV = qw(-h);
            test_help();
            @ARGV = qw(-?);
            test_help();
            }
    },
);

our $tests += $_->{count} for @tests;
plan tests => $tests;

$_->{code}->() for @tests;
