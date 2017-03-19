#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use feature qw( state );

use Benchmark;
use Path::Tiny;
use Try::Tiny;

use SSP2::Iter;
use SSP2::Log;
use SSP2::Sigungu;
use SSP2::Util;

local $| = 1;

my $log_file = shift;
die "Usage: $0 <log_file>\n" unless $log_file;

my $LOG = SSP2::Log->new( file => $log_file );

my @years = (
    2006 .. 2100,
);

for my $year (@years) {
    $LOG->info("processing $year");
    my $t0 = Benchmark->new;
    try {
        doit($year);
    }
    catch {
        $LOG->warn("caught error: $_");
    };
    my $t1 = Benchmark->new;
    my $td = timediff( $t1, $t0 );
    $LOG->info( "elapsed time: %s", timestr($td) );
}

sub doit {
    my $year = shift;

    return unless $year;

    my $data_dir = "W:/grid1kmData_ascii";
    my $term     = "daily";
    my $var      = "PM10";
    my $ndays    = 365;
    my $ncols    = 751;
    my $nrows    = 601;
    my $output   = "W:/ssp2/result/30-${var}/SSP2_${var}-1d-avg_daily_CityLevel_${year}_sub.csv";
    my $encoding = "cp949";
    my $csv_sep  = ",";

    if ( path($output)->is_file ) {
        $LOG->info("skip: $output file is already exists");
        return;
    }

    state $ss = SSP2::Sigungu->new(
        ncols         => $ncols,
        nrows         => $nrows,
        info_file     => "W:/define/sigungu230_info.txt",
        boundary_file => "W:/define/sigungu230_boundary.txt",
    );

    my @files;
    {
        my $file_fmt = sprintf(
            "%s/%s/%s/%d/ssp2_%s_%s_%d%%s_1kmgrid.txt",
            $data_dir,
            $term,
            $var,
            $year,
            lc($var),
            $term,
            $year,
        );

        for my $md ( SSP2::Util::normalize_days("%02d%02d") ) {
            my $file = sprintf( $file_fmt, $md );
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
        cb_file_init => sub {
            my ( $self, $file_idx, $file ) = @_;

            #
            # debug log
            #
            $LOG->debug("processing $file");
        },
        cb_file_retry => sub {
            my ( $self, $file_idx, $file, $retry, $msg ) = @_;

            $LOG->warn($msg);
            $LOG->debug( "retry(%d/%d): $file", $retry, $self->retry );

            for my $code ( $ss->codes ) {
                $self->result->[$file_idx]{$code} = {
                    val => 0,
                    cnt => 0,
                };
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
            my $fh = $output_path->filehandle( ">", ":raw:encoding($encoding)" );
            print $fh join( $csv_sep, $ss->daily_headers($year) ) . "\n";
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
                print $fh join( $csv_sep, @items ) . "\n";
            }
            close $fh;
        },
    );

    $si->iter;
}
