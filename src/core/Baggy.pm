my role Baggy does QuantHash {

# A Bag/BagHash/Mix/MixHash consists of a single hash with Pairs.
# The keys of the hash, are the .WHICH strings of the original object key.
# The values are Pairs containing the original object key and value.

    has %!elems; # key.WHICH => (key,value)

# The Baggy role takes care of all mutable and immutable aspects that are
# shared between Bag,BagHash,Mix,MixHash.  Any specific behaviour for
# mutable and immutable aspects of Mix/MixHash need to live in Mixy.
# Immutables aspects of Bag/Mix, need to live to Bag/Mix respectively.

#--- private methods
    method !WHICH() {
        self.^name
          ~ '|'
          ~ self.keys.sort.map( { $_.WHICH ~ '(' ~ self.AT-KEY($_) ~ ')' } );
    }
    method !PAIR(\key,\value) { Pair.new(key, my Int $ = value ) }
    method !TOTAL() {
        nqp::if(
          (my $storage := nqp::getattr(%!elems,Map,'$!storage')),
          nqp::stmts(
            (my $total = 0),
            (my $iter := nqp::iterator($storage)),
            nqp::while(
              $iter,
              $total = $total
                + nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')
            ),
            $total
          ),
          0
        )
    }
    method !SANITY(%hash --> Nil) {
        nqp::stmts(
          (my $low := nqp::create(IterationBuffer)),
          (my $elems := nqp::getattr(%hash,Map,'$!storage')),
          (my $iter := nqp::iterator($elems)),
          nqp::while(
            $iter,
            nqp::if(
              nqp::isle_i(
                nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value'),
                0
              ),
              nqp::stmts(
                nqp::if(
                  nqp::islt_i(
                    nqp::getattr(nqp::iterval($iter),Pair,'$!value'),
                    0
                  ),
                  nqp::push($low,nqp::getattr(nqp::iterval($iter),Pair,'$!key'))
                ),
                nqp::deletekey($elems,nqp::iterkey_s($iter))
              )
            )
          ),
          nqp::if(
            nqp::elems($low),
            X::AdHoc.new( payload =>
              "Found negative values for "
              ~ nqp::p6bindattrinvres(nqp::create(List),List,'$!reified',$low)
              ~ " in "
              ~ self.^name
            ).throw,
            Nil
          )
        )
    }
    method !LISTIFY(&formatter, str $joiner) {
        nqp::if(
          (my int $elems = %!elems.elems),   # also handle unallocated %!elems
          nqp::stmts(
            (my $pairs := nqp::getattr(%!elems,Map,'$!storage')),
            (my $list := nqp::setelems(nqp::list_s,$elems)),
            (my $iter := nqp::iterator($pairs)),
            (my int $i = -1),
            nqp::while(
              $iter,
              nqp::bindpos_s($list,($i = nqp::add_i($i,1)),
                formatter(
                  (my $pair := nqp::iterval(nqp::shift($iter))).key,
                  $pair.value
                )
              )
            ),
            nqp::p6box_s(nqp::join($joiner,$list))
          ),
          ""
        )
    }

#--- interface methods
    method SET-SELF(Baggy:D: Mu \elems) {
        nqp::if(
          elems.elems,
          nqp::stmts(                        # need to have allocated %!elems
            (%!elems := elems),
            nqp::if(
              nqp::istype(self,Bag) || nqp::istype(self,Mix),
              nqp::stmts(
                (my $iter := nqp::iterator(
                  nqp::getattr(%!elems,Map,'$!storage')
                )),
                nqp::while(
                  $iter,
                  nqp::stmts(
                    (my $pair := nqp::iterval(nqp::shift($iter))),
                    nqp::bindattr($pair,Pair,'$!value',
                      nqp::decont(nqp::getattr($pair,Pair,'$!value'))
                    )
                  )
                )
              )
            ),
            self
          ),
          self
        )
    }
    multi method ACCEPTS(Baggy:U: $other) {
        $other.^does(self)
    }
    multi method ACCEPTS(Baggy:D: Mu $other) {
        $other (<+) self && self (<+) $other
    }
    multi method ACCEPTS(Baggy:D: Baggy:D $other --> Bool:D) {
        nqp::p6bool(
          nqp::unless(
            nqp::eqaddr(self,$other),
            nqp::if(
              (%!elems.elems
                == nqp::getattr($other,$other.WHAT,'%!elems').elems),
              nqp::stmts(
                (my $iter := nqp::iterator(
                  nqp::getattr(%!elems,Map,'$!storage'))),
                (my $oelems := nqp::getattr(
                  nqp::getattr($other,$other.WHAT,'%!elems'),Map,'$!storage')),
                nqp::while(
                  $iter,
                  nqp::stmts(
                    nqp::shift($iter),
                    nqp::unless(
                      (nqp::existskey($oelems,nqp::iterkey_s($iter))
                        && nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                        == nqp::getattr(nqp::atkey(
                             $oelems,nqp::iterkey_s($iter)),Pair,'$!value')),
                      return False
                    )
                  )
                ),
                1
              )
            )
          )
        )
    }

    multi method AT-KEY(Baggy:D: \k) {  # exception: ro version for Bag/Mix
        nqp::if(
          (my $elems := nqp::getattr(%!elems,Map,'$!storage')),
          nqp::if(
            nqp::existskey($elems,(my $which := k.WHICH)),
            nqp::getattr(nqp::decont(nqp::atkey($elems,$which)),Pair,'$!value'),
            0
          ),
          0
        )
    }
    multi method DELETE-KEY(Baggy:D: \k) {
        nqp::if(
          (my $elems := nqp::getattr(%!elems,Map,'$!storage')),
          nqp::if(
            nqp::existskey($elems,(my $which := k.WHICH)),
            nqp::stmts(
              (my $value := nqp::getattr(
                nqp::decont(nqp::atkey($elems,$which)),Pair,'$!value')),
              nqp::deletekey($elems,$which),
              $value
            ),
            0
          ),
          0
        )
    }
    multi method EXISTS-KEY(Baggy:D: \k) {
        nqp::p6bool(
          nqp::if(
            (my $elems := nqp::getattr(%!elems,Map,'$!storage')),
            nqp::existskey($elems,k.WHICH)
          )
        )
    }

#--- object creation methods
    multi method new(Baggy:_:) { nqp::create(self) }
    multi method new(Baggy:_: +@args) {
        nqp::stmts(
          (my $elems := nqp::hash),
          (my $iterator := @args.iterator),
          nqp::until(
            nqp::eqaddr(
              (my $pulled := nqp::decont($iterator.pull-one)),
              IterationEnd
            ),
            nqp::if(
              nqp::existskey(
                $elems,
                (my $which := $pulled.WHICH)
              ),
              nqp::stmts(
                (my $value :=
                  nqp::getattr(nqp::atkey($elems,$which),Pair,'$!value')),
                ($value = $value + 1),
              ),
              nqp::bindkey($elems,$which,self!PAIR($pulled,1))
            )
          ),
          nqp::create(self).SET-SELF($elems)
        )
    }
    method new-from-pairs(*@pairs) {
        nqp::stmts(
          (my $elems := nqp::hash),
          (my $iterator := @pairs.iterator),
          nqp::until(
            nqp::eqaddr(
              (my $pulled := nqp::decont($iterator.pull-one)),
              IterationEnd
            ),
            nqp::if(
              nqp::istype($pulled,Pair),
              nqp::stmts(
                (my int $seen-pair = 1),
                nqp::if(
                  nqp::existskey(
                    $elems,
                    (my $which := nqp::getattr($pulled,Pair,'$!key').WHICH)
                  ),
                  nqp::stmts(
                    (my $value :=
                      nqp::getattr(nqp::atkey($elems,$which),Pair,'$!value')),
                    ($value = $value + nqp::getattr($pulled,Pair,'$!value'))
                  ),
                  nqp::bindkey($elems,$which,self!PAIR(
                    nqp::getattr($pulled,Pair,'$!key'),
                    nqp::getattr($pulled,Pair,'$!value'),
                  ))
                )
              ),
              nqp::if(
                nqp::existskey(
                  $elems,
                  ($which := $pulled.WHICH)
                ),
                nqp::stmts(
                  ($value :=
                    nqp::getattr(nqp::atkey($elems,$which),Pair,'$!value')),
                  ($value = $value + 1),
                ),
                nqp::bindkey($elems,$which,self!PAIR($pulled,1))
              )
            )
          ),
          nqp::if($seen-pair && nqp::elems($elems),self!SANITY($elems)),
          nqp::create(self).SET-SELF($elems)
        )
    }

#--- iterator methods
    multi method iterator(Baggy:D:) {
        Rakudo::Iterator.Mappy-values(%!elems)
    }
    multi method keys(Baggy:D:) {
        Seq.new(class :: does Rakudo::Iterator::Mappy {
            method pull-one() {
                $!iter
                  ?? nqp::iterval(nqp::shift($!iter)).key
                  !! IterationEnd
            }
            method push-all($target --> IterationEnd) {
                nqp::while(  # doesn't sink
                  $!iter,
                  $target.push(nqp::iterval(nqp::shift($!iter)).key)
                )
            }
        }.new(%!elems))
    }
    multi method kv(Baggy:D:) {
        Seq.new(Rakudo::Iterator.Mappy-kv-from-pairs(%!elems))
    }
    multi method values(Baggy:D:) {
        Seq.new(class :: does Rakudo::Iterator::Mappy {
            method pull-one() is raw {
                $!iter
                    ?? nqp::getattr(nqp::decont(
                         nqp::iterval(nqp::shift($!iter))),Pair,'$!value')
                    !! IterationEnd
            }
            method push-all($target --> IterationEnd) {
                nqp::while(  # doesn't sink
                  $!iter,
                  $target.push(nqp::getattr(nqp::decont(
                    nqp::iterval(nqp::shift($!iter))),Pair,'$!value'))
                )
            }
        }.new(%!elems))
    }
    multi method antipairs(Baggy:D:) {
        Seq.new(class :: does Rakudo::Iterator::Mappy {
            method pull-one() {
                nqp::if(
                  $!iter,
                  nqp::iterval(nqp::shift($!iter)).antipair,
                  IterationEnd
                )
            }
            method push-all($target --> IterationEnd) {
                nqp::while(
                  $!iter,
                  $target.push(nqp::iterval(nqp::shift($!iter)).antipair),
                )
            }
        }.new(%!elems))
    }
    proto method kxxv(|) { * }
    multi method kxxv(Baggy:D:) {
        Seq.new(class :: does Rakudo::Iterator::Mappy {
            has Mu $!key;
            has int $!times;

            method pull-one() is raw {
                nqp::if(
                  $!times,
                  nqp::stmts(
                    ($!times = nqp::sub_i($!times,1)),
                    $!key
                  ),
                  nqp::if(
                    $!iter,
                    nqp::stmts(
                      ($!key := nqp::getattr(
                        (my $pair := nqp::decont(
                          nqp::iterval(nqp::shift($!iter)))),
                        Pair,
                        '$!key'
                      )),
                      ($!times =
                        nqp::sub_i(nqp::getattr($pair,Pair,'$!value'),1)),
                      $!key
                    ),
                    IterationEnd
                  )
                )
            }
            method skip-one() { # the default skip-one, too difficult to handle
                nqp::not_i(nqp::eqaddr(self.pull-one,IterationEnd))
            }
            method push-all($target --> IterationEnd) {
                nqp::while(
                  $!iter,
                  nqp::stmts(
                    ($!key := nqp::getattr(
                      (my $pair := nqp::decont(
                        nqp::iterval(nqp::shift($!iter)))),
                      Pair,
                      '$!key'
                    )),
                    ($!times =
                      nqp::add_i(nqp::getattr($pair,Pair,'$!value'),1)),
                    nqp::while(  # doesn't sink
                      ($!times = nqp::sub_i($!times,1)),
                      $target.push($!key)
                    )
                  )
                )
            }
        }.new(%!elems))
    }
    multi method invert(Baggy:D:) {
        Seq.new(Rakudo::Iterator.Invert(%!elems.values.iterator))
    }

#--- introspection methods
    multi method WHICH(Baggy:D:)   { self!WHICH }
    method total(Baggy:D:)         { self!TOTAL }
    multi method elems(Baggy:D: --> Int:D) { %!elems.elems }
    multi method Bool(Baggy:D: --> Bool:D) { %!elems.Bool }
    multi method hash(Baggy:D: --> Hash:D) {
        my \h = Hash.^parameterize(Any, Any).new;
        h = %!elems.values;
        h;
    }
    method default(Baggy:D: --> 0) { }

    multi method Str(Baggy:D: --> Str:D) {
        self!LISTIFY(-> \k,\v {v==1 ?? k.gist !! "{k.gist}({v})"}, ' ')
    }
    multi method gist(Baggy:D: --> Str:D) {
        my str $name = nqp::unbox_s(self.^name);
        ( nqp::chars($name) == 3 ?? nqp::lc($name) !! "$name.new" )
        ~ '('
        ~ self!LISTIFY(-> \k,\v {v==1 ?? k.gist !! "{k.gist}({v})"}, ', ')
        ~ ')'
    }
    multi method perl(Baggy:D: --> Str:D) {
        '('
        ~ self!LISTIFY( -> \k,\v {"{k.perl}=>{v}"}, ',')
        ~ ").{self.^name}"
    }

#--- selection methods
    proto method grabpairs (|) { * }
    multi method grabpairs(Baggy:D:) {
        %!elems.DELETE-KEY(%!elems.keys.pick);
    }
    multi method grabpairs(Baggy:D: $count) {
        if nqp::istype($count,Whatever) || $count == Inf {
            my @grabbed = %!elems{%!elems.keys.pick(%!elems.elems)};
            %!elems = ();
            @grabbed;
        }
        else {
            %!elems{ %!elems.keys.pick($count) }:delete;
        }
    }

    proto method pickpairs(|) { * }
    multi method pickpairs(Baggy:D:) {
        %!elems.AT-KEY(%!elems.keys.pick);
    }
    multi method pickpairs(Baggy:D: Callable:D $calculate) {
        self.pickpairs( $calculate(self.total) )
    }
    multi method pickpairs(Baggy:D: $count) {
        %!elems{ %!elems.keys.pick(
          nqp::istype($count,Whatever) || $count == Inf
            ?? %!elems.elems
            !! $count
        ) };
    }

    proto method grab(|) { * }
    multi method grab(Baggy:D:) {
        my \grabbed := self.roll;
        %!elems.DELETE-KEY(grabbed.WHICH)
          if %!elems.AT-KEY(grabbed.WHICH).value-- == 1;
        grabbed;
    }
    multi method grab(Baggy:D: Callable:D $calculate) {
        self.grab( $calculate(self.total) )
    }
    multi method grab(Baggy:D: $count) {
        if nqp::istype($count,Whatever) || $count == Inf {
            my @grabbed = self!ROLLPICKGRABN(self.total,%!elems.values);
            %!elems = ();
            @grabbed;
        }
        else {
            my @grabbed = self!ROLLPICKGRABN($count,%!elems.values);
            for @grabbed {
                if %!elems.AT-KEY(.WHICH) -> $pair {
                    %!elems.DELETE-KEY(.WHICH) unless $pair.value;
                }
            }
            @grabbed;
        }
    }

    proto method pick(|) { * }
    multi method pick(Baggy:D:) { self.roll }
    multi method pick(Baggy:D: Callable:D $calculate) {
        self.pick( $calculate(self.total) )
    }
    multi method pick(Baggy:D: $count) {
        my $hash     := nqp::getattr(%!elems,Map,'$!storage');
        my int $elems = nqp::elems($hash);
        my $pairs    := nqp::setelems(nqp::list,$elems);

        my \iter := nqp::iterator($hash);
        my int $i = -1;
        my $pair;

        nqp::while(
          nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
          nqp::bindpos($pairs,$i,Pair.new(
            nqp::getattr(
              ($pair := nqp::iterval(nqp::shift(iter))),Pair,'$!key'),
            nqp::assign(nqp::p6scalarfromdesc(nqp::null),
              nqp::getattr($pair,Pair,'$!value'))
          ))
        );

        self!ROLLPICKGRABN(
          nqp::istype($count,Whatever) || $count == Inf ?? self.total !! $count,
          $pairs
        )
    }

    proto method roll(|) { * }
    multi method roll(Baggy:D:) {
        nqp::stmts(
          (my Int $rand = self.total.rand.Int),
          (my Int $seen = 0),
          (my \iter := nqp::iterator(nqp::getattr(%!elems,Map,'$!storage'))),
          nqp::while(
            iter && ($seen = $seen + nqp::getattr(
              nqp::iterval(nqp::shift(iter)),Pair,'$!value')) <= $rand,
            nqp::null
          ),
          nqp::if(
            $seen > $rand,
            nqp::getattr(nqp::iterval(iter),Pair,'$!key'),
            Nil
          )
        )
    }
    multi method roll(Baggy:D: $count) {
        nqp::istype($count,Whatever) || $count == Inf
          ?? Seq.new(Rakudo::Iterator.Roller(self))
          !! self!ROLLPICKGRABN($count, %!elems.values, :keep);
    }

    method !ROLLPICKGRABN(\count, @pairs, :$keep) { # N times
        Seq.new(class :: does Iterator {
            has Int $!total;
            has int $!elems;
            has $!pairs;
            has int $!todo;
            has int $!keep;

            method !SET-SELF($!total, \pairs, \keep, \todo) {
                $!elems  = pairs.elems;  # reifies
                $!pairs := nqp::getattr(pairs,List,'$!reified');
                $!todo   = todo;
                $!keep   = +?keep;
                self
            }
            method new(\total,\pairs,\keep,\count) {
                nqp::create(self)!SET-SELF(
                  total, pairs, keep, keep ?? count !! (total min count))
            }

            method pull-one() {
                if $!todo {
                    $!todo = nqp::sub_i($!todo,1);
                    my Int $rand = $!total.rand.Int;
                    my Int $seen = 0;
                    my int $i    = -1;
                    nqp::while(
                      nqp::islt_i(($i = nqp::add_i($i,1)),$!elems),
                      ($seen = $seen + nqp::atpos($!pairs,$i).value),
                      nqp::if(
                        $seen > $rand,
                        nqp::stmts(
                          nqp::unless(
                            $!keep,
                            nqp::stmts(
                              --(nqp::atpos($!pairs,$i)).value,
                              --$!total,
                            )
                          ),
                          return nqp::atpos($!pairs,$i).key
                        )
                      )
                    );
                }
                IterationEnd
            }
        }.new(self.total,@pairs,$keep,count))
    }

#--- classification method
    proto method classify-list(|) { * }
    multi method classify-list( &test, \list) {
        fail X::Cannot::Lazy.new(:action<classify>) if list.is-lazy;
        my \iter = (nqp::istype(list, Iterable) ?? list !! list.list).iterator;

        while (my $value := iter.pull-one) !=:= IterationEnd {
            my $tested := test($value);
            if nqp::istype($tested, Iterable) { # multi-level classify
                X::Invalid::ComputedValue.new(
                    :name<mapper>,
                    :method<classify-list>,
                    :value<an Iterable item>,
                    :reason(self.^name ~ ' cannot be nested and so does not '
                        ~ 'support multi-level classification'),
                ).throw;
            }
            else {
                self{$tested}++;
            }
        }
        self;
    }
    multi method classify-list( %test, |c ) {
        self.classify-list( { %test{$^a} }, |c );
    }
    multi method classify-list( @test, |c ) {
        self.classify-list( { @test[$^a] }, |c );
    }
    multi method classify-list(&test, **@list, |c) {
        self.classify-list(&test, @list, |c);
    }

    proto method categorize-list(|) { * }
    multi method categorize-list( &test, \list ) {
        fail X::Cannot::Lazy.new(:action<categorize>) if list.is-lazy;
        my \iter = (nqp::istype(list, Iterable) ?? list !! list.list).iterator;
        my $value := iter.pull-one;
        unless $value =:= IterationEnd {
            my $tested := test($value);

            # multi-level categorize
            if nqp::istype($tested[0],Iterable) {
                X::Invalid::ComputedValue.new(
                    :name<mapper>,
                    :method<categorize-list>,
                    :value<a nested Iterable item>,
                    :reason(self.^name ~ ' cannot be nested and so does not '
                        ~ 'support multi-level categorization'),
                ).throw;
            }
            # simple categorize
            else {
                loop {
                    self{$_}++ for @$tested;
                    last if ($value := iter.pull-one) =:= IterationEnd;
                    nqp::istype(($tested := test($value))[0], Iterable)
                        and X::Invalid::ComputedValue.new(
                            :name<mapper>,
                            :method<categorize-list>,
                            :value('an item with different number of elements '
                                ~ 'in it than previous items'),
                            :reason('all values need to have the same number '
                                ~ 'of elements. Mixed-level classification is '
                                ~ 'not supported.'),
                        ).throw;
                };
            }
       }
       self;
    }
    multi method categorize-list( %test, |c ) {
        self.categorize-list( { %test{$^a} }, |c );
    }
    multi method categorize-list( @test, |c ) {
        self.categorize-list( { @test[$^a] }, |c );
    }
    multi method categorize-list( &test, **@list, |c ) {
        self.categorize-list( &test, @list, |c );
    }

#--- coercion methods
    method !SETIFY(\type, int $bind) {
        nqp::if(
          nqp::getattr(%!elems,Map,'$!storage'),
          nqp::stmts(
            (my $elems := nqp::clone(nqp::getattr(%!elems,Map,'$!storage'))),
            (my $iter := nqp::iterator($elems)),
            nqp::while(
              $iter,
              nqp::bindkey(
                $elems,
                nqp::iterkey_s(my $tmp := nqp::shift($iter)),
                nqp::if(
                  $bind,
                  nqp::getattr(nqp::decont(nqp::iterval($tmp)),Pair,'$!key'),
                  (nqp::p6scalarfromdesc(nqp::null) =
                    nqp::getattr(nqp::decont(nqp::iterval($tmp)),Pair,'$!key'))
                )
              )
            ),
            nqp::create(type).SET-SELF($elems)
          ),
          nqp::create(type)
        )
    }
    method Set()     { self!SETIFY(Set,     1) }
    method SetHash() { self!SETIFY(SetHash, 0) }
}

multi sub infix:<eqv>(Baggy:D \a, Baggy:D \b) {
    nqp::p6bool(
      nqp::unless(
        nqp::eqaddr(a,b),
        nqp::eqaddr(a.WHAT,b.WHAT)
          && nqp::getattr(nqp::decont(a),a.WHAT,'%!elems')
               eqv nqp::getattr(nqp::decont(b),b.WHAT,'%!elems')
      )
    )
}
# vim: ft=perl6 expandtab sw=4
