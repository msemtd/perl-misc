#! perl -w
use strict;

# Hot file handle magic...
select( ( select(STDERR), $| = 1 )[0] );
select( ( select(STDOUT), $| = 1 )[0] );
use tmstub;

my $time = time;

t "epoch time is currently $time";

my $loc = localtime($time);

t "local time is $loc";

$loc = localtime(0);

t "DYK? local time of zero is $loc (but that is when considered from the current rules)";
$loc = gmtime(0);
t "DYK? GMT time of zero is $loc";
t "On Jan 1st 1970, Great Britain was not using the GMT that we currently \n".
"use on that day - BST was in use!";
t "see http://en.wikipedia.org/wiki/British_Summer_Time#Periods_of_deviation";

t <<'EODAT';

In 1968, the clocks went forward as usual in March, but in the autumn, 
they did not return to Greenwich Mean Time. Britain had entered a three-year 
experiment, confusingly called British Standard Time, and stayed one hour 
ahead of Greenwich until 1971.

This was not the first experiment to shift the clocks in winter. In the 
Second World War (1939-45), Britain had adopted Double British Summer Time, 
with the clocks one hour ahead of Greenwich in winter and two hours ahead 
in summer.

When the British Standard Time experiment ended, the Home Office carried 
out an exhaustive review to find out whether it had been successful. 
The answer was both yes and no. There were ‘pros and cons’ to having the 
clocks forward and, on balance, the Government decided to return to the 
original British Summer Time.

http://hansard.millbanksystems.com/commons/1968/jan/23/british-standard-time-bill-lords

EODAT




