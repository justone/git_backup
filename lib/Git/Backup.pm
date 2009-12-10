package Git::Backup;

use warnings;
use strict;
use Getopt::Long;
use Pod::Usage;
use Cwd;

=head1 NAME

Git::Backup - Backups with Git.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module examines a git repository and, after checking in the changes,
pushes a copy to a remote.  Usually, this will be accomplished by calling the
included git_backup.pl script, but the backend API can be called elsewhere.

    use Git::Backup;

    # backup according to $config options
    Git::Backup::backup($config);

=head1 FUNCTIONS

=head2 backup_cmd_line

Parses command line arguments and then calls backup().

=cut

sub backup_cmd_line {

    Getopt::Long::Configure("no_auto_abbrev");

    my %options;
    my $opts_ok = GetOptions(
        \%options,            'path|p=s',
        'help|h|?',           'man',
        'remote|r=s',         'database-dir|f=s',
        'commit-message|c=s', 'mysql-defaults|x=s',
        'database|d=s',       'prefix|o=s',
        'test|t',             'verbose|v',
    );

    pod2usage(2) if !$opts_ok;
    pod2usage(1) if exists $options{help};
    pod2usage( -exitstatus => 0, -verbose => 2 ) if exists $options{man};

    pod2usage(2) if !$options{'path'};

    backup( \%options );
}

=head2 _parse_options

=cut

sub _parse_options {
    my $options = shift;

    my %conf = %{$options};

    if ( !$conf{'path'} ) {

        # we are able to use the current working directory as a path
        # if it has a .git_backuprc in it
        my $cwd = getcwd;
        if ( -e "$cwd/.git_backuprc" ) {
            $conf{'path'} = $cwd;
        }
    }

    # we at least need path
    pod2usage(2) if !$conf{'path'};

    return \%conf;
}

=head2 backup

Actually performs the backups.

TODO: list config options.

=cut

sub backup {

    #my $options = shift;

    #my $config = _parse_options($options);
}

=head1 AUTHOR

Nate Jones, C<< <nate at endot.org> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::Backup

Information on calling the git_backup.pl script can be obtained by running it
with the --help or --man options.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 by Nate Jones C<< <nate at endot.org> >>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of Git::Backup
