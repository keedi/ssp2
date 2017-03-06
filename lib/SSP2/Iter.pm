package SSP2::Iter;
# ABSTRACT: SSP2 iter

use utf8;

use Moo;
use Types::Standard qw( ArrayRef CodeRef Int );
use Types::Path::Tiny qw( File );

use SSP2::Util;

our $VERSION = '0.001';

has ndays    => ( is => "ro",  isa => Int, required => 1 );
has nrows    => ( is => "ro",  isa => Int, required => 1 );
has ncols    => ( is => "ro",  isa => Int, required => 1 );
has files    => ( is => "ro",  isa => ArrayRef[File], coerce => 1, required => 1 );
has headers  => ( is => "rwp", isa => ArrayRef );
has cb_init  => ( is => "rw",  isa => CodeRef );
has cb_final => ( is => "rw",  isa => CodeRef );
has cb       => ( is => "rw",  isa => CodeRef );
has ndv      => ( is => "rwp", isa => Int );
has result   => ( is => "rw" );

sub iter {
    my $self = shift;

    $self->cb_init->($self) if $self->cb_init;

    for my $file ( @{ $self->files } ) {
        warn "processing $file\n";;

        die "file does not exists: $file\n" unless $file->exists;
        my $fh = $file->filehandle( "<", ":raw:encoding(UTF-8)" );

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
		$self->_set_headers( [] );
        while (<$fh>) {
            SSP2::Util::portable_chomp();

            if ( m/$regex_kv/ ) {
                my $k = $1;
                my $v = $2;
                $header{$k} = $v;
                push @{ $self->headers }, $_;
                $self->_set_ndv($v) if $k eq "NODATA_value";
                next;
            }

            my @items = split;
            my $cols = @items;
            die( sprintf "invalid cols row(%d): %d == %d", $rows, $cols, $self->ncols )
                unless $cols == $self->ncols;

            $cols = 0;
            for my $item (@items) {
                $self->cb->( $self, $rows, $cols, $item ) if $self->cb;
                ++$cols;
            }

            ++$rows;
        }

        die( sprintf "invalid ncols: %d == %d\n", $self->ncols, $header{ncols} )
            unless $self->ncols == $header{ncols};
        die( sprintf "invalid nrows: %d == %d\n", $self->nrows, $header{nrows} )
            unless $self->nrows == $header{nrows};

        close $fh;
    }

    $self->cb_final->($self) if $self->cb_final;
}

1;

# COPYRIGHT

__END__

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...


=attr ndays

=attr nrows

=attr ncols

=attr files

=attr headers

=attr cb_init

=attr cb_final

=attr cb

=attr result

=method iter
