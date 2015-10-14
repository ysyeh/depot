package Hanzi;

$Hanzi::revision = '@(#)hanzi:Hanzi.pm 1.2 28 Mar 1997 13:01:57';
$Hanzi::VERSION = '1.0';

my $HanziPat = '([\x80-\xff])([\x40-\xff])';
my $HZpat = '~([\{}])';

my %CodeTable = (
	BIG5 => {
		MAP => [ 0xa140, 0xa3fe, 0xa440, 0xc67e, 0xc940, 0xf9d5 ]
	},
	GB   => {
		MAP => [ 0xa1a1, 0xa9fe, 0xb0a1, 0xd7f9, 0xd8a1, 0xf7fe ]
	}
);

sub HzWhat {
	my ($text) = shift;
	my (@chartsets, @winners) = ( (), () );
	my (%charsets, %hzchars);
	my ($hzstart, $hzend, $num_char16) = ( 0, 0, 0 );

	undef %charsets;
	if (@_) {
		my $name;
		foreach (@_) {
			$name = uc $_;
			$charsets{$name} = $_;
			if ($name ne 'HZ' && $name ne 'ASCII') 
			{ push(@charsets, $name); next; }
		}
	} else {
		map { $charsets{$_} = $_; } (@charsets = keys %CodeTable);
		$charsets{HZ} = 'HZ';
		$charsets{ASCII} = 'ASCII';
	}
	
	undef %hzchars;
	if (@charsets || $charsets{ASCII}) {
		my @candidates;

		map { $CodeTable{$_}->{TALLY} = 0; } @charsets;

		for ($postmatch = $text; 
		     $postmatch =~ /$HanziPat/o; 
		     $postmatch = $') {
			$hzchars{ord($1) *256 + ord($2)}++;
		}

		map { $num_char16++; } keys %hzchars;

		map {
			$entry = $CodeTable{$_};
			my %tmpchars = %hzchars;
			my $mapcnt = $#{$entry->{MAP}} - 1;
			my ($lo, $hi);
			for ($i = 0; $i <= $mapcnt; $i += 2) {
				($lo, $hi) = @{$entry->{MAP}}[$i, $i+1];
				foreach $code (keys %tmpchars) {
					next if ($code < $lo);
					next if ($code > $hi);
					$entry->{TALLY}++;
					delete $tmpchars{$code};
				}
			}
			push(@candidates, $_) if ($entry->{TALLY} > 0);
		} @charsets;

		@winners = reverse sort { 
			$CodeTable{$a}{TALLY} <=> $CodeTable{$b}{TALLY}; 
		} @candidates if @candidates;

		# make sure this is indeed ASCII
		if ($num_char16 == 0 && $charsets{ASCII}) {
			$num_char16 = 1 if ($text =~ /[\x80-\xff]/);
		}

		# maybe there isn't a definitive winner?
		if (@winners &&
			($num_char16 > $CodeTable{$winners[0]}->{TALLY})) {
			splice(@winners, -1, 0, '?');
		}
	}

	if ($charsets{HZ} and !$num_char16) {
		for ($postmatch = $text; 
		     $postmatch =~ /$HZpat/o; 
		     $postmatch = $') {
			($1 eq '}') ? $hzend++ : $hzstart++;
		}
		push(@winners, $charsets{HZ}) if ($hzstart && $hzstart == $hzend);
	}

	push(@winners, $charsets{ASCII}) if ($#winners < 0) && $charsets{ASCII};

	@winners;
}

1;
__END__

=head1 NAME

Hanzi - hanzi text processing utilities.

=head1 SYNOPSIS

	use Hanzi;

	undef $/;
	$sometext = <>;

	#
	# have no clue what character set $sometext is
	#
	($whatis, @whatcouldbe) = Hanzi::HzWhat($sometext);
	if ($whatis eq '?') {
	   print "it's not ascii";
	   if ($#whatcouldbe >= 0) {
	      print " and neither ", join(" nor ", @whatcouldbe);
	   }
	   print "\n";
	} else {
	   print "it looks like $whatis.\n";
	}


	#
	# see if $sometext is either gb or hz?
	#
	($whatis) = Hanzi::HzWhat($sometext, 'gb', 'hz');
	if (!$whatis) {
	   print "It is neither gb nor hz.\n");
	} elsif ($whatis eq '?') {
	   # its neither 'gb' nor 'hz', could it be 'big5'?
	   ($isbig5) = Hanzi::HzWhat($sometext, 'big5');
	   print "It's ", $isbig5 eq 'big5' ? "" : " not ", "big5.\n";
	} else {
	   print "it looks like $whatis.\n";
	   if ($whatis eq 'hz') {
	      ($isascii) = Hanzi::HzWhat($sometext, 'ASCII');
	      if ($isascii eq 'ASCII') {
	   	 print "But of course, hz is 7bit code.\n";
	      } else {
		 # should never happen.
	   	 print "&*%@!! what a crap this Hanzi::HzWhat() is.\n";
	      }
	   }
	}

=head1 DESCRIPTION

Only one utility C<Hanzi::HzWhat> is implemented at this moment.

C<Hanzi::HzWhat> makes a semi-intelligent guess about what code set the 
given input text segment is. It returns an array of code sets with
descending likelihood, depends what code sets caller wishs C<Hanzi::HzWhat> 
to check. If caller provides no target code sets, all code sets that known 
to C<Hanzi> will be checked. If none of the target code sets is found
to be conclusive (which means there are two-byte codes don't belong to
any target code set), the first element of the array which C<Hanzi::HzWhat>
returns will be '?'. On the other hand, if C<Hanzi::HzWhat> is certain
that none of the target char sets is the answer, a null array is returned.

Known Hanzi encoding sets: GB, Big5, HZ. Plus ASCII.

This module is intended to provide assorted Hanzi text processing
utilites for the Perl world. Addition and comment are all welcome.

You need Perl version 5.000 or later to use this module.

=head1 CAVEAT

It makes no sense to apply C<Hanzi::HzWhat> to heterogeneous text or 
binary data.

=head1 AUTHORS

Simon Yeh <syeh@csfcorp.com>, 7 February, 1997.

=cut
