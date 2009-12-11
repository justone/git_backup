#!/usr/bin/perl

use strict;
use warnings;
use Git::Backup;

Git::Backup::backup_cmd_line();

__END__

=head1 NAME

git_backup.pl - Simple git based backups.

=head1 SYNOPSIS

 git_backup.pl [options] [--path <path>]

 Options:
  -p --path <path>          Root directory to back up.  This is the only
                            required argument. It may be ommited if you run
                            git_backup.pl from a directory that has a
                            .git_backuprc.
  -c --commit-message <commit message>
                            Git commit message.  Default value is: 'updated'
  -r --remote <git remote>  Once any changes are committed, they will be pushed
                            to this remote.  Default value is: 'backup'
  -w --write-config         Using the current command line values, store the configuration into
                            the <path>'s .git_backuprc and exit.
     --push/--nopush        Defaults to true ('do push' but allows you to disable the git push
                            to enable use without a remote configured.

 Database options:
  -d --database <database>  Database to dump out as part of the backup.  If not
                            specified, then no database dumping will be done.
  -f --database-dir <dir>   Directory in which to put database backups.
  -x --mysql-defaults <mysql defaults file>
                            File containing mysql options.
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
 directory to process. However, --path might be implicit if you are running
 this from a directory that contains a .git_backuprc file.

=head1 DESCRIPTION

This script implements a simple git based backup system.  Given a git
repository path, it will commit any changes that happened in that directory and
then push the changes to a git remote.  Effectively, it does this:

 git add <new or modified files>
 git rm <deleted files>
 git commit -m 'updated'
 git push backup

It does not take care of creating the git repository or the remote clone or the
git remote configuration.  See the SETUP section for that.

If there is an associated database to backup, the --database option may be
used.  If this is passed, tables from that database (optionally filtered by
--prefix) will be dumped into individual files in a diff-friendly format.  If
any options are needed to connect to mysql, they can be put in a file and
specified with the --mysql-defaults flag.

This should follow the format (typically in ~/.my.cnf)
 [client]
 host=mydatabasehost
 user=mydbuser
 password=mydbpass

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

Warning, make sure to do a local config of these values and not to use the --global option.
When running this from cron '--global' settings will not be read.

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
