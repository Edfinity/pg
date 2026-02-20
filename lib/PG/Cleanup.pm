# lib/PG/Cleanup.pm
# Post-request memory teardown for PG objects.
# Injected via package reopening — keeps cleanup logic out of core modules.
# Loaded by the renderer (xenophon) via: use PG::Cleanup;

package PG::Cleanup;

# Recursively clear a package namespace and all its sub-packages.
# e.g., context::Fraction:: contains BOP::, and BOP:: contains divide::
sub _erase_pkg_recursive {
    my ($pkg) = @_;
    no strict 'refs';
    my @sub_pkgs = grep { /::$/ } keys %{$pkg};
    for my $sub (@sub_pkgs) {
        _erase_pkg_recursive("${pkg}${sub}");
    }
    %{$pkg} = ();
}

package PGcore;

sub cleanup {
    my $self = shift;
    $self->{PG_ANSWERS_HASH} = {};
    $self->{envir} = undef;
    $self->{PG_alias} = undef;
    $self->{PG_loadMacros} = undef;
    $self->{PG_random_generator} = undef;
    $self->{WARNING_messages} = [];
    $self->{DEBUG_messages} = [];
    $self->{OUTPUT_ARRAY} = [];
    $self->clear_internal_debug_messages();
}

package Value::Context;

sub cleanup {
    my $self = shift;
    for my $key (qw(flags functions operators constants variables parens
                     lists strings reduction value)) {
        $self->{$key} = undef;
    }
    for my $obj_key (@{$self->{data}{objects} || []}) {
        $self->{$obj_key} = undef;
    }
}

package WeBWorK::PG::Translator;

sub cleanup {
    my $self = shift;

    # The separate PGcore instance held by the translator
    $self->{rh_pgcore}->cleanup() if $self->{rh_pgcore};

    # PGcore fields on the translator itself (Translator inherits from PGcore)
    $self->PGcore::cleanup();

    # Contexts inside Safe compartment
    if ($self->{safe}) {
        no strict 'refs';
        my $root = $self->{safe}->root();

        if (exists ${"${root}::"}{"context"}) {
            my $ctx_hash = *{"${root}::context"}{HASH};
            if (ref($ctx_hash) eq 'HASH') {
                for my $ctx_name (keys %$ctx_hash) {
                    my $ctx = $ctx_hash->{$ctx_name};
                    eval { $ctx->cleanup() } if ref($ctx) && $ctx->can('cleanup');
                    $ctx_hash->{$ctx_name} = undef;
                }
                %$ctx_hash = ();
            }
        }

        # context:: and value:: sub-packages created by macros
        # (e.g., contextFraction.pl creates context::Fraction::BOP::divide, etc.
        # and contextSetOfSets.pl creates value:: sub-packages).
        # Must recurse because packages can be deeply nested.
        for my $ns ("${root}::context::", "${root}::value::") {
            PG::Cleanup::_erase_pkg_recursive($ns) if %{$ns};
        }

        # Erase Safe compartment symbol table
        $self->{safe}->erase();
    }

    # Translator's own fields
    $self->{envir} = undef;
    $self->{rh_pgcore} = undef;
    $self->{ra_included_modules} = [];
    $self->{safe} = undef;
}

1;
