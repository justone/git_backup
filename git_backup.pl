#!/usr/bin/perl

use strict;
use warnings;
use Carp;
use Getopt::Long;
use Pod::Usage;
use Cwd;
use YAML qw(Dump LoadFile DumpFile);
use File::Temp qw(tempfile);

Getopt::Long::Configure("no_auto_abbrev");

my %options;
my $opts_ok = GetOptions(
    \%options,            'help|?|h',
    'man',                'path|p=s',
    'remote|r=s',         'database|d=s',
    'database-dir|f=s',   'prefix|o=s',
    'commit-message|c=s', 'test|t',
    'mysql-defaults|x=s', 'verbose|v',
    'write-config|w',     'push!',
    'wp-config=s',        'git-init',
    'git-name=s',         'git-email=s',
    'backup-db-host=s',
);

pod2usage(2) if !$opts_ok;
pod2usage(1) if exists $options{help};
pod2usage( -exitstatus => 0, -verbose => 2 ) if exists $options{man};

# set up configuration
my %conf = %options;

# we need a path. If one's not provided, it better be implicit.
if(!$options{'path'}) {
   # we are able to use the current working directory as a path if it has a .git_backuprc in it
   # or any wordpress config we can find (relative path or abs path)
   my $cwd = getcwd;
   if(-e "$cwd/.git_backuprc" || -e "$cwd/$options{'wp-config'}" || -e "$options{'wp-config'}") {
      $options{'path'} = $cwd;
      $conf{'path'} = $cwd;
   } elsif(defined($options{'wp-config'})) {
        die "No wp-config.php and we needed one to exist\n";
   }
}


# we at least need path
pod2usage(2) if !$options{'path'};

# check to see if we are using a wordpress config instead of .git_backuprc
if($options{'wp-config'}) {
   my $wp_config = $options{'wp-config'};
   if(! -e $wp_config) {
      $wp_config = $options{'path'} . "/" . $options{'wp-config'};
   }
   open(my $wp, "<", $wp_config) || die "Can't open wordpress config: $!\n";
   my %convert = (
      'DB_NAME' => 'database',
      'DB_USER' => 'db_user', 
      'DB_PASSWORD' => 'db_password',
      'DB_HOST' => 'db_host',
   );
   while(<$wp>) {
      if(/table_prefix.*?=.*?["'](.*?)['"]/) {
         $conf{'table_prefix'} = $1;
      } elsif (/define\(\s*['"](.*?)['"]\s*,\s*["'](.*?)['"]\)/) {
         if($convert{$1}) {
            $conf{$convert{$1}} = $2;
         }
         
      }
   }
   close($wp);
   if(!defined($conf{db_host})) {
       $conf{db_host} = $conf{'backup-db-host'};
   }
   # create a config file for mysql 
   my ($fh, $filename) = tempfile();
   $conf{'mysql-defaults'} = $filename;
   chmod 0600, $filename; # nobody else can read this, has passwords in it.
   print $fh "[client]\n";
   print $fh "host=$conf{db_host}\n";
   print $fh "user=$conf{db_user}\n";
   print $fh "password=$conf{db_password}\n";
   close($fh);
} else {
   # Check for a config file in path
   my $config_file = $options{'path'} . "/.git_backuprc";
   if(-e $config_file) {
      my $loaded_config = LoadFile($config_file);
      if($loaded_config) {
         # prefer things already specified by getopt parsing. 
         %conf = (%$loaded_config, %conf);
      }
   }

   if($options{'write-config'}) {
      DumpFile($config_file, \%conf);
      print "Saved configuration to $config_file\n";
      exit;
   }
}

# default remote for git
$conf{'remote'} ||= 'backup';

# default commit message for git
$conf{'commit-message'} ||= 'updated';

# default database dir is $path/db
$conf{'database-dir'} ||= "$conf{path}/db";

# default to push == 1
if ( !defined( $conf{'push'} ) ) {
    $conf{'push'} = 1;
}

my $defaults_file_option = "";
if ( $conf{'mysql-defaults'} ) {
    $defaults_file_option = " --defaults-file=$conf{'mysql-defaults'} ";
}

print_configuration() if $conf{'verbose'};

print "Changing to: $options{'path'}\n";
chdir $options{'path'}
    || die "unable to change to directory $options{'path'}";

if(!-d ".git" && $conf{'git-init'}) {
   run_command("git init", { modifies => 1 });
   run_command("git config user.name \"$conf{'git-name'}\"", { modifies => 1 });
   run_command("git config user.email \"$conf{'git-email'}\"", { modifies => 1 });
}

# first, if a database is specified, dump its tables
if ( $conf{'database'} ) {
    print "Database specified, dumping tables.\n";

    if ( $conf{'database-dir'} ) {
        if ( !( -e $conf{'database-dir'} ) ) {
            run_command( "/bin/mkdir -p $conf{'database-dir'}",
                { modifies => 1 } );
        }
        $conf{'database-dir'} .= "/" unless $conf{'database-dir'} =~ /\/$/;
    }

    my @table_list = split(
        /\n/,
        run_command(
            "/usr/bin/mysql $defaults_file_option --silent $conf{'database'} -e \"show tables\""
        )
    );
    if ( $conf{'prefix'} ) {
        @table_list = grep {/^$conf{'prefix'}/} @table_list;
    }
    print "Tables to dump: " . join( ",", @table_list ) . ".\n"
        if $conf{'verbose'};
    foreach my $table (@table_list) {
        print "Dumping $table.\n";
        run_command(
            "/usr/bin/mysqldump $defaults_file_option --extended-insert=FALSE $conf{'database'} $table | /bin/sed 's/ AUTO_INCREMENT=[0-9]\\+//' > $conf{'database-dir'}$table.dump.sql",
            { modifies => 1 }
        );
    }
}

# now, make sure everything is checked in and then push it to the backup remote
print "Checking git status.\n";
my $git_status = run_command( '/usr/bin/git status', { ignore_exit => 1 } );
print "Git status:\n$git_status\n" if $conf{'verbose'};

if ( $git_status =~ /nothing to commit/ ) {
    print "Nothing to commit, exiting...\n";
    exit 1;
}
else {

    # first schedule the changes
    foreach my $line ( split( /\n/, $git_status ) ) {

        #print "processing $line\n" if $conf{'verbose'};
        if ( $line =~ /^#\tmodified: +(.*)$/ ) {
            my $file = $1;
            print "Adding modified file: $file\n";
            run_command( "/usr/bin/git add $file", { modifies => 1 } );
        }
        elsif ( $line =~ /^#\tdeleted: +(.*)$/ ) {
            my $file = $1;
            print "Removing deleted file: $file\n";
            run_command( "/usr/bin/git rm $file", { modifies => 1 } );
        }
        elsif ( $line =~ /^#\t(.*)$/ ) {
            my $file = $1;
            next if $file =~ /new file/;    # this is already staged
            print "Adding new file: $file\n";
            run_command( "/usr/bin/git add $file", { modifies => 1 } );
        }
    }

    # now commit
    print "Committing with message '$conf{'commit-message'}'\n";
    run_command( "/usr/bin/git commit -m \"$conf{'commit-message'}\"",
        { modifies => 1 } );

    if ( $conf{'push'} != 0 ) {

        # then push to the remote
        print "Pushing to backup remote: $conf{'remote'}\n";
        run_command( "/usr/bin/git push $conf{'remote'}", { modifies => 1 } );
    }
    else {
        print "Commited, but not pushing (push disabled with --nopush.)\n";
    }
}

exit;

sub print_configuration {
    print "Configuration after parsing options:\n";
    printf " path: %s\n",   $conf{'path'};
    printf " remote: %s\n", $conf{'remote'};
    printf " database: %s\n",
        $conf{'database'} ? $conf{'database'} : '<none specified>';
    printf " database-dir: %s\n",
        $conf{'database-dir'} ? $conf{'database-dir'} : '<none specified>';
    printf " prefix: %s\n",
        $conf{'prefix'} ? $conf{'prefix'} : '<none specified>';
    printf " mysql-defaults: %s\n",
        $conf{'mysql-defaults'}
        ? $conf{'mysql-defaults'}
        : '<none specified>';
    printf " verbose: %s\n", $conf{'verbose'} ? 'true' : 'false';
    printf " test: %s\n",    $conf{'test'}    ? 'true' : 'false';
    printf " commit-message: '%s'\n",
        $conf{'commit-message'}
        ? $conf{'commit-message'}
        : '<none specified>';
}

sub run_command {
    my ( $cmd, $options ) = @_;
    print "Running command: $cmd\n" if $conf{'verbose'};

    return if ( $options->{modifies} && $conf{'test'} );

    my $output = `$cmd`;
    my $rc     = $? >> 8;
    if ( !$options->{'ignore_exit'} && $rc ) {
        die "$cmd failed with exit code $rc:\n$output\n";
    }

    return $output;
}

__END__

=head1 NAME

git_backup.pl - Simple git based backups.

=head1 SYNOPSIS

 git_backup.pl [options] [--path <path>]

 Options:
  -p --path <path>          Root directory to back up.  This is the only
                            required argument. It may be ommited if you run the app
                            from a domain directory directly.
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
 directory to process. However, --path might be implicit if you are running this from the
 domain directory (when it contains a .git_backuprc file.)

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
