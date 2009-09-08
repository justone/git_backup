#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;
use YAML qw(Dump);

my %options;
my $opts_ok = GetOptions(
    \%options,
    'help|?',
    'man',
    'path=s',
    'remote:s',
    'database:s',
    'prefix:s',
    'commit-message:s',
    'test',
    'mysql-defaults:s',
    'verbose',
);

pod2usage(2) if !$opts_ok;
pod2usage(1) if exists $options{help};
pod2usage( -exitstatus => 0, -verbose => 2 ) if exists $options{man};

# set up configuration
my %conf = %options;

# we at least need path
pod2usage(2) if !$options{'path'};
# default remote for git
$conf{'remote'} ||= 'backup';
# default commit message for git
$conf{'commit-message'} ||= 'updated';

my $defaults_file_option = "";
if ($conf{'mysql-defaults'}) {
    $defaults_file_option = " --defaults-file=$conf{'mysql-defaults'} ";
}

print_configuration() if $conf{'verbose'};

print "Changing to: $options{'path'}\n";
chdir $options{'path'} || die "unable to change to directory $options{'path'}";

# first, if a database is specified, dump its tables
if ($conf{'database'}) {
    print "Database specified, dumping tables.\n";

    my @table_list = split(/\n/, run_command("/usr/bin/mysql $defaults_file_option --silent $conf{'database'} -e \"show tables\""));
    if ($conf{'prefix'}) {
        @table_list = grep {/^$conf{'prefix'}/} @table_list;
    }
    print "Tables to dump: ".join(",", @table_list).".\n" if $conf{'verbose'};
    foreach my $table (@table_list) {
        print "Dumping $table.\n";
        run_command("/usr/bin/mysqldump $defaults_file_option --extended-insert=FALSE $conf{'database'} $table > $table.dump.sql", {modifies => 1});
    }
}

# now, make sure everything is checked in and then push it to the backup remote
print "Checking git status.\n";
my $git_status = run_command('/usr/bin/git status', {ignore_exit=>1});
print "Git status:\n$git_status\n" if $conf{'verbose'};

if ($git_status =~ /nothing to commit/) {
    print "Nothing to commit, exiting...\n";
}
else {

    # first schedule the changes
    foreach my $line (split(/\n/, $git_status)) {
        #print "processing $line\n" if $conf{'verbose'};
        if ($line =~ /^#\tmodified: +(.*)$/) {
            my $file = $1;
            print "Adding modified file: $file\n";
            run_command("/usr/bin/git add $file", {modifies => 1});
        }
        elsif ($line =~ /^#\tdeleted: +(.*)$/) {
            my $file = $1;
            print "Removing deleted file: $file\n";
            run_command("/usr/bin/git rm $file", {modifies => 1});
        }
        elsif ($line =~ /^#\t(.*)$/) {
            my $file = $1;
            print "Adding new file: $file\n";
            run_command("/usr/bin/git add $file", {modifies => 1});
        }
    }

    # now commit
    print "Committing with message '$conf{'commit-message'}'\n";
    run_command("/usr/bin/git commit -m \"$conf{'commit-message'}\"", {modifies => 1});

    # then push to the remote
    print "Pushing to backup remote: $conf{'remote'}\n";
    run_command("/usr/bin/git push $conf{'remote'}", {modifies => 1});
}

exit;

sub print_configuration {
    print "Configuration after parsing options:\n";
    printf " path: %s\n", $conf{'path'};
    printf " remote: %s\n", $conf{'remote'};
    printf " database: %s\n", $conf{'database'} ? $conf{'database'} : '<none specified>';
    printf " prefix: %s\n", $conf{'prefix'} ? $conf{'prefix'} : '<none specified>';
    printf " mysql-defaults: %s\n", $conf{'mysql-defaults'} ? $conf{'mysql-defaults'} : '<none specified>';
    printf " verbose: %s\n", $conf{'verbose'} ? 'true' : 'false';
    printf " test: %s\n", $conf{'test'} ? 'true' : 'false';
    printf " commit-message: '%s'\n", $conf{'commit-message'} ? $conf{'commit-message'} : '<none specified>';
}

sub run_command {
	my ($cmd, $options) = @_;
	print "Running command: $cmd\n" if $conf{'verbose'};

    return if ($options->{modifies} && $conf{'test'});

    my $output = `$cmd`;
    my $rc = $? >> 8;
    if (!$options->{'ignore_exit'} && $rc) {
        die "$cmd failed with exit code $rc:\n$output\n";
    }

	return $output;
}


__END__

=head1 NAME

git_backup.pl - Script to backup a site with git to a remote site

=head1 SYNOPSIS

 git_backup.pl [options]

 Options:
    --help            brief help message
    --man             full documentation

=head1 REQUIRED ARGUMENTS

 A list of every argument that must appear.  This can be ommitted if
 there are no required args.

=head1 OPTIONS

 Every option, what it does and any caveats that they may have.  This
 should also include the required arguments if applicable.

=head1 DESCRIPTION

 A full description of the application and it's features

=head1 AUTHOR

Nate Jones E<lt>nate@endot.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2009 by Nate Jones E<lt>nate@endot.orgE<gt>.

This program is free software; you can use, modify, and redistribute it under
the same terms as Perl 5.10.x itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
