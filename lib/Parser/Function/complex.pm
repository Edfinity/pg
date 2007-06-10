#########################################################################
#
#  Implements functions that require complex inputs
#
package Parser::Function::complex;
use strict;
our @ISA = qw(Parser::Function);

#
#  Check that the argument is complex, and
#    mark the result as real or complex, as appropriate.
#
sub _check {
  my $self = shift;
  return $self->checkComplex(@_) if $self->{def}{complex};
  return $self->checkReal(@_);
}

#
#  Evaluate by calling the appropriate routine from Value.pm.
#
sub _eval {
  my $self = shift; my $context = $self->context; my $name = $self->{name};
  my $c = Value->Package("Complex",$context)->promote($_[0])->inContext($context);
  $c->$name;
}

#
#  Check for the right number of arguments.
#  Convert argument to a complex (does error checking)
#    and then call the appropriate routine from Value.pm.
#
sub _call {
  my $self = shift; my $context = $self->context; my $name = shift;
  Value::Error("Function '%s' has too many inputs",$name) if scalar(@_) > 1;
  Value::Error("Function '%s' has too few inputs",$name) if scalar(@_) == 0;
  my $c = Value->Package("Complex",$context)->promote($_[0])->inContext($context);
  $c->$name;
}

##################################################
#
#  Sepcifal versions of sqrt, log and ^ that are used
#  in the Complex context.
#

#
#  Subclass of fumeric functions that promote negative reals
#  to complex before performing the function (so that sqrt(-2)
#  is defined, for example).
#
package Parser::Function::complex_numeric;
use strict;
our @ISA = qw(Parser::Function::numeric);

sub sqrt {
  my $self = shift; my $context = $self->context;
  my $x = Value::makeValue(shift,context=>$context);
  $x = Value->Package("Complex",$context)->promote($x)->inContext($context)
    if $x->value < 0 && $self->{def}{negativeIsComplex};
  $x->sqrt;
}

sub log {
  my $self = shift; my $context = $self->context;
  my $x = Value::makeValue(shift,$context);
  $x = Value->Package("Complex",$context)->promote($x)->inContext($context)
    if $x->value < 0 && $self->{def}{negativeIsComplex};
  $x->log;
}

#
#  Special power operator that promotes negative real
#  bases to complex numbers before taking power (so that
#  (-3)^(1/2) is define, for example).
#
package Parser::Function::complex_power;
use strict;
our @ISA = qw(Parser::BOP::power Parser::BOP);

sub _eval {
  my $self = shift; my $context = $self->context;
  my $a = Value::makeValue(shift,context=>$context); my $b = shift;
  $a = Value->Package("Complex",$context)->promote($a)->inContext($context)
    if Value::isReal($a) && $a->value < 0 && $self->{def}{negativeIsComplex};
  return $a ** $b;
}


#########################################################################

1;
