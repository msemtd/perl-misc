#!/usr/bin/perl -w
use strict;
require v5.8;
my $title   = 'KeTech DTND Test';
my $version = "v1.0 (15th Mar 2013)";

BEGIN {

    # This must be in a BEGIN in order for the 'use' to be conditional
    if ( $^O eq "MSWin32" ) {
        require Win32::SerialPort;
        eval "use Win32::SerialPort";
        die "$@\n" if ($@);
        require Win32::TieRegistry;
        eval 'use Win32::TieRegistry';
        die "$@\n" if ($@);
        eval 'use Win32::Mutex';
        die "$@\n" if ($@);
    } else {
        eval "use Device::SerialPort";
        die "$@\n" if ($@);
    }
}
use IO qw(Handle File);
autoflush STDERR 1;
autoflush STDOUT 1;
use FindBin qw($Bin);
use lib "$Bin";
use tmstub;
use beautify;
use dtnd;

# Die upon warn - comment out this line to show further warnings...
#~ local $SIG{__WARN__} = sub { die $_[0] };
use Time::HiRes('gettimeofday');
use File::Slurp;
use File::Basename;
use Getopt::Long;
use Pod::Usage;

#~ use Text::Wrap();
my $withreader        = 90;                # <-- serial reader timer delay in ms
my $autoresume        = '';                # default=false
my $logfile           = undef;             # default=none
my $fixedsleep        = 0;
my $readersip         = 32;                # <-- reader sips n chars per read
my $useport           = 'com1';            # serial port in DOS format
my $man               = 0;
my $help              = 0;
my $mutexname         = "dtndemurunning";
my $shortcutfile      = "shortcuts.dat";
my $shortcutnoautorun = 0;
my $hu_direct_mode    = 1;
my $baud              = 9600;
{
    GetOptions(
        'help|?'            => \$help,
        'man'               => \$man,
        'autoresume'        => \$autoresume,
        'fixedsleep:i'      => \$fixedsleep,
        'withreader:i'      => \$withreader,
        'readersip:i'       => \$readersip,
        'port=s'            => \$useport,
        'logfile=s'         => \$logfile,
        'mutexname=s'       => \$mutexname,
        'shortcutfile=s'    => \$shortcutfile,
        'shortcutnoautorun' => \$shortcutnoautorun,
        'humode'            => \$hu_direct_mode,
    ) or pod2usage(2);
    pod2usage(1) if $help;
    pod2usage( -verbose => 2 ) if $man;

    #~ t "ARGS: ".d \@ARGV;
}

# Announce application...
sub HELP_MESSAGE {
    t "$title - $version";
    t
"For help, read the embedded POD documentation or the accompanying manual";
}

sub VERSION_MESSAGE {
    t "$title - $version";
    t sprintf "Perl version: $], v%vd", $^V;
    t "OS   version: $^O";
}
VERSION_MESSAGE();
## Enumerate serial ports (Windows only)
sub enumports {
    $Registry->Delimiter("/");
    my $k = $Registry->{"LMachine/HARDWARE/DEVICEMAP/SERIALCOMM/"}
      or die "Can't read LMachine/HARDWARE/DEVICEMAP/SERIALCOMM/ key: $^E\n";
    my @ports = values %$k;

    # filter out exotic ports (non COMn ports) and sort by COM port number...
    # make a quick hash of names to numbers...
    my %p;
    foreach (@ports) {
        next unless /^com(\d+)$/i;
        $p{$_} = $1;
    }
    @ports = sort { $p{$a} <=> $p{$b} } keys %p;
    return @ports;
}
my $mutex;
if ( $^O eq "MSWin32" ) {
    my @ports = enumports();
    t "Serial ports detected:" . d \@ports;
    $mutex = Win32::Mutex->new( 1, $mutexname );

    # If this happens, $^E will be set to 183 (ERROR_ALREADY_EXISTS).
    if ($^E) {
        t "Windows claims that the Emulator is already running on "
          . "this machine.";
        t "Only one instance will run unless overridden "
          . "with the -mutexname option";
        sleep 10;
        die "failed to open mutex '$mutexname': $^E \n";

# TODO more delicate shutdown or pop existing instance window using Win32 API calls
    }
}

=head2 DEPENCENDIES ON TK MODULES

The graphical user interface ("GUI") is built with the ubiquitous Tk library
and relies on the standard set of widgets distributed with Perl/Tk.

=cut

use Tk;
use Tk::widgets qw(Button Label Frame Scale Checkbutton LabEntry LabFrame
  DialogBox ProgressBar Radiobutton Text Menu Balloon);

# CSV column names...
# TODO - sort out fields for DTGR
my @cn          = qw(  );
my $csv_numcols = scalar @cn;
my %cn;
@cn{@cn} = ( 0 .. $#cn );

#~ t d \%cn;
###########################################################
# Construct basic GUI
my $mw = new MainWindow( -title => $title );
beautify::beautify($mw);

# Add menu bar...
$mw->configure( -menu => my $menubar = $mw->Menu( -menuitems => &roll_menus ) );

#~ $mw->geometry("+0+0"); # <-- position window at top left
#~ $mw->FullScreen;
# A fixed-width font...
my $code_font = $mw->fontCreate(
    'code',
    -family => 'courier new',
    -size   => ( $^O eq 'MSWin32' ? 8 : 10 )
);
{
    my $images = roll_images();
    foreach ( keys %$images ) {
        $mw->Pixmap( $_, -data => $images->{$_} );
    }
}
$mw->Icon( -image => 'ketech32' );

# The status frame is packed to the bottom side...
my $status_message = "$title $version";
{
    my $fr_status =
      $mw->Frame( -relief => 'sunken', -borderwidth => 2 )
      ->pack( -fill => 'x', -side => 'bottom' );
    $fr_status->Label( -image => 'ketech16' )->pack( -side => 'left' );
    $fr_status->Label( -textvariable => \$status_message )
      ->pack( -side => 'left' );
}

# The top frame contains all the controls - pack before messages textbox...
my $topframe = $mw->Frame()->pack( -side => 'top' );
my $maxlines = 900;
my $message_text_widget;

# The output messages frame is packed above the status frame and stretches to fill all remaining space...
{
    my $fr =
      $mw->LabFrame( -label => 'Messages', -labelside => 'acrosstop' )
      ->pack( -fill => 'both', -expand => 1, -side => 'bottom' );
    $mw->fontCreate(
        'textbox',
        -family => 'courier new',
        -size   => ( $^O eq 'MSWin32' ? 8 : 10 )
    );
    my $tp = $fr->Scrolled(
        'Text',
        -scrollbars => 'se',
        -font       => 'textbox',

        #~ -tabs => [8, 'left'],
        qw(-height 10 -width 60 -wrap none),

        #~ qw(-fg yellow -bg black),
    )->pack( -fill => 'both', -expand => 1, );
    $tp = $tp->Subwidget("text");

    #~ tie *STDOUT, ref $tp, $tp;
    #~ tie *STDERR, ref $tp, $tp;
    $tp->tagConfigure( "blue",  -foreground => "blue" );
    $tp->tagConfigure( "green", -foreground => "#35783C" );
    $tp->tagConfigure(
        "bluerev",
        -foreground  => 'white',
        -background  => 'blue',
        -relief      => 'raised',
        -borderwidth => 1
    );
    $tp->tagConfigure(
        "greenrev",
        -foreground  => 'white',
        -background  => '#35783C',
        -relief      => 'raised',
        -borderwidth => 1
    );

# Augment popup menu...
# To disable the default Menu, use $text->menu(undef). To supply your own Menu, first create it and then use $text->menu(my_menu).
    my $menu = $tp->menu();

    # remove the file menu and add a clear button...
    $menu->delete(0);
    $menu->insert(
        0, 'command',
        -label   => "Clear",
        -command => sub { $tp->delete( '1.0', 'end' ) }
    );

    #~ t d $menu;
    # Add ctrl-scroll font grow/shrink feature...
    $tp->bind(
        '<Control-4>' => sub { fontadjust( 'textbox', 1 ); $_[0]->break; } );
    $tp->bind(
        '<Control-5>' => sub { fontadjust( 'textbox', -1 ); $_[0]->break; } );

  # now use re-ordered bindtags to stop the class-wide scroll events occuring...
    my (@bindtags) = $tp->bindtags;
    $tp->bindtags( [ @bindtags[ 1, 0, 2, 3 ] ] );

#~ $fr->Button(-text=>'Clear', -command => sub{$tp->delete('1.0', 'end')})->pack();
    $message_text_widget = $tp;
}

sub fontadjust {
    my ( $font, $addme ) = @_;
    my $size = $mw->fontConfigure( $font, -size );
    $size += $addme;

    # min size? max size?
    $mw->fontConfigure( $font, -size => $size );
}

sub text_widget_out {
    my @stuff = @_;
    $message_text_widget->insert( 'end', @stuff );
    my $endline = $message_text_widget->index('end');
    if ( $endline > $maxlines ) {
        $message_text_widget->delete( '1.0', "end - $maxlines lines" );
    }
    $message_text_widget->see('end');
    $mw->update();
}
###########################################################
my $ob;              # <-- serial port object
my $reader_timer;    # <-- serial reader timer
my $serial_reader_buffer = '';
my $reader_total_bytes   = 0;

# Journey data...
my $journey_file = '';
my @j;               #<-- currently loaded journey
my $jp;              #<-- current line pointer into journey
my $journey_linenum = 0;    # line position for gui
my $journey_linetot = 0;    # line count for gui
my $jtid;                   #<-- journey timer
my $journey_snooze   = 0;   #<-- last loaded line sleep value in seconds
my $journey_minsleep = 60;  # minimum sleep in milliseconds
my $logfh;                  # logfile handle
###########################################################
# GUI objects and data...
#~ my $run_journey_btn;
my $run_journey_progbar;
## The values for the GUI objects are held in a  hashref
my $dtnd_data = {
    SELECT       => "ASCII_MSG",
    ASCII_MSG    => "TEST",
    HEADER       => "HEAD",
    MESSAGE_TYPE => "POLL",
    DISPLAY      => "123abcdefghijklmnopqrst",
};
my $balloon = $mw->Balloon();

#~ my $continuous_update = 0;
#~ my $scale200 = 0;
my $time_field  = 1;
my $last_resume = '<none>';
my $last_rx     = '<none>';
my $shortcuts   = [];
###########################################################
## GUI controls...
#~ my $debug_gui = 0;
my $debug_gui = 1;
my $fr        = $topframe->Frame()->pack();

#~ my $fr_1 = $fr->Frame();
my $fr_1 = $fr->Frame()->pack( -side => 'left', -anchor => 'n' );
my $fr_2 = $fr->Frame();
my $fr_3 = $topframe->Frame();

#~ my $fr_2 = $fr->Frame()->pack(-side => 'left', -anchor => 'n');
#~ my $fr_3 = $topframe->Frame()->pack();
my $fr_4 = $topframe->Frame()->pack();
my $fr_5 = $topframe->Frame()->pack( -side => 'left', -anchor => 'n' );
$fr_1->configure( -bg => 'green' )  if $debug_gui;
$fr_2->configure( -bg => 'orange' ) if $debug_gui;
$fr_3->configure( -bg => 'pink' )   if $debug_gui;
$fr_4->configure( -bg => 'yellow' ) if $debug_gui;
$fr_5->configure( -bg => 'blue' )   if $debug_gui;
## collect data back from DTND
my $dtnd_in_buf   = '';
my $dtnd_buf_size = 300;
my $dtnd_msg_mode = 1;

sub dtnd_serial_in {
    my $msg = shift;
    my @ba = unpack "C*", $msg;
    foreach (@ba) { dtnd_serial_byte_in($_) }
}

sub dtnd_serial_byte_in {
    my $b = shift;

    # in test mode terminate message with CR or LF
    if ( $dtnd_msg_mode == 1 ) {
        if ( $b == 0x0A || $b == 0x0D ) {
            dtnd_serial_test_mode_message($dtnd_in_buf);
            $dtnd_in_buf = '';
            return;
        }

        # allow switch to normal mode
        if ( $b == 0x01 ) {
            $dtnd_msg_mode = 0;

            # start msg here!
            $dtnd_in_buf = $b;
            return;
        }

        # append
        # TODO limit
        $dtnd_in_buf .= chr($b);
        return;
    }
    if ( $dtnd_msg_mode == 0 ) {

        # TODO state machine and msg interp
    }
}

sub dtnd_serial_test_mode_message {
    my $msg = shift;
    return unless length($msg);
    t "MSG: '" . $msg . "'";
}
{    # DTND...
    my $frq =
      $fr_5->LabFrame( -label => 'DTND Misc', -labelside => 'acrosstop' )
      ->pack( -side => 'bottom' );
    $frq->configure( -bg => 'purple' ) if $debug_gui;
    $frq->Checkbutton(
        -text     => "test mode",
        -variable => \$dtnd_msg_mode,
        -bg       => 'pink'
    )->pack();
    {
        my $fr = $frq->Frame( -bg => 'cyan' )->pack();
        $fr->Label( -text => "port:" )->pack( -side => 'left' );
        $fr->Entry( -width => 6, -textvariable => \$useport )
          ->pack( -side => 'left' );
        $fr->Button(
            -text    => "open",
            -command => sub { serial_open_port($useport) }
        )->pack( -side => 'left' );
        $fr->Button(
            -text    => "close",
            -command => sub { serial_close_port() }
        )->pack( -side => 'left' );
        setColor_helper(
            $fr,
            [
                '-background',          '-activebackground',
                '-highlightbackground', '-highlightcolor'
            ],
            'cyan'
        );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "HEADER:" )->pack( -side => 'left' );
        $fr->Entry( -textvariable => \( $dtnd_data->{HEADER} ) )
          ->pack( -side => 'left' );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "ASCII:" )->pack( -side => 'left' );
        $fr->Entry( -textvariable => \( $dtnd_data->{ASCII_MSG} ) )
          ->pack( -side => 'left' );
        $fr->Button(
            -text    => "send",
            -command => sub { send_ascii( $dtnd_data->{ASCII_MSG} ); }
        )->pack( -side => 'left' );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "Poll:" )->pack( -side => 'left' );
        $fr->Button( -text => "send", -command => sub { send_data("POLL"); } )
          ->pack( -side => 'left' );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "ENTERTEST:" )->pack( -side => 'left' );
        $fr->Button(
            -text    => "send",
            -command => sub { send_data("ENTERTEST"); }
        )->pack( -side => 'left' );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "DISPLAY:" )->pack( -side => 'left' );
        $fr->Entry( -textvariable => \( $dtnd_data->{DISPLAY} ) )
          ->pack( -side => 'left' );
        $fr->Button(
            -text    => "send",
            -command => sub { send_data("DISPLAY"); }
        )->pack( -side => 'left' );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "DISPLAY TEST:" )->pack( -side => 'left' );
        $fr->Button(
            -text    => "send",
            -command => sub { send_data("DISPLAY_TEST"); }
        )->pack( -side => 'left' );
    }
    {
        my $fr = $frq->Frame()->pack();
        $fr->Label( -text => "DISPLAY CLEAR:" )->pack( -side => 'left' );
        $fr->Button(
            -text    => "send",
            -command => sub { send_data("DISPLAY_CLEAR"); }
        )->pack( -side => 'left' );
    }
}
{    # Journey...
    my $fr =
      $fr_4->LabFrame( -label => 'Journey & Data', -labelside => 'acrosstop' )
      ->pack( -side => 'bottom' );
    my $fr1 = $fr->Frame()->pack( -side => 'top' );
    $run_journey_progbar = $fr1->ProgressBar(
        -width    => 20,
        -length   => 300,
        -from     => 0,
        -to       => 100,
        -blocks   => 50,
        -colors   => [ 0, 'green' ],
        -variable => \$journey_linenum,

        #~ -variable => \$jp, # set this later!
      )->pack(
        -side => 'left',

        #~ -pad => 10,
      );

    #
    $fr1->Label( -text => 'Line' )->pack( -side => 'left' );
    $fr1->Label(
        -textvariable => \$journey_linenum,
        -width        => 5,
        -font         => 'code'
    )->pack( -side => 'left' );
    $fr1->Label( -text => 'of' )->pack( -side => 'left' );
    $fr1->Label(
        -textvariable => \$journey_linetot,
        -width        => 5,
        -font         => 'code'
    )->pack( -side => 'left' );
    $fr1->Button( -text => 'send', -command => \&send_data )
      ->pack( -side => 'left', -padx => 10 );

    #
    my $fr2 = $fr->Frame()->pack( -side => 'top' );

#~ $fr->Label(-text => 'Discarded')->pack();
#~ $fr->Entry(-width => 5, -relief => 'groove', -borderwidth => 2, -textvariable => \$discarded_msgs)->pack();
    $fr2->Button( -text => 'Rewind', -command => \&journey_rewind )
      ->pack( -side => 'left' );
    $fr2->Button( -text => 'Pause', -command => \&journey_pause )
      ->pack( -side => 'left' );
    $fr2->Button( -text => 'Resume', -command => \&journey_resume )
      ->pack( -side => 'left' );
    $fr2->Button( -text => 'Step', -command => \&journey_step )
      ->pack( -side => 'left' );
    $fr2->Label( -textvariable => \$last_resume )->pack( -side => 'left' );
    $fr2->Label( -textvariable => \$last_rx )->pack( -side => 'left' );

    #
    my $fr3 = $fr->Frame( -bg => 'orange' )->pack( -side => 'right' );
    $fr3->Label( -text => 'HU Direct Mode', -bg => 'orange', )
      ->pack( -side => 'left' );
    $fr3->Checkbutton( -variable => \$hu_direct_mode, -bg => 'orange', )
      ->pack( -side => 'left' );
}
#####################################################################
$mw->after(
    600,
    sub {

        # Redirect STDOUT and STDERR
        tie *STDOUT, ref $message_text_widget, $message_text_widget;
        tie *STDERR, ref $message_text_widget, $message_text_widget;

        #~ tie *STDOUT, 'grabber', $message_text_widget, 'stdout';
        #~ tie *STDERR, 'grabber', $message_text_widget, 'stderr';
        t "$title - $version";

        #
        if ($logfile) {
            $logfh = new IO::File "> $logfile";
            if ( not defined $logfh ) {
                warn "failed to open logfile '$logfile' for writing: $!\n";
            } else {
                print $logfh "# logfile started " . localtime() . "\n";
            }
        }

        # Add configurable shortcuts to menubar...
        #~ $shortcuts = loadShortcuts($shortcutfile);
        #~ addShortcutsToMenu($menubar, $shortcuts);
        # set off reader timer...
        serial_open_port($useport);
        open_file_from_commandline();
    }
);

# And go...
MainLoop();
###########################################################
# writes a timestamped message to the logfile if open...
sub logwrite {
    return unless $logfh;
    my ( $sec, $usec ) = gettimeofday;
    my $msg = shift;
    my $ts = timestamp1( $sec, $usec );
    print $logfh "$ts $msg\n";
}

sub open_file_from_commandline {

    #~ t "ARGV=".d \@ARGV;
    my $file = shift @ARGV;
    journey_load($file) if $file && -f $file;
    journey_restart() if $autoresume;
}

sub serial_open_port {
    my $port = shift;
    $port = 'com1' if not $port;
    t "opening port $port...";
    die "Serial port '$port' doesn't look right\n"
      unless $port =~ /^COM(\d+)$/i;
    if ( $^O eq "MSWin32" ) {
        $ob = Win32::SerialPort->new( $port, 1 );
    } else {

        # translate port name internally for unix variants...
        my $portnum = $1;
        $portnum--;
        $port = '/dev/ttyS' . $portnum;
        $ob = Device::SerialPort->new( $port, 1 );
    }
    die "Can't open serial port $port: $^E\n" unless ($ob);

    #~ $ob->debug(1);
    $ob->baudrate($baud)   || die "yikes! $^E $!";
    $ob->parity("none")    || die "yikes! $^E $!";
    $ob->databits(8)       || die "yikes! $^E $!";
    $ob->stopbits(1)       || die "yikes! $^E $!";
    $ob->handshake("none") || die "yikes! $^E $!";

    # set up port just so - use everything available to make it 'raw'...
    # from stty(1)
    # raw = same as -ignbrk -brkint -ignpar -parmrk -inpck -istrip
    # -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel
    # -opost -isig -icanon -xcase min 1 time 0
    $ob->datatype('raw');
    $ob->stty_istrip(0);
    $ob->stty_inlcr(0);
    $ob->stty_igncr(0);
    $ob->stty_icrnl(0);
    $ob->stty_opost(0);
    $ob->stty_isig(0);
    $ob->stty_icanon(0);
    $ob->write_settings || die "yikes! $^E $!";

    #~ $ob->save('cross-plat.config');
    t "OK, port opened";

    # start the background reader timer...
    serial_reader_start() if ($withreader);
}

sub serial_reader_start {
    serial_reader_stop();
    $reader_timer = $mw->after( $withreader, \&serial_reader_read );
}

sub serial_reader_stop {
    return unless $reader_timer;
    my $silent = shift;
    t "Reader timer running: cancelling" unless $silent;
    $reader_timer->cancel;
    undef $reader_timer;
}

sub serial_reader_read {
    $reader_timer->cancel;
    undef $reader_timer;
    my $get = $readersip;

    # unable to do much without a serial port object...
    if ($ob) {
        my ( $got, $msg ) = $ob->read($get);

        #~ t "W(read of $get got $got)" unless ($got == $get);
        if ($got) {
            $reader_total_bytes += $got;
            my @chars = map { sprintf "%02X", $_; } unpack "C*", $msg;
            text_widget_out(
                "RX(" . scalar(@chars) . ")\t", 'bluerev',
                "@chars\n",                     'blue'
            );
            logwrite( "RX(" . scalar(@chars) . ") @chars" );
            $last_rx = localtime;
            $last_rx =~ s/^.* (\d+:\d+:\d+).*$/$1/;

            # callback
            dtnd_serial_in($msg);
        }
    }
    $reader_timer = $mw->after( $withreader, \&serial_reader_read );
}

sub serial_close_port {

    #~ my $portobj = shift;
    #~ $portobj = $ob unless $portobj;
    #~ return unless $portobj;
    #~ $portobj->close || die "unable to close port\n";
    #~ undef $portobj;
    return unless $ob;
    $ob->close || die "unable to close port\n";
    undef $ob;
}

sub serial_write_port {
    my $msg = shift;

    #~ t "saying '$msg'";
    if ( not $ob ) {
        warn("port not open\n");
        return;
    }
    my $count_out = $ob->write($msg);
    warn "write failed\n" unless ($count_out);
    warn "write incomplete\n" if ( $count_out != length($msg) );
}
###########################################################
#~ sub change_scale {
#~ foreach($scale_actual, $scale_target, $scale_permitted){
#~ $_->configure(
#~ -from => 0, -to => $scale200? 200 : 100,
#~ -tickinterval => $scale200? 20 : 10,
#~ );
#~ }
#~ }
###########################################################
sub send_ascii {
    my $msg = shift;
    my @ba = unpack( "C*", $msg );
    push @ba, 0x0A;
    my $packdata = pack( "C*", @ba );
    showtxmsg($packdata);
    serial_write_port($packdata);
}

# Polulate a msg object from GUI and send...
sub send_data {
    my @args = @_;
    my $packdata;
    my $head = $dtnd_data->{HEADER};
    if ( $args[0] eq "POLL" ) {
        $packdata = dtnd::make_poll_message($head);
    } elsif ( $args[0] eq "ENTERTEST" ) {

        # enter test mode again with <SOH>E<ETX>
        $packdata = chr(0x01) . chr(0x45) . chr(0x03);
    } elsif ( $args[0] eq "DISPLAY" ) {
        my $msg = $dtnd_data->{DISPLAY};
        $packdata = dtnd::make_display_message( $head, $msg );
    } elsif ( $args[0] eq "DISPLAY_TEST" ) {
        $packdata = dtnd::make_display_test_message($head);
    } elsif ( $args[0] eq "DISPLAY_CLEAR" ) {
        $packdata = dtnd::make_display_clear_message($head);
    } else {
        $packdata = get_send_data_from_controls(@args);
    }
    showtxmsg($packdata);
    serial_write_port($packdata);
}
###########################################################
# Polulate a vobc msg object from GUI...
# within here we do a bit of normalisation
sub get_send_data_from_controls {

    # by default we use ASCII_MSG
    my $data = $dtnd_data->{ASCII_MSG};
    my @args = @_;
    if (@args) {
        if ( exists $dtnd_data->{ $args[0] } ) {
            $data = $dtnd_data->{ $args[0] };
        }
    }
    my @ba;
    @ba = unpack( "C*", $data );
    push @ba, 0x0A;

    #~ if($hu_direct_mode){
    #~ @ba = dtgr::mkmsg_ba_hu_direct($dtgr_data);
    #~ } else {
    #~ @ba = dtgr::mkmsg_ba($dtgr_data);
    #~ }
    my $packdata = pack( "C*", @ba );
    return $packdata;
}

# Display bytes being sent just prior to sending.
sub showtxmsg {
    my ($msg) = @_;
    my @chars = map { sprintf "%02X", $_; } unpack "C*", $msg;

    #~ t "TX(".scalar(@chars).")\t@chars";
    text_widget_out( "TX(" . scalar(@chars) . ")\t",
        'greenrev', "@chars\n", 'green' );
    logwrite( "TX(" . scalar(@chars) . ") @chars" );
}

sub journey_help_doc {
    my $msg = <<"EODATA";

    $title $version


You can load a "journey" from a well-formed CSV file to
automate the setting of values, The CSV file must not contain
any logical errors, Excel errors, quoted fields, etc.
Be sure to check your journey as plain ascii text (e.g. in a text editor).

* The first line of the CSV file contains column headings.
* All fields must contain valid values - even when unused
* fields cannot contain commas

CSV column mappings...
EODATA

#~ the timing for a line used to be based on using the time field as an offset from the time that the first line was sent!
#~ if we reset the time to be now and the next line is due to go off at 200 seconds we would have to wait for 200 sec for it to start
#~ so we would have to reset the start accordingly by subtracting the resume time or say it started that much in the past!
# timing is now based on simple sleeps
    foreach ( 0 .. $#cn ) {
        $msg .= "   " . ( $_ + 1 ) . "\t" . $cn[$_] . "\n";
    }
    return $msg;
}
###########################################################
sub journey_unschedule {
    return unless $jtid;
    my $silent = shift;
    t "Timer running: cancelling" unless $silent;
    $jtid->cancel;
    undef $jtid;
}

sub journey_clear {
    journey_unschedule();
    $journey_file = undef;

    # Set the status bar message to the default...
    $status_message = "$title $version";

    # Reset the journey parameters...
    @j               = ();
    $jp              = 0;
    $journey_linenum = 1;
    $journey_linetot = 0;
}

sub journey_load_run {
    journey_load();
    journey_resume();
}

# Read a journey from a CSV file into memory
sub journey_load {
    journey_clear();

    # pop a file chooser if not file given as argument...
    my $file = shift;
    if ( not $file ) {
        my $types =
          [ [ 'CSV Files', [ '.txt', '.csv' ] ], [ 'All Files', '*', ], ];
        $file = $mw->getOpenFile( -filetypes => $types );
        return unless defined $file;
    }
    @j = read_file($file) or die "unable to read file '$file':$!\n";
    @j = map { chomp; $_ } @j;
    $journey_file = $file;

    # Set the status bar message to include the journey file...
    $status_message = "$title -- " . basename($journey_file);
    $jp              = 0;           #<-- point at line 1
    $journey_linenum = 1;
    $journey_linetot = scalar @j;

    # todo cope with too short a file
    #~ @journey_headings = split /,/, $j[0];
    # todo choke on wrong number of headings
    #~ t "$journey_file: @journey_headings";
    t "Loaded '$journey_file' with $journey_linetot lines";

    # todo validate all rows
    $run_journey_progbar->configure( -from => 1, -to => $journey_linetot );
    journey_interp_current_line();    # load first line into widgets
    $mw->update();

    # force validation of fields? zzz
}

sub journey_restart {
    journey_rewind();
    journey_resume();
}

sub journey_rewind {
    journey_unschedule();

    # validate...
    die "no journey loaded!\n\n" unless ( $journey_file and @j );
    $jp              = 0;    #<-- point at line 1
    $journey_linenum = 1;
    journey_interp_current_line();    # load
}

# returns undef if finished
sub journey_step {
    my $chugging = shift;
    journey_unschedule($chugging);

    # validate...
    die "no journey loaded!\n\n" unless ( $journey_file and @j );
    journey_interp_current_line();    # load
    send_data();                      # send
    $jp++;
    $journey_linenum++;

    # sent last line?
    if ( $jp > $#j ) {
        t "looks like we're finished here after $#j lines";
        $jp--;
        $journey_linenum--;           # step back onto the edge!
        return;
    }
    journey_interp_current_line() if not $chugging;  # load next unless chugging
    return 1;
}

sub journey_resume {
    journey_unschedule();
    journey_chug();
    $last_resume = localtime;
    $last_resume =~ s/^.* (\d+:\d+:\d+).*$/$1/;
}

sub journey_pause {
    journey_unschedule();
}

# send the current line and schedule the next line to be sent...
sub journey_chug {
    return unless journey_step('silently');
    my $sleep = ($journey_snooze);
    if ( $sleep < $journey_minsleep ) {
        t "sleep of $sleep ms is too short. Setting to $journey_minsleep";
        $sleep = $journey_minsleep;
    }
    $sleep = $fixedsleep if ($fixedsleep);
    $jtid = $mw->after( $sleep, \&journey_chug );
}

# This routine can throw an exception (via die()) so deal with it...
sub journey_line_validate {
    my $cols    = shift;
    my $linenum = $jp + 1;
    my @n       = @$cols;
    my $width   = scalar @$cols;
    my $killme;
    die
"ERROR: Journey line $linenum has $width columns - should be $csv_numcols\n"
      if ( $width != $csv_numcols );

    # check certain fields for numbers
    my @naturals = qw(SLEEP SPEED TARGET PERMITTED
      VOBC_ACTIVE VOBC_DORMANT VOBC_MASTER VOBC_STATUS
      OPERATION_MODE NEXT_PREV DWELL_ON DTT DTT_ON
      AUDIO AUDIO_MUTE TRAIN_STATUS MSG_LINE MSG_ATTR
      BLANK STANDBY LOGO);
    foreach my $colname (@naturals) {
        my $colnum = $cn{$colname};
        my $val    = $cols->[$colnum];
        if ( not $val =~ /^\s*\d+\s*$/ ) {
            print STDERR
"ERROR: value '$val' in $colname column ($colnum) doesn't look like a natural number\n";
            $mw->update();
            $killme = 'please!';
        }
    }
    my @integers = qw(DWELL);
    foreach my $colname (@integers) {
        my $colnum = $cn{$colname};
        my $val    = $cols->[$colnum];
        if ( not $val =~ /^\s*-?\d+\s*$/ ) {
            print STDERR
"ERROR: value '$val' in $colname column ($colnum) doesn't look like an integer\n";
            $mw->update();
            $killme = 'please!';
        }
    }
    die "ERROR: Journey line $linenum unusable\n" if $killme;

    # ZZZ TODO: complete validation of input line
}

# Loads the values from the current journey line into the widgets...
# This routine can throw an exception (via die()) so deal with it...
sub journey_interp_current_line {

    # skip remarks - lines that begin '#'...
    while ( ( $journey_linenum < scalar @j ) && ( $j[$jp] =~ /^\s*#/ ) ) {
        t "COMMENT: " . $j[$jp];
        $journey_linenum++;
        $jp++;
    }

# if the line says "goto line <linenumber>" then go there...
# A goto line that tries to goto another line will fail - that's probably for the best!
    if ( $j[$jp] =~ /^\s*goto\s+line\s+(\d+)/i ) {
        my $linenumber = $1;

        # too far?
        if ( $linenumber > scalar @j ) {
            die "line "
              . ( $jp + 1 )
              . " told us to goto line $linenumber which is beyond the extents of the journey!\n";
        }
        t "goto: $linenumber";
        $journey_linenum = $linenumber;
        $jp              = $journey_linenum - 1;
    }

    # read the line and update the vars...
    my @n = split /,/, $j[$jp];
    journey_line_validate( \@n );

    # TODO - read values into control variables
    $mw->update();
}

sub crc_test {

    # take contents of current controls into msg string then
    # adjust the CRC byte to emulate a CRC failure...
    my $packdata = get_send_data_from_controls();

    # the CRC byte is 3rd from end...
    my $crc = substr $packdata, -3, 1;
    $crc = ord $crc;

    # pop a dialog allowing change...
    my $d =
      $mw->DialogBox( -title => "CRC Test", -buttons => [ "OK", "Cancel" ] );
    $d->add(
        "LabEntry",
        -label        => 'Numeric CRC value',
        -textvariable => \$crc,
    )->pack;
    my $button = $d->Show;
    return unless $button eq 'OK';
    die "CRC value must be a number\n" if not $crc =~ /^\d+$/;
    $crc = chr($crc);
    substr( $packdata, -3, 1 ) = $crc;

    #~ t "data: ". vobc::sanit($packdata);
    showtxmsg($packdata);
    serial_write_port($packdata);
}
#####################################################################
sub roll_images {
    my $i = {};
    $i->{icon16} = <<'EOXPM';

/* XPM */
static char *icon16[] = {
/* width height num_colors chars_per_pixel */
"    16    16       16            1",
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
"l c #00ffff",
"m c #ffffff",
/* pixels */
"````````````````",
"`mmmmmmmmmmmmmm`",
"`m`mmm`mm```mmm`",
"`m`mmm`m`mmm`mm`",
"`mm`m`mm`mmm`mm`",
"`mm`m`mm`mmm`mm`",
"`mmm`mmm`mmm`mm`",
"`mmm`mmmm```mmm`",
"`m````m``mmm``m`",
"`m`mmmm``mmm``m`",
"`m```mm`m`m`m`m`",
"`m`mmmm`m`m`m`m`",
"`m`mmmm`mm`mm`m`",
"`m````m`mm`mm`m`",
"`mmmmmmmmmmmmmm`",
"````````````````"
};
EOXPM
    $i->{glowy} = <<'EOXPM';
/* XPM */
static char *glowy[] = {
/* width height num_colors chars_per_pixel */
"    32    32      128            2",
/* colors */
"`` c #212321",
"`. c #2f9515",
"`# c #b1954f",
"`a c #41c819",
"`b c #2d571f",
"`c c #74ca28",
"`d c #8a9534",
"`e c #9cd244",
"`f c #886134",
"`g c #409094",
"`h c #30771d",
"`i c #4ae514",
"`j c #6fcb79",
"`k c #e4d079",
"`l c #38af18",
"`m c #253c1e",
"`n c #4ecc52",
"`o c #a2dbac",
"`p c #3c879a",
"`q c #69ab37",
"`r c #6ee123",
"`s c #54761c",
"`t c #a0e6a0",
"`u c #ce9e66",
"`v c #51ad1b",
"`w c #48af70",
"`x c #8a7a36",
"`y c #486c1c",
"`z c #bfe9c0",
"`A c #51931c",
"`B c #2f8719",
"`C c #7ce174",
"`D c #644124",
"`E c #71b49c",
"`F c #60ca1c",
"`G c #2b691d",
"`H c #274f1c",
"`I c #232f20",
"`J c #8cd439",
"`K c #42b24e",
"`L c #5ed955",
"`M c #3f7820",
"`N c #5fe617",
"`O c #daefdd",
"`P c #9cb244",
"`Q c #b0f1a0",
"`R c #38a00c",
"`S c #42db1c",
"`T c #79cd58",
"`U c #8caa38",
"`V c #80e260",
"`W c #2d601a",
"`X c #44a477",
"`Y c #d9b571",
"`Z c #8edd72",
"`0 c #946f3d",
"`1 c #3c3c3c",
"`2 c #60cb68",
"`3 c #8ae536",
"`4 c #50bd6b",
"`5 c #aa7b4c",
"`6 c #2e2d2d",
"`7 c #4bf115",
"`8 c #26441d",
".` c #75be29",
".. c #b0e050",
".# c #d4cec8",
".a c #c8d264",
".b c #e8b674",
".c c #c8ccb4",
".d c #9c9e44",
".e c #f1faf7",
".f c #52b244",
".g c #c0b260",
".h c #ccc6bc",
".i c #84c66c",
".j c #81a12f",
".k c #fad086",
".l c #c0a85e",
".m c #52a328",
".n c #62d91c",
".o c #3cbe19",
".p c #518524",
".q c #54c124",
".r c #a1d882",
".s c #9cea8c",
".t c #4cc058",
".u c #5ff517",
".v c #6ec184",
".w c #91dd98",
".x c #85852d",
".y c #44be52",
".z c #bcc25c",
".A c #71be57",
".B c #439117",
".C c #74d37c",
".D c #90d470",
".E c #6ed723",
".F c #77ac29",
".G c #c3f2b8",
".H c #74ee26",
".I c #ecc17e",
".J c #bcdec4",
".K c #44c739",
".L c #4bda3a",
".M c #d6aa6c",
".N c #b28752",
".O c #b4d298",
".P c #b1e6b1",
".Q c #408724",
".R c #fcdc94",
".S c #3ca237",
".T c #48a186",
".U c #40ac2a",
".V c #a2be4a",
".W c #51e634",
".X c #7cc69c",
".Y c #74d35a",
".Z c #56d940",
".0 c #bf925c",
".1 c #3f9234",
".2 c #84b731",
".3 c #8fea83",
".4 c #5fe24c",
".5 c #87d597",
".6 c #386a1d",
".7 c #96853e",
".8 c #5c4e1c",
/* pixels */
"`g`g`p`p`p`p`p`p`g`p`g`g`g`g`p`p`p`p`p`g`p`g`p`p`p`p`p`p`g`g`g`p",
".T.T.T`g`p`g.T`X`X.T`X`X`X`X`X`g`g`g.T`X`X`X.T`g`p`g`g.T`X`X`X`X",
"`w`w`w.T.T.T`w`K`K.y.y.y.S`K.y`w.T`w`w.y.y.y.y`w.T.T`w`4`K.S.y.y",
"`X```8`4`w`4`G```h.L`h```````H.y`4.t`m`````I`8`K`w`4.f`W```````W",
"`4```m.t`4.t`I```S`h`I```H```I`G`n.K```I`m```I`b`n`n`H`6```8`I`H",
"`2`I`I.L`n.S`6`W`S`I`6`l.L.U`6`I.L.K```H`7`l`I`H.L`.`6`m.K`n.K.S",
"`2`H``.L.L`H``.o`B`I`G.L`n.L`````S.S`I`G`7`B`I`h`i`8`6.S`n`4.v`4",
"`j`W``.o.K`I`m`7`H`I.S`2`2.L`I```S`.`6`````I`8`S`S```I.L.v`E`E`E",
"`j`h`6`l`B```B`7`m``.y`2`2`L`````7`G`6`m`I`I`I`S.o`6`8`n.v`E`E`E",
".C.1```.`m``.L.W`I`I.K`L`2`K`I`8`7`b```a`7`W`I`l.U`6`8`L`j.v.v`E",
".5.f```m`6`W`L.4`8`6.S.4.4`G`6`B.W`m```i`7`G``.U.K```I.L.4.C.v.X",
"`o`4`6`6`I.f.C`C`h`6`8.U`M`6`I.4.W`I```l`.`I`I.Z.4`m`1`b`K.Q`8.5",
"`o`C```6`m`C.w.5.C`m`6``````.f`V`n``````````.1`C`C.m`````````H.5",
"`z`t.Q`M`q.w`o`o.w.Y`M`W`M.C`C.3`T`M`M.Q.Q`4`Z.w.w.w.f.6`W.1.5`o",
"`O.P`t`t`t.P.J.J.P`t.s.3.3.s`t`o`t.s.3.3.3`t`t.P.J`t.s.3.3`t.P.J",
".e`O`z`z.P`z`z`z.P`Q`t`Q`t`Q`z`z`z`Q`t`t`Q.P`z`z`z`z.P`Q`Q.P`z`O",
".e.e`O.G.G`Q`Q`Q`Q`Q`Q`Q`Q`Q.G`O.G.G`Q`Q`Q`Q.G`Q.G.G.G`Q`Q.G`O`O",
".#.#.c.O.r.Y.Y.Y.Y`T`Z`Z.Y.Y.r.r.r`Z.Y`T`Z`Z`T.A.r.r.D.A.i.O.c.h",
"`D`D.8`s`M```````````v.B`````h`A`A`W````.B`v`````A`A.6```H`s.8`D",
".b.M.g.V.p`6```````m.n.B`6`6`M.E.E`I`1``.n.n```I`J`J`M``.p.V.l`u",
".R.k`k...6```R`7`N.H.H`M`6`I`W.H.B```1`m.H`F```b`3`3`W`6.F.a`k.I",
".R.k`k..`H`6.o.u.u.H.H`W```H`m`7`m`H```b.H`v```y`3`3`8```c.a.k.k",
".k`k.a`e`m`1``````.``r`8```.```R```.```M`r.B`6.Q`3`3`I```e.a`Y.I",
".I.b.z`J```6```````F`r`I`m.o```I`W`.``.B`r`h```v`3`F```m`e.z`Y.b",
".b`Y.z.````8`S`F`F`r`F```H`i````.o`h`I`v`r`b``.q`r`v`6`H`e.g.M.M",
".M.M.V.m`6`W`i`N`N.E`v`6.6`N`m`H.u`W``.q.E`H```F`N`M`6`y.V.l`u`u",
"`u.l`U.p`6`m`h.6`M.E.B``.Q.E`A`v.n`m```c`c`b`6`H`M`I`I.F`U`#.0.0",
".0`#`U`y`````````m`F`y``.B.2.2.2`c```I`c.2`A```I`````y.2.d`#.N.N",
".N.N`d.p`y`M`M.6.p.``A`y.j.j`d.d.F`y`s.F.j.2`A`y`W.p.F`d.7`5`5`5",
"`5`5.7.j.j.F.F.F.j.j.j.j.x.7.7.x`d.j`d`d.7`d.j.j.F.j`d.7`0`5`0`0",
"`0`0`0`x.x.x.x.x`x`x`x.x`x`0`0`f`x`x`x`x`0`x`x.x.x.x`x`0`f`0`f`f",
"`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f`f"
};
EOXPM
    $i->{glowy16} = <<'EOXPM';
/* XPM */
static char *glowy16[] = {
/* width height num_colors chars_per_pixel */
"    16    16       64            2",
/* colors */
"`` c #212620",
"`. c #3c8d24",
"`# c #a08d45",
"`a c #48c810",
"`b c #355b26",
"`c c #72a032",
"`d c #9f8451",
"`e c #3ca818",
"`f c #35751e",
"`g c #88c23c",
"`h c #acd254",
"`i c #34838f",
"`j c #2b3f22",
"`k c #488430",
"`l c #349082",
"`m c #318121",
"`n c #e8be7c",
"`o c #548a2c",
"`p c #44aa70",
"`q c #58e218",
"`r c #77e339",
"`s c #51c357",
"`t c #2e6922",
"`u c #9ed4af",
"`v c #2d4d23",
"`w c #3c9c1c",
"`x c #307730",
"`y c #a0ae46",
"`z c #5fb124",
"`A c #283224",
"`B c #8ddc87",
"`C c #bcded1",
"`D c #8ca73c",
"`E c #e1e9e4",
"`F c #d4aa6c",
"`G c #80ce98",
"`H c #c49a5f",
"`I c #c4ce5c",
"`J c #7cb450",
"`K c #44a848",
"`L c #549e64",
"`M c #64ac84",
"`N c #66c85a",
"`O c #9ce48c",
"`P c #60c424",
"`Q c #5c9f2c",
"`R c #399349",
"`S c #54a854",
"`T c #94ec80",
"`U c #54d054",
"`V c #44a27c",
"`W c #44b544",
"`X c #d0b868",
"`Y c #ae814e",
"`Z c #54b678",
"`0 c #3c9e4c",
"`1 c #3cba1c",
"`2 c #64ba84",
"`3 c #a4e5a2",
"`4 c #c4eabc",
"`5 c #318339",
"`6 c #44c737",
"`7 c #94d6a0",
"`8 c #f0ce84",
/* pixels */
"`l`i`i`l`l`l`l`i`i`l`l`i`i`i`l`l",
"`5`R`V`x`K`5`t`0`p`x`x`R`p`0`t`5",
"`x`5`W`j`w`v`m`j`6`A`m`j`1`A`5`x",
"`R`x`.`m`v`e`U```1`j`t`t`.`m`Z`Z",
"`S`t`j`6`A`6`s```e`v`x`m`t`R`Z`M",
"`Z`A`b`U`j`0`x`x`m`m`m`f`m`t`W`L",
"`G`v`S`G`S`v`t`U`.`v`t`s`N`b`v`M",
"`C`7`7`u`7`B`B`u`7`B`B`7`u`G`B`u",
"`E`C`O`B`B`T`B`3`O`B`T`7`3`B`3`C",
"`E`4`b`````U```N`Q```r```T`b`J`E",
"`d`D`j`a`q`w`A`w`v`j`1`v`P`A`c`d",
"`8`h`A```f`.`t`j`t`v`z`b`r```h`n",
"`8`g`j`q`r`f`e`A`e`f`e`f`P`v`I`n",
"`n`c`A`j`Q`b`z`g`.`k`c`A`j`o`X`F",
"`H`D`c`Q`J`c`y`y`D`D`y`c`c`y`H`H",
"`Y`#`#`#`#`#`Y`Y`d`#`d`#`#`d`Y`Y"
};

EOXPM
    $i->{icon32} = <<'EOXPM';
/* XPM */
static char *icon32[] = {
/* width height num_colors chars_per_pixel */
"    32    32       16            1",
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
"l c #00ffff",
"m c #ffffff",
/* pixels */
"````````````````````````````````",
"````````````````````````````````",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mm`mmm`mm```mm````mmm```mmmm``",
"``mm`mmm`m`mmm`m`mmm`m`mmm`mmm``",
"``mmm`m`mm`mmm`m````mm`mmmmmmm``",
"``mmm`m`mm`mmm`m`mmm`m`mmmmmmm``",
"``mmmm`mmm`mmm`m`mmm`m`mmm`mmm``",
"``mmmm`mmmm```mm````mmm```mmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmm````m``mmm``m`mmm`mmmmmm``",
"``mmmm`mmmm``mmm``m`mmm`mmmmmm``",
"``mmmm```mm`m`m`m`m`mmm`mmmmmm``",
"``mmmm`mmmm`m`m`m`m`mmm`mmmmmm``",
"``mmmm`mmmm`mm`mm`m`mmm`mmmmmm``",
"``mmmm````m`mm`mm`mm```mmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"``mmmmmmmmmmmmmmmmmmmmmmmmmmmm``",
"````````````````````````````````",
"````````````````````````````````",
"mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm"
};
EOXPM
    $i->{ketech16} = <<'EOXPM';
/* XPM */
static char * swoops_16px_border_xpm[] = {
"16 16 32 1",
"   c #000100",
".  c #12114B",
"+  c #222243",
"@  c #242B67",
"#  c #323333",
"$  c #A02221",
"%  c #773331",
"&  c #4E4D53",
"*  c #4A4D72",
"=  c #925555",
"-  c #676690",
";  c #6C6977",
">  c #AA6F6F",
",  c #868393",
"'  c #878684",
")  c #AB8889",
"!  c #DF8787",
"~  c #939FC5",
"{  c #A0A29F",
"]  c #B79EA0",
"^  c #A4A4B2",
"/  c #D89993",
"(  c #A3B2C6",
"_  c #C1C0E5",
":  c #C9C5C2",
"<  c #CCC6D7",
"[  c #F0CBCB",
"}  c #E0DCEE",
"|  c #FFDCCA",
"1  c #FDDEDD",
"2  c #E8E9E6",
"3  c #FDFFFC",
"                ",
" :;<:>/<,(}3333 ",
" 33{-}]>[{-<333 ",
" 333:*(2=/2*~33 ",
" 33332*~2=!2&~3 ",
" 33333:@<2%/2@^ ",
" 333333;*3)$2,@ ",
" 333333^.2[$:<. ",
" 333333_+21$:}@ ",
" 333333_&3|%2_# ",
" 333333;{3/'3,{ ",
" 33333{'3|;3<;3 ",
" 3333^{3:'2^'33 ",
" 332':2){2'{333 ",
" <{{:]]^,{23333 ",
"                "};
EOXPM
    $i->{ketech32} = <<'EOXPM';
/* XPM */
static char * swoops_32px_border_xpm[] = {
"32 32 33 1",
"   c None",
".  c #FFFFFF",
"+  c #000000",
"@  c #CCCCCC",
"#  c #999999",
"$  c #666666",
"%  c #333333",
"&  c #333366",
"*  c #666699",
"=  c #FFCCCC",
"-  c #9999CC",
";  c #663333",
">  c #996666",
",  c #330066",
"'  c #CC6666",
")  c #CC3333",
"!  c #FF9999",
"~  c #000033",
"{  c #993333",
"]  c #660000",
"^  c #333399",
"/  c #CCCCFF",
"(  c #CC0000",
"_  c #CC9999",
":  c #000066",
"<  c #3366CC",
"[  c #330000",
"}  c #003399",
"|  c #003366",
"1  c #FF6666",
"2  c #FFCC99",
"3  c #990000",
"4  c #6666CC",
"++++++++++++++++++++++++++++++++",
"+@..............@..............+",
"+.#$*-@.=>>'=..**-/............+",
"+...#%*-..@;{!=.#%&-@..........+",
"+.....$&*@..#;'!..#%*-.........+",
"+......@%*-...${'=.@$&*@.......+",
"+........$&*@..#;'!..#&*-......+",
"+.........$&<@..@;)!..#%&-.....+",
"+..........#|}-..@;{'..@%&*....+",
"+...........#&^/..@;)'..@%^*...+",
"+............$&,@..#;)!..#&,#..+",
"+.............%^&...${(=..$&,..+",
"+.............#&,#..@]({..@~,$.+",
"+..............~,%...>)3@..&,~.+",
"+..............&,+..._)]#..*,~#+",
"+..............*:+@..=(]$..-:~#+",
"+..............*^+@..=)]$..-&~$+",
"+..............-&+@..=1[#../4+#+",
"+..............-&%...='+@..-*+@+",
"+.............@-+#...!;%...-%%.+",
"+.............@$%...='+#..@$+@.+",
"+.............#+#...2;$...@%$..+",
"+............#%#...=>%...@%%...+",
"+...........@%$...=>%@..@$%....+",
"+..........@%$...=>%...@$$.....+",
"+.........#%#...=;$...@%$......+",
"+.......@$%@..._;#...#%#.......+",
"+......#%#...=>$@..@$$.........+",
"+....#$$@..=>;#..@$%@..........+",
"+.@*$$@.@>>;#.@$&%#............+",
"+..............................+",
"++++++++++++++++++++++++++++++++"};
EOXPM
    return $i;
}

sub roll_menus {
    [
        map [ 'cascade', $_->[0], -menuitems => $_->[1], -tearoff => 0 ],
        [
            '~File',
            [

#~ ['command', "Load and run...", qw/-accelerator Ctrl-o/, -command => \&journey_load_run], '',
#~ ['command', "Load...", qw/-accelerator Ctrl-o/, -command => \&journey_load],
#~ ['command', "Clear", qw/-accelerator Ctrl-o/, -command => \&journey_clear],
#~ ['command', 'Restart', qw/-accelerator Ctrl-a/, -command => \&journey_restart],
#~ ['command', 'Pause', qw/-accelerator Ctrl-a/, -command => \&journey_pause],
#~ ['command', 'Resume', qw/-accelerator Ctrl-a/, -command => \&journey_resume],
#~ '',
#~ [qw/command ~Quit  -accelerator Ctrl-q -command/ => \&exit],
                [
                    'command', "Load and run...", -command => \&journey_load_run
                ],
                '',
                [ 'command', "Load...", -command => \&journey_load ],
                [ 'command', "Clear",   -command => \&journey_clear ],
                [ 'command', 'Restart', -command => \&journey_restart ],
                [ 'command', 'Pause',   -command => \&journey_pause ],
                [ 'command', 'Resume',  -command => \&journey_resume ],
                '',
                [ 'command', '~Quit', -command => \&exit ],
            ],
        ],
        [
            '~Edit',
            [
                [ command => 'CRC test', -command => \&crc_test ],

    #~ [command => 'Decode HU response', -command => sub{decode_hu_response()}],
                [
                    command  => 'Select Serial Port',
                    -command => sub { select_serial_port() }
                ],

                #~ ['command', 'Preferences ...'],
            ],
        ],
        [
            '~Shortcuts',
            [],
        ],
        [
            '~Help',
            [

#~ ['command', 'Help', -command => sub {text_dialog('Help', journey_help_doc())}],
#~ ['command', 'About', -command => sub {text_dialog('About', about_docs())}],
                [ 'command', 'About', -command => sub { about_box_new() } ],
            ],
        ],
    ];    # <-- returns a listref
}

sub about_box_new {
    my $ab =
      $mw->DialogBox( -title => 'About DTG-R Emulator', -buttons => ['OK'] );
    $ab->Icon( -image => 'ketech32' );
    my $pic =
      $ab->add( 'Label', -image => 'ketech32' )
      ->pack( -side => 'left', -padx => 10 );
    my $lab1 = $ab->add( 'Label', -text => "$title" )->pack( -padx => 30 );
    my $lab2 = $ab->add( 'Label', -text => "$version" )->pack;
    my $answer = $ab->Show();
}

sub decode_hu_response {
    my $dw = $mw->DialogBox(
        -title   => 'Decode HU response',
        -buttons => [ 'OK', 'Cancel' ]
    );
    $dw->Icon( -image => 'ketech32' );
    my $entryval = '';
    $dw->add( 'Label', -text => 'Enter HU response hex bytes' )
      ->pack( -padx => 10, -pady => 10 );
    my $entry =
      $dw->add( 'Entry', -textvariable => \$entryval )
      ->pack( -padx => 10, -pady => 10 );
    my $answer = $dw->Show();
    return unless $answer eq 'OK';
    t "Decode: " . d($entryval);
}

sub select_serial_port {
    my @ports = enumports();
    t "Serial ports detected:" . d \@ports;
    my $dw = $mw->DialogBox(
        -title   => 'Select Serial Port',
        -buttons => [ 'OK', 'Cancel' ]
    );
    $dw->Icon( -image => 'ketech32' );
    my $entryval = '';
    $dw->add( 'Label', -text => 'Enter port' )
      ->pack( -padx => 10, -pady => 10 );
    my $entry =
      $dw->add( 'Entry', -textvariable => \$entryval )
      ->pack( -padx => 10, -pady => 10 );
    my $answer = $dw->Show();
    return unless $answer eq 'OK';
    t "Opening port: " . d($entryval);
    $useport = $entryval;
    serial_open_port($useport);
}

sub loadShortcuts {
    my ($file) = @_;
    my $shortcuts = [];

    # load shortcut data file
    my @s = read_file($file) or die "unable to read file '$file':$!\n";
    @s = grep { chomp; s/^\s+//; s/#.*$//; s/\+.*$//; s/\s+$//; length } @s;
    t "shortcuts: -";
    foreach (@s) {
        my @v = split(/\s*\|\s*/);

        # drop empty fields...
        @v = grep { length } @v;
        next unless @v;
        if ( scalar @v < 2 ) {
            warn "expected 2 columns of data in shortcut file for "
              . d \@v . "\n";
            next;
        }
        my ( $title, $csv ) = (@v);
        t "  " . d($title) . " => " . d($csv);
        push @$shortcuts, [ $title, $csv ];
    }
    return $shortcuts;
}

sub addShortcutsToMenu {
    my ( $menubar, $shortcuts ) = @_;

    # locate "Shortcut" entry...
    my $s_menu = $menubar->entrycget( 'Shortcuts', '-menu' );

    #~ t d $s_menu;
    if ( not $s_menu ) {
        warn "no menu entitled 'Shortcuts' found!\n";
        return;
    }

    # TODO clear the menu first
    foreach (@$shortcuts) {
        my ( $title, $csv ) = (@$_);
        $s_menu->command(
            -label   => $title,
            -command => sub { runShortcut( $title, $csv ) },
        );
    }
}

sub runShortcut {
    my ( $title, $csv ) = (@_);
    t "Run shortcut " . d \@_;
    journey_load($csv);
    journey_resume() unless ($shortcutnoautorun);
}

sub setColor_helper {
    my ( $widget, $options, $color ) = @_;
    foreach my $option (@$options) {
        Tk::catch {
            $widget->configure( $option => $color );
        }
    }
    foreach my $child ( $widget->children ) {
        setColor_helper( $child, $options, $color );
    }
}
##################################################
# this code is taken from the widget demo...
my ( $VIEW, $VIEW_TEXT );

sub text_dialog {
    my ( $title, $data ) = @_;
    if ( not Exists $VIEW) {
        $VIEW = $mw->Toplevel;

        #~ $VIEW->iconname('widget');
        my $view_buttons = $VIEW->Frame;
        $view_buttons->pack(qw/-side bottom -expand 1 -fill x/);
        my $view_buttons_dismiss = $view_buttons->Button(
            -text    => 'OK',
            -command => [ $VIEW => 'withdraw' ],
        );
        $view_buttons_dismiss->pack(qw/-side left -expand 1/);
        $VIEW_TEXT = $VIEW->Scrolled( 'Text',
            qw/-scrollbars e -height 30 -width 78 -wrap word -setgrid 1 -padx 10 -pady 10/
        );
        $VIEW_TEXT->pack(qw/-side left -expand 1 -fill both/);
    } else {
        $VIEW->deiconify;
        $VIEW->raise;
    }
    $VIEW->title($title);
    $VIEW_TEXT->configure(qw/-state normal/);
    $VIEW_TEXT->delete(qw/1.0 end/);
    $VIEW_TEXT->insert( '1.0', $data );
    $VIEW_TEXT->markSet(qw/insert 1.0/);
    $VIEW_TEXT->configure(qw/-state disabled/);
}

# For capturing STDOUT and STDERR in the message window...
package grabber;

sub TIEHANDLE {
    my ( $class, $textwidget, $tag ) = @_;
    return bless { textwidget => $textwidget, tag => $tag }, $class;
}

sub PRINTF {
    my $w = shift;
    $w->PRINT( sprintf( shift, @_ ) );
}

sub PRINT {
    my $obj = shift;
    my $tag = $obj->{tag};
    my $w   = $obj->{textwidget};
    while (@_) { $w->insert( 'end', shift, $tag ); }
    $w->see('end');    # <-- always scroll to end
}

package main;

=head1 CAVEATS

A bug exists on the Windows platform where reads from the serial
port are somehow blocking causing the GUI to hang/freeze at startup
although the serial port is opened successfully.
This usually happens when the fillgun leaves the port in a broken state.
If this happens, close the program, open the windows device manager,
disable and re-enable the port, and all should be well.


=cut
