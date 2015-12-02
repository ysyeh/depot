#
# a class of converter "wrapper" for TPC server so one can convert
# certain mime objects into something TPC can handle.
#
# Simon Yeh <syeh@csfcorp.com>, April 1997
#
# $Revision = '@(#)Converter:Entity.pm 1.2 11 Apr 1997 17:09:56';
#
package Converter::Entity;

use Converter::Toolbox;
use Carp;

my %fields = (
	type	=> undef,	# content-type	
	attrs	=> undef,	# content-type attributes; a hash reference
	module	=> undef,	# package to be loaded
	cvtfunc	=> undef,	# converter wrapper subroutine to be called
	cvtexec	=> undef,	# path of external converter
	envvars	=> undef,	# necessary enviroment vars; a hash reference
);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	my $data = shift;
	my $self = {
		_permitted => \%fields,
		%fields,
	};

	bless $self, $class;
	$self->init($data) if $data;

	$self;
}

sub init {
	my ($self, $data) = @_;
	my @values = split(/\|/, $data);
	my $envref;

	if ($#values < 2) {
		carp "Malformatted entry: $data";
		return 0;
	}

	($self->{type}, $self->{attrs}) 
		= Converter::Toolbox::parsetype(lc $values[0]);
	($self->{module}, $self->{cvtfunc}, $self->{cvtexec}) = @values[1 .. 3];

	$envref = Converter::Toolbox::mkhash('=', split(/;/, $values[4]));
	$self->envvars($envref) if $envref;

	return 1;
}

sub setenv {
	my $self = shift;
	my %myenv = %{$self->envvars};

	while (($key, $var) = each %myenv) { $ENV{$key} = $var; }

	1;
}

sub unsetenv {
	my $self = shift;
	my %myenv = %{$self->envvars};

	foreach $key (keys %myenv) { delete $ENV{$key}; }

	1;
}

sub require {
	my $self = shift;
	my $filename = $self->module;
	$filename =~ s|::|/|g;
	$filename .= ".pm" unless /\.pl$/;
	return 1 if $INC{$filename};
	my ($realfilename , $result);
	ITER: {
		foreach $prefix (@INC) {
			$realfilename = "$prefix/$filename";
			if (-f $realfilename) {
				$result = require $realfilename;
				last ITER;
			}
		}
		carp "Can't find $filename in \@INC";
	}
	carp "$filename did not return true value" unless $result;
	$INC{$filename} = $realfilename;
	return $result;
}

sub AUTOLOAD {
	my $self = shift;
	my $class = ref($self) || croak "$self is not an object";
	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	unless (exists $self->{_permitted}->{$name}) {
		croak "Can't access `$name' field in object of class $class";
	}
	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}
}

1;
