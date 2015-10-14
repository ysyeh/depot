#
# 
#
# Simon Yeh <syeh@csfcorp.com>, April 1997
#
# $Revision = '@(#)Converter:Toolbox.pm 1.2 11 Apr 1997 17:09:58';
#
package Converter::Toolbox;

use Converter::Entity;

#
# Utility to build a hash of Converter::Entity from a file.
# Each hash element is a list of converters corresponding to
# that particular content-type.
#
# The format of the file is:
#
sub loadconverters {
	my $file = shift;
	my $result;
	my %cvthash = {};

	return undef unless ($file && -r $file);

	open(FH, $file) || return undef;
	while (<FH>) {
		next if (/^#/);
		my $cvt = new Converter::Entity($_);
		next unless $cvt;
		if (! exists $cvthash{$cvt->type}) {
			my @onelist = ();
			$cvthash{$cvt->type} = \@onelist;
		}

		# load this package;
		if ($result = $cvt->require()) {
			# assume there is no duplicate converter for now
			push(@{$cvthash{$cvt->type}}, $cvt);
		} else {
			undef $cvt;
		}
	}

	%cvthash;
}

sub mkhash {
	my $delimiter = shift;
	my %h = {};
	my ($name, $val);

	for (@_) {
		($name, $val) = split /$delimiter/;
		$name =~ s/^\s//;
		$name =~ s/\s$//;
		$val =~ s/^\s//;
		$val =~ s/\s$//;
		$val =~ s/^"//;
		$val =~ s/"$//;
		$h{$name} = $val if $name;
	}
	\%h;
}

#
# Given a MIME content-type header field, return its 'type' as a scalar
# and it's auxiliary 'parameters' (i.e. a list of ';' delimited 
# <name>=<value> pairs) as a hash reference.
#
sub parsetype {
	my @cte = split(/;/, shift);
	my $type = shift @cte;
	($type, mkhash('=', @cte));
}

1;
