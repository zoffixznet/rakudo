my class MixinCacheHOW {
    method new_type($class_type) {
        my $mo := self.new();
        my $type := nqp::newtype($mo, 'Uninstantiable');
        nqp::setparameterizer($type, sub ($type, @roles) {
            $class_type.HOW.generate_mixin($class_type, @roles);
        });
        $type
    }
}

role Perl6::Metamodel::Mixins {
    has $!mixin_cache;
    has $!is_mixin;
    has $!mixin_attribute;

    method set_is_mixin($obj) { $!is_mixin := 1 }
    method is_mixin($obj) { $!is_mixin }
    method set_mixin_attribute($obj, $attr) { $!mixin_attribute := $attr }
    method mixin_attribute($obj) { $!mixin_attribute }
    method flush_cache($obj) { }

    method setup_mixin_cache($obj) {
        $!mixin_cache := MixinCacheHOW.new_type($obj.WHAT);
    }

    method mixin($obj, *@roles, :$need-mixin-attribute) {
        # Lookup mixin, generating it if needed.
        my int $i := 0;
        my int $n := nqp::elems(@roles);
        while $i < $n {
            @roles[$i] := nqp::decont(@roles[$i]);
            ++$i;
        }
        my $mixin_type := nqp::parameterizetype($!mixin_cache, @roles);

        # Ensure there's a mixin attribute, if we need it.
        if $need-mixin-attribute {
            my $found := $mixin_type.HOW.mixin_attribute($mixin_type);
            unless $found {
                my %ex := nqp::gethllsym('Raku', 'P6EX');
                if !nqp::isnull(%ex) && nqp::existskey(%ex, 'X::Role::Initialization') {
                    nqp::atkey(%ex, 'X::Role::Initialization')(@roles[0]);
                }
                else {
                    my $name := @roles[0].HOW.name(@roles[0]);
                    nqp::die("Can only supply an initialization value for a role if it has a single public attribute, but this is not the case for '$name'");
                }
            }
        }

        # If the original object was concrete, change its type by calling a
        # low level op. Otherwise, we just return the new type object
        nqp::isconcrete($obj) ?? nqp::rebless($obj, $mixin_type) !! $mixin_type
    }

    # Generates a new mixin. Not intended for direct use; use mixin, to hit
    # the mixin cache.
    method generate_mixin($obj, @roles) {
        # Flush its cache as promised, otherwise outdated NFAs will stick around.
        self.flush_cache($obj) if !nqp::isnull($obj) || self.is_mixin($obj);

        # Work out a type name for the post-mixed-in role.
        my @role_names;
        for @roles { @role_names.push(~$_.HOW.name($_)) }
        my $new_name := self.name($obj) ~ '+{' ~
            nqp::join(',', @role_names) ~ '}';

        my @role_shortnames;
        for @roles { my $cur := $_; @role_shortnames.push(~$_.HOW.shortname($_)); }
        my $new_shortname := $obj.HOW.shortname($obj) ~ '+{' ~
            nqp::join(',', @role_shortnames) ~ '}';

        # Create new type, derive it from ourself and then add
        # all the roles we're mixing it.
        my $new_type := self.new_type(:name($new_name), :repr($obj.REPR), :is_mixin);
        $new_type.HOW.set_language_revision($new_type, $obj.HOW.language-revision($obj))
            if $obj.HOW.is_composed($obj);
        $new_type.HOW.set_is_mixin($new_type);
        $new_type.HOW.add_parent($new_type, $obj.WHAT);
        for @roles {
            $new_type.HOW.add_role($new_type, $_);
        }
        $new_type.HOW.compose($new_type);
        $new_type.HOW.set_shortname($new_type, $new_shortname);
        $new_type.HOW.set_boolification_mode($new_type,
            nqp::existskey(nqp::hllize($new_type.HOW.method_table($new_type)), 'Bool')
            || nqp::can($new_type.HOW, 'submethod_table')
                && nqp::existskey(nqp::hllize($new_type.HOW.submethod_table($new_type)), 'Bool')
                ?? 0
                !! self.get_boolification_mode($obj));
        $new_type.HOW.publish_boolification_spec($new_type);

        # Locate an attribute that can serve as the initialization attribute,
        # if there is one.
        my $found;
        for $new_type.HOW.attributes($new_type, :local) {
            if $_.is_built {
                if $found {
                    $found := NQPMu;
                    last;
                }
                $found := $_;
            }
        }
        if $found {
            $new_type.HOW.set_mixin_attribute($new_type, $found);
        }

        $new_type
    }

    method mixin_base($obj) {
        for self.mro($obj) {
            unless $_.HOW.is_mixin($_) {
                return $_;
            }
        }
    }
}

# vim: expandtab sw=4
