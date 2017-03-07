package SSP2::Log;
# ABSTRACT: SSP2 log

use utf8;

use Moo;
use Types::Path::Tiny qw( Path );

use Time::Piece;

our $VERSION = '0.001';

has file => ( is => "ro", isa => Path, coerce => 1, required => 1 );

sub debug { shift->_logging( "debug", @_ ) }
sub info  { shift->_logging( "info",  @_ ) }
sub warn  { shift->_logging( "warn",  @_ ) }
sub error { shift->_logging( "error", @_ ) }

sub _logging {
    my ( $self, $level, $fmt, @params ) = @_;

    my $t = localtime;
    my $prefix = sprintf( "[%s] [%s] ", $t->datetime, $level );

    $self->file->touchpath;
    my $fh = $self->file->filehandle( ">>", ":raw:encoding(UTF-8)" );

    my $msg = sprintf $fmt, @params;

    print STDOUT $prefix, $msg, "\n";
    print $fh $prefix, $msg, "\n";

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

=method info

=method warn

=method error
