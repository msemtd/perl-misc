#!/usr/bin/perl -w
use strict;
use FindBin qw($Bin);
use lib "$Bin";
use tmstub;
use sock;
use prot_led_test;
use bits;
use IO::Handle;
use File::Slurp;
autoflush STDOUT 1;
autoflush STDERR 1;
#
use File::Slurp;

use Win32::SerialPort;
use Win32::TieRegistry;
use Win32::Clipboard;
#----------------------------------------------------------------------------
use Tk;
use Tk::Canvas;
use Tk::widgets qw/JPEG PNG/;
use Tk::Balloon;
# use Tk::ErrorDialog;
use Tk::DialogBox;
use Tk::BrowseEntry;
use Tk::LabEntry;
#----------------------------------------------------------------------------
my $model = {
    mw => undef,
    c => undef,
    title => 'KeTech LED Font Testbed 1',
    version => "v1.0 (20th Sep 3013)",
    
    serial=>{
        ob => undef,
        baud => 19200,
        withreader => 90,
        portname => "COM7",
        bgrtimer => undef,
        autostart => 0,
    },
    tcp=>{
        host => 'localhost',
        port => 49333,
    },
    geom => {
        gridx => 20,
        gridy => 20,
    },
    colours => {
        bg => "#1e501d",
        led_on => 'orange',
        led_off => '#4a4a4a',
        led_highlight => 'yellow',
        grid => '#000040',
        grid_bg => 'black',
    },
};
my $next_tcp_recover = 0;
my $destination = '';
#----------------------------------------------------------------------------
t "Hello";
make_gui();
MainLoop();

sub make_gui
{
    my $title = $model->{title};
    my $clr = $model->{colours};
    my $mw = new MainWindow(-title => $title);
    my $fr1 = $mw->Frame()->pack(-side => 'top'); 
    my $c = $fr1->Canvas(-width => 800, -height => 480, -bg => $clr->{bg})->pack(-side => 'left');
    my $balloon = $mw->Balloon();
    $mw->configure(-menu => my $menubar = $mw->Menu(-menuitems => &roll_menus));
    
    $model->{mw} = $mw;
    $model->{c} = $c;

    # Use a small delay before starting off features...
    $mw->after(500, sub{
        # set off reader timer...
        if($model->{serial}->{autostart}){
            ser::serial_start($model);
        }
        #open_file_from_commandline();
        my $host = $model->{tcp}->{host};
        my $port = $model->{tcp}->{port};
        sock::ss_setup($host,$port,\&{socket_hook}, $mw);
        bridge_launch();
    });
    my $recovertimer = $mw->repeat(1234 => \&recovery);
    draw_grid();
    {
        my $x = 600;
        my $y = 50;
        my $t = "COMMS: unknown";
        $c->createText($x, $y, 
            -fill => 'white', 
            -text => $t, 
            -tags => ['COMMS'],
        );
    }
    {
        my $c_button = $c->Button(-text => 'Request Glyph',
            -command => sub{glyph_request()});
        $c->createWindow(400, 50, -window => $c_button, qw/-anchor nw/);
        my $c_button2 = $c->Button(-text => 'Send Glyph',
            -command => sub{glyph_send()});
        $c->createWindow(400, 90, -window => $c_button2, qw/-anchor nw/);
        my $c_button5 = $c->Button(-text => 'Replace Glyph',
            -command => sub{glyph_replace()});
        $c->createWindow(400, 130, -window => $c_button5, qw/-anchor nw/);
        
        
        
        my @destinations = read_file("Destinations.txt");
        @destinations = grep{chomp; s/^\d+$//; length} @destinations;
        my $be = $c->BrowseEntry(-variable => \$destination, 
            -choices => \@destinations);
        $c->createWindow(400, 170, -window => $be, qw/-anchor nw/);
        
        my $c_button4 = $c->Button(-text => 'Send Destination',
            -command => \&send_destination);
        $c->createWindow(400, 200, -window => $c_button4, qw/-anchor nw/);

        my $c_button3 = $c->Button(-text => 'Default Text',
            -command => sub{ sock::ss_send("T:Default Text\r\n");});
        $c->createWindow(400, 240, -window => $c_button3, qw/-anchor nw/);
        
    }
}

sub send_destination
{
    t "$destination";
    sock::ss_send("T:".$destination."\r\n");
}

sub recovery
{
    # recover TCP comms
    # TODO start tcp serial bridge app
    # TODO show whether TCP serial bridge is up
    sock::recover();
}

sub bridge_launch
{
    my $cmd = "C:\\projects\\eclipse-workspace\\test-jssc-1\\tcpser.exe";
    system($cmd);
}

sub led_send_command
{
        my $m = $model;
    my $mw = $m->{mw};
    # pop up a dialog and ask for glyph to request;
    my $dw = $mw->DialogBox(-title => 'LED send command', -buttons => ['OK', 'Cancel']);
    my $cmd = "";
    my $b = $dw->add('LabEntry', -label => "Enter command", -textvariable => \$cmd)->pack(-padx => 10, -pady => 10);
    my $answer = $dw->Show( );
    return unless $answer eq 'OK';
    return unless length $cmd;
    sock::ss_send($cmd."\r\n");
}

sub glyph_request
{
    my $m = $model;
    my $mw = $m->{mw};
    # pop up a dialog and ask for glyph to request;
    my $dw = $mw->DialogBox(-title => 'Request glyph', -buttons => ['OK', 'Cancel']);
    my $char = "";
    my $b = $dw->add('LabEntry', -label => "Enter single char", -textvariable => \$char)->pack(-padx => 10, -pady => 10);
    my $answer = $dw->Show( );
    return unless $answer eq 'OK';
    return unless length $char == 1;
    
    sock::ss_send("XG".$char."\r\n");
}

sub glyph_response
{
    my $resp = shift;
    t "glyph_response: ".d($resp);
    # decode and update GUI
    my $c = $model->{c};
    my $clr = $model->{colours};
    led_all_off($c, $clr);
    if(not $resp =~ /^char (\d+) '(.)' has width (\d+): (.*)$/){
        warn "glyph_response interpret failure 1\n";
        return;
    }
    my ($asc, $g, $width, $data) = ($1, $2, $3, $4);
    my @words = split(/ /, $data);
    return if(scalar(@words) != 16);
    t "OK, ASCII char $asc is $width wide with words ".scalar(@words);
    for(my $y = 0; $y < 16; $y++){
        my $w = $words[$y];
        my @bs = bits::get_bottom_n_bits(16, hex($w));
        for(my $x = 0; $x < 16; $x++){
            my $on = $bs[$x];
            my $id = $c->find('withtag' => "led_".$x."_".$y);
            led_on_off($c, $clr, $id, $on);
        }
    }
    sock::ss_send("T:glyph '$g'\r\n");    
}

sub glyph_send
{
    my $m = $model;
    my $c = $m->{c};
    my @leds = $c->find( 'withtag', 'led' );
    my @bits = ('') x 16;
    for(my $y = 0; $y < 16; $y++){
        for(my $x = 0; $x < 16; $x++){
            my $tag = "led_".$x."_".$y;
            my $id = $c->find('withtag' => $tag);
            if(not $id){
                warn "failed to find tag $tag";
                return;
            }
            my @taglist = $c->gettags($id);
            my $on = (grep /^LED_ON$/, @taglist);
            $bits[$y] .= $on ? '1' : '0';
        }
    }
    # t d \@bits;
    @bits = map { sprintf("%04X", bits::bin2dec($_)) } @bits;
    my $msg = "XS". " 65 16 ".join(" ", @bits);
    t $msg;
    sock::ss_send($msg."\r\n");    
}

sub glyph_replace
{
    my $m = $model;
    my $mw = $m->{mw};
    my $c = $m->{c};
    
    # pop up a dialog and ask for glyph to replace;
    my $dw = $mw->DialogBox(-title => 'Replace glyph', -buttons => ['OK', 'Cancel']);
    my $char = "";
    my $b = $dw->add('LabEntry', -label => "Enter single char", -textvariable => \$char)->pack(-padx => 10, -pady => 10);
    my $answer = $dw->Show( );
    return unless $answer eq 'OK';
    return unless length $char == 1;

    my @leds = $c->find( 'withtag', 'led' );
    my @bits = ('') x 16;
    my $width = 0;
    for(my $y = 0; $y < 16; $y++){
        for(my $x = 0; $x < 16; $x++){
            my $tag = "led_".$x."_".$y;
            my $id = $c->find('withtag' => $tag);
            if(not $id){
                warn "failed to find tag $tag";
                return;
            }
            my @taglist = $c->gettags($id);
            my $on = (grep /^LED_ON$/, @taglist);
            $bits[$y] .= $on ? '1' : '0';
            if(($on) and $x+1 > $width){
                $width = $x+1;
            }  
        }
    }
    # t d \@bits;
    @bits = map { sprintf("%04X", bits::bin2dec($_)) } @bits;
    my $msg = "XR". " ".ord($char)." ".$width." ".join(" ", @bits);
    t $msg;
    sock::ss_send($msg."\r\n");    
}

sub comms_status
{
    my ($what) = @_;
    my $m = $model;
    my $c = $m->{c};
    my ($id) = $c->find( 'withtag', 'COMMS' );
    if($what eq "OK") {
        $c->itemconfigure($id, -text => "COMMS: connected OK");
    } elsif($what eq "connection_down") {
        $c->itemconfigure($id, -text => "COMMS: connection down");
    } else {
        $c->itemconfigure($id, -text => $what);
        t "comms_status: handler required for ".$what;
    }
}

sub socket_hook
{
    my $what = shift;
    if($what eq "bytes"){
        my @msg = prot_led_test::add_bytes(shift);
        return unless @msg;
        foreach (@msg){
            chomp;
            next if($_ eq "unhandled command");
            next if($_ eq "OK");
            t "msg: ".d($_);
            if(/\<XG\>(.*)$/){
                my $resp = $1;
                glyph_response($resp);
            }
        }
        comms_status("OK");
        return;
    }   
    comms_status($what);
}

sub serial_port_choose
{
    my $c = $model->{serial};
    my $mw = $model->{mw};
    my @ports = enumports();
    t "Windows registry indicates ".scalar(@ports)." ports";
    foreach(@ports){
        t "$_";
    } 
    # pop dialog with chooser
    my $dw = $mw->DialogBox(-title => 'Select Serial Port', -buttons => ['OK', 'Cancel']);
    #$dw->Icon(-image => 'ketech32');
#    my $entryval = '';
#
#    $dw->add('Label', -text => 'Enter port')->pack(-padx => 10, -pady => 10);
#    my $entry = $dw->add('Entry', -textvariable => \$entryval)->pack(-padx => 10, -pady => 10);

    my $var = '';
    my $b = $dw->add('BrowseEntry', -label => "Choose port", -variable => \$var)->pack(-padx => 10, -pady => 10);
    foreach(@ports){
        $b->insert("end", $_);
    }

    my $answer = $dw->Show( );
    return unless $answer eq 'OK';

    t "Opening port: ".d($var);
    $c->{portname} = $var;
    ser::serial_stop();
    ser::serial_start();
}

sub  draw_grid {
    my $c = $model->{c};
    $c->delete("cell");
    my $offx = 30;
    my $offy = 30;
    my $cellw = 20;
    my $cellh = 20;
    my $clr = $model->{colours};
    for(my $row = 0; $row < 16; $row++){
        for(my $col = 0; $col < 16; $col++){
            #draw_cell_outline($row, $col);
            my $x = $offx + ($col * $cellw);
            my $y = $offy + ($row * $cellh);
            $c->createRectangle($x,$y, $x+$cellw, $y+$cellh, 
                -fill => $clr->{grid_bg}, 
                -outline => $clr->{grid}, 
                #-activefill => 'LightSeaGreen',
                #-activeoutline => 'yellow',
                -tags => ["cell", "cell_".$col."_".$row]
            );
            $c->createOval($x+1,$y+1, $x+$cellw-1, $y+$cellh-1, 
                -fill =>  $clr->{led_off}, 
                -outline => $clr->{led_off}, 
                #-activefill => 'black',
                -activeoutline => $clr->{led_highlight},
                -tags => ["cell", "led_".$col."_".$row, "led"]
            );
        }
    }
    $c->bind("led", "<Button-1>", sub{ toggle_led_on_off() });
}

sub toggle_led_on_off {
    my $c = $model->{c};
    my $clr = $model->{colours};
    my ($id) = $c->find( 'withtag', 'current' );
    #t "click_1: id = $id";
    my @taglist = $c->gettags($id);
    #t "\t taglist =" . d \@taglist;
    # on or off?
    my $on = grep(/^LED_ON$/, @taglist);
    led_on_off($c, $clr, $id, ($on ?  0 : 1));
}

sub led_on_off
{
    my($c, $clr, $id, $on) = @_;
    if($on){
        $c->addtag("LED_ON", "withtag", $id);
        $c->itemconfigure($id, -fill => $clr->{led_on}, -outline => $clr->{led_on});
    } else {
        $c->dtag($id, "LED_ON");
        $c->itemconfigure($id, -fill => $clr->{led_off}, -outline => $clr->{led_off});
    }
}

sub led_all_off
{
    my($c, $clr, $on) = @_;
    my @leds = $c->find( 'withtag', 'led' );
    foreach(@leds){
        led_on_off($c, $clr, $_, 0);
    }
}

sub draw_cell_outline {
    my($row, $col) = @_; 
}

sub clear_grid {
    my $c = $model->{c};
    $c->delete("cell");
}

# Enumerate serial ports (Windows only)
sub enumports {
    $Registry->Delimiter("/");
    my $k = $Registry->{"LMachine/HARDWARE/DEVICEMAP/SERIALCOMM/"}
    or  die "Can't read LMachine/HARDWARE/DEVICEMAP/SERIALCOMM/ key: $^E\n";
    my @ports = values %$k;
    # filter out exotic ports (non COMn ports) and sort by COM port number...
    # make a quick hash of names to numbers...
    my %p;
    foreach(@ports){
        next unless /^com(\d+)$/i;
        $p{$_} = $1;
    }
    # other hints to be found in 
    # HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E978-E325-11CE-BFC1-08002BE10318}
    # the '{4D36E978-E325-11CE-BFC1-08002BE10318}' is a ClassGUID
    @ports = sort { $p{$a} <=> $p{$b} } keys %p;
    return @ports;
}

sub paste_clipboard {
    my $clip = Win32::Clipboard::GetText();
#    t d $clip;
    # criteria: zeroes and ones tab separated
    my @rows = split /^/, $clip;
    @rows = grep { chomp; s/^\s+//; s/\s+$//; s/\s//g; length;} @rows;
    # set to 16 rows
    push(@rows, "0" x 16) while(scalar @rows < 16);
    $#rows = 15;
    foreach(@rows){
        # trim to 16 bits
        /^[10]+$/ or return;
        $_.=  "0" x 16;
        $_ = substr($_, 16)
    }
    t d \@rows;
    t "OK";
    # update display...
    my $c = $model->{c};
    my $clr = $model->{colours};
    led_all_off($c, $clr);
    
    for(my $y = 0; $y < 16; $y++){
        t "row $y...";
        my @bs = split(//, $rows[$y]);
        for(my $x = 0; $x < 16; $x++){
            my $on = $bs[$x];
            my $id = $c->find('withtag' => "led_".$x."_".$y);
            led_on_off($c, $clr, $id, $on);
        }
    }
    
    
      
}
sub roll_menus {
    [
      map ['cascade', $_->[0], -menuitems => $_->[1], -tearoff => 0 ],
          ['~File',
            [
              #~ ['command', "Load and run...", qw/-accelerator Ctrl-o/, -command => \&journey_load_run], '',
              #~ ['command', "Load...", qw/-accelerator Ctrl-o/, -command => \&journey_load],
              #~ ['command', "Clear", qw/-accelerator Ctrl-o/, -command => \&journey_clear],
              #~ ['command', 'Restart', qw/-accelerator Ctrl-a/, -command => \&journey_restart],
              #~ ['command', 'Pause', qw/-accelerator Ctrl-a/, -command => \&journey_pause],
              #~ ['command', 'Resume', qw/-accelerator Ctrl-a/, -command => \&journey_resume],
              #~ '',
          
              # JOURNEY FILES NOT SUPPORTED

              #~ ['command', "Load and run...", -command => \&journey_load_run], '',
              #~ ['command', "Load...", -command => \&journey_load],
#              ['command', "Clear", -command => \&journey_clear],
              #~ ['command', 'Restart', -command => \&journey_restart],
              #~ ['command', 'Pause', -command => \&journey_pause],
              #~ ['command', 'Resume', -command => \&journey_resume],
              '',
              ['command', '~Quit', -command => \&exit],
            ],
          ],
          ['~Edit',
            [
              [command => 'Draw grid', -command =>sub{draw_grid()}],
              [command => 'Clear grid', -command =>sub{clear_grid()}],
              [command => 'Request glyph definition', -command =>sub{glyph_request()}],
              [command => 'Send glyph definition', -command =>sub{glyph_send()}],
              [command => 'Replace glyph definition', -command =>sub{glyph_replace()}],
              [command => 'Paste from clipboard', -command =>sub{paste_clipboard()}, , -accelerator => 'Ctrl-v',],
              
              #~ [command => 'Decode HU response', -command => sub{decode_hu_response()}],
#              [command => 'Select Serial Port', -command => sub{select_serial_port()}],
              [command => 'Select Colour', 
                -command => sub{ 
                    my $mw = $model->{mw};
                    return unless $mw;
                    my $clr = $mw->chooseColor(-title => "Choose a colour");
                    t d $clr; 
                  }],
              #~ ['command', 'Preferences ...'],
            ],
          ],
          ['~Comms',
            [
                    [command => 'Socket send command', -command =>sub{led_send_command()}],
            
                    [command => 'Serial Start', -command => sub{serial_start()} ],
                    [command => 'Serial Stop', -command => sub{serial_stop()}],
                    [command => 'Serial Select Port', -command => sub{serial_port_choose()}],
                    [command => 'Bridge Launch', -command => sub{bridge_launch()}],
            
            ],
          ],
          ['~Help',
            [
              #~ ['command', 'Help', -command => sub {text_dialog('Help', journey_help_doc())}],
              #~ ['command', 'About', -command => sub {text_dialog('About', about_docs())}],
#              ['command', 'About', -command => sub {about_box_new()}],
              ['command', 'About', -command => sub {}],
            ],
          ],
    ]; # <-- returns a listref
}


#------------------------------------------------------------------------------


