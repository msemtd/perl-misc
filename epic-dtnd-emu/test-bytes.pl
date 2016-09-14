#! perl -w
use strict;
use FindBin;                # where was script installed?
use lib $FindBin::Bin;      # use that dir for libs, too
use tmstub;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);

my $bytes = "0x5B, 0x7B, 0x49, 0x4F, 0x6C";

my @ba = map{s/,//; hex} split( / /, $bytes);

@ba = map{unpack( "B32", pack("N", $_))} @ba;
@ba = map{substr($_,24,8)} @ba;
@ba = map{reverse; $_} @ba;

t d \@ba;

t "Q".join( "", @ba);