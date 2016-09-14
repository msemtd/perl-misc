#! perl -w
use strict;
use FindBin;                # where was script installed?
use lib $FindBin::Bin;      # use that dir for libs, too
use tmstub;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);

use dtnd;


my $res = dtnd::header("ABCD");
t d $res;
$res = dtnd::header("AD");
t d $res;
$res = dtnd::header("D");
t d $res;
$res = dtnd::header("");
t d $res;
$res = dtnd::header("1234");
t d $res;
$res = dtnd::header("12345");
t d $res;
$res = dtnd::header("\000\001\002\003\000");
t d $res;

my $msg = dtnd::make_poll_message("1234");
my @chars = map {sprintf "%02X", $_;} unpack "C*", $msg;
t "@chars";

# expect 56
my $h = dtnd::get_checksum_hex(chr(1));
t d $h;

my $d = dtnd::append_checksum_bytes('');

t d $d;
@chars = map {sprintf "%02X", $_;} unpack "C*", $d;
t "@chars";


__END__
sub get_checksum_hex {
    my $msg = shift;
    my @ba = unpack("C*", $msg);
    my $sum = 0x55;
    foreach(@ba){$sum += $_;}
    $sum &= 0xFF;
    return sprintf("%02X", $sum);
}

sub append_checksum_bytes {
    my $msg = shift;
    my $hex = get_checksum_hex($msg);
    my @ba = unpack("C*", $msg);
    push @ba, unpack("HH", $hex);
    return pack("C*", @ba);
}
