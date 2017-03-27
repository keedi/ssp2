#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Benchmark;
use Path::Tiny;
use Statistics::Basic;
use Text::CSV;
use Try::Tiny;

use SSP2::Log;
use SSP2::Sigungu;

local $| = 1;

my $log_file      = shift;
my $output_avg    = shift;
my $output_stddev = shift;
my @files         = @ARGV;
die
    "Usage: $0 <log_file> <output_avg> <output_stddev> <csv_file1> [ <csv_file2> ... ]\n"
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

    my $ncols    = 365;
    my $nrows    = 230;
    my $encoding = "cp949";
    my $csv_sep  = ",";

    my $ss = SSP2::Sigungu->new(
        ncols         => 751,
        nrows         => 601,
        info_file     => "W:/define/sigungu230_info.txt",
        boundary_file => "W:/define/sigungu230_boundary.txt",
    );

    #
    # gather
    #
    my %result;
    for ( my $i = 0; $i < @files; ++$i ) {
        my $file = path($files[$i]);
        die "file does not exists: $file\n" unless $file->exists;
        my $fh = $file->filehandle( "<", ":raw:encoding($encoding)" );

        $LOG->info("processing $file");

        my $csv = Text::CSV->new(
            {
                binary   => 1,
                sep_char => $csv_sep,
            }
        ) or die "Cannot use CSV: " . Text::CSV->error_diag();

        my $headers = $csv->getline($fh);
        my $row = 0;
        while ( my $data = $csv->getline($fh) ) {
            my ( $code, $nm2, $nm1, @items ) = @$data;

            unless ( @items == $ncols ) {
                close $fh;
                die sprintf( "ncols is invalid: %s, row(%d)\n", $file, $row + 1 );
            }

            $result{$code} = [] unless defined $result{$code};
            for ( my $col = 0; $col < @items; ++$col ) {
                $result{$code}[$col] = [] unless defined $result{$code}[$col];
                push @{ $result{$code}[$col] }, $items[$col];
            }

            ++$row;
        }
        unless ( $csv->eof ) {
            close $fh;
            die sprintf( "csv error: %s, %s\n", $file, $csv->error_diag );
        }

        unless ( $row == $nrows ) {
            close $fh;
            die sprintf( "nrows is invalid: %s\n", $file );
        }

        close $fh;
    }

    #
    # calculate
    #
    $LOG->info("calculating...");
    my %result_avg    = ();
    my %result_stddev = ();
    for my $code ( $ss->codes ) {
        $result_avg{$code}    = [];
        $result_stddev{$code} = [];
        for ( my $col = 0; $col < $ncols; ++$col ) {
            my $v = Statistics::Basic::vector( $result{$code}[$col] );
            $result_avg{$code}[$col]    = Statistics::Basic::mean($v)->query;
            $result_stddev{$code}[$col] = Statistics::Basic::stddev($v)->query;
        }
    }

    #
    # write avg
    #
    $LOG->info("writing $output_avg");
    unless ( path($output_avg)->is_file ) {
        write_city( $output_avg, $encoding, $csv_sep, $ss, \%result_avg );
    }
    else {
        $LOG->info("skip: $output_avg file is already exists");
    }

    #
    # write stddev
    #
    $LOG->info("writing $output_stddev");
    unless ( path($output_stddev)->is_file ) {
        write_city( $output_stddev, $encoding, $csv_sep, $ss, \%result_stddev );
    }
    else {
        $LOG->info("skip: $output_stddev file is already exists");
    }
}

sub write_city {
    my ( $output, $encoding, $csv_sep, $ss, $result ) = @_;

    my $output_path = path($output);
    $output_path->parent->mkpath;
    my $fh = $output_path->filehandle( ">", ":raw:encoding($encoding)" );
    print $fh join( $csv_sep, $ss->daily_headers ) . "\n";
    for my $code ( $ss->codes ) {
        my @items = ( $code, $ss->nm2($code), $ss->nm1($code) );
        for my $item ( @{ $result->{$code} } ) {
            push @items, sprintf( "%f", $item );
        }
        print $fh join( $csv_sep, @items ) . "\n";
    }
    close $fh;
}
