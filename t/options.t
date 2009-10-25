#!/usr/bin/perl

use Test::More;

use Git::Backup;
use Test::MockModule;

my $module = Test::MockModule->new('Git::Backup');
my $backup_args;
$module->mock( 'backup', sub { $backup_args = \@_ } );

my @tests = (
    {   count => 1,
        code  => sub {
            my $t = 'simplest';

            @ARGV = qw(--path /test/path);

            Git::Backup::backup_cmd_line();

            is_deeply(
                $backup_args,
                [ { path => '/test/path' } ],
                "$t - config is correct"
            );
            }
    }
);

our $tests += $_->{count} for @tests;
plan tests => $tests;

$_->{code}->() for @tests;
