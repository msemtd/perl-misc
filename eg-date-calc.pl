#! perl -w
use strict;

# Hot file handle magic...
select( ( select(STDERR), $| = 1 )[0] );
select( ( select(STDOUT), $| = 1 )[0] );
use tmstub;


use Date::Manip;
my $err;
my $d =  DateCalc('2014-02-26', '+ 40weeks', \$err);


t "plus 40 weeks = ".d $d;
t "error = ". d $err;

exit;
