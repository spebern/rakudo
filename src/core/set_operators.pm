
proto sub infix:<(elem)>($, $ --> Bool:D) is pure {*}
multi sub infix:<(elem)>($a, Any $b --> Bool:D) {
    $a (elem) $b.Set(:view);
}
multi sub infix:<(elem)>(Str:D $a, Map:D $b --> Bool:D) {
    $b.AT-KEY($a).Bool;
}
multi sub infix:<(elem)>($a, Set $b --> Bool:D) {
    $b.EXISTS-KEY($a);
}
# U+2208 ELEMENT OF
only sub infix:<∈>($a, $b --> Bool:D) is pure {
    $a (elem) $b;
}
# U+2209 NOT AN ELEMENT OF
only sub infix:<∉>($a, $b --> Bool:D) is pure {
    $a !(elem) $b;
}

proto sub infix:<(cont)>($, $ --> Bool:D) is pure {*}
multi sub infix:<(cont)>(Any $a, $b --> Bool:D) {
    $a.Set(:view) (cont) $b;
}
multi sub infix:<(cont)>(Map:D $a, Str:D $b --> Bool:D) {
    $a.AT-KEY($b).Bool
}
multi sub infix:<(cont)>(Set $a, $b --> Bool:D) {
    $a.EXISTS-KEY($b);
}
# U+220B CONTAINS AS MEMBER
only sub infix:<∋>($a, $b --> Bool:D) is pure {
    $a (cont) $b;
}
# U+220C DOES NOT CONTAIN AS MEMBER
only sub infix:<∌>($a, $b --> Bool:D) is pure {
    $a !(cont) $b;
}

only sub infix:<(|)>(**@p) is pure {
    return set() unless @p;

    if Rakudo::Internals.ANY_DEFINED_TYPE(@p, Mixy) {
        my $mixhash = nqp::istype(@p[0], MixHash)
            ?? MixHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.MixHash;
        for @p.map(*.Mix(:view)) -> $mix {
            for $mix.keys {
                # Handle negative weights: don't take max for keys that are zero
                $mixhash{$_} ?? ($mixhash{$_} max= $mix{$_})
                             !!  $mixhash{$_}    = $mix{$_}
            }
        }
        $mixhash.Mix(:view);
    }
    elsif Rakudo::Internals.ANY_DEFINED_TYPE(@p, Baggy) {
        my $baghash = nqp::istype(@p[0], BagHash)
            ?? BagHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.BagHash;
        for @p.map(*.Bag(:view)) -> $bag {
            $baghash{$_} max= $bag{$_} for $bag.keys;
        }
        $baghash.Bag(:view);
    }
    else {
        Set.new( @p.map(*.Set(:view).keys.Slip) );
    }
}
# U+222A UNION
only sub infix:<∪>(|p) is pure {
    infix:<(|)>(|p);
}

only sub infix:<(&)>(**@p) is pure {
    return set() unless @p;

    if Rakudo::Internals.ANY_DEFINED_TYPE(@p, Mixy) {
        my $mixhash = nqp::istype(@p[0], MixHash)
            ?? MixHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.MixHash;
        for @p.map(*.Mix(:view)) -> $mix {
            $mix{$_}
              ?? ($mixhash{$_} min= $mix{$_})
              !! $mixhash.DELETE-KEY($_)
              for $mixhash.keys;
        }
        $mixhash.Mix(:view);
    }
    elsif Rakudo::Internals.ANY_DEFINED_TYPE(@p,Baggy) {
        my $baghash = nqp::istype(@p[0], BagHash)
            ?? BagHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.BagHash;
        for @p.map(*.Bag(:view)) -> $bag {
            $bag{$_}
              ?? ($baghash{$_} min= $bag{$_})
              !! $baghash.DELETE-KEY($_)
              for $baghash.keys;
        }
        $baghash.Bag(:view);
    }
    else {
        my $sethash = nqp::istype(@p[0], SetHash)
          ?? SetHash.new(@p.shift.keys)
          !! @p.shift.SetHash;
        for @p.map(*.Set(:view)) -> $set {
            $set{$_} || $sethash.DELETE-KEY($_) for $sethash.keys;
        }
        $sethash.Set(:view);
    }
}
# U+2229 INTERSECTION
only sub infix:<∩>(|p) is pure {
    infix:<(&)>(|p);
}

only sub infix:<(-)>(**@p) is pure {
    return set() unless @p;

    if Rakudo::Internals.ANY_DEFINED_TYPE(@p,Mixy) {
        my $mixhash = nqp::istype(@p[0], MixHash)
            ?? MixHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.MixHash;
        for @p.map(*.Mix(:view)) -> $mix {
            $mix{$_} < $mixhash{$_}
              ?? ($mixhash{$_} -= $mix{$_})
              !! $mixhash.DELETE-KEY($_)
              for $mixhash.keys;
        }
        $mixhash.Mix(:view);
    }
    elsif Rakudo::Internals.ANY_DEFINED_TYPE(@p,Baggy) {
        my $baghash = nqp::istype(@p[0], BagHash)
            ?? BagHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.BagHash;
        for @p.map(*.Bag(:view)) -> $bag {
            $bag{$_} < $baghash{$_}
              ?? ($baghash{$_} -= $bag{$_})
              !! $baghash.DELETE-KEY($_)
              for $baghash.keys;
        }
        $baghash.Bag(:view);
    }
    else {
        my $sethash = nqp::istype(@p[0],SetHash)
          ?? SetHash.new(@p.shift.keys)
          !! @p.shift.SetHash;
        for @p.map(*.Set(:view)) -> $set {
            $set{$_} && $sethash.DELETE-KEY($_) for $sethash.keys;
        }
        $sethash.Set(:view);
    }
}

# U+2216 SET MINUS
only sub infix:<∖>(|p) is pure {
    infix:<(-)>(|p);
}

only sub infix:<(^)>(**@p) is pure {
    return set() unless my $chain = @p.elems;

    if $chain == 1 {
        return @p[0];
    } elsif $chain == 2 {
        my ($a, $b) = @p;
        my $mixy-or-baggy = False;
        if nqp::istype($a, Mixy) || nqp::istype($b, Mixy) {
            ($a, $b) = $a.MixHash, $b.MixHash;
            $mixy-or-baggy = True;
        } elsif nqp::istype($a, Baggy) || nqp::istype($b, Baggy) {
            ($a, $b) = $a.BagHash, $b.BagHash;
            $mixy-or-baggy = True;
        }
        return  $mixy-or-baggy
                    # the set formula is not symmetric for bag/mix. this is.
                    ?? ($a (-) $b) (+) ($b (-) $a)
                    # set formula for the two-arg set.
                    !! ($a (|) $b) (-) ($b (&) $a);
    } else {
        if Rakudo::Internals.ANY_DEFINED_TYPE(@p,Mixy)
             || Rakudo::Internals.ANY_DEFINED_TYPE(@p,Baggy) {
            my $head;
            while (@p) {
                my ($a, $b);
                if $head.defined {
                    ($a, $b) = $head, @p.shift;
                } else {
                    ($a, $b) = @p.shift, @p.shift;
                }
                if nqp::istype($a, Mixy) || nqp::istype($b, Mixy) {
                    ($a, $b) = $a.MixHash, $b.MixHash;
                } elsif nqp::istype($a, Baggy) || nqp::istype($b, Baggy) {
                    ($a, $b) = $a.BagHash, $b.BagHash;
                }
                $head = ($a (-) $b) (+) ($b (-) $a);
            }
            return $head;
        } else {
            return ([(+)] @p>>.Bag).grep(*.value == 1).Set;
        } 
    }
}
# U+2296 CIRCLED MINUS
only sub infix:<⊖>($a, $b) is pure {
    $a (^) $b;
}

multi sub infix:<eqv>(Setty:D \a, Setty:D \b) {
    nqp::p6bool(
      nqp::unless(
        nqp::eqaddr(a,b),
        nqp::eqaddr(a.WHAT,b.WHAT)
          && nqp::getattr(nqp::decont(a),a.WHAT,'%!elems')
               eqv nqp::getattr(nqp::decont(b),b.WHAT,'%!elems')
      )
    )
}

proto sub infix:<<(<=)>>($, $ --> Bool:D) is pure {*}
multi sub infix:<<(<=)>>(Any $a, Any $b --> Bool:D) {
    $a.Set(:view) (<=) $b.Set(:view);
}
multi sub infix:<<(<=)>>(Setty $a, Setty $b --> Bool:D) {
    $a <= $b and so $a.keys.all (elem) $b
}
# U+2286 SUBSET OF OR EQUAL TO
only sub infix:<⊆>($a, $b --> Bool:D) is pure {
    $a (<=) $b;
}
# U+2288 NEITHER A SUBSET OF NOR EQUAL TO
only sub infix:<⊈>($a, $b --> Bool:D) is pure {
    $a !(<=) $b;
}

proto sub infix:<<(<)>>($, $ --> Bool:D) is pure {*}
multi sub infix:<<(<)>>(Any $a, Any $b --> Bool:D) {
    $a.Set(:view) (<) $b.Set(:view);
}
multi sub infix:<<(<)>>(Setty $a, Setty $b --> Bool:D) {
    $a < $b and so $a.keys.all (elem) $b;
}
# U+2282 SUBSET OF
only sub infix:<⊂>($a, $b --> Bool:D) is pure {
    $a (<) $b;
}
# U+2284 NOT A SUBSET OF
only sub infix:<⊄>($a, $b --> Bool:D) is pure {
    $a !(<) $b;
}

proto sub infix:<<(>=)>>($, $ --> Bool:D) is pure {*}
multi sub infix:<<(>=)>>(Any $a, Any $b --> Bool:D) {
    $a.Set(:view) (>=) $b.Set(:view);
}
multi sub infix:<<(>=)>>(Setty $a, Setty $b --> Bool:D) {
    $a >= $b and so $b.keys.all (elem) $a;
}
# U+2287 SUPERSET OF OR EQUAL TO
only sub infix:<⊇>($a, $b --> Bool:D) is pure {
    $a (>=) $b;
}
# U+2289 NEITHER A SUPERSET OF NOR EQUAL TO
only sub infix:<⊉>($a, $b --> Bool:D) is pure {
    $a !(>=) $b;
}

proto sub infix:<<(>)>>($, $ --> Bool:D) is pure {*}
multi sub infix:<<(>)>>(Any $a, Any $b --> Bool:D) {
    $a.Set(:view) (>) $b.Set(:view);
}
multi sub infix:<<(>)>>(Setty $a, Setty $b --> Bool:D) {
    $a > $b and so $b.keys.all (elem) $a;
}
# U+2283 SUPERSET OF
only sub infix:<⊃>($a, $b --> Bool:D) is pure {
    $a (>) $b;
}
# U+2285 NOT A SUPERSET OF
only sub infix:<⊅>($a, $b --> Bool:D) is pure {
    $a !(>) $b;
}

only sub infix:<(.)>(**@p) is pure {
    return bag() unless @p;

    if Rakudo::Internals.ANY_DEFINED_TYPE(@p,Mixy) {
        my $mixhash = nqp::istype(@p[0], MixHash)
            ?? MixHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.MixHash;
        for @p.map(*.Mix(:view)) -> $mix {
            $mix{$_}
              ?? ($mixhash{$_} *= $mix{$_})
              !! $mixhash.DELETE-KEY($_)
              for $mixhash.keys;
        }
        $mixhash.Mix(:view);
    }
    else {  # go Baggy by default
        my $baghash = nqp::istype(@p[0], BagHash)
            ?? BagHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.BagHash;
        for @p.map(*.Bag(:view)) -> $bag {
            $bag{$_}
              ?? ($baghash{$_} *= $bag{$_})
              !! $baghash.DELETE-KEY($_)
              for $baghash.keys;
        }
        $baghash.Bag(:view);
    }
}
# U+228D MULTISET MULTIPLICATION
only sub infix:<⊍>(|p) is pure {
    infix:<(.)>(|p);
}

only sub infix:<(+)>(**@p) is pure {
    return bag() unless @p;

    if Rakudo::Internals.ANY_DEFINED_TYPE(@p,Mixy) {
        my $mixhash = nqp::istype(@p[0], MixHash)
            ?? MixHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.MixHash;
        for @p.map(*.Mix(:view)) -> $mix {
            $mixhash{$_} += $mix{$_} for $mix.keys;
        }
        $mixhash.Mix(:view);
    }
    else {  # go Baggy by default
        my $baghash = nqp::istype(@p[0], BagHash)
            ?? BagHash.new-from-pairs(@p.shift.pairs)
            !! @p.shift.BagHash;
        for @p.map(*.Bag(:view)) -> $bag {
            $baghash{$_} += $bag{$_} for $bag.keys;
        }
        $baghash.Bag(:view);
    }
}
# U+228E MULTISET UNION
only sub infix:<⊎>(|p) is pure {
    infix:<(+)>(|p);
}

proto sub infix:<<(<+)>>($, $ --> Bool:D) is pure {*}
multi sub infix:<<(<+)>>(Any $a, Any $b --> Bool:D) {
    if nqp::istype($a, Mixy) or nqp::istype($b, Mixy) {
        $a.Mix(:view) (<+) $b.Mix(:view);
    } else {
        $a.Bag(:view) (<+) $b.Bag(:view);
    }
}
multi sub infix:<<(<+)>>(QuantHash:U $a, QuantHash:U $b --> True ) {}
multi sub infix:<<(<+)>>(QuantHash:U $a, QuantHash:D $b --> True ) {}
multi sub infix:<<(<+)>>(QuantHash:D $a, QuantHash:U $b --> Bool:D ) {
    not $a.keys;
}
multi sub infix:<<(<+)>>(QuantHash:D $a, QuantHash:D $b --> Bool:D ) {
    for $a.keys {
        return False if $a{$_} > $b{$_};
    }
    True;
}
# U+227C PRECEDES OR EQUAL TO
only sub infix:<≼>($a, $b --> Bool:D) is pure {
    $a (<+) $b;
}

proto sub infix:<<(>+)>>($, $ --> Bool:D) is pure {*}
multi sub infix:<<(>+)>>(QuantHash:U $a, QuantHash:U $b --> True ) {}
multi sub infix:<<(>+)>>(QuantHash:D $a, QuantHash:U $b --> True ) {}
multi sub infix:<<(>+)>>(QuantHash:U $a, QuantHash:D $b --> Bool:D ) {
    not $b.keys;
}
multi sub infix:<<(>+)>>(QuantHash:D $a, QuantHash:D $b --> Bool:D) {
    for $b.keys {
        return False if $b{$_} > $a{$_};
    }
    True;
}
multi sub infix:<<(>+)>>(Any $a, Any $b --> Bool:D) {
    if nqp::istype($a, Mixy) or nqp::istype($b, Mixy) {
        $a.Mix(:view) (>+) $b.Mix(:view);
    } else {
        $a.Bag(:view) (>+) $b.Bag(:view);
    }
}
# U+227D SUCCEEDS OR EQUAL TO
only sub infix:<≽>($a, $b --> Bool:D) is pure {
    $a (>+) $b;
}

proto sub set(|) { * }
multi sub set() { BEGIN nqp::create(Set) }
multi sub set(*@a --> Set:D) { Set.new(@a) }

proto sub bag(|) { * }
multi sub bag() { BEGIN nqp::create(Bag) }
multi sub bag(*@a --> Bag:D) { Bag.new(@a) }

proto sub mix(|) { * }
multi sub mix() { BEGIN nqp::create(Mix) }
multi sub mix(*@a --> Mix:D) { Mix.new(@a) }

# vim: ft=perl6 expandtab sw=4
