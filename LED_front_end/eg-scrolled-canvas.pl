#!perl
use strict;
use warnings;
use Tk;
use Tk::Balloon;
# Hot file handle magic...
select( ( select(STDERR), $| = 1 )[0] );
select( ( select(STDOUT), $| = 1 )[0] );
use tmstub;
# Construct GUI...
my $title = "Scrolled Canvas";
my $mw = new MainWindow( -title => $title );
# some game area geometry...
my $bg_border = 8;
my $bg_gap    = 5;
my $bg_lap    = 15;
my $card_w    = 73;
my $card_h    = 97;
my $bg_colour = '#008200';
# Icons...
my %pixmaps;
make_pixmaps( \%pixmaps );
$mw->Pixmap( 'dilbert',      -data => $pixmaps{'dilbert'} );
$mw->Pixmap( 'smalldilbert', -data => $pixmaps{'smalldilbert'} );
# Set the window-manager icon (possibly Win32 specific)...
$mw->Icon( -image => 'dilbert' );
# toolbar...
my $toolbar =
  $mw->Frame( -relief, 'raised', -borderwidth, 2 )->pack( -fill => 'x' );
$toolbar->Button( -text => 'Deal',
 #-command => \&deal 
 )->pack( -side => 'left' );
$toolbar->Button( -text => 'Test1', 
#-command => \&test1 
)->pack( -side => 'left' );
# Canvas...
my $c = $mw->Scrolled(
    'Canvas',
    -width        => 800,
    -height       => 600,
    -bg           => $bg_colour,
    -relief       => 'sunken',
    -borderwidth  => 2,
    -scrollbars   => 'osoe',
    -scrollregion => [qw/0 0 800 600/],
    -confine      => 'false',
)->pack( '-expand' => 'yes', -fill => 'both' );
# we need to get the proper canvas rather than the scrolled frame in order
# to do certain things with it...
$c = $c->Subwidget('canvas');
# Bottom frame - status bar...
my $statustext = $title;
my $fr2        =
  $mw->Frame( -relief, 'sunken', -borderwidth, 1 )->pack( -fill => 'x' );
$fr2->Label( -image        => 'smalldilbert' )->pack( -side => 'left' );
$fr2->Label( -textvariable => \$statustext )->pack( -side   => 'left' );

MainLoop();
####################################
#################################################
# Define some handy pixmap icons.
sub make_pixmaps {
    my $hash = shift;
    $hash->{"dilbert"} = <<"EOXPM";
/* XPM */
static char *dilbert[] = {
/* width height num_colors chars_per_pixel */
"    32    32       16      1",
/* colors */
"` c #000000",
". c #800000",
"# c #008000",
"a c #808000",
"b c #000080",
"c c #800080",
"d c #008080",
"e c #c0c0c0",
"f c #808080",
"g c #ff0000",
"h c #00ff00",
"i c #ffff00",
"j c #0000ff",
"k c #ff00ff",
"l c none",
"m c #ffffff",
/* pixels */
"llllllll````l`l``l`l````llllllll",
"lllllll`mimi`i`im`m`mimi`lllllll",
"llllllll``imimimimimim``llllllll",
"lllllllll`mimimimimimi`lllllllll",
"lllllllll`imimimimimim`lllllllll",
"lllllllll`mimimimimimi`lllllllll",
"lllllllll`imimimimimim`lllllllll",
"lllllllll`mim``im``imi`lllllllll",
"lllllllll`im`mm``mm`im`lllllllll",
"lllllll`l````mm``mm````l`lllllll",
"llllll`m``im`mm``mm`im``i`llllll",
"llllll`im`mim``im``imi`im`llllll",
"llllll`m``imimimimimim``i`llllll",
"lllllll`l`mimi`im`mimi`l`lllllll",
"lllllllll`imi`imim`mim`lllllllll",
"lllllllll`mim`mimi`imi`lllllllll",
"lllllllll`imi`imim`mim`lllllllll",
"lllllllll`mimi````mimi`lllllllll",
"lllllllll`imimimimimim`lllllllll",
"lllllllll`mimimimimimi`lllllllll",
"lllllllll`imimimimimim`lllllllll",
"lllllllll`mimimimimimi`lllllllll",
"lllllllll````mimimi````lllllllll",
"llllllll`mmmm``````mmmm`llllllll",
"llllllll```mmm````mmm```llllllll",
"lllllll`mmm````g`````mmm`lllllll",
"llllll`mmm`mmm`gg`mmmmmmm`llllll",
"lllll`mmm`g`mm``g`mmmmmmmm`lllll",
"llll`mmm`gg``m````mmmmmmmmm`llll",
"lll`mmmm`g`````g``mmmmmmmmmm`lll",
"ll`mmm`m````g``gg`mmmmmmm`mmm`ll",
"l`mmm`mm``````````mmmmmmmm`mmm`l"
};
EOXPM
    $hash->{"smalldilbert"} = <<"EOXPM";
/* XPM */
static char *smalldilbert[] = {
/* width height num_colors chars_per_pixel */
"    16    16       14      1",
/* colors */
"` c #000000",
". c #380000",
"# c #383800",
"a c #383838",
"b c #790000",
"c c #793838",
"d c #797938",
"e c #797979",
"f c none",
"g c #bebe38",
"h c #bebe79",
"i c #ffff79",
"j c #bebebe",
"k c #ffffff",
/* pixels */
"fff`dd##aadd`fff",
"ffff`iiiiii`ffff",
"ffff`iiiiii`ffff",
"ffff`ihghgi`ffff",
"fff``deeeed``fff",
"fffdaiededi#dfff",
"fffa`iighii`#fff",
"ffff`idiidi`ffff",
"ffff`igddhi`ffff",
"ffff`iiiiii`ffff",
"ffff`iiiiii`ffff",
"ffffaeedddeaffff",
"fff`eee.`eee`fff",
"ff`jjck.bkkkj`ff",
"f`jkb.a.`kkkkj`f",
"`jjj``...kkkjjj`"
};
EOXPM
}
__END__
