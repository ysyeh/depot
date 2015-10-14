package Hanzi::conversion;

=head1 NAME

Hanzi::conversion - convert a Hanzi (Chinese character set) text message
                    into PostScript message.

=head1 SYNOPSIS

Convert a MIME entity $in_entity, a Hanzi text message, into a PostScript
MIME entity $out_entity:

	use Hanzi::conversion;
	$out_entity = Hanzi::conversion::text2ps( $in_entity 
                                         [, $converter [, $hzcode ] ]);

where $converter is the optional path of hanzi converter (either `cnprint'
or `hz2ps'). Its default is '/usr/local/bin/hz2ps'. 

If the content-type of $in_entity is not 'text/plain' or the message body
is not Hanzi message (checked with C<Hanzi::utils::HzWhat> if $hzcode is not 
supplied) then $out_entity will be 'undef'.
	
If message's character set is known, so there is no need to check it
with C<Hanzi::utils::HzWhat>, use these two functions:

	# convert traditional (BIG5) Hanzi to postscript
	$out_entity = Hanzi::conversion::bg2ps( $in_entity [, $converter ]);
	
	# convert simplified (GB) Hanzi to postscript
	$out_entity = Hanzi::conversion::gb2ps( $in_entity [, $converter ]);

	# convert simplified (HZ) Hanzi to postscript,
	# note that converter `hz2ps' doesn't support HZ to PostScript 
	# conversion
	$out_entity = Hanzi::conversion::hz2ps( $in_entity [, $converter ]);

This module requires Eryq's MIME-tools Version 3.204 be installed, which is
available from CPAN.

=head1 AUTHOR

Simon Yeh <syeh@csfcorp.com>, April 1997

=head1 VERSION

$Revision: '@(#)Hanzi:conversion.pm 1.6 10 Jun 1997 18:09:12'

=cut

use Hanzi::utils;
use MIME::Entity;


sub mime2ps {
	my ($ent, $converter, $whatis) = @_;
	my $body = $ent->bodyhandle;
	my $IO = $body->open("r");
	my ($data, $ctl, $size);
	my ($hz2ps, $cnprint);

	$data = 0;

	$converter = '/usr/local/bin/hz2ps' unless $converter;

	# make sure we know where to find Hanzi fonts
	return undef unless ( $ENV{'HBFPATH'} ); 

	if ($converter =~ /hz2ps/) {
		$hz2ps = 1 
	} elsif ($converter =~ /cnprint/) {
		$cnprint = 1;
	} else {
		return undef;
	}

	# also make sure we know where to find prolog (hz2ps only)
	return undef if ( $hz2ps && ! $ENV{'HZLIB'} ); 

	# input entity's content-type must be 'text/plain'
	return undef unless $ent->mime_type eq 'text/plain';

	if (! $whatis) {
		# peek first 4K if we don't know its length
		$ctl = $ent->head->get('Content-length') || 4096;
		$IO->read($data, $ctl);
	
		# see if this is indeed Hanzi
		($whatis) = Hanzi::utils::HzWhat($data);
	}
	$whatis = uc $whatis;

	$size = $ENV{'SIZE'} || 16;
	if ($whatis eq 'BIG5') {
		# traditional characters
		return $ent unless $ENV{'BGFONT'}; 
		if ($hz2ps) {
			$arg = "-big -hf " . $ENV{'BGFONT'} . ".hbf";
		} else {
			$arg = "-big5 -f=". $ENV{'BGFONT'} . ".hbf";
		}
	} elsif ($whatis eq 'GB') {
		# simplified characters
		return $ent unless $ENV{'GBFONT'}; 
		if ($hz2ps) {
			$arg = "-hf " . $ENV{'GBFONT'} . ".hbf";
		} else {
			$arg = "-gb -f=". $ENV{'GBFONT'} . ".hbf";
		}
	} elsif ($whatis eq 'HZ') {
		# unfortunately 'hz2ps' doesn't handle HZ.
		if ($hz2ps) {
			return undef;
		} else {
			$arg = "-hz -f=". $ENV{'GBFONT'} . ".hbf";
		}
	} else {
		# anything else is beyond me.
		return undef;
	}

	my $ofile = $body->path . ".ps";

	#
	# I wonder if I could just replace the original entity's 
	# body and fix its header?
	# 
	my $newent = build MIME::Entity 
			Path		=> $ofile,
			Type		=> "application/postscript",
			Encoding 	=> '7bit';

	my $newbody = $newent->bodyhandle;
	my $cmd = "| $converter $arg ";
	if ($hz2ps) {
		# run hz2ps 
		$cmd .= "$size 1 > $ofile 2> /dev/null";
	} else {
		# run cnprint 
		$cmd .= "-i -w -t -size=$size -o=$ofile 2> /dev/null";
	}
	$newbody->writer($cmd);
	my $newIO = $newbody->open("w");
	$newIO->print($data) || return undef;
	# in case there is more
	while ($IO->read($data, 4096)) {
		$newIO->print($data);
	}
	$newIO->close;
	$IO->close;

	# see if coverted file exists?
	# definitely need a better mechanism to figure out whether
	# the conversion is successful or not.
	return undef unless (-e $ofile && -s _);

	my $desc = $ent->head->get('Content-description');
	$newent->head->replace('Content-description', $desc) if $desc;
	$newent->sync_headers(Length=>'COMPUTE');

	# return converted entity
	return $newent;
}

sub hz2ps {
	push(@_, '') if $#_ == 0;
	return mime2ps(@_, 'HZ');
}

sub gb2ps {
	push(@_, '') if $#_ == 0;
	return mime2ps(@_, 'GB');
}

sub bg2ps {
	push(@_, '') if $#_ == 0;
	return mime2ps(@_, 'BIG5');
}

sub text2ps {
	return mime2ps(@_);
}

1;
