#! perl -w
use strict;
use FindBin;                # where was script installed?
use lib $FindBin::Bin;      # use that dir for libs, too
use tmstub;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);

#######################################################################
t "Tests for dtnd.pm";
use Test::More tests => 4;
use dtnd;
#######################################################################

is(dtnd::get_checksum_hex(''), '55', "checksum hex for empty string should be 55");
is(dtnd::get_checksum_hex(chr(0x01)), '56', "checksum hex for 0x01 string should be 56");
is(dtnd::get_checksum_hex(chr(0x01).chr(0x02)), '58', "checksum hex for 0x01.0x02 string should be 58");

# test wrap and escape
is(dtnd::escape_and_wrap(''), chr(0x01).chr(0x03), "wrap empty");



my $hex = dtnd::get_checksum_hex('1234');
t "checksum hex for '1234' string: ".d $hex;

my $head = "1234";

my $msg = "1  hello";

my $packdata = dtnd::make_display_message("1234", $msg);
t d $packdata;




