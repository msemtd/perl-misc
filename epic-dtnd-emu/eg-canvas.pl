#! perl -w
use strict;
use FindBin;                # where was script installed?
use lib $FindBin::Bin;      # use that dir for libs, too
use tmstub;
use aeglcd;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);


=for docs

The AEG GV10 LCD panel is used for the DTND 3 Digit Train Number
5 bytes of data with 2 bits used for backplane control (which need to be zero)

The AEG VN11 LCD glass is used for DTND 20 Character Destination Panels
60 segments requiring 8 bytes of data with 4 bits used for backplane
control (which need to be zero)

Here we define the segment geometry of both LCD panels in a graphical Tk Canvas.


=cut

my $glass_options = {
    GV10 => "38 seg font x3 chars train number |38|3",
    VN11 => "60 seg font x10 chars destination indicator |60|10",
    GV18 => "38 seg font x4 chars |38|4",
    GV17 => "38 seg font x?",
    GV19 => "38 seg font x?",
};

my $seg_vn11_defs = aeglcd::define_vn11_polygons();
my $seg_gv10_defs = aeglcd::define_gv10_polygons();

use Tk;
use Tk::Canvas;
use Tk::widgets qw/PNG/;
use Tk::Balloon;


my $mw = new MainWindow(-title => 'DTND Canvas');
my $fr1 = $mw->Frame()->pack(-side => 'top');

my $c = $fr1->Canvas(-width => 800, -height => 600, -bg => 'black')->pack(-side => 'left');
my $balloon = $mw->Balloon();

my @clrs = qw(red blue green yellow pink purple cyan magenta brown orange);
## for better or worse the square width and height and char gap are global
my $sqw = 50;
my $sqh = 50;
my $char_gap = 10;

#~ my $fig = $mw->Photo(-file => 'seg60_fig1.png');
#~ my $fig2 = $mw->Photo(-file => 'aeg-gv10-segs.png');
#~ $fr1->Label(-image => $fig)->pack(-side => 'left');
#~ $fr1->Label(-image => $fig2)->pack(-side => 'left');

populate();

my $segs_to_show = "50,53";
my $cellsize = $sqw;

my $fr = $mw->Frame()->pack(-side => 'bottom');
#~ $fr->Button(-text => "draw_gv10", -command => sub { draw_gv10() } )->pack(-side => 'left');


$fr->Button(-text => "populate", -command => sub { populate()} )->pack(-side => 'left');
$fr->Label(-text => "Show Segs:")->pack(-side => 'left');
$fr->Entry(-textvariable => \$segs_to_show)->pack(-side => 'left');
$fr->Button(-text=> "go", -command => sub { show_segs($segs_to_show)} )->pack(-side => 'left');
$fr->Label(-text => "Cell Size:")->pack(-side => 'left');
$fr->Entry(-textvariable => \$cellsize)->pack(-side => 'left');
$fr->Button(-text=> "go", 
    -command => sub { 
        return unless $cellsize =~ /\d+/;
        $sqw = $sqh = $cellsize;
        $char_gap = $sqw/5;
        populate();
    } )->pack(-side => 'left');
$fr->Button(-text => "GV10 seglist", -command => sub{ dump_gv10_seglist() })->pack(-side => 'left');
MainLoop();

sub dump_gv10_seglist {
    # get selected segments from the GV10 char
    my @segpolys = $c->find( 'withtag', 'gv10&&SEG_ON' );
    my @segs;
    foreach(@segpolys){
        my @taglist = $c->gettags($_);
        push @segs, grep (/^poly/, @taglist);
    }
    @segs = grep{s/^poly//;length} @segs;
    t "gv10 segs = @segs";
    

}

sub show_segs{
    my ($offx, $offy) = (100, 50);
    my $segs = shift;
    $c->delete('all');
    draw_vn11_cells($offx, $offy, 'grey');

    my @s = grep{ /\d+/ }split(/,/, $segs);
    foreach(@s){
        draw_vn11_seg($_, $offx, $offy);
    }
}


sub populate{
    $c->delete('all');
    my ($offx, $offy) = (70, 50);
    
    my @safe = ($sqw, $sqh, $char_gap);
    
    draw_vn11_char($offx, $offy);
    $offx += ($sqw *3) + $char_gap;
    draw_vn11_char($offx, $offy);
    $offx += ($sqw *3) + $char_gap;
    draw_vn11_char($offx, $offy);
    $offx += ($sqw *3) + ($char_gap*3);


    $sqw = 60;
    $sqh = 80;
    $char_gap = $sqw/5;

    draw_gv10_char($offx, $offy);
    
    # attach balloon to all segment items
    my $msghash = {};
    for(1..60){
        my $tag = sprintf("poly%02d",$_);
        $msghash->{$tag} = $tag;
    }
    $balloon->attach($c, -balloonposition => 'mouse', -msg => $msghash);
    $c->bind("vn11", "<Button-1>", sub{ toggle_seg_on_off() });
    $c->bind("gv10", "<Button-1>", sub{ toggle_seg_on_off() });

    ($sqw, $sqh, $char_gap) = @safe;
}

# segment on-off
# tag item as on with "SEG_ON"
sub toggle_seg_on_off {
    my ($id) = $c->find( 'withtag', 'current' );
    t "click_1: id = $id";
    my @taglist = $c->gettags($id);
    t "\t taglist =" . d \@taglist;
    
    # on or off?
    if(grep /^SEG_ON$/, @taglist ){
        $c->dtag($id, "SEG_ON");
        $c->itemconfigure($id, -fill => '');
    } else {
        $c->addtag("SEG_ON", "withtag", $id);
        $c->itemconfigure($id, -fill => 'yellow');
    }

}



sub draw_vn11_cells {
    my ($offx, $offy, $cell_clr) = @_;
    # 20 seg is 3x8 cells
    foreach my $x (0..2){
        foreach my $y (0..5){
            my $x1 = $offx + ($x * $sqw);
            my $x2 = $x1+$sqw;
            my $y1 = $offy + ($y * $sqh);
            my $y2 = $y1+$sqh;
            $c->createRectangle($x1, $y1, $x2, $y2, -outline => $cell_clr, -tags => ['cell']);
        }
    }
}

# draw numbered GV10 segment at tile offset
sub draw_gv10seg {
    my ($segnum, $offx, $offy) = @_;
    my $tag = sprintf("poly%02d",$segnum);
    my $s = $seg_gv10_defs->{$tag};
    return unless defined $s;
    my $pts = $s->{pts};
    my ($cx, $cy) = ($s->{cx}, $s->{cy});
    my $id = draw_poly($cx, $cy, $pts, $offx, $offy, 'orange');
    # give it a tag 
    $c->addtag($tag, withtag => $id);
    $c->addtag("gv10", withtag => $id);
}

# draw numbered VN11 segment at tile offset
sub draw_vn11_seg {
    my ($segnum, $offx, $offy) = @_;
    my $tag = sprintf("poly%02d",$segnum);
    my $s = $seg_vn11_defs->{$tag};
    return unless defined $s;
    my $pts = $s->{pts};
    my ($cx, $cy) = ($s->{cx}, $s->{cy});
    my $id = draw_poly($cx, $cy, $pts, $offx, $offy, 'magenta');
    # give it a tag
    $c->addtag($tag, withtag => $id);
    $c->addtag("vn11", withtag => $id);
}

# draw a single VN11 char from all 60 segments
sub draw_vn11_char {
    my ($offx, $offy) = @_;
    for(1..60){ draw_vn11_seg($_, $offx, $offy); }
}

# draw a single GV10 char from all 38 segments
sub draw_gv10_char {
    my ($offx, $offy) = @_;
    for(1..38){ draw_gv10seg($_, $offx, $offy); }
}

sub draw_poly {
    my ($cx, $cy, $pts, $offx, $offy, $clr) = @_;
    my $id = $c->createPolygon(@$pts, -outline => $clr, 
        -fill => 'black', -activefill => 'LightSeaGreen');
    # scale and translate the coords list
    $c->scale($id, 0, 0, $sqw, $sqh);
    $c->move($id, $offx + $cx * $sqw, $offy + $cy * $sqh);
    return $id;
}
