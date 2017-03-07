package SSP2::Log;
# ABSTRACT: SSP2 log

use utf8;

use Moo;
use Types::Path::Tiny qw( Path );

use Time::Piece;

our $VERSION = '0.001';

has file => ( is => "ro", isa => Path, coerce => 1, required => 1 );

sub debug {
    my ( $self, @msgs ) = @_;

    my $t = localtime;
    my $prefix = sprintf( "[%s] [%s] ", $t->datetime, "debug" );

    $self->file->touchpath;
    my $fh = $self->file->filehandle( ">>", ":raw:encoding(UTF-8)" );

    print STDOUT $prefix, @msgs, "\n";
    print $fh $prefix, @msgs, "\n";

    close $fh;
}

1;

# COPYRIGHT

__END__

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...


=attr file

=method debug
