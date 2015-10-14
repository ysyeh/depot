#
# %Z%Rolo:%M% %I% %G% %U%
#
# Simon Yeh <syeh@csfcorp.com>
#
package Rolo::Entry;

require 'table.pl';
require 'phone.pl';

# default fields used
my @fields = (
	'ID',
	'E-Mail',
	'Name',
	'Alias',
	'Telephone',
	'Facsimile',
	'URL',
	'Address',
	'Comment'
);

@ISA = qw( Table );

sub new {
        my $type = shift;
        my $self;

        $self = @_ ? Table->new(@_, @fields) : Table->new();

        bless $self, $type;

	$self->makerefs('E-Mail');
	$self->makerefs('URL');

        return $self;
}

sub store {
	my $self = shift;
	my @params = @_;

	return if (! @_);
	if ($#params == 0) {
		my $idx = 0;
		for (split(/\|/, $params[0])) {
			$self->{$fields[$idx++]} = $_;
		}

		$self->makerefs('E-Mail');
		$self->makerefs('URL');
	} else {
		my %params = @params;
		foreach $key (keys %params) {
			$self->{$key} = $params{$key};
			$self->makerefs($key) 
				if ($key eq 'E-Mail' || $key eq 'URL');
		}
	}
}

sub append {
	my $self = shift;
	my %params = @_;

	foreach $key (keys %params) {
		if ($key eq 'E-Mail' || $key eq 'URL') {
			my (@list) = ();
			$self->{$key} = \@list unless $self->{$key};
			foreach $val (split(',', $params{$key})) {
				$val =~ s/\s//g;
				next if grep(&EQ($val, $_), @{$self->{$key}});
				push(@{$self->{$key}}, $val);
			}
			next;
		}
		$self->{$key} .= "\n" if ($self->{$key});
		$self->{$key} .= $params{$key};
	}
}

sub copy {
	my ($self, $src) = @_;
	foreach $key (keys %$src) {
		next if (! $src->{$key});
		# takes no blank lines here.
		$src->{$key} =~ s/\s+\n// if ! ref($src->{$key});
		$self->{$key} = $src->{$key} if ($src->{$key});
	}
}

sub parsemsg {
	my ($self, $msg) = @_;
	my ($key);

	foreach (split(/\n+/, $msg)) {
		#chop;
		next if /^#/;
		s/^\s+//;
		s/\s+$//;
		next if (! s/^([-\w]+):\s*//);
		$key = $1;
		s/\|/,/g;
		if ($key) {
			# name should be replaced, not appended
			if ($key eq 'Name') {
				$self->{'Name'} = $_;
			} else {
				$self->append($key, $_ || ' ');
			}
		}
	}
}

sub makerefs {
	my $self = shift;
	my $key = shift;

	if ($self->{$key} && ! ref($self->{$key})) {
		my @list = split(',', $self->{$key});
		$self->{$key} = \@list;
	}
}

sub pretty_prt {
	my $self = shift;
	my $fmt = shift || "  %12s  %s\n";
	my @seq = @_ || @fields[2,3,1,4,5,6,7,8]; 
	my ($field, $out);

	undef $out;
        for (@seq) {
		next if (! $self->{$_});
		$field = $_ . ":";
		if (ref($self->{$_}) eq "ARRAY") {
			$out .= sprintf $fmt, $field, $self->out_this($_, ', ');
			next;
		}
		for (split('\n', $self->{$_})) {
                	$out .= sprintf $fmt, $field, $_;
			$field = ' ' x 10;
		}
        }
	return $out;
}

sub out_this {
	my $self = shift;
	my $field = shift || 'E-Mail';
	my $delimiter = shift || '\n';
	my $out;

	return undef if (! $self->{$field});
	if (ref($self->{$field}) eq "ARRAY") {
		return join($delimiter, @{$self->{$field}});
	} else {
		return $self->{$field};
	}
}

sub out {
	my ($self) = @_;
	my ($id) = $self->{'ID'};
	my (@lump);

	for (@fields[0..6]) {
		push(@lump, $self->out_this($_, ','));
	}
	print join('|', @lump), "|\n";

	for (@fields[7,8]) {
		$prefix = $_ eq 'Address' ? '@' : '#';
		for (split('\n', $self->{$_})) {
			print "$prefix$id|$_\n";
		}
	}
}

#
# generate cover page for tpc-rp service,
# usage goes like: 
# 	$cover = $recipient->rp_cover(1) . "\n" . $originator->rp_cover(0);
#

sub rp_cover {
	my ($self, $recv) = @_;
	my ($fmt) = "%-12s\t%s\n";
	my ($field, $number, $phone, $out);

	$out .= sprintf $fmt, $recv?"Recipient:":"Originator:", $self->{'Name'};
	if ($recv && $self->{'Address'}) {
		$field = "Address:";
		for (split('\n', $self->{'Address'})) { 
			$out .= sprintf($fmt, $field, $_);
			$field = "       ";
		}
	}
	undef $number;
	undef $phone;
	for (@fields[4,5]) {
		if ($numbers = $self->{$_}) {
			$numbers =~ s/[^0-9 ,]//g;
			($phone) = $numbers =~ /(\d+)/;
			$out .= sprintf($fmt, "$_:", &cv_phone($phone));
		}
	}
	my (@eaddress) = @{$self->{'E-Mail'}};
	$out .= sprintf($fmt, "E-Mail:", $eaddress[0]) unless $recv;

	return $out;
}

#
# generate tpc-rp relay `address', something like:
#    remote-printer.<name>/<address>/<telephone>@<facsimile>.iddd.tpc.int
#
sub rp_to {
	my ($self) = shift;
	my ($shortform) = shift;
	my ($to, $name, $address, $telephone, $facsimile);
	my ($number);

	if (! $self->{'Facsimile'}) {
		return '';
	}
	($number = $self->{'Facsimile'}) =~ s/[^0-9 ,]//g;
	$number =~ s/\D//g;
	($facsimile = &cv_phone($number)) =~ s/\D//g;

	if ($shortform) {
		return "remote-printer\@$facsimile.iddd.tpc.int";
	}

	($name = $self->{'Name'}) =~ s/\W/_/g;
#	if ($address = $self->{'Address'}) {
#		$address =~ s!/!_!g;
#		$address =~ s!\n!/!g;
#		$address =~ s![^/\w]!_!g;
#		$address =~ s!^!/!;
#	}
#	if ($number = $self->{'Telephone'}) {
#		$number =~ s/[^0-9 ,]//g;
#		$number =~ s/^\s+//;
#		$number =~ s/(\d+).*/\1/;
#		$telephone = 'TEL_' . &cv_phone($number);
#		$telephone =~ s!\W!_!g;
#		$telephone =~ s!^!/!;
#	}
	$to="remote-printer.$name$address$telephone\@$facsimile.iddd.tpc.int";
	return $to;
}

#
# this is much faster than ($x) = $y =~ m/^$y$/i,
# about 9:1
#
sub EQ { lc $_[0] eq lc $_[1] }

1;
