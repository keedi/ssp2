package SSP2::Util;
# ABSTRACT: SSP2 util

use utf8;
use strict;
use warnings;

our $VERSION = '0.001';

sub portable_chomp {
    my $regex = qr/(?:\x{0d}?\x{0a}|\x{0d})$/;

    if ( defined wantarray ) {
        my $count = 0;
        $count += ( @_ ? ( map { s!$regex!!g } @_ ) : s!$regex!!g );
        return $count;
    }
    else {
        @_ ? do { s!$regex!!g for @_ } : s!$regex!!g;
        return;
    }
}

1;

# COPYRIGHT

__END__

=for Pod::Coverage BUILDARGS

=head1 SYNOPSIS

    ...


=head1 DESCRIPTION

...


=func portable_chomp
