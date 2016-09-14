#!/usr/bin/perl -w
use strict;
package aeglcd;

# Defines the geometry for certain AEG LCD segment panels.
#
# Each segment is defined within in a 1x1 cell.

#~ The bit pattern of the segments 8 bytes of data is as shown in Table 1.
#~ Byte Bit 7 Bit 6 Bit 5 Bit 4 Bit 3 Bit 2 Bit 1 Bit 0
#~ 0 BP BP BP BP 51 40 52 60
#~ 1 59 54 55 53 44 45 43 42
#~ 2 41 28 32 33 31 30 29 16
#~ 3 20 21 19 9 7 6 8 18
#~ 4 17 5 15 14 13 4 2 1
#~ 5 3 11 10 12 27 26 25 23
#~ 6 22 24 39 38 37 35 34 36
#~ 7 47 46 48 57 56 49 50 58


#########################################################
# AEG VN11 has 5x 60 segment characters
# 3x6 cells
#
# The prototypes for segment shapes could be simplified further by adding 
# reflections: -
#   flip in the X direction is px = 1 - px
#   flip in the Y direction is py = 1 - py
sub define_vn11_polygons {
    # define some segment shape prototypes...
    my $p = {
        left_triangle => [0,0 , 0.5, 0.5, 0, 1],
        upper_triangle => [0,0 , 0.5, 0.5, 1, 0],
        lower_triangle => [0,1 , 0.5, 0.5, 1, 1],
        right_triangle => [1,0 , 0.5, 0.5, 1, 1],
        box => [0,0,0,1,1,1,1,0], # e.g. 5
        ll_triangle => [0,0,0,1,1,1], # e.g. 56
        ur_triangle => [0,0,1,0,1,1], # e.g. 57
        ul_triangle => [0,0,1,0,0,1], # e.g. 59
        lr_triangle => [1,0,1,1,0,1], # e.g. 60
        funny_50 => [0,0, 0.5, 1, 1, 0, 1, 1, 0, 1], # 50
        funny_51 => [0,0, 1,0, 0.5, 1], # e.g.  51
    };
    my $hashref = {
        poly01 => { cx => 0, cy => 0, pts => $p->{left_triangle}},
        poly02 => { cx => 0, cy => 0, pts => $p->{upper_triangle}},
        poly03 => { cx => 0, cy => 0, pts => $p->{lower_triangle}},
        poly04 => { cx => 0, cy => 0, pts => $p->{right_triangle}},
        poly05 => { cx => 1, cy => 0, pts => $p->{box}},
        poly06 => { cx => 2, cy => 0, pts => $p->{left_triangle}},
        poly07 => { cx => 2, cy => 0, pts => $p->{upper_triangle}},
        poly08 => { cx => 2, cy => 0, pts => $p->{lower_triangle}},
        poly09 => { cx => 2, cy => 0, pts => $p->{right_triangle}},

        poly10 => { cx => 0, cy => 1, pts => $p->{left_triangle}},
        poly11 => { cx => 0, cy => 1, pts => $p->{upper_triangle}},
        poly12 => { cx => 0, cy => 1, pts => $p->{lower_triangle}},
        poly13 => { cx => 0, cy => 1, pts => $p->{right_triangle}},
        
        poly14 => { cx => 1, cy => 1, pts => $p->{left_triangle}},
        poly15 => { cx => 1, cy => 1, pts => $p->{upper_triangle}},
        poly16 => { cx => 1, cy => 1, pts => $p->{lower_triangle}},
        poly17 => { cx => 1, cy => 1, pts => $p->{right_triangle}},

        poly18 => { cx => 2, cy => 1, pts => $p->{left_triangle}},
        poly19 => { cx => 2, cy => 1, pts => $p->{upper_triangle}},
        poly20 => { cx => 2, cy => 1, pts => $p->{lower_triangle}},
        poly21 => { cx => 2, cy => 1, pts => $p->{right_triangle}},

        poly22 => { cx => 0, cy => 2, pts => $p->{left_triangle}},
        poly23 => { cx => 0, cy => 2, pts => $p->{upper_triangle}},
        poly24 => { cx => 0, cy => 2, pts => $p->{lower_triangle}},
        poly25 => { cx => 0, cy => 2, pts => $p->{right_triangle}},

        poly26 => { cx => 1, cy => 2, pts => $p->{left_triangle}},
        poly27 => { cx => 1, cy => 2, pts => $p->{upper_triangle}},
        poly28 => { cx => 1, cy => 2, pts => $p->{lower_triangle}},
        poly29 => { cx => 1, cy => 2, pts => $p->{right_triangle}},
        
        poly30 => { cx => 2, cy => 2, pts => $p->{left_triangle}},
        poly31 => { cx => 2, cy => 2, pts => $p->{upper_triangle}},
        poly32 => { cx => 2, cy => 2, pts => $p->{lower_triangle}},
        poly33 => { cx => 2, cy => 2, pts => $p->{right_triangle}},

        poly34 => { cx => 0, cy => 3, pts => $p->{left_triangle}},
        poly35 => { cx => 0, cy => 3, pts => $p->{upper_triangle}},
        poly36 => { cx => 0, cy => 3, pts => $p->{lower_triangle}},
        poly37 => { cx => 0, cy => 3, pts => $p->{right_triangle}},
        poly38 => { cx => 1, cy => 3, pts => $p->{left_triangle}},
        poly39 => { cx => 1, cy => 3, pts => $p->{upper_triangle}},
        poly40 => { cx => 1, cy => 3, pts => $p->{lower_triangle}},
        poly41 => { cx => 1, cy => 3, pts => $p->{right_triangle}},
        poly42 => { cx => 2, cy => 3, pts => $p->{left_triangle}},
        poly43 => { cx => 2, cy => 3, pts => $p->{upper_triangle}},
        poly44 => { cx => 2, cy => 3, pts => $p->{lower_triangle}},
        poly45 => { cx => 2, cy => 3, pts => $p->{right_triangle}},

        poly46 => { cx => 0, cy => 4, pts => $p->{left_triangle}},
        poly47 => { cx => 0, cy => 4, pts => $p->{upper_triangle}},
        poly48 => { cx => 0, cy => 4, pts => $p->{lower_triangle}},
        poly49 => { cx => 0, cy => 4, pts => $p->{right_triangle}},

        poly50 => { cx => 1, cy => 4, pts => $p->{funny_50}},
        poly51 => { cx => 1, cy => 4, pts => $p->{funny_51}},

        poly52 => { cx => 2, cy => 4, pts => $p->{left_triangle}},
        poly53 => { cx => 2, cy => 4, pts => $p->{upper_triangle}},
        poly54 => { cx => 2, cy => 4, pts => $p->{lower_triangle}},
        poly55 => { cx => 2, cy => 4, pts => $p->{right_triangle}},

        poly56 => { cx => 0, cy => 5, pts => $p->{ll_triangle}},
        poly57 => { cx => 0, cy => 5, pts => $p->{ur_triangle}},
        poly58 => { cx => 1, cy => 5, pts => $p->{box}},
        poly59 => { cx => 2, cy => 5, pts => $p->{ul_triangle}},
        poly60 => { cx => 2, cy => 5, pts => $p->{lr_triangle}},
    };
    return $hashref
}


#########################################################
# AEG GV10 has 3x 38 segment characters
# 3x5 cells
# corners have arc segments - some fancy bits!
# 3 Digit Train Number
# 5 bytes of data with 2 bits used for backplane control (data needs to be ‘0’)
sub define_gv10_polygons {
    # define some segment shape prototypes...
    my $p = {
        curve_1 => [qw( 0 0 1 0 0.5 0.1 0.25 0.25 0.1 0.5 0 1 )], # e.g. 1
        curve_2 => [qw( 1 1 1 0 0.5 0.1 0.25 0.25 0.1 0.5 0 1 )], # e.g. 2
        curve_4 => [qw( 0 0 0.5 0.1 0.75 0.25 0.9 0.5 1 1 0 1 )], # e.g. 4
        curve_5 => [qw( 0 0 0.5 0.1 0.75 0.25 0.9 0.5 1 1 1 0 )], # e.g. 5
        tri_25 => [qw( 0 0 0.5 1 0 1 )], # e.g. 25 
        pol_26 => [qw( 0 0 1 0 1 1 0.5 1 )], # e.g. 26
        pol_30 => [qw( 0 0 1 0 0.5 1 0 1 )], # e.g. 30
        tri_31 => [qw(  1 0 1 1 0.5 1 )], # e.g. 31
        tri_34 => [qw( 0.5 0 1 0 1 1 )], # e.g. 34
        tri_36 => [qw( 0 0 0.5 0 0 1 )], # e.g. 36
        curve_32 => [qw( 0 0  0.1 0.5 0.25 0.75 0.5 0.9 1 1 0 1)], # e.g. 32
        curve_33 => [qw( 0 0 0.5 0 1 1 0.5 0.9 0.25 0.75 0.1 0.5)], # e.g. 33
        curve_37 => [qw( 0.5 0 1 0 0.9 0.5 0.75 0.75 0.5 0.9 0 1)], # e.g. 37
        curve_38 => [qw(1 0 0.9 0.5 0.75 0.75 0.5 0.9 0 1 1 1)], # e.g. 37
        left_triangle => [0,0 , 0.5, 0.5, 0, 1],
        upper_triangle => [0,0 , 0.5, 0.5, 1, 0],
        lower_triangle => [0,1 , 0.5, 0.5, 1, 1],
        right_triangle => [1,0 , 0.5, 0.5, 1, 1],
        box => [0,0,0,1,1,1,1,0], # e.g. 5
        ll_triangle => [0,0,0,1,1,1], # e.g. 56
        ur_triangle => [0,0,1,0,1,1], # e.g. 57
        ul_triangle => [0,0,1,0,0,1], # e.g. 59
        lr_triangle => [1,0,1,1,0,1], # e.g. 60
        funny_50 => [0,0, 0.5, 1, 1, 0, 1, 1, 0, 1], # 50
        funny_51 => [0,0, 1,0, 0.5, 1], # e.g.  51
    };
    my $hashref = {
        poly01 => { cx => 0, cy => 0, pts => $p->{curve_1}},
        poly02 => { cx => 0, cy => 0, pts => $p->{curve_2}},
        poly03 => { cx => 1, cy => 0, pts => $p->{box}},
        poly04 => { cx => 2, cy => 0, pts => $p->{curve_4}},
        poly05 => { cx => 2, cy => 0, pts => $p->{curve_5}},
        poly06 => { cx => 0, cy => 1, pts => $p->{box}},
        poly07 => { cx => 1, cy => 1, pts => $p->{left_triangle}},
        poly08 => { cx => 1, cy => 1, pts => $p->{upper_triangle}},
        poly09 => { cx => 1, cy => 1, pts => $p->{right_triangle}},
        poly10 => { cx => 1, cy => 1, pts => $p->{lower_triangle}},
        poly11 => { cx => 2, cy => 1, pts => $p->{ul_triangle}},
        poly12 => { cx => 2, cy => 1, pts => $p->{lr_triangle}},
        poly13 => { cx => 0, cy => 2, pts => $p->{left_triangle}},
        poly14 => { cx => 0, cy => 2, pts => $p->{upper_triangle}},
        poly15 => { cx => 0, cy => 2, pts => $p->{right_triangle}},
        poly16 => { cx => 0, cy => 2, pts => $p->{lower_triangle}},
        poly17 => { cx => 1, cy => 2, pts => $p->{left_triangle}},
        poly18 => { cx => 1, cy => 2, pts => $p->{upper_triangle}},
        poly19 => { cx => 1, cy => 2, pts => $p->{right_triangle}},
        poly20 => { cx => 1, cy => 2, pts => $p->{lower_triangle}},
        poly21 => { cx => 2, cy => 2, pts => $p->{left_triangle}},
        poly22 => { cx => 2, cy => 2, pts => $p->{upper_triangle}},
        poly23 => { cx => 2, cy => 2, pts => $p->{right_triangle}},
        poly24 => { cx => 2, cy => 2, pts => $p->{lower_triangle}},
        poly25 => { cx => 0, cy => 3, pts => $p->{tri_25}},
        poly26 => { cx => 0, cy => 3, pts => $p->{pol_26}},
        poly27 => { cx => 1, cy => 3, pts => $p->{left_triangle}},
        poly28 => { cx => 1, cy => 3, pts => $p->{lower_triangle}},
        poly29 => { cx => 1, cy => 3, pts => $p->{ur_triangle}},
        poly30 => { cx => 2, cy => 3, pts => $p->{pol_30}},
        poly31 => { cx => 2, cy => 3, pts => $p->{tri_31}},
        poly32 => { cx => 0, cy => 4, pts => $p->{curve_32}},
        poly33 => { cx => 0, cy => 4, pts => $p->{curve_33}},
        poly34 => { cx => 0, cy => 4, pts => $p->{tri_34}},
        poly35 => { cx => 1, cy => 4, pts => $p->{box}},
        poly36 => { cx => 2, cy => 4, pts => $p->{tri_36}},
        poly37 => { cx => 2, cy => 4, pts => $p->{curve_37}},
        poly38 => { cx => 2, cy => 4, pts => $p->{curve_38}},
        
        # TODO complete!
    };
    return $hashref
}



1; # <-- success!
__END__


