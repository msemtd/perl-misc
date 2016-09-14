#!perl -w
use strict;
use File::Slurp;
use tmstub;

my @hexcolors = ( "00", "33", "66", "99",
"CC", "FF" );
my %oppcolors = (
"00" => "FF",
"33" => "FF",
"66" => "FF",
"99" => "FF",
"CC" => "00",
"FF" => "00",
);

my @websafes;
my @opps;

sub generate_websafes {
    foreach my $r (@hexcolors) {
        my $r_opp = $oppcolors{$r};
        foreach my $g (@hexcolors) {
            my $g_opp = $oppcolors{$g};
            foreach my $b (@hexcolors) {
                my $b_opp = $oppcolors{$b};
                my $rgb = $r.$g.$b;
                my $rgb_opp = $r_opp.$g_opp.$b_opp;
                push @websafes, $rgb;
                push @opps, $rgb_opp;
            }
        }
    }
}

generate_websafes();
html_out_colours("websafes.html", \@websafes, \@opps);

sub html_out_colours {
    my $fname = shift;
    my $bgref = shift;
    my $fgref = shift;
    my $num = scalar(@$bgref);

    my @out;
    push @out, "<html><body><table>";

    foreach(my $i = 0; $i<$num; $i++){
        my $bg = $bgref->[$i];
        my $fg = $fgref->[$i];
        #~ print "$bg == $fg \n";
        push @out, "<tr><td bgcolor=$bg><font color=$fg>$bg<br/>$fg</td></tr>";
    }
    push @out, "</table></body></html>";
    my $out = join "\n", @out;
    write_file($fname, $out);
}

# snap number to nearest 0x33 boundary
sub snap {
    my $r = shift;
    my $round = sprintf "%.0f", $r/0x33;
    my $nrst = int($round) * 0x33;
    return $nrst;
}

# snap rgb values to websafe rgb values
sub snap_rgb {
    my($r, $g, $b) = @_;
    ($r, $g, $b) = map{snap($_)} ($r, $g, $b);
    return ($r, $g, $b);
}

sub split_rgb {
    my $v = shift;
    # split supplied value into RRGGBB decimal integers...
    die unless $v =~ /^([[:xdigit:]]{2})([[:xdigit:]]{2})([[:xdigit:]]{2})$/;
    my ($r, $g, $b) = (hex($1), hex($2), hex($3));
    return($r, $g, $b);
}

sub join_rgb {
    my($r, $g, $b) = @_;
    return(sprintf("%02X%02X%02X", $r, $g, $b));
}

sub contrasting_rgb {
	my @rgb = split_rgb(shift);
	# make websafe
    @rgb = snap_rgb(@rgb);
    @rgb = map{ hex( $oppcolors{ sprintf("%02X", $_) } ) } @rgb;
	return join_rgb(@rgb);
}

{
	# generate 256 random colours...
	my @r = (1..256);
	@r = map{ sprintf("%02X%02X%02X", int(rand(256)), int(rand(256)), int(rand(256)))} @r;
	#~ t d \@r;
	# create 256 associated contrasting colours...
	my @c = map{ contrasting_rgb($_)} @r;
	# bang them into a file...
	html_out_colours("rands.html", \@r, \@c);
}