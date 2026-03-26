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

        # Restore $Value::context to a valid default before erasing the
        # compartment.  Without this, the global still points to a scalar
        # inside the (now-cleared) compartment %context hash, so any code
        # that dereferences $$Value::context between requests would crash
        # with "Can't call method 'get' on an undefined value" (Value.pm:961).
        $Value::context = \$Value::defaultContext;

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
