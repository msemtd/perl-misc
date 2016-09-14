#! perl -w
use strict;

# Hot file handle magic...
select( ( select(STDERR), $| = 1 )[0] );
select( ( select(STDOUT), $| = 1 )[0] );
use tmstub;

=for docs

Techniques when dealing with data in text files that you want to be both
human and machine readable.

The simplest scenario is where you have one type of data on individual lines. 
Simple use of regular IO filehandle reads.  

Another scenario is blocks of lines or paragraphs separated by blank lines. The blank lines may contain spaces and the paragraphs may be indented. Trailing space might be present too because as far as the human reader/writer is concerned those lines ARE blank. 


=cut

## Strips leading and trailing space from all lines in the given text.
## Possibly not the most efficient but it retains newlines.
sub trimmer {
    my $t = shift;
    my @r = split /^/, $t;
    @r = map { chomp; s/^\s+//; s/\s+$//; $_ } @r;
    $t = join "\n", @r;
    return $t;
}

## Strips leading and trailing space from all lines in the given text.
## Empty lines are lost!
sub trimmer2 {
    my $t = shift;
    $t =~ s/^\s+//gm;
    $t =~ s/\s+$//gm; 
    return $t;
}

## Blank lines mark the boundary between blocks of non-blank lines.
sub split_paras {
    my $t = shift;
    # trim lines...
    $t = trimmer($t);
    # replace multiple blank lines with single blanks...
    $t =~ s/\n\n\n+/\n\n/g;
    # get as a nice list...
    my @aa = split "\n\n", $t;
    return @aa;
}

test_trimmers();

sub test_trimmers {
    
    my $t = <<'EOT';
    
    
          This is some indented text. E1RL78 Connection can fail.
            Failure to connect can be caused if an area of flash used    
            by the debugger gets corrupted.
            
            
            This can be worked around by setting the debugger configuration / 
            connection settings tab option "Erase Flash ROM When starting" to Yes.
            Once connection is established OK, the option can be reset to No.
            No entry of Hello world project under Executable project.
            The HEW project importer does not import the linkage order from HEW. 
            
            e2 studio does not have the facility to define the linkage order.
            SHC: 'Output file type':-code=asmcode differences for per file v/s     
            project settings.
            
            The range button is available on the Eventpoints Data Access Settings
             tab of an OA address point even though these eventpoints are
              unavailable on the SH target.             
              
                                      
                                      
            Trace Fill until Full or Stop has no effect for some SH targets. 
            
    
EOT
    
    # trimmer2 doesn't retain newlines!
    my $t2 = trimmer2($t);
#    t d $t2;
    
    my $t1 = trimmer($t);
#    t d $t1;
    
    my @paras = split_paras($t);
    t d \@paras;
    
}

