package SSP2::Iter;
# ABSTRACT: SSP2 iter

use utf8;

use Moo;
use Types::Standard qw( ArrayRef CodeRef Int );
use Types::Path::Tiny qw( File );

use SSP2::Util;

our $VERSION = '0.001';

has nrows => ( is => "ro", isa => Int, required => 1 );
has ncols => ( is => "ro", isa => Int, required => 1 );
has files => ( is => "ro", isa => ArrayRef [File], coerce => 1, required => 1 );
has retry       => ( is => "ro", isa => Int, default => sub { 3 } );
has retry_delay => ( is => "ro", isa => Int, default => sub { 1 } );
has headers       => ( is => "rwp", isa => ArrayRef );
has cb_init       => ( is => "rw",  isa => CodeRef );
has cb_final      => ( is => "rw",  isa => CodeRef );
has cb_file_init  => ( is => "rw",  isa => CodeRef );
has cb_file_retry => ( is => "rw",  isa => CodeRef );
has cb            => ( is => "rw",  isa => CodeRef );
has ndv           => ( is => "rwp", isa => Int );
has result        => ( is => "rw" );

sub iter {
    my $self = shift;

    $self->cb_init->($self) if $self->cb_init;

    LOOP_FILE:
    for (
        my $file_idx = 0, my $retry = 0;
        $file_idx < @{ $self->files };
        ++$file_idx, $retry = 0
        )
    {
        my $file = $self->files->[$file_idx];

        $self->cb_file_init->( $self, $file_idx, $file ) if $self->cb_file_init;

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
        my $regex_kv    = qr/^($header_keys)\s+(\S+)$/;
        my $row         = 0;
        $self->_set_headers( [] );
        while (<$fh>) {
            SSP2::Util::portable_chomp();

            if (m/$regex_kv/) {
                my $k = $1;
                my $v = $2;
                $header{$k} = $v;
                push @{ $self->headers }, $_;
                $self->_set_ndv($v) if $k eq "NODATA_value";
                next;
            }

            my @items = split;
            my $ncols = @items;
            unless ( $ncols == $self->ncols ) {
                my $msg = sprintf(
                    "invalid ncols row(%d): %d == %d: %s",
                    $row,
                    $ncols,
                    $self->ncols,
                    $file
                );
                if ( $retry < $self->retry ) {
                    ++$retry;
                    if ( $self->cb_file_retry ) {
                        sleep $self->retry_delay if $self->retry_delay;
                        $self->cb_file_retry->( $self, $file_idx, $file, $retry, $msg )
                    }
                    close $fh;
                    redo LOOP_FILE;
                }
                else {
                    die $msg;
                }
            }

            my $col = 0;
            for my $item (@items) {
                $self->cb->( $self, $file_idx, $row, $col, $item ) if $self->cb;
                ++$col;
            }

            ++$row;
        }

        unless ( $self->ncols == $header{ncols} ) {
            die(
                sprintf(
                    "invalid ncols between attr and header: %d == %d: %s\n",
                    $self->ncols,
                    $header{ncols},
                    $file,
                )
            );
        }

        unless ( $self->nrows == $header{nrows} ) {
            die(
                sprintf(
                    "invalid nrows between attr and header: %d == %d: %s\n",
                    $self->nrows,
                    $header{nrows},
                    $file,
                )
            );
        }

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


=attr nrows

=attr ncols

=attr files

=attr retry

=attr retry_delay

=attr headers

=attr cb_init

=attr cb_final

=attr cb_file_init

=attr cb_file_retry

=attr cb

=attr ndv

=attr result

=method iter
