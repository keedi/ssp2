package SSP2::Sigungu;
# ABSTRACT: SSP2 siguntu

use utf8;

use Moo;
use Types::Standard qw( ArrayRef HashRef Int );
use Types::Path::Tiny qw( File );

use Encode;

use SSP2::Iter;
use SSP2::Util;

our $VERSION = '0.001';

has nrows         => ( is => "ro", isa => Int,  required => 1 );
has ncols         => ( is => "ro", isa => Int,  required => 1 );
has info_file     => ( is => "ro", isa => File, coerce   => 1, required => 1 );
has boundary_file => ( is => "ro", isa => File, coerce   => 1, required => 1 );

has _info     => ( is => "rwp", isa => HashRef );
has _boundary => ( is => "rwp", isa => ArrayRef );

sub BUILD {
    my $self = shift;

    $self->_process_info;
    $self->_process_boundary;
}

sub codes { sort { $a <=> $b } keys %{ $_[0]->_info } };
sub nm1   { $_[0]->_info->{$_[1]}{nm1} };
sub nm2   { $_[0]->_info->{$_[1]}{nm2} };

sub rowcol2info {
    my ( $self, $row, $col ) = @_;

    return unless 0 <= $row && $row < $self->nrows;
    return unless 0 <= $col && $col < $self->ncols;

    return unless $self->_boundary;
    return unless $self->_info;

    my $ucc_code = $self->_boundary->[$row][$col];
    return unless $ucc_code;
    return unless $self->_info->{$ucc_code};

    my $nm1 = $self->_info->{$ucc_code}{nm1};
    my $nm2 = $self->_info->{$ucc_code}{nm2};

    return ( $ucc_code, $nm1, $nm2 );
}

sub _process_info {
    my $self = shift;

    $self->_set__info( +{} );

    my $fh = $self->info_file->filehandle( "<", ":raw:encoding(cp949)" );
    while (<$fh>) {
        SSP2::Util::portable_chomp();

        my $line = Encode::decode_utf8( Encode::encode_utf8($_) );

        next if $line =~ /^UCC_CODE/;

        my ( $code, $nm1, $nm2 ) = split /\t/, $line;
        next unless $code;

        $self->_info->{$code} = {
            nm1 => $nm1,
            nm2 => $nm2,
        };
    }
}

sub _process_boundary {
    my $self = shift;

    my $si = SSP2::Iter->new(
        ncols   => $self->ncols,
        nrows   => $self->nrows,
        files   => [ $self->boundary_file ],
        result  => [],
        cb_init => sub {
            my $self = shift;

            for ( my $i = 0; $i < $self->nrows; ++$i ) {
                $self->result->[$i] = [];
                for ( my $j = 0; $j < $self->ncols; ++$j ) {
                    $self->result->[$i][$j] = undef;
                }
            }
        },
        cb => sub {
            my ( $self, $file_idx, $row, $col, $item ) = @_;

            return if $item == $self->ndv;

            $self->result->[$row][$col] = $item;
        },
    );
    $si->iter;

    $self->_set__boundary( $si->result );
}

sub daily_headers {
    my ( $self, $year ) = @_;

    my @headers = (
        "시군구코드",
        "시군구",
        "시도", 
    );

    my @ssp2_day_max = SSP2::Util::month_days( 1 .. 12 );
    for ( my $i = 0; $i < @ssp2_day_max; ++$i ) {
        my $max = $ssp2_day_max[$i];
        for my $day ( 1 .. $ssp2_day_max[$i] ) {
            if ($year) {
                push(
                    @headers,
                    sprintf( "%04d-%02d-%02d", $year, $i + 1, $day ),
                );
            }
            else {
                push(
                    @headers,
                    sprintf( "%02d-%02d", $i + 1, $day ),
                );
            }
        }
    }

    return @headers;
}

1;

# COPYRIGHT

__END__

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...


=attr nrows

=attr ncols

=attr info_file

=attr boundary_file

=method codes

=method nm1

=method nm2

=method rowcol2info

=method daily_headers
