#!/usr/bin/perl -w
use strict;
package beautify;
#~ use tmstub;

sub beautify {
    return unless $^O eq 'linux';
    my $mw = shift;
    return unless -d $ENV{HOME}.'/.kde/';
=for interesting
          'GTK_RC_FILES' => '/etc/gtk/gtkrc:/home/mick/.gtkrc:/home/mick/.kde/share/config/gtkrc',
          'GTK2_RC_FILES' => '/etc/gtk-2.0/gtkrc:/home/mick/.gtkrc-2.0:/home/mick/.kde/share/config/gtkrc',
          'GS_LIB' => '/home/mick/.fonts',
          'KDE_FULL_SESSION' => 'true',
=cut

    my $beauty = {};
    # Under KDE we can use kreadconfig to get the configured fonts from kdeglobals...
    # fixed=Bitstream Vera Sans Mono,8,-1,5,50,0,0,0,0,0
    # font=Bitstream Vera Sans,10,-1,5,75,1,0,0,0,0
    # menuFont=Bitstream Vera Sans,8,-1,5,50,0,0,0,0,0
    # taskbarFont=Bitstream Vera Sans,8,-1,5,50,0,0,0,0,0
    # toolBarFont=Bitstream Vera Sans,8,-1,5,50,0,0,0,0,0
    #
    # Cool! It seems that the third field is a "style hint" (in my case -1), 
    # the 4th is the "char set" (in my case 5), 
    # the 5th is the weight (in my case 50 meaning medium), 
    # and the 6th part is "font bits" (in my case 0) 
    # documented in the link above. the remaining fields appear 
    # to be unused up to KDE3.3.
    foreach(qw(font fixed menuFont taskbarFont toolBarFont)){
        my $font = `kreadconfig --file kdeglobals --group General --key $_`;
        my @bits = split /,/, $font;
        my($face, $points, $weight,)  = (@bits)[0,1,4];
        $beauty->{$_} = [$face, $points, $weight];
    }
    # Set the font for the MainWindow...
    if($beauty && $beauty->{font}){
        #~ $mw->optionAdd('*Font' => '{'.$beauty->{font}->[0].'} '.$beauty->{font}->[1]);
    }
    # A global BorderWidth of one pixel looks nicer for a start...
    $mw->optionAdd('*BorderWidth' => 1);
    $ENV{beautify} = $beauty;
}

1; # <-- success!
