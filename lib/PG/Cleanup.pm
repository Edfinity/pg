# lib/PG/Cleanup.pm
# Post-request memory teardown for PG objects.
# Injected via package reopening — keeps cleanup logic out of core modules.
# Loaded by the renderer (xenophon) via: use PG::Cleanup;

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

        # context:: sub-packages created by macros (e.g., contextFraction.pl
        # creates context::Fraction::BOP::divide, context::Fraction::Real, etc.)
        my $context_pkg = "${root}::context::";
        if (%{$context_pkg}) {
            my @context_sub_pkgs = grep { /::$/ } keys %{$context_pkg};
            for my $sub_pkg (@context_sub_pkgs) {
                my $full_sub = "${context_pkg}${sub_pkg}";
                %{$full_sub} = () if %{$full_sub};
            }
            %{$context_pkg} = ();
        }

        # value:: sub-packages created by macros (e.g., contextSetOfSets.pl)
        my $value_pkg = "${root}::value::";
        if (%{$value_pkg}) {
            my @value_sub_pkgs = grep { /::$/ } keys %{$value_pkg};
            for my $sub_pkg (@value_sub_pkgs) {
                my $full_sub = "${value_pkg}${sub_pkg}";
                %{$full_sub} = () if %{$full_sub};
            }
            %{$value_pkg} = ();
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
