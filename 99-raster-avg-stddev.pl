#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Benchmark;
use Path::Tiny;
use Statistics::Basic;
use Try::Tiny;

use SSP2::Iter;
use SSP2::Log;

local $| = 1;

my $log_file      = shift;
my $output_avg    = shift;
my $output_stddev = shift;
my @files         = @ARGV;
die
    "Usage: $0 <log_file> <output_avg> <output_stddev> <raster_file1> [ <raster_file2> ... ]\n"
    unless $log_file && $output_avg && $output_stddev && @files;

my $LOG = SSP2::Log->new( file => $log_file );

{
    $LOG->info("processing avg & stddev");
    my $t0 = Benchmark->new;
    try {
        doit( $output_avg, $output_stddev, @files );
    }
    catch {
        $LOG->warn("caught error: $_");
    };
    my $t1 = Benchmark->new;
    my $td = timediff( $t1, $t0 );
    $LOG->info( "elapsed time: %s", timestr($td) );
}

sub doit {
    my ( $output_avg, $output_stddev, @files ) = @_;

    return unless @files;

    my $ncols    = 751;
    my $nrows    = 601;
    my $encoding = "cp949";

    my $si = SSP2::Iter->new(
        ncols   => $ncols,
        nrows   => $nrows,
        files   => \@files,
        result  => {
            cache  => [],
            avg    => [],
            stddev => [],
        },
        cb_init => sub {
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

            for ( my $row = 0; $row < $self->nrows; ++$row ) {
                $self->result->{cache}[$file_idx][$row] = [];
                for ( my $col = 0; $col < $self->ncols; ++$col ) {
                    $self->result->{cache}[$file_idx][$row][$col] = undef;
                }
            }
        },
        cb => sub {
            my ( $self, $file_idx, $row, $col, $item ) = @_;

            return if $item == $self->ndv;

            $self->result->{cache}[$file_idx][$row][$col] = $item;
        },
        cb_final => sub {
            my $self = shift;

            #
            # avg & stddev
            #
            for ( my $row = 0; $row < $self->nrows; ++$row ) {
                $self->result->{avg}[$row]    = [];
                $self->result->{stddev}[$row] = [];
                for ( my $col = 0; $col < $self->ncols; ++$col ) {
                    my @items;
                    for ( my $i = 0; $i < @{ $self->files }; ++$i ) {
                        my $item = $self->result->[$i][$row][$col];
                        next unless defined $item;
                        next if $item == $self->ndv;

                        push @items, $item;
                    }
                    if (@items) {
                        my $v = Statistics::Basic::vector(@items);
                        $self->result->{avg}[$row][$col]    = Statistics::Basic::mean($v)->query;
                        $self->result->{stddev}[$row][$col] = Statistics::Basic::stddev($v)->query;
                    }
                    else {
                        $self->result->{avg}[$row][$col]    = undef;
                        $self->result->{stddev}[$row][$col] = undef;
                    }
                }
            }
        },
    );

    $si->iter;

    #
    # write avg
    #
    unless ( path($output_avg)->is_file ) {
        write_grid_1km( $output_avg, $encoding, $si, $si->result->{avg} );
    }
    else {
        $LOG->info("skip: $output_avg file is already exists");
    }

    #
    # write stddev
    #
    unless ( path($output_stddev)->is_file ) {
        write_grid_1km( $output_stddev, $encoding, $si, $si->result->{stddev} );
    }
    else {
        $LOG->info("skip: $output_stddev file is already exists");
    }
}

sub write_grid_1km {
    my ( $output, $encoding, $si, $result ) = @_;

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
