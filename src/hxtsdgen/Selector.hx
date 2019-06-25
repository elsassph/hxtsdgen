package hxtsdgen;

import haxe.macro.Type;
import hxtsdgen.Generator;

using haxe.macro.Tools;

class Selector {

    public var exposed:Array<ExposeKind>;
    public var onAutoInclude:Array<ExposeKind> -> Void;

    var autoIncluded:Map<String, Bool>;

    public function new() {
        autoIncluded = new Map<String, Bool>();
    }

    public function getExposed(types:Array<Type>) {
        exposed = [];
        for (type in types) {
            switch [type, type.follow()] {
                case [TType(_.get() => t, _), TAnonymous(_.get() => anon)]:
                    if (t.meta.has(":expose")) {
                        exposed.push(ETypedef(t, anon));
                    }
                case [_, TInst(_.get() => cl, _)]:
                    if (cl.meta.has(':enum')) {
                        if (Generator.GEN_ENUM_TS || cl.meta.has(":expose"))
                            exposed.push(EEnum(cl));
                    } else {
                        if (cl.meta.has(":expose")) {
                            exposed.push(EClass(cl));
                        }
                        for (f in cl.statics.get()) {
                            if (f.meta.has(":expose"))
                                exposed.push(EMethod(cl, f));
                        }
                    }
                default:
            }
        }
        return exposed.length;
    }

    public function ensureIncluded(t:Type) {
        // A type is referenced, maybe it needs to be generated as well
        switch [t, t.follow()] {
            case [_, TInst(_.get() => cl, _)] if (!cl.isExtern && !cl.meta.has(":expose")):
                var key = cl.pack.join('.') + '.' + cl.name;
                if (!autoIncluded.exists(key)) {
                    autoIncluded.set(key, true);
                    onAutoInclude([EClass(cl)]);
                }
                return true;
            case [TType(_.get() => tt, _), TAnonymous(_.get() => anon)]:
                var key = tt.pack.join('.') + '.' + tt.name;
                if (!autoIncluded.exists(key)) {
                    autoIncluded.set(key, true);
                    onAutoInclude([ETypedef(tt, anon)]);
                }
                return true;
            case [TAbstract(_.get() => ab, params), _]:
                var cl = ab.impl.get();
                if (cl.meta.has(':enum')) {
                    var key = cl.pack.join('.') + '.' + cl.name;
                    if (!autoIncluded.exists(key)) {
                        autoIncluded.set(key, true);
                        onAutoInclude([EEnum(cl)]);
                    }
                    return true;
                }
            default:
        }
        return false;
    }
}
