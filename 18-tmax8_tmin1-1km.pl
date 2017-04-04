#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Benchmark;
use Path::Tiny;
use Try::Tiny;

use SSP2::Iter;
use SSP2::Log;
use SSP2::Util;

local $| = 1;

my $log_file = shift;
die "Usage: $0 <log_file>\n" unless $log_file;

my $LOG = SSP2::Log->new( file => $log_file );

my @years = (
    2006 .. 2025,
    2046 .. 2065,
    2080 .. 2099,
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
    my $var1     = "tmax";
    my $var2     = "tmin";
    my $ndays    = 365;
    my $ncols    = 751;
    my $nrows    = 601;
    my $output   = "W:/ssp2/result/18-tmax8_tmin1/SSP2_tmax8_tmin1-1y-yearly_1km_${year}_sub.txt";
    my $encoding = "cp949";

    if ( path($output)->is_file ) {
        $LOG->info("skip: $output file is already exists");
        return;
    }

    my @files1;
    {
        my $file_fmt = sprintf(
            "%s/%s/%s/%d/ssp2_%s_%s_%d-%%03d_1kmgrid.txt",
            $data_dir,
            $term,
            $var1,
            $year,
            $var1,
            $term,
            $year,
        );

        #
        # skip unless 8 month
        #
        my $start = 0;
        my $end   = 0;
        map { $start += $_ } SSP2::Util::month_days( 1 .. 7 );
        map { $end   += $_ } SSP2::Util::month_days( 1 .. 8 );
        ++$start;

        for ( my $i = $start; $i <= $end; ++$i ) {
            my $file = sprintf( $file_fmt, $i );
            push @files1, $file;
        }
    }

    my @files2;
    {
        my $file_fmt = sprintf(
            "%s/%s/%s/%d/ssp2_%s_%s_%d-%%03d_1kmgrid.txt",
            $data_dir,
            $term,
            $var2,
            $year,
            $var2,
            $term,
            $year,
        );

        #
        # skip unless 1 month
        #
        my $start = 0;
        my $end   = 0;
        map { $start += $_ } SSP2::Util::month_days( 0 );
        map { $end   += $_ } SSP2::Util::month_days( 1 );
        ++$start;

        for ( my $i = $start; $i <= $end; ++$i ) {
            my $file = sprintf( $file_fmt, $i );
            push @files2, $file;
        }
    }

    my $cb_init = sub {
        my $self = shift;

        for ( my $i = 0; $i < @{ $self->files }; ++$i ) {
            $self->result->{cache}[$i] = [];
            for ( my $row = 0; $row < $self->nrows; ++$row ) {
                $self->result->{cache}[$i][$row] = [];
                for ( my $col = 0; $col < $self->ncols; ++$col ) {
                    $self->result->{cache}[$i][$row][$col] = undef;
                }
            }
        }
    };

    my $cb_file_init = sub {
        my ( $self, $file_idx, $file ) = @_;

        #
        # debug log
        #
        $LOG->debug("processing $file");
    };

    my $cb_file_retry = sub {
        my ( $self, $file_idx, $file, $retry, $msg ) = @_;

        $LOG->warn($msg);
        $LOG->debug( "retry(%d/%d): $file", $retry, $self->retry );

        for ( my $row = 0; $row < $self->nrows; ++$row ) {
            $self->result->{cache}[$file_idx][$row] = [];
            for ( my $col = 0; $col < $self->ncols; ++$col ) {
                $self->result->{cache}[$file_idx][$row][$col] = undef;
            }
        }
    };

    my $cb = sub {
        my ( $self, $file_idx, $row, $col, $item ) = @_;

        return if $item == $self->ndv;

        $self->result->{cache}[$file_idx][$row][$col] = $item;
    };

    my $cb_final = sub {
        my $self = shift;

        #
        # yearly 1km avg
        #
        my @result = ();
        for ( my $row = 0; $row < $self->nrows; ++$row ) {
            $result[$row] = [];
            for ( my $col = 0; $col < $self->ncols; ++$col ) {
                my $sum = undef;
                my $cnt = 0;
                for ( my $i = 0; $i < @{ $self->files }; ++$i ) {
                    my $item = $self->result->{cache}[$i][$row][$col];
                    next unless defined $item;
                    next if $item == $self->ndv;

                    $sum = 0 unless defined $sum;
                    $sum += $item;
                    ++$cnt;
                }
                if ( $cnt > 0 ) {
                    $result[$row][$col] = $sum / $cnt;
                }
                else {
                    $result[$row][$col] = undef;
                }
            }
        }
        $self->result->{final} = \@result;
    };

    my %common_params = (
        ncols         => $ncols,
        nrows         => $nrows,
        cb_init       => $cb_init,
        cb_file_init  => $cb_file_init,
        cb_file_retry => $cb_file_retry,
        cb            => $cb,
        cb_final      => $cb_final,
    );

    my $si_tmax8 = SSP2::Iter->new(    
        %common_params,
        files  => \@files1,
        result => {
            cache => [],
            final => [],
        },
    );
    $si_tmax8->iter;

    my $si_tmin1 = SSP2::Iter->new(
        %common_params,
        files  => \@files2,
        result => {
            cache => [],
            final => [],
        },
    );
    $si_tmin1->iter;

    my $grid_1km = si_subtract( $si_tmax8, $si_tmin1 );
    die "subtract tmax8, tmin1 failed\n" unless $grid_1km;

    write_grid_1km( $output, $encoding, $si_tmax8, $grid_1km );
}

sub si_subtract {
    my ( $si1, $si2 ) = @_;

    return unless $si1->nrows == $si2->nrows;
    return unless $si1->ncols == $si2->ncols;
    return unless $si1->result && $si1->result->{final};
    return unless $si2->result && $si2->result->{final};

    my @result = ();
    for ( my $row = 0; $row < $si1->nrows; ++$row ) {
        $result[$row] = [];
        for ( my $col = 0; $col < $si1->ncols; ++$col ) {
            my $val1 = $si1->result->{final}[$row][$col];
            my $val2 = $si2->result->{final}[$row][$col];

            if ( defined $val1 && defined $val2 ) {
                $result[$row][$col] = $val1 - $val2;
            }
            else {
                $result[$row][$col] = undef;
            }
        }
    }

    return \@result;
}

sub write_grid_1km {
    my ( $output, $encoding, $si, $result ) = @_;

    #
    # write
    #
    my $output_path = path($output);
    $output_path->parent->mkpath;
    my $fh = $output_path->filehandle( ">", ":raw:encoding($encoding)" );
    for my $header ( @{ $si->headers } ) {
        print $fh $header . "\n";
    }
    for ( my $row = 0; $row < $si->nrows; ++$row ) {
        for ( my $col = 0; $col < $si->ncols; ++$col ) {
            my $val = $result->[$row][$col];
            if ( defined $val ) {
                printf $fh "%f", $val;
            }
            else {
                print $fh $si->ndv;
            }
            print $fh q{ };
        }
        print $fh "\n";
    }
    close $fh;
}
