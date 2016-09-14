#! perl -w
use strict;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);
use tmstub;
use bits;
use File::Slurp;
#
my $file = "lee_font.txt";

# merge in Pic Line font if required...
my $picfont = read_picfont("picfont1.txt");

t "reading $file";
my $t = read_file($file);
die unless $t;
t "OK";
# need this quick fix...
$t =~ s/\n\n\n+/\n\n/g;
# get as a nice list...
my @aa = split "\n\n", $t;
# grab parameters from heading...
my $info = shift @aa;
my %config = $info =~ /^(\w+)=(.+)$/mg ;
#t d \%config;
if(not defined $config{'InterCharacterGap'}){
    die "'InterCharacterGap' not defined in start of font file\n";
}
my $icg = $config{'InterCharacterGap'};
#t "InterCharacterGap = ".d $icg;
t "static const int inter_char_gap = $icg;";
#t d \@aa;
# create quick hash 
my %chars = (@aa);
#t d \%chars;
# convert hash back into a list - split the key by commas
my @v;
@aa = map{ @v = split ",", $_, 4; [ @v, $chars{$_}] } keys %chars;
#t d \@aa;
undef %chars;
my %widths;
my %bms;
my %infos;
foreach(@aa){
    # my($anum, $width, $height, $char, $bm) = @$_;
    proc_char(@$_);
}

merge_picfont($picfont);

my @ks = sort keys %chars;

my $inf = join("\n", map {$infos{$_ }} @ks);
t $inf;

my $out = "uint8_t charfontwidths[] = {\n";
foreach(@ks){
    $out.= $widths{$_}.", ";
}
$out.=  "\n};\n";
t $out;

t "uint16_t charfontdata[] = {";
foreach(@ks){
    t $chars{$_};
    t join "\n", map{ sprintf("    %s,", $_)} @{$bms{$_}};
}
t "};";


# output a C source 2D array
sub proc_char
{
     my($anum, $width, $height, $char, $bm) = @_;
     $anum =~ s/^(\d+)$/$1/;
     $char =~ s/^"(.)"\n.*/$1/;
    # t d [$anum, $char];
    
    my $key = sprintf("chr_%03d",$anum);
    
    my $out = sprintf "    // ASCII char %3d, 0x%02X  = '%s' width: %2d ", $anum, $anum, $char, $width;
#    t $out;
    $infos{$key} = $out;
    
    # get the bitmap and slice and dice
    my $nice = $bm;
    $nice =~ tr/01/.#/;
    $nice =~ s/^/    \/\/ /gm;
#    t $nice;

    # use the bitmap to create hex representations
    my @rows = split /^/, $bm;
    @rows = grep{ chomp; length } @rows;
    # pad out to 16 bits width
    @rows = map { binpad16($_) } @rows;
    #t $out.d \@rows;
    my @hex = map { sprintf("0x%04X", bin2dec($_))} @rows;
    my $hex = join(", ", @hex);
    $chars{$key} = join "\n", $out, $nice;
    $widths{$key} = $width;
    $bms{$key} = [@hex];
}

sub merge_picfont {
    my $picfont = shift;
    return unless $picfont; 
    foreach(keys %$picfont){
        my $k = $_;
        my $obj = $picfont->{$k};
        $infos{$k} = $obj->{info};
        $chars{$k} = join "\n",  $obj->{info}, $obj->{nice};
        $widths{$k} =  $obj->{width};
        $bms{$k} =$obj->{hexi};
    }

}


## pad out the given binary number to 16 bits wide
sub binpad16 {
    return substr( shift."0" x 16, 0, 16);
}
## get decimal value of given binary string (max 32 bits)
sub bin2dec {
    return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub read_picfont {
    my $file = shift;
    return unless $file;
    t "read_picfont $file";
    my $t = read_file($file);
    die unless $t;
    t "OK";
    # need this quick fix...
    $t =~ s/\n\n\n+/\n\n/g;
    # get as a nice list...
    my @aa = split "\n\n", $t;
    
    @aa = grep{ chomp; s/^\s+//; s/\s+$//; length; } @aa;
    #t d \@aa;
    my $ret = {};
    my @defs;
    my $c = ord("@");
    foreach(@aa){
        if(/^ASCII (.)$/){
            $c = ord($1);
            t "ascii change to $c = ".chr($c);
            next;
        }
        t "ascii val for $c = ".chr($c);
        my $key = sprintf("chr_%03d",$c);
        
        # split 
        # get the bitmap and slice and dice
        my $bm = $_;
        $bm =~ tr/ /v/; $bm =~ s/v//gm;
        my $nice = $bm;
        
        $nice =~ tr/01/.#/;
        $nice =~ s/^/    \/\/ /gm;
        #t $nice;

        # use the bitmap to create hex representations
        my @rows = split /^/, $bm;
        @rows = grep{ chomp; length } @rows;
        
        my $w = length($rows[0]);
        #t "width = $w ????";
        # pad out to 16 bits width
        @rows = map { binpad16($_) } @rows;
        #t d \@rows;
        my @hex = map { sprintf("0x%04X", bin2dec($_))} @rows;
        my $inf = sprintf "    // ASCII char %3d, 0x%02X  = '%s' width: %2d ", $c, $c, chr($c), $w;
#    t $out;
        my $info = {
            achar => $c,
            key => $key,
            nice => $nice,
            hexi => [@hex],
            width => $w,
            info => $inf, 
        };
        $ret->{$key} = $info;
        $c++;
    }
    return $ret;
}

