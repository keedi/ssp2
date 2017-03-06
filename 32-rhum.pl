#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Benchmark;
use Path::Tiny;

use SSP2::Iter;
use SSP2::Sigungu;
use SSP2::Util;

my $data_dir = "W:/grid1kmData_ascii";
my $term     = "daily";
my $var      = "rhum";
my $year     = 2006;
my $ndays    = 365;
my $ncols    = 751;
my $nrows    = 601;
my $output   = "W:/ssp2/result/$term/$var/$year/SSP2_${var}-1d-avg_${term}_CityLevel_${year}_sub.txt";

my $ss = SSP2::Sigungu->new(
    ncols         => $ncols,
    nrows         => $nrows,
    info_file     => "W:/define/sigungu230_info.txt",
    boundary_file => "W:/define/sigungu230_boundary.txt",
);

my @files;
{
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

    for ( my $i = 1; $i <= $ndays; ++$i ) {
        my $file = sprintf( $file_fmt, $i );
        push @files, $file;
    }
}

my $si = SSP2::Iter->new(
    ncols   => $ncols,
    nrows   => $nrows,
    files   => \@files,
    result  => [],
    cb_init => sub {
        my $self = shift;

        for ( my $i = 0; $i < @{ $self->files }; ++$i ) {
            $self->result->[$i] = {};
            for my $code ( $ss->codes ) {
                $self->result->[$i]{$code} = {
                    val => 0,
                    cnt => 0,
                };
            }
        }
    },
    cb => sub {
        my ( $self, $file_idx, $row, $col, $item ) = @_;

        return if $item == $self->ndv;

        my ( $code, $nm1, $nm2 ) = $ss->rowcol2info( $row, $col );
        return unless $code;

        $self->result->[$file_idx]{$code}{val} += $item;
        ++$self->result->[$file_idx]{$code}{cnt};
    },
    cb_final => sub {
        my $self = shift;

        #
        # daily sigungu avg
        #
        for ( my $i = 0; $i < @{ $self->files }; ++$i ) {
            for my $code ( $ss->codes ) {
                my $val = $self->result->[$i]{$code}{val};
                my $cnt = $self->result->[$i]{$code}{cnt};
                if ( $cnt > 0 ) {
                    $self->result->[$i]{$code}{avg} = $val / $cnt;
                }
                else {
                    $self->result->[$i]{$code}{avg} = undef;
                }
            }
        }

        #
        # write
        #
        my $output_path = path($output);
        $output_path->parent->mkpath;
        my $fh = $output_path->filehandle( ">", ":raw:encoding(UTF-8)" );
        print $fh join( "\t", $ss->daily_headers($year) ) . "\n";
        for my $code ( $ss->codes ) {
            my @items = ( $code, $ss->nm2($code), $ss->nm1($code) );
            for ( my $i = 0; $i < @{ $self->files }; ++$i ) {
                my $avg = $self->result->[$i]{$code}{avg};
                if ( defined $avg ) {
                    push @items, sprintf("%f", $avg);
                }
                else {
                    push @items, $self->ndv;
                }
            }
            print $fh join( "\t", @items ) . "\n";
        }
        close $fh;
    },
);

my $t0 = Benchmark->new;

$si->iter;

my $t1 = Benchmark->new;
my $td = timediff( $t1, $t0 );
print "elapsed time:", timestr($td), "\n";
