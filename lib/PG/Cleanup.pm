# lib/PG/Cleanup.pm
# Post-request memory teardown for PG objects.
# Injected via package reopening — keeps cleanup logic out of core modules.
# Loaded by the renderer (xenophon) via: use PG::Cleanup;

package PG::Cleanup;

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
                    $ctx_hash->{$ctx_name} = undef;
                }
                %$ctx_hash = ();
            }
        }

        $self->{safe}->erase();
    }

    # Translator's own fields
    $self->{envir} = undef;
    $self->{rh_pgcore} = undef;
    $self->{ra_included_modules} = [];
    $self->{safe} = undef;
}

1;
