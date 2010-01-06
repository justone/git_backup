package Git::Backup;

use warnings;
use strict;
use Getopt::Long;
use Pod::Usage;
use Cwd;
use YAML qw(Dump LoadFile DumpFile);

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

=head2 _print_configuration

=cut

sub _print_configuration {
    my $conf = shift;

    print "Configuration after parsing options:\n";
    printf " path: %s\n",   $conf->{'path'};
    printf " remote: %s\n", $conf->{'remote'};
    printf " database: %s\n",
        $conf->{'database'} ? $conf->{'database'} : '<none specified>';
    printf " database-dir: %s\n",
        $conf->{'database-dir'}
        ? $conf->{'database-dir'}
        : '<none specified>';
    printf " prefix: %s\n",
        $conf->{'prefix'} ? $conf->{'prefix'} : '<none specified>';
    printf " mysql-defaults: %s\n",
        $conf->{'mysql-defaults'}
        ? $conf->{'mysql-defaults'}
        : '<none specified>';
    printf " verbose: %s\n", $conf->{'verbose'} ? 'true' : 'false';
    printf " test: %s\n",    $conf->{'test'}    ? 'true' : 'false';
    printf " commit-message: '%s'\n", $conf->{'commit-message'};
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

    # Check for a config file in path
    my $config_file = $conf{'path'} . "/.git_backuprc";
    if ( -e $config_file ) {
        my $loaded_config = LoadFile($config_file);

        # prefer things already specified by getopt parsing.
        %conf = ( %$loaded_config, %conf );
    }

    if ( $conf{'write-config'} ) {
        delete $conf{'write-config'};    # no need to save this
        DumpFile( $config_file, \%conf );
        print "Saved configuration to $config_file\n";
        exit;
    }

    # default remote for git
    $conf{'remote'} ||= 'backup';

    # default commit message for git
    $conf{'commit-message'} ||= 'updated';

    # default database dir is nothing
    $conf{'database-dir'} ||= '';

    # default to push == 1
    if ( !defined( $conf{'push'} ) ) {
        $conf{'push'} = 1;
    }

    _print_configuration( \%conf ) if $conf{'verbose'};

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
