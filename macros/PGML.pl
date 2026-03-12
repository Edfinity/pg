######################################################################
######################################################################
#
# PGML.pl - Thin wrapper for PGML.pm
#
# This file handles the initialization that must occur inside the
# Safe compartment. The main PGML code is in lib/PGML.pm which is
# pre-loaded and shared into Safe to avoid per-request compilation.
#
######################################################################

# Check that PGML.pm is installed (loaded outside Safe and shared in)
if (!$PGML::installed) {
  die "\n************************************************************\n" .
        "* This problem requires the PGML.pm package, which doesn't\n".
        "* seem to be installed. Please ensure PGML is added to the\n".
        "* modules list in defaults.config.\n".
        "************************************************************\n\n"
}

######################################################################
#
# Initialization that must run inside the Safe compartment
#

sub _PGML_init {
  # Populate the closure hash — these references resolve naturally inside
  # Safe, so PGML.pm can call through them without symbolic dereferencing.
  $PGML::_env = {
    ANS                => \&ANS,
    NAMED_ANS          => \&NAMED_ANS,
    NAMED_ANS_RULE     => \&NAMED_ANS_RULE,
    ans_rule           => \&ans_rule,
    PG_restricted_eval => \&PG_restricted_eval,
    lex_sort           => \&lex_sort,
    general_math_ev3   => \&general_math_ev3,
    EV3P               => \&EV3P,
    String             => \&String,
    WARN_MESSAGE       => \&WARN_MESSAGE,
    PTX_cleanup        => \&PTX_cleanup,
    displayMode        => \$displayMode,
    context            => \%context,
  };

  # Create the PGML function inside Safe that calls PGML::Format2
  PG_restricted_eval('sub PGML {PGML::Format2(@_)}');

  # Load required macros
  loadMacros("MathObjects.pl");
  my $context = Context(); # prevent Typeset context from becoming active
  loadMacros("contextTypeset.pl");
  Context($context);

  # Add TeX preamble for hardcopy
  $problemPreamble->{TeX} .= $PGML::preamble unless $problemPreamble->{TeX} =~ m/definitions for PGML/;

  ## Avoid bad spacing at the top of the problem (need to modify hardcopyPreamble.tex)
  TEXT(MODES(HTML=>'', TeX=>'
    \ifx\pgmlMarker\undefined
      \newdimen\pgmlMarker \pgmlMarker=0.00314159pt  % hack to tell if \newline was used
    \fi
    \ifx\oldnewline\undefined \let\oldnewline=\newline \fi
    \def\newline{\oldnewline\hskip-\pgmlMarker\hskip\pgmlMarker\relax}%
    \parindent=0pt
    \catcode`\^^M=\active
    \def^^M{\ifmmode\else\fi\ignorespaces}%  skip paragraph breaks in the preamble
    \def\par{\ifmmode\else\endgraf\fi\ignorespaces}%
  '));
}

######################################################################

1;
