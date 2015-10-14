#
# %Z%Rolo:%M% %I% %G% %U%
#
# Simon Yeh <syeh@csfcorp.com>, April 1997
#
package Rolo::List;

use Rolo::Entry;
#use HTML::Base;
use Sys::Hostname;
use Carp;
use Flocker;

my %mfield = ('@','Address','#','Comment');

sub new {
	my $that = shift;
	my $basedir = shift;
	my $darpidir = shift;
	my $class = ref($that) || $that;
	my $self = {};
	bless $self, $class;

	$self->{base} = $basedir;
	($basedir, $self->{name}) = ($basedir =~ m|^(\S*/)?([^/]+)$|);

	return undef unless $self->loadconfig();

	return undef unless $self->loadlist();

	foreach $f (qw(hello update bye note)) {
		my $file = "$self->{base}/form.$f";
		$file = "$darpidir/form.$f" unless (-r $file);
		$self->{$f} = $file if (-r $file);
	}

	$self;
}

sub loadconfig {
	my $self = shift;
	my $config = "$self->{base}/config";

	return 0 unless (-d $self->{base} && -r $config);

	do $config;
	croak $@ if $@;

	$self->{name} = $LISTNAME;
	$self->{policy} = $POLICY;
	$self->{pig} = $PIG;
	$self->{owner} = $OWNER;
	$self->{signature} = $OWNERSIG;
	my @domain = @OWNERDOMAIN;;
	$self->{ownerdomain} = \@domain;
	$self->{id} = $COUNT;

	return 1;
}

#
# Utility to build a hash of Rolo::Entity from a file.
#
sub loadlist {
	my $self = shift;
	my $file = shift || "$self->{base}/list";
	my %glist = {};
	my (@gid, @obsid, @bcc, @fax);
	my ($key, $entry, $ownerentry);

	return 0 unless ($file && -r $file);

	open(LIST, $file) || return undef;
	while (<LIST>) {
		chop;
		/^([@#]?)(\d+)\|(.*)/ || next;
		if ($1) {
			$key = $gid[$2];
			if ($key && ($entry = $glist{$key})) {
				$entry->append($mfield{$1}, $3);
			}
		} else {
			$entry = new Rolo::Entry($_);
			$key = $entry->{'Name'} || ${$entry->{'E-Mail'}}[0];
			next unless $key;
			$glist{$key} = $entry;
			$gid[$2] = $key;
			if (grep(&EQ($self->{owner}, $_), @{$entry->{'E-Mail'}})) {
				$ownerentry = $entry;
				$self->{ownerentry} = \$ownerentry;
			}
		}
	}
	close LIST;

	$self->{gid} = \@gid;
	$self->{obsid} = \@obsid;
	$self->{list} = \%glist;

	my ($tmpfax, $tmpemail);
	foreach $key (sort keys %glist) {
		$entry = $glist{$key};
		next if ($entry == $ownerentry);
		if (($tmpfax = $entry->{'Facsimile'}) && $tmpfax =~ /^\*/) {
			push(@fax, $entry->rp_to(0));
		} elsif ($tmpemail = $entry->{'E-Mail'}) {
			splice(@bcc, 0, 0, @$tmpemail);
		}
	}
	$self->{bcc} = \@bcc;
	$self->{fax} = \@fax;

	return 1;
}

sub printmlist {
	my $self = shift;
	my %glist = %{$self->{list}};
	my $eaddr;

	foreach (sort keys %glist) {
		$eaddr = $glist{$_}->out_this('E-Mail', "\n") || next;
		print $eaddr, "\n";
	}
}

sub printlist {
	my $self = shift;
	my %glist = %{$self->{list}};

	foreach (sort keys %glist) {
		next unless $glist{$_};
		print $glist{$_}->pretty_prt(), "\n";
	}
}

sub updatelist {
	my $self = shift;
	my ($delete, $id) = @_;
	my $file = "$self->{base}/list";
	my $obslist =  $file . ".obs";
	my $backlist = $file . ".bak";
	my $r;

	$r = rename $file, $backlist;
	$self->prtentry($file, @{$self->{gid}});
	$self->prtentry($obslist, @{$self->{obsid}}) if ($delete);

	$self->prtconfig() if ($id && ! $delete);
}

sub prtentry {
	my $self = shift;
	my $file = shift;
	my %glist = %{$self->{list}};
	my (@eary) = @_;

	open(SAVEOUT, ">&STDOUT");
	open(STDOUT, ">$file") || croak "Can't redirect to $file: $!";
	flocker(STDOUT, $LOCK_EX);
	for (@eary) {
		next unless $glist{$_};
		$glist{$_}->out() if $_;
	}
	flocker(STDOUT, $LOCK_UN);
	close STDOUT;
	open(STDOUT, ">&SAVEOUT");
}

sub prtconfig {
	my $self = shift;
	my $config = shift;
	my @ownerdomain = @{$self->{ownerdomain}};

	$config = "$self->{base}/config" unless $config;
	$r = rename $config, $config . ".bak";
	open(SAVEOUT, ">&STDOUT");
	open(STDOUT, ">$config") || croak "Can't redirect to $config: $!";
	flocker(STDOUT, $LOCK_EX);

	map { s/(.*)/'\1'/ } @ownerdomain;

	print "\$OWNER='" . $self->{owner} . "';\n";
	print "\$LISTNAME='" . uc $self->{name} . "';\n";
	print "\@OWNERDOMAIN=(" . join(',', @ownerdomain) . ");\n";
	print "\$OWNERSIG='" . $self->{signature} . "';\n";
	print "\$POLICY=" . ( $self->{policy} || '0' ) . ";\n";
	print "\$PIG=" . ( $self->{pig} || '0' ) . ";\n";
	print "\$COUNT=$self->{id};\n";

	flocker(STDOUT, $LOCK_UN);
	close STDOUT;
	open(STDOUT, ">&SAVEOUT");
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


sub EQ { lc $_[0] eq lc $_[1] }

sub printhtmllist {
#	my $self = shift;
#	my $listname = $self->{name};
#	my %glist = %{$self->{list}};
#	my $ownerentry = ${$self->{ownerentry}};
#	my ($page, $body, $table, $tr, $td);
#	my $entry;
#	my $string;
#	my @mtime;
#	my ($dourl, $href);
#
#	$listname =~ y/a-z/A-Z/;
#	$page = new HTML::Base::Page;
#	new HTML::Base::Title;
#	new HTML::Base::Text "$listname List";
#	$page->make_current();
#	$body = new HTML::Base::Body;
#	new HTML::Base::Header 1;
#	new HTML::Base::Text "$listname List";
#
#	$body->make_current();
#	$table = new HTML::Base::Table ('BORDER','','CELLPADDING',4);
#
#	foreach (sort keys %glist) {
#		$entry = $glist{$_};
#		$table->make_current();
#		$tr = new HTML::Base::TableRow;
#		new HTML::Base::TableHeader ('ALIGN','left');
#		$string = $entry->{'Name'};
#		new HTML::Base::Text ('Text', $entry->{'Name'});
#		if ($entry->{'Alias'}) {
#			$tr->make_current();
#			new HTML::Base::TableData ('ALIGN','right');
#			new HTML::Base::Italic;
#			new HTML::Base::Text ('Text', 'Alias:');
#			$tr->make_current();
#			new HTML::Base::TableData;
#			new HTML::Base::Text ('Text', $entry->{'Alias'});
#		}
#		foreach $tag ('E-Mail', 'URL') {
#			next unless (@elms = @{$entry->{$tag}});
#			$dourl = $tag eq 'URL';
#			$table->make_current();
#			$tr = new HTML::Base::TableRow;
#			new HTML::Base::TableData ('ALIGN','right');
#			new HTML::Base::Italic;
#			new HTML::Base::Text ('Text', $tag.':');
#			$tr->make_current();
#			$td = new HTML::Base::TableData('COLSPAN',2);
#			while (@elms) {
#				($elm = shift @elms) =~ s/\s//g;
#				$elm =~ s|^(http://)*|http://| if $dourl;
#				$td->make_current();
#				$href = $dourl ? $elm : 'mailto:'.$elm;
#				new HTML::Base::Anchor('HREF', $href);
#				new HTML::Base::Text ('Text',$elm);
#				if (@elms) {
#					$td->make_current();
#					new HTML::Base::Text ('Text', ', ');
#				}
#			}
#		}
#		if ($entry->{'Telephone'}) {
#			$table->make_current();
#			$tr = new HTML::Base::TableRow;
#			new HTML::Base::TableData ('ALIGN','right');
#			new HTML::Base::Italic;
#			new HTML::Base::Text ('Text','Telephone:');
#			$tr->make_current();
#			new HTML::Base::TableData('COLSPAN',2);
#			new HTML::Base::Text ('Text',$entry->{'Telephone'});
#		}
#		if ($string = $entry->{'Facsimile'}) {
#			$table->make_current();
#			$tr = new HTML::Base::TableRow;
#			new HTML::Base::TableData ('ALIGN','right');
#			new HTML::Base::Italic;
#			new HTML::Base::Text ('Text','Facsimile:');
#			$tr->make_current();
#			new HTML::Base::TableData('COLSPAN',2);
#			if ($string =~ s/^\*//) {
#				new HTML::Base::Anchor('HREF','mailto:' . $entry->rp_to(0));
#			}
#			new HTML::Base::Text ('Text',$string);
#		}
#		if ($string = $entry->{'Address'}) {
#			$table->make_current();
#			my @lines = split('\n', $string);
#			$tr = new HTML::Base::TableRow;
#			new HTML::Base::TableData ('ALIGN','right','VALIGN','top');
#			new HTML::Base::Italic;
#			new HTML::Base::Text ('Text','Address:');
#			$tr->make_current();
#			$td = new HTML::Base::TableData('COLSPAN',2);
#			while (@lines) {
#				$td->make_current();
#				new HTML::Base::Text ('Text',shift(@lines));
#				new HTML::Base::Break if @lines;
#			}
#		}
#	}
#	$body->make_current();
#	new HTML::Base::Break;
#	new HTML::Base::HorizontalRule;
#	$body->make_current();
#	new HTML::Base::Table('WIDTH', '100%');
#	$tr = new HTML::Base::TableRow;
#	$tr->make_current();
#	new HTML::Base::TableData('ALIGN','left');
#	new HTML::Base::Text('Text', 'Comments to hosekeeper, ');
#	new HTML::Base::Anchor('HREF', 'mailto:' . $ownerentry->{'E-Mail'}[0]);
#	new HTML::Base::Text('Text', $ownerentry->{'E-Mail'}[0]);
#	$tr->make_current();
#	new HTML::Base::TableData('ALIGN','right');
#	my @liststat = stat($self->{base} . "list");
#	@mtime = localtime($liststat[9]);
#	new HTML::Base::Text('Text', 
#		sprintf("Last modified %d/%d/%d", 
#		$mtime[4]+1,$mtime[3],$mtime[5]));
#	$page->realize;
}

sub lookup {
	my ($self, $email, $name) = @_;
	my %list = %{$self->{list}};
	my @gid = @{$self->{gid}};
	my $ownerentry = ${$self->{ownerentry}};
	my $entry = $list{$name};
	my $oname;

	if ($entry && grep(&EQ($email, $_), @{$entry->{'E-Mail'}})) {
		return ($entry, $email, $name); 
	}

	my ($ownerid, $ownerhost) = $self->{owner} =~ /(\S+)\@(.*)/;
	my ($fromid, $fromhost);
	if ($email =~ /@/) {
		($fromid, $fromhost) = $email =~ /(\S+)\@(.*)/;
	} else {
		($fromid, $fromhost) = ($email, hostname());
	}
	my $match;
	if (&EQ($ownerid, $fromid)) {
		my ($fname, $falias, $faddrtype, $flength, @faddrs)
			= gethostbyname($fromhost);
		my @octal = unpack('C4', $faddrs[0]);
		last CHECKLIST unless (@octal);
		my @ownerdomain = @{$self->{ownerdomain}};
		for (@ownerdomain) {
			my @adomain = split(/\./);
			$match = 0;
			for (0..$#adomain) {
				last if ($octal[$_] != $adomain[$_]);
				$match = 1;
			}
			last if $match;
		}
		if ($match) {
			$entry = $ownerentry;
			$oname = $gid[$ownerentry->{'ID'}];
			$email = $self->{owner};
		}
	}
CHECKLIST:
	if (! $match) {
		foreach $key (keys %list) {
			if (grep(&EQ($email, $_), @{$list{$key}->{'E-Mail'}}))
			{
				$entry = $list{$key};
				# official name is different.
				$oname = $list{$key}->{'Name'};
				$match = 1;
				last;
			}
		}
	}
	($entry, $email, $match ? $oname : $name);
}

sub rplookup {
	my ($self, $recipient) = @_;
	my %glist = %{$self->{list}};
	my $ep = $glist{$recipient};
	
	return $ep if $ep;
	my ($recnum, $key, $num, @data);
	($recnum = $recipient) =~ s/[^\d]//g;
	while (($key, $ep) = each %glist) {
		if ($recnum) {
			($num = $ep->{'Facsimile'}) =~ s/[^\d]//g;
			return $ep if $num eq $recnum;
		}
		@data = @{$ep->{'E-Mail'}};
		for (qw(Alias Name)) {
			next unless $ep->{$_};
			push(@data, $ep->{$_});
		}
		return $ep if (grep(&EQ($recipient, $_), @data));
	}
	return undef;
}

sub add {
	my ($self, $newentry, $oname) = @_;
	my %glist = %{$self->{list}};
	my $nname = $newentry->{'Name'};
	my $dupname;
	if ($glist{$nname}) {
		$oname = $newentry->{'E-Mail'} if ($glist{$oname});
		$dupname = $nname;	
		$newentry->{'Name'} = $oname;
	} elsif (! $nname) {
		$newentry->{'Name'} = $oname;
	}
	$self->modify($newentry);
	return $dupname;
}

sub delete {
	my ($self, $entry) = @_;
	my $gid = \@{$self->{gid}};
	my $obsid = \@{$self->{obsid}};
	$$obsid[$entry->{'ID'}] = $entry->{'Name'};
	$$gid[$entry->{'ID'}] = 0;
}

sub modify {
	my ($self, $newentry, $oldentry) = @_;
	my $glist = \%{$self->{list}};
	my $gid = \@{$self->{gid}};

	return undef unless ($newentry);

	my $nname = $newentry->{'Name'};
	my $oname = $oldentry ? $oldentry->{'Name'} : $nname;
	my $dupname;
	if ($nname ne $oname) {
		if ($$glist{$nname}) {
			$newentry->{'Name'} = $oname;
			$dupname = $nname;
		} else {
			$$glist{$nname} = $oldentry;
			delete $$glist{$oname};
		}
	} elsif (! $oldentry) {
		$self->{id}++;
		my $id = $self->{id};
		$newentry->store('ID', $id);
		$nname = $newentry->{'Name'} || ${$newentry->{'E-Mail'}}[0];
		$$glist{$nname} = $newentry;
		$$gid[$id] = $nname;

		return undef;
	}

	# id is not allowed to be changed.
	$newentry->store('ID', $oldentry->{'ID'});
	$oldentry->copy($newentry);
	$$gid[$oldentry->{'ID'}] = $nname;

	return $dupname;
}

1;
