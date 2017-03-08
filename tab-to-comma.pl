#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use feature qw( say );

use Path::Tiny;

my ( $arg_src, $arg_dest ) = @ARGV;
die "Usage: $0 <src_dir> <dest_dir>\n" unless $arg_src && -d $arg_src && $arg_dest;

my $src  = path($arg_src);
my $dest = path($arg_dest);

$dest->mkpath;
for my $s ( $src->children ) {
    next unless $s->is_file;

    my $d = $dest->child( $s->basename );

    say "$s -> $d";

    my $sfh = $s->filehandle( "<", ":raw:encoding(cp949)" );
    my $dfh = $d->filehandle( ">", ":raw:encoding(cp949)" );
    while (<$sfh>) {
        s/\t/,/gms;
        print {$dfh} $_;
    }
    close $dfh;
    close $sfh;
}
