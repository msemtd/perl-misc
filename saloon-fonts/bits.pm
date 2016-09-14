#!/usr/bin/perl -w
use strict;
package bits;
#~ use tmstub;
###########################################################
# bit twiddling routines...
# get array of lowest n bits of a numeric value
# bits must be more than zero
sub get_bottom_n_bits {
    my $bits = shift;
    my $num = shift;
    my @bits = split //, unpack( "B32", pack("N", $num));
    return splice @bits, 0-$bits;
}
# takes an ascii representation of an unsigned binary number (up to 32 bits)
# and returns the decimal equivalent - leading zeros are not required
sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}
# takes an unsigned decimal number (up to 32 bit) and returns an ascii 
# representation of the number in unsigned binary - leading zeros are not returned
sub dec2bin {
    my $str = unpack("B32", pack("N", shift));
    $str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
    return $str;
}

1; # <-- return true