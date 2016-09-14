#! perl -w
use strict;
package prot_led_test;

use Carp;
use tmstub; 

my $msg = '';

## given some bytes, returns a list of completed messages or undef
sub add_bytes {
    my $bytes = shift;
    # drive state machine - bytes to message translator
    # split data into messages and only return those of interest!
    my @chars = map {sprintf "%02X", $_;} unpack "C*", $bytes;
    t("RX(".scalar(@chars).") @chars");
    my @msgs;
    my @bytes = unpack "C*", $bytes;
    foreach(@bytes){
        if($_ == 0x0A || $_ == 0x0D){
            if(length $msg){
                push @msgs, $msg;
            }
            $msg = '';
            next;
        }
        $msg.= chr($_);
    }
    return @msgs;
}

sub clear {
    $msg = '';
}

1;