#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;
use YAML qw(Dump);

Getopt::Long::Configure("no_auto_abbrev");

my %options;
my $opts_ok = GetOptions(
    \%options,
    'help|?|h',
    'man',
    'path|p=s',
    'remote|r=s',
    'database|d=s',
    'prefix|o=s',
    'commit-message|c=s',
    'test|t',
    'mysql-defaults|x=s',
    'verbose|v',
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
        run_command("/usr/bin/mysqldump $defaults_file_option --extended-insert=FALSE $conf{'database'} $table | /bin/sed 's/ AUTO_INCREMENT=[0-9]\\+//' > $table.dump.sql", {modifies => 1});
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

git_backup.pl - Simple git based backups.

=head1 SYNOPSIS

 git_backup.pl [options] --path <path>

 Options:
  -p --path <path>          Root directory to back up.  This is the only
                            required argument.
  -c --commit-message <commit message>
                            Git commit message.  Default value is: 'updated'
  -r --remote <git remote>  Once any changes are committed, they will be pushed
                            to this remote.  Default value is: 'backup'

 Database options:
  -d --database <database>  Database to dump out as part of the backup.  If not
                            specified, then no database dumping will be done.
  -x --mysql-defaults <mysql defaults file>
  -o --prefix <prefix>      Database table prefix.  If specified, only tables
                            with this prefix will be dumped.

 Documentation options:
  -v --verbose              Print more details about what the script is doing.
  -t --test                 Don't actually do anything.  Useful when combined
                            with --verbose.
  -h --help -?              brief help message
     --man                  full documentation

=head1 REQUIRED ARGUMENTS

 The only argument that must appear is --path.  This tells git_backup.pl what
 directory to process.

=head1 DESCRIPTION

This script implements a simple git based backup system.  Given a git
repository path, it will commit any changes that happened in that directory and
then push the changes to a git remote.  Effectively, it does this:

 git add <new or modified files>
 git rm <deleted files>
 git commit -m 'updated'
 git push backup

It does not take care of creating the git repository or the remote clone or the
git remote configuration.

If there is an associated database to backup, the --database option may be
used.  If this is passed, tables from that database (optionally filtered by
--prefix) will be dumped into individual files in a diff-friendly format.

=head1 SETUP

To set up a directory for use with git_backup.pl, follow these steps:

=head2 1. Create the git repostory and add all the files to it.

 $ cd /some/directory
 $ git init
 $ git add .

=head2 2. Configure your commit settings in the new repository and make the initial commit.

 $ git config user.name "Your Name"
 $ git config user.email "your@email.com"
 $ git commit -m "initial commit"

=head2 3. Create a bare clone and copy it to another location.

 $ cd ..
 $ git clone --bare directory directory.git
 $ scp -r directory.git user@domain.com:
 $ cd directory

=head2 4. Add the git remote configuration and test the push.

 $ git remote add backup user@domain.com:directory.git
 $ git push backup

=head1 AUTHOR

Nate Jones E<lt>nate@endot.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2009 by Nate Jones E<lt>nate@endot.orgE<gt>.

This program is free software; you can use, modify, and redistribute it under
the Artistic License, version 2.0.

See http://www.opensource.org/licenses/artistic-license-2.0.php

=cut
