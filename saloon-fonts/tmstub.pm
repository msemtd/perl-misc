package tmstub;
#
# MSEMTD - provides a modified subset of
# Log::TraceMessages by Ed Avis (epa98@doc.ic.ac.uk).
# Usually works under perl2exe on Win32.
#
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
require AutoLoader;
@ISA = qw(Exporter AutoLoader);
@EXPORT = qw(t d);
@EXPORT_OK = qw(t d);
use vars '$VERSION';
$VERSION = '1.0';
sub t(@) {
    foreach (@_) {
       print STDOUT "$_\n";
    }
}
sub d($) {
    require Data::Dumper;
    my $s = $_[0];
    my $d = Data::Dumper::Dumper($s);
    $d =~ s/^\$VAR1 =\s*//;
    $d =~ s/;$//;
    chomp $d;
    return $d;
}
1;
