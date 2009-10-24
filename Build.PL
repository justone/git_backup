use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Git::Backup',
    license             => 'perl',
    dist_author         => q{Nate Jones <nate@endot.org>},
    dist_version_from   => 'lib/Git/Backup.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Git-Backup-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
