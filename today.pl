#! perl -w
use strict;
use FindBin;                # where was script installed?
use lib $FindBin::Bin;      # use that dir for libs, too
use tmstub;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);

use Win32::Clipboard;

use Date::Manip qw(ParseDate UnixDate Date_Init);
Date_Init("TZ=GMT");

# Monday November 15 2010
my $t = UnixDate("today", "%A %B %d %Y");
t $t;
Win32::Clipboard::Set($t);
