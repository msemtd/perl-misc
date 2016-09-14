#! perl -w
use strict;
package sock;

use Carp;
use IO::Socket;
use IO::Select;
use tmstub; 


my $sock = undef;
my $sel = undef;
my $readtimer = undef;
my $readrate = 50;
my $hookcode = undef;
my $mw = undef;
my $next_recover_time = 0;

my ($host, $port) = ("localhost", "49322");

my $msgbuf = '';

sub ss_setup {
    my($hook, $win);
    ($host,$port,$hook, $win) = @_;
    ss_set_hook($hook);
    $mw = $win;
}

sub ss_set_hook {
    # code ref arg
    my $ref = shift;
    croak("bad arg") unless ref($ref) eq "CODE";
    $hookcode = $ref;
    return 1;
}

# call this repeatedly if desired - will attempt connect if not connected
sub recover {
        
    eval {
        if(time() > $next_recover_time){
            return if $sock and $sock->connected();
            t "not connected so....";
            ss_connect();
            # all OK?
            $next_recover_time = 0;
        }
    };# trap run-time errors in connect
    if ($@) {
        t "TCP connection id down: $@"; 
        $next_recover_time = time() + 20;
        if(defined $hookcode){
             $hookcode->("connection_down", "$@");
        }
    } 
    
}
#------------------------------------------------------------------------------
sub ss_read {
    my $hand = $sock;
    if ($^O eq 'MSWin32') {
        my(@ready) = $sel->can_read(0);
        return if $#ready == -1;
        $hand = $ready[0];
        # we don't seem to get the exception in the select set
        # maybe because it is always preceded by a readable select
        my(@ex) = $sel->has_exception(0);
        if(@ex) {
            ss_disconnect();
            if(defined $hookcode){
                $hookcode->("exception");
            }
            return;
        }
    }
    my $numbytes = 300;                         
    my $line = "";
    my $buf;
    my $num = sysread $hand, $buf, $numbytes;
    if(not defined $num){
        ss_disconnect();
        if(defined $hookcode){
            $hookcode->("fault");
        }
        return;
    }
    # sometimes we get a zero read - is this only in a disconnect condition?
    if($num == 0){
        if(defined $hookcode){
            $hookcode->("zero read");
        }
        ss_disconnect();
        return;
    }
    # t "got bytes $num";
    # TODO add to incoming message and act as bytes to message translator
    # TODO only notify parent upon complete message of interest
    $line .= $buf;
    if(defined $hookcode){
        $hookcode->("bytes", $line);
    }
    
} # end s_read

sub ss_disconnect
{
    return unless $sock;
    t "disconnect...";
    if($sock->connected()){
        $sock->shutdown(2);
        $sock->close();
    }
    # $sel->remove($sock);    
    undef $sock; 
}

sub ss_connect
{
    #my ($host, $port) = @_;
    
    ss_disconnect();
    $sock = IO::Socket::INET->new(PeerAddr => $host.':'.$port);
    croak "Cannot connect" unless defined $sock;
    if ($^O eq 'MSWin32') {
        $sock->autoflush(1);
        $sel = IO::Select->new;
        $sel->add($sock);
        $readtimer = $mw->repeat($readrate => \&ss_read);
    } else {
        $mw->fileevent($sock, 'readable' => \&ss_read);
    }
    return $sock;
}

sub ss_send
{
    my $msg = shift;
    if(not $sock){
        t "no socket";
        return;
    }
    #t "sending ".d($msg);
    $sock->send($msg);
}

1;