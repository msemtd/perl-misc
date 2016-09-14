#! perl -w
use strict;
package ser;

use Carp;
use tmstub; 

my $model = undef;

sub ser_setup {
    $model = shift;
}

sub serial_start {
    my $m = $model;
    my $c = $m->{serial};
    my $baud = $c->{baud};
    my $portname = $c->{portname};
    my $rr =  $c->{withreader};
    t "open port $portname at $baud baud";
    my $p = new Win32::SerialPort($portname, 0);
    die "Can't open serial port $portname: $^E\n" unless ($p);
    t "open";
    $p->debug(1);
    $p->baudrate($baud) || die "failed to set baud rate: $^E $!\n";
    $p->parity("none") || die "failed to set parity: $^E $!\n";
    $p->databits(8) || die "failed to set databits: $^E $!\n";
    $p->stopbits(1) || die "failed to set stopbits: $^E $!\n";
    # $p->dtr_active(0);
    #$p->error_msg(1);  # prints hardware messages like "Framing Error"
    #$p->user_msg(1);   # prints function messages like "Waiting for CTS"
    $p->handshake("none") || die "failed to set handshake: $^E $!\n";

    # set up port just so - use everything available to make it 'raw'...
    # from stty(1)
    # raw = same as -ignbrk -brkint -ignpar -parmrk -inpck -istrip
    # -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel
    # -opost -isig -icanon -xcase min 1 time 0

    #$ob->datatype('raw');
    #$ob->stty_istrip(0);
    #$ob->stty_inlcr(0);
    #$ob->stty_igncr(0);
    #$ob->stty_icrnl(0);
    #$ob->stty_opost(0);
    #$ob->stty_isig(0);
    #$ob->stty_icanon(0);

    $p->write_settings || die  "failed to write settings: $^E $!";
    #~ $ob->save('cross-plat.config');
    t "OK, port opened";
    $c->{ob} = $p;
    # start the background reader timer...
    serial_bgr_start($m);
}
sub serial_bgr_start {
    my $m = $model;
    my $c = $m->{serial};
    my $rr = $c->{withreader};
    my $mw = $m->{mw};
    serial_bgr_stop($m);
    my $timer =  $mw->after($rr, \&serial_bgr_read);
    $c->{bgrtimer} = $timer;
}

sub serial_bgr_stop {
    my $m = $model;
    my $c = $m->{serial};
    my $timer =  $c->{bgrtimer};
    return unless defined $timer;
    my $silent = 0;
    t "Reader timer running: cancelling" unless $silent;
    $timer->cancel();
    undef $timer; 
    $c->{bgrtimer} = undef;
}

sub serial_bgr_read {
    my $m = $model;
    my $mw = $m->{mw};
    my $c = $m->{serial};
    my $timer =  $c->{bgrtimer};
    $timer->cancel();
    undef $timer;
    $c->{bgrtimer} = undef;
    my $get = 30;
    my $ob = $c->{ob};
    return unless $ob;
    # unable to do much without a serial port object...
    my ($got, $msg) = $ob->read($get);
    #~ t "W(read of $get got $got)" unless ($got == $get);
    if($got){
        # my $reader_total_bytes += $got;
        my @chars = map {sprintf "%02X", $_;} unpack "C*", $msg;
        #text_widget_out("RX(".scalar(@chars).")\t", 'bluerev', "@chars\n", 'blue');
        #logwrite("RX(".scalar(@chars).") @chars");
        #$last_rx = localtime;
        #$last_rx =~ s/^.* (\d+:\d+:\d+).*$/$1/;
        t "RX: ".scalar(@chars);
    }
    my $rr = $c->{withreader};
    return unless $rr;
    $timer =  $mw->after($rr, \&serial_bgr_read);
    $c->{bgrtimer} = $timer;
}

sub serial_stop {
    t "serial stop";
    serial_bgr_stop();
    my $c = $model->{serial};
    my $portobj = $c->{ob};
    return unless $portobj;
    $portobj->close || die "unable to close port\n";
    undef $portobj;
    $c->{ob} = undef;
}

#
#sub serial_write_port {
#    my $msg = shift;
#    #~ t "saying '$msg'";
#    if(not $ob){
#        warn("port not open\n");
#        return;
#    }
#    my $count_out = $ob->write($msg);
#    warn "write failed\n" unless ($count_out);
#    warn "write incomplete\n" if ($count_out != length($msg));
#}
#

1;