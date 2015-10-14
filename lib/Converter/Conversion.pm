#
# 
#
# Simon Yeh <syeh@csfcorp.com>, September 1997
#
# $Revision = '@(#)Converter:Conversion.pm 1.1 23 Sep 1997 16:13:08';
#
package Converter::Conversion;

use Exporter();
use Converter::Entity;

@ISA = qw(Exporter);

@EXPORT  = qw(ConvertMime);

sub ConvertMime {
    my $partref = shift;
    my $cvtrsref = shift;
    my $i = 0;
    my $ent;
    foreach $ent (@$partref)
    {
      my $cvtent;
      my $cvtptr = $$cvtrsref{$ent->mime_type};
      my @cvts = @$cvtptr if defined $cvtptr;

      undef $cvtent;
      if (@cvts) {
	my $content_type = lc $ent->head->get('Content-type');
	my ($type, $ap) = Converter::Toolbox::parsetype $content_type;
	my %attrs = %{$ap};
	my $converter;

        CVTLOOP: foreach $converter (@cvts) {
		my %cvtattrs = %{$converter->attrs};

		# try to match converter's mime-type parameters
		if (defined %cvtattrs) {
			next CVTLOOP if (! defined %attrs);
			my ($attr, $val);
			my $dontmatch = 0;
			while (($attr, $val) = each %cvtattrs) {
				next if $attrs{$attr} eq $val;
				$dontmatch++;
				last;
			}
			next CVTLOOP if $dontmatch;
		}

		my $pkg = $converter->module;
		my $call = $converter->cvtfunc;
        	my $cvtexec = $converter->cvtexec;

		# install necessary env vars for this converter
		$converter->setenv;
		$cvtent = eval "${pkg}::${call}(\$ent, \$cvtexec)";

		# this one got converted!
		last if $cvtent;
        }
	if ($cvtent) {
		push(@cvtparts, $cvtent);
		splice(@$partref, $i, 1, $cvtent);
	}
        $i++;
      }
    }
}

1;
