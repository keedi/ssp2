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

sub normalize_days {
    my $fmt = shift;

    my @result;
    my @day_max = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    for ( my $i = 0; $i < @day_max; ++$i ) {
        my $max = $day_max[$i];
        for my $day ( 1 .. $day_max[$i] ) {
            push @result, sprintf( $fmt, $i + 1, $day );
        }
    }

    return @result;
}

sub month_days {
    my @months = @_;

    my @result;
    my @day_max = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
    for my $month (@months) {
        unless ( 1 <= $month && $month <= 12 ) {
            push @result, 0;
            next;
        }
        push @result, $day_max[ $month - 1 ];
    }

    return wantarray ? @result : $result[0];
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

=func normalize_month_day
