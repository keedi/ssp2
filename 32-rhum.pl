#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Path::Tiny;

use SSP2::Iter;
use SSP2::Util;

my $data_dir = "W:/grid1kmData_ascii";
my $term     = "daily";
my $var      = "rhum";
my $year     = 2006;
my $ndays    = 365;
my $ncols    = 751;
my $nrows    = 601;
my $output   = "32-rhum.dat";

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
    ndays   => $ndays,
    ncols   => $ncols,
    nrows   => $nrows,
    files   => \@files,
    result  => [],
    cb_init => sub {
        my $self = shift;

        for ( my $i = 0; $i < $self->nrows; ++$i ) {
            $self->result->[$i] = [];
            for ( my $j = 0; $j < $self->ncols; ++$j ) {
                $self->result->[$i][$j] = {
                    val => 0,
                    cnt => 0,
                };
            }
        }
    },
    cb => sub {
        my ( $self, $rows, $cols, $item ) = @_;

        return if $item == $self->ndv;

        #
        # sum and count
        #
        $self->result->[$rows][$cols]{val} += $item;
        ++$self->result->[$rows][$cols]{cnt};
    },
    cb_final => sub {
        my $self = shift;

        #
        # avg
        #
        for ( my $i = 0; $i < $self->nrows; ++$i ) {
            for ( my $j = 0; $j < $self->ncols; ++$j ) {
                my $cnt = $self->result->[$i][$j]{cnt};
                my $val = $self->result->[$i][$j]{val};
                if ( $cnt > 0 ) {
                    $self->result->[$i][$j]{avg} = $val / $cnt;
                }
                else {
                    $self->result->[$i][$j]{avg} = undef;
                }
            }
        }

        #
        # write
        #
        my $fh = path($output)->filehandle( ">", ":raw:encoding(UTF-8)" );
        print $fh "$_\n" for @{ $self->headers };
        for ( my $i = 0; $i < $self->nrows; ++$i ) {
            for ( my $j = 0; $j < $self->ncols; ++$j ) {
                my $avg = $self->result->[$i][$j]{avg};
                if ( defined $avg ) {
                    printf $fh "%.2f", $avg;
                }
                else {
                    print $fh $self->ndv;
                }
                print $fh q{ };
            }
            print $fh "\n";
        }
    },
);

$si->iter;
