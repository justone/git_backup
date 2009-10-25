package Git::Backup;

use warnings;
use strict;
use Getopt::Long;

=head1 NAME

Git::Backup - The great new Git::Backup!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Git::Backup;

    my $foo = Git::Backup->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 backup_cmd_line

=cut

sub backup_cmd_line {

    my %options;
    my $opts_ok = GetOptions( \%options, 'path|p=s' );

    backup( \%options );
}

=head2 _parse_options

=cut

#sub _parse_options {
#}

=head2 backup

=cut

sub backup {

    #my $options = shift;

    #my $config = _parse_options($options);
}

=head1 AUTHOR

Nate Jones, C<< <nate at endot.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-git-backup at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Git-Backup>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::Backup


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-Backup>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Git-Backup>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Git-Backup>

=item * Search CPAN

L<http://search.cpan.org/dist/Git-Backup/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Nate Jones.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Git::Backup
