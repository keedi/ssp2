#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use feature qw( say );

use Path::Tiny;

my $ndays = 365;
my $ncols = 751;
my $nrows = 601;

my $output = "24-tavg.dat";

my $data_dir = "/mnt/500g/SHARE/dr.park/data/East_Asia/grid1kmData_ascii";

my $term = "daily";
my $var  = "tavg";
my $year = 2006;

# ex: /mnt/500g/SHARE/dr.park/data/East_Asia/grid1kmData_ascii/daily/tavg/2006/
my $file_fmt = "$data_dir/$term/$var/$year/ssp2_${var}_${term}_${year}-%03d_pointdata.txt";

my @files;
for ( my $i = 1; $i <= $ndays; ++$i ) {
    push( @files, sprintf( $file_fmt, $i ) );
}

my $result;
for ( my $i = 0; $i < $nrows; ++$i ) {
    $result->[$i] = [];
    for ( my $j = 0; $j < $ncols; ++$j ) {
        $result->[$i][$j] = {
            val => 0,
            cnt => 0,
        };
    }
}

my @header_strings;
for my $file (@files) {
    say $file;
    my $fh = path($file)->filehandle( "<", ":raw:encoding(UTF-8)" );

    my %header = (
        ncols        => 0,
        nrows        => 0,
        xllcorner    => undef,
        yllcorner    => undef,
        cellsize     => undef,
        NODATA_value => undef,
    );
    my $header_keys = join "|", keys %header;
    my $regex_kv = qr/^($header_keys)\s+(\S+)$/;
    my $rows = 0;
    @header_strings = ();
    while (<$fh>) {
        s/(?:\x{0d}?\x{0a}|\x{0d})$//; # chomp

        if ( m/$regex_kv/ ) {
            my $k = $1;
            my $v = $2;
            $header{$k} = $v;
            push @header_strings, $_;
            next;
        }

        my @items = split;
        my $cols = @items;
        die "invalid cols row($rows): $cols == $ncols" unless $cols == $ncols;

        $cols = 0;
        for my $item (@items) {
            if ( $item != -9999 ) {
                $result->[$rows][$cols]{val} += $item;
                ++$result->[$rows][$cols]{cnt};
            }
            ++$cols;
        }

        ++$rows;
    }
    die "invalid ncols: $ncols == $header{ncols}\n" unless $ncols == $header{ncols};
    die "invalid nrows: $nrows == $header{nrows}\n" unless $nrows == $header{nrows};

    close $fh;
}

{
    my $fh = path($output)->filehandle( ">", ":raw:encoding(UTF-8)" );

    print $fh "$_\n" for @header_strings;
    for ( my $i = 0; $i < $nrows; ++$i ) {
        for ( my $j = 0; $j < $ncols; ++$j ) {
            my $cnt = $result->[$i][$j]{cnt};
            my $val = $result->[$i][$j]{val};
            if ( $cnt > 0 ) {
                printf $fh "%.2f", $result->[$i][$j]{val} / $cnt;;
            }
            else {
                print $fh -9999;
            }
            print $fh q{ };
        }
        print $fh "\n";
    }
}

