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

    # Safe compartment cleanup. Two paths:
    #   - cached (XENOPHON_CACHE_SAFE=1): wipe per-request stash pollution but
    #     keep the static shares intact, so the next request reuses them.
    #   - non-cached (legacy default): erase the whole compartment as before.
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

        if ($self->{safe_is_cached}
            && $WeBWorK::PG::Translator::CACHED_SAFE_READY) {
            # Selective wipe: clear any stash entry that wasn't part of the
            # static cache snapshot. Skip sub-package buckets ('Foo::') —
            # those are the shared module namespaces and stay.
            my $stash = \%{"${root}::"};
            for my $key (keys %$stash) {
                next if $WeBWorK::PG::Translator::CACHED_STATIC_KEYS{$key};
                next if $key =~ /::$/;
                # Undef each slot of the typeglob, then drop the stash entry.
                undef ${"${root}::${key}"};
                undef @{"${root}::${key}"};
                undef %{"${root}::${key}"};
                undef &{"${root}::${key}"};
                delete $stash->{$key};
            }
        } else {
            $self->{safe}->erase();
        }
    }

    # Translator's own fields
    $self->{envir} = undef;
    $self->{rh_pgcore} = undef;
    $self->{ra_included_modules} = [];
    # In cached mode, dropping $self->{safe} only releases this Translator's
    # reference; the singleton in $WeBWorK::PG::Translator::CACHED_SAFE keeps
    # the compartment alive for the next request.
    $self->{safe} = undef;
}

1;
