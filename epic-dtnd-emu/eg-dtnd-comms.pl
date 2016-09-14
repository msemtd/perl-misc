#! perl -w
use strict;
use FindBin;                # where was script installed?
use lib $FindBin::Bin;      # use that dir for libs, too
use tmstub;
# Hot file handle magic...
select((select(STDERR), $| = 1)[0]);
select((select(STDOUT), $| = 1)[0]);



use IO::Socket;
use Tk;

my $mw = MainWindow->new;
my $text = $mw->Text->pack;
my $sock = IO::Socket::INET->new(PeerAddr => 'localhost:10254');
die "Cannot connect" unless defined $sock;
$mw->fileevent($sock, 'readable' => \&read_sock);
MainLoop;

sub read_sock {
    my $numbytes = 5;	
    my $line;
    while ($numbytes) {
        my $buf;
        my $num = sysread $sock, $buf, $numbytes;
        $numbytes -= $num;
        $line .= $buf;
    }
    $text->insert('end',"$line\n");
}