#! perl -w
use strict;

# Hot file handle magic...
select( ( select(STDERR), $| = 1 )[0] );
select( ( select(STDOUT), $| = 1 )[0] );
use tmstub;
use bits;
use bmfont;
use File::Slurp;

=for docs

The Picadilly Line DI font is defined in a spreadsheet. OpenOffice is used to 
convert it to machine and human-readable text. This script converts the text 
to C code. An embedded default font is loaded first (see code) and then 
sequences of ASCII characters are overloaded from file. 

The C source code that is produced gives each row of pixels in each character 
as a 16 bit integer. The maximum width of a glyph is 16. The pixel bits are held
left-to-right MSB-to-LSB. An array of character widths is generated. 

The bmfont package contains a complete default font with characters ASCII 32 (space) to 
ASCII 126 (tilde).

Additional glyph definitions can be loaded from file and merged with the default 
font to replace characters but leaving a contiguous set of glyphs, i.e. with no gaps 
in the ASCII sequence.

=cut

sub generate_digit_font 
{
    my $t = read_file("digit-font-16-pixels.txt");
    die unless $t;
     $t = bmfont::trimmer($t);
    # replace multiple blank lines with single blanks...
    $t =~ s/\n\n\n+/\n\n/g;
    # get as a nice list...
    my @aa = split "\n\n", $t;
    @aa = grep { chomp; s/^\s+//; s/\s+$//; length; } @aa;
    # t d \@aa;
    my $i = 0;
    my @wid;
    foreach(@aa){
        my $bm = $_;
        tr/.#/01/;
        my @dat = bmfont::bitmap_geom($_, 1);
        #t d \@dat;
        push @wid, $dat[2];
        t "// bitmap for $i -- width = ".$dat[2];
        t $dat[3];
        t  $bm;
        $i++;
    }
    
    t "const uint8_t digitfontwidths[] = {".join(",",@wid)."};";
    exit;   
}



# TODO process args
my $file =
"C:\\projects\\DTND\\PIC Line demo\\DI Font (altered from Issue 1 23-10-2013).txt";

#my $output_c_source = "font_src_output.c";
my $output_c_source   = undef;
#my $kern_destinations = "C:\\projects\\DTND\\PIC Line demo\\destinations.txt";
#my $kern_destinations = "northernline-dest-20char.txt";
my $kern_destinations = undef;


my $f  = bmfont::proc_default_font( bmfont::default_font_text() );
my $t = read_file($file);
die unless $t;
my $f2 = bmfont::simple_font_interp($t);
my $s1 = bmfont::font_study($f2);
t d $s1;
$f = bmfont::merge_simple_fonts( $f, $f2 );

my $fullfont = bmfont::font_study( $f, "gethex" );
#t "---------------------------------------------------------";
#t d $fullfont;
#
#exit;

#my $out = bmfont::kern_bitmaps($fullfont,"L[1]eicest[1]er Squar[1]e");
#t d $out;
#exit;

if ($output_c_source) {
    my $s = bmfont::generate_source($fullfont);

    #t $s;
    write_file( $output_c_source, $s );
}

if ($kern_destinations) {
    my @dests = read_file($kern_destinations) or die;
    my @out;
    foreach(@dests){
        chomp;
        push @out,  bmfont::kern_text($fullfont,$_);
    }
    my $outfile = $kern_destinations."-kerned.txt";
    # write_file( "destination_kern.txt", @out );
    write_file( $outfile, @out );
}

#my $kern_bitmaps_as_tsv = undef;
# my $kern_bitmaps_as_tsv = "destination_kern.txt";
my $kern_bitmaps_as_tsv = "northernline-dest-20char.txt-kerned.txt";




if($kern_bitmaps_as_tsv) {
    my @dests = read_file($kern_bitmaps_as_tsv) or die;
    my @out;
    foreach(@dests){
        chomp;
        push @out,  bmfont::kern_bitmaps($fullfont,$_);
        push @out, "\n\n\n";
    }
    write_file( "destination_kern_tsv.txt", @out );
    
    # intersperse with tabs for easier spreadsheet import
    my $q = join "\n", @out;
    $q =~ tr/.#/vq/; 
    my $tsv = join "\t", split(//, $q);
    write_file( "destination_kern.tsv", "\t".$tsv);
    
}


