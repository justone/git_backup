#!perl

use Test::More;
use strict;

use FindBin qw($Bin);

#require "$Bin/helper.pl";

use Git::Backup;
use Test::MockModule;

my $pu_module = Test::MockModule->new('Git::Backup');
my $pod2usage_args;
$pu_module->mock( 'pod2usage',
    sub { $pod2usage_args = \@_; die "pod2usage called\n"; } );

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
);

our $tests += $_->{count} for @tests;

plan tests => $tests;

$_->{code}->() for @tests;

