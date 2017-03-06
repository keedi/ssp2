#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Path::Tiny;

my $ndays = 365;
my $ncols = 751;
my $nrows = 601;

my $output = "32-rhum.dat";

#my $data_dir = "/mnt/500g/SHARE/dr.park/data/East_Asia/grid1kmData_ascii";
my $data_dir = "W:/grid1kmData_ascii";

my $term = "daily";
my $var  = "rhum";
my $year = 2006;

# ex:
#     linux:    /mnt/500g/SHARE/dr.park/data/East_Asia/grid1kmData_ascii/daily/tavg/2006/
#     windows:                                      W:/grid1kmData_ascii/daily/rhum/2006/ssp2_rhum_daily_2006-001_1kmgrid.txt
my $file_fmt = sprintf(
    "%s/%s/%s/%d/ssp2_%s_%s_%d-%%03d_1kmgrid.txt",
    $data_dir,
    $term,
    $var,
    $year,
    $var,
    $term,
    $year,
);

my @files;
for ( my $i = 1; $i <= $ndays; ++$i ) {
    my $file = sprintf( $file_fmt, $i );
    push @files, $file;
}

my %params = (
    header   => [],
    result   => $result,
    ndays    => $ndays,
    nrows    => $nrows,
    ncols    => $ncols,
    files    => \@files,
    cb_init  => sub {
        my ( $params ) = @_;

        for ( my $i = 0; $i < $params->{nrows}; ++$i ) {
            $params->{result}[$i] = [];
            for ( my $j = 0; $j < $params->{ncols}; ++$j ) {
                $params->{result}[$i][$j] = {
                    val => 0,
                    cnt => 0,
                };
            }
        }
    },
    cb       => sub {
        my ( $params, $rows, $cols, $item ) = @_;

        if ( $item != -9999 ) {
            $params->{result}[$rows][$cols]{val} += $item;
            ++$params->{result}[$rows][$cols]{cnt};
        }
    },
    cb_final => sub {
        my ( $params ) = @_;

        for ( my $i = 0; $i < $params->{nrows}; ++$i ) {
            for ( my $j = 0; $j < $params->{ncols}; ++$j ) {
                my $cnt = $params->{result}[$i][$j]{cnt};
                my $val = $params->{result}[$i][$j]{val};
                if ( $cnt > 0 ) {
                    $params->{result}[$i][$j]{avg} = $val / $cnt;
                }
                else {
                    $params->{result}[$i][$j]{avg} = undef;
                }
            }
        }
    },
);

iter( \%params );

my $ndv = no_data_value( $params{header} );
warn "no data value: $ndv\n";

{
    my $fh = path($output)->filehandle( ">", ":raw:encoding(UTF-8)" );

    print $fh "$_\n" for @{ $params{header} };
    for ( my $i = 0; $i < $nrows; ++$i ) {
        for ( my $j = 0; $j < $ncols; ++$j ) {
            my $avg = $result->[$i][$j]{avg};
            if ( defined $avg ) {
                printf $fh "%.2f", $avg;
            }
            else {
                print $fh $ndv;
            }
            print $fh q{ };
        }
        print $fh "\n";
    }
}

sub no_data_value {
    my $headers = shift;

    my $ndv;
    for my $header ( @$headers ) {
        next unless $header =~ m/^NODATA_value\s(\S+)/;
        $ndv = $1;
    }

    return $ndv;
}

sub iter {
    my $params = shift;

    $params->{cb_init}->($params);

    my @header_strings;
    for my $file (@files) {
        warn "processing $file\n";;

        my $path = path($file);
        warn "file does not exists: $file\n" unless $path->exists;
        my $fh = $path->filehandle( "<", ":raw:encoding(UTF-8)" );

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
            portable_chomp();

            if ( m/$regex_kv/ ) {
                my $k = $1;
                my $v = $2;
                $header{$k} = $v;
                push @header_strings, $_;
                next;
            }

            my @items = split;
            my $cols = @items;
            die "invalid cols row($rows): $cols == $params->{ncols}" unless $cols == $params->{ncols};

            $cols = 0;
            for my $item (@items) {
                $params->{cb}->( $params, $rows, $cols, $item );
                ++$cols;
            }

            ++$rows;
        }
        die "invalid ncols: $params->{ncols} == $header{ncols}\n" unless $params->{ncols} == $header{ncols};
        die "invalid nrows: $params->{nrows} == $header{nrows}\n" unless $params->{nrows} == $header{nrows};

        close $fh;
    }

    $params->{header} = \@header_strings;

    $params->{cb_final}->($params);
}

sub portable_chomp {
    my $line = shift;

    $_ //= $line;
    s/(?:\x{0d}?\x{0a}|\x{0d})$//; # chomp
}
