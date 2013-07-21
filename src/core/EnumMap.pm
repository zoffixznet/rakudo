my class EnumMap does Associative {
    # declared in BOOTSTRAP.pm:
    #   has $!storage;         # Parrot Hash PMC of key->value mappings

    multi method Bool(EnumMap:D:) {
        nqp::p6bool(nqp::defined($!storage) ?? nqp::elems($!storage) !! 0)
    }
    method elems(EnumMap:D:) {
        nqp::defined($!storage) ?? nqp::p6box_i(nqp::elems($!storage)) !! 0
    }

    multi method ACCEPTS(EnumMap:D: Any $topic) {
        so self.exists($topic.any);
    }

    multi method ACCEPTS(EnumMap:D: Cool:D $topic) {
        so self.exists($topic);
    }

    multi method ACCEPTS(EnumMap:D: Positional $topic) {
        so self.exists($topic.any);
    }

    multi method ACCEPTS(EnumMap:D: Regex $topic) {
        so self.keys.any.match($topic);
    }
    
    proto method exists(|) {*}
    multi method exists(EnumMap:D: Str:D \key) {
        nqp::p6bool(
            nqp::defined($!storage)
            && nqp::existskey($!storage, nqp::unbox_s(key))
        )
    }
    multi method exists(EnumMap:D: \key) {
        nqp::p6bool(
            nqp::defined($!storage)
            && nqp::existskey($!storage, nqp::unbox_s(key.Stringy))
        )
    }

    multi method perl(EnumMap:D:) {
        self.^name ~ '.new('
            ~ self.keys.map({ .perl ~ ', ' ~ self.at_key($_).perl ~ ', '}).join
            ~ ')';
    }

    method iterator(EnumMap:D:) { self.pairs.iterator }
    method list(EnumMap:D:) { self.pairs }

    method keys(EnumMap:D:)   { self.pairs.map( { $_.key } ) }
    method kv(EnumMap:D:)     { self.pairs.map( { $_.kv } ) }
    method values(EnumMap:D:) { self.pairs.map( { $_.value } ) }
    method pairs(EnumMap:D:) {
        return unless nqp::defined($!storage);
        gather {
            my Mu $iter := nqp::iterator($!storage);
            my Mu $pair;
            while $iter {
                $pair := nqp::shift($iter);
#?if jvm
                take Pair.new(:key(nqp::p6box_s(nqp::iterkey_s($pair))), :value(nqp::iterval($pair)));
#?endif
#?if parrot
                take Pair.new(:key($pair.key), :value($pair.value));
#?endif
            }
            Nil
        }
    }
    method invert(EnumMap:D:) {
        return unless nqp::defined($!storage);
        gather {
            my Mu $iter := nqp::iterator($!storage);
            my Mu $pair;
            while $iter {
                $pair := nqp::shift($iter);
#?if jvm
                take Pair.new(:key(nqp::iterval($pair)), :value(nqp::p6box_s(nqp::iterkey_s($pair))));
#?endif
#?if parrot
                take Pair.new(:key($pair.value), :value($pair.key));
#?endif
            }
            Nil
        }
    }

    method at_key($key) is rw {
        my str $skey = nqp::unbox_s($key.Str);
        nqp::defined($!storage) && nqp::existskey($!storage, $skey)
          ?? nqp::atkey($!storage, $skey)
          !! Any
    }

    method STORE_AT_KEY(\key, Mu \value) is rw {
        nqp::defined($!storage) ||
            nqp::bindattr(self, EnumMap, '$!storage', nqp::hash());
        nqp::bindkey($!storage, nqp::unbox_s(key.Str), value)
    }
    
    method Capture(EnumMap:D:) {
        my $cap := nqp::create(Capture);
        nqp::bindattr($cap, Capture, '$!hash', $!storage);
        $cap
    }
    
    method FLATTENABLE_LIST() { nqp::list() }
    method FLATTENABLE_HASH() {
        nqp::defined($!storage) ||
            nqp::bindattr(self, EnumMap, '$!storage', nqp::hash());
        $!storage
    }

    method fmt(EnumMap:D: $format = "%s\t\%s", $sep = "\n") {
        self.pairs.fmt($format, $sep);
    }
    
    method hash(\SELF:) is rw {
        SELF
    }
}

multi sub infix:<eqv>(EnumMap:D $a, EnumMap:D $b) {
    if +$a != +$b { return Bool::False }
    for $a.kv -> $k, $v {
        unless $b.exists($k) && $b{$k} eqv $v {
            return Bool::False;
        }
    }
    Bool::True;
}

