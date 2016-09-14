#!/usr/bin/perl -w
use strict;
package dtnd;
use tmstub;
###########################################################
# DTND functionality
#
# data passed around in either byte arrays (@ba) 
# just lists of small ints
# or packed data
# just a scalar of  pack("C*", @ba);
#


# wrap with SOH, ETX
sub escape_and_wrap {
    my $data = shift;
    $data = escape($data);
    return chr(0x01).$data.chr(0x03);
}

# ESC = ESC+ESC, SOH = ESC+'1', ETX = ESC+'3' 
sub escape {
    my @bytes = unpack("C*", shift);
    my @out;
    foreach(@bytes){
        # escape other special chars...
        if($_ == 0x01){
            push(@out, 0x1B, 0x31);
            next;
        }
        if($_ == 0x03){
            push(@out, 0x1B, 0x33);
            next;
        }
        if($_ == 0x1B){
            push(@out, 0x1B, 0x1B);
            next;
        }
        push(@out, $_);
    }
    return pack("C*", @out);
}

# ESC = ESC+ESC, SOH = ESC+'1', ETX = ESC+'3' 
sub unescape {
    my @bytes = unpack("C*", shift);
    my @out;
    my $esc = 0;
    foreach(@bytes){
        if($esc){
            if($_ == 0x1B){
                push(@out, 0x1B);
            } elsif($_ == 0x31){
                push(@out, 0x01);
            } elsif($_ == 0x33){
                push(@out, 0x03);
            } else {
                push(@out, $_);
            }
            $esc = 0;
            next;
        }
        if($_ == 0x1B){
            $esc = 1;
            next;
        }
        push(@out, $_);
    }
    return pack("C*", @out);
}

sub header {
    my $head = shift;
    # 4 bytes of header with 2byte source and 2 byte dest
    return pack("CCCC", unpack("C*",$head));
}

## returns a 2 character hex value of a checksum.
## Checksum starts with 0x55 then adding the numeric value of each byte
## Truncated to 8 bits then returned as 2 digits of ascii hex
sub get_checksum_hex {
    my $msg = shift;
    my @ba = unpack("C*", $msg);
    my $sum = 0x55;
    foreach(@ba){$sum += $_;}
    $sum &= 0xFF;
    return sprintf("%02X", $sum);
}

sub append_checksum_bytes {
    my $msg = shift;
    my $hex = get_checksum_hex($msg);
    my ($h1, $h2) = split //, $hex;
    my @ba = unpack("C*", $msg);
    push @ba, ord($h1), ord($h2);
    #~ t d \@ba;
    return pack("C*", @ba);
}

sub make_message_type {
    my($header, $mtype, $data) = @_;
    my $msg = header($header).$mtype;
    $msg .=$data if defined $data;
    # append checksum...
    $msg = append_checksum_bytes($msg);
    return escape_and_wrap($msg);
}

sub make_poll_message {
    my $header = shift;
    return make_message_type($header, chr(0x20));
}

sub make_display_message {
    my $header = shift;
    my $msg = shift;
    my $digits = "";
    my $text = "";
    if(defined $msg && length($msg)>0 ){ 
        $digits = substr($msg, 0, 3);
    }
    if(defined $msg && length($msg)>3 ){ 
        $text = substr($msg, 3, 20);
    }
    # format message 3 digits, 20 text
    my $data  = sprintf("\\L1%-3s\\L2%-20s", $digits, $text);
    #~ t d $data;
    #$data = pack("C*", $data);
    return make_message_type($header, chr(0x32), $data);
}

sub make_display_test_message {
    my $header = shift;
    return make_message_type($header, chr(0x32), "\\Z");
}
sub make_display_clear_message {
    my $header = shift;
    return make_message_type($header, chr(0x32), "\\C");
}
1; # <-- return true