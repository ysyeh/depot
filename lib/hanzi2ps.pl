#
# Convert a Hanzi (Chinese character set) text message into a
# PostScript message.
#
# Simon Yeh <syeh@csfcorp.com>, March 1997
#
# Usage: 
#	$out_entity = Hanzi2ps( $in_entity [, $converter ]);
# where
#	$in_entity is a MIME::Entity with content-type as 'text/plain'
#	$out_entity is the converted MIME::Entity if $in_entity is
#		indeed Hanzi message; otherwise $out_entity is 'undef'.
#	$converter is the optional path of the hanzi converter `hz2ps'
#		its default is '/usr/local/bin/hz2ps'.
#
use Hanzi;
use MIME::Entity;

my $REVISION = '@(#)hanzi:hanzi2ps.pl 1.3 28 Mar 1997 17:36:45';

sub Hanzi2ps {
	my $ent = shift;
	my $hz2ps = shift || '/usr/local/bin/hz2ps';
	my $body = $ent->bodyhandle;
	my $IO = $body->open("r");
	my ($data, $ctl, $whatis);

	$data = 0;

	# make sure we know where to find Hanzi fonts and prolog
	return $ent unless ( $ENV{'HBFPATH'} && $ENV{'HZLIB'} ); 

	# input entity's content-type must be 'text/plain'
	return undef unless $ent->mime_type eq 'text/plain';

	# peek first 4K if we don't know the c-t-l
	$ctl = $ent->head->get('Content-length') || 4096;
	$IO->read($data, $ctl);

	# see if this is indeed Hanzi
	($whatis) = Hanzi::HzWhat($data);

	if ($whatis eq 'BIG5') {
		# traditional characters
		$arg = '-big -hf kck24.hbf 10 1';
	} elsif ($whatis eq 'GB' || $whatis eq 'HZ') {
		# simplified characters
		$arg = '-hf ccs16.hbf 10 1';
	} else {
		# anything else is beyond me.
		return $undef;
	}

	my $ofile = $body->path . ".ps";

	my $newent = build MIME::Entity 
			Path		=> $ofile,
			Type		=> "application/postscript",
			Encoding 	=> '7bit';

	my $newbody = $newent->bodyhandle;
	# run hz2ps 
	$newbody->writer("| $hz2ps $arg > $ofile");
	my $newIO = $newbody->open("w");
	$newIO->print($data) || return $undef;
	# in case there are more
	while ($IO->read($data, 4096)) {
		$newIO->print($data);
	}
	$newIO->close;
	$IO->close;

	# see if coverted file exists?
	return $undef unless (-e $ofile);

	my $desc = $ent->head->get('Content-description');
	$newent->head->replace('Content-description', $desc) if $desc;
	$newent->sync_headers(Length=>'COMPUTE');

	# return converted entity
	return $newent;
}

1;
