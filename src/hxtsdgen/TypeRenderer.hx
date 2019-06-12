package hxtsdgen;

import haxe.macro.Type;
using haxe.macro.Tools;

import hxtsdgen.ArgsRenderer.renderArgs;
import hxtsdgen.Generator.ensureIncluded;

class TypeRenderer {

    public static function renderType(ctx:Generator, t:Type, paren = false):String {
        inline function wrap(s) return if (paren) '($s)' else s;

        return switch (t) {
            case TInst(_.get() => cl, params):
                switch [cl, params] {
                    case [{pack: [], name: "String"}, _]:
                        "string";

                    case [{pack: [], name: "Array"}, [elemT]]:
                        renderType(ctx, elemT, true) + "[]";

                    case [{name: name, kind: KTypeParameter(_)}, _]:
                        name;

                    default:
                        ensureIncluded(t);
                        formatName(ctx, cl, params);
                }

            case TAbstract(_.get() => ab, params):
                switch [ab, params] {
                    case [{pack: [], name: "Int" | "Float"}, _]:
                        "number";

                    case [{pack: [], name: "Bool"}, _]:
                        "boolean";

                    case [{pack: [], name: "Void"}, _]:
                        "void";

                    case [{pack: [], name: "Null"}, [realT]]: // Haxe 4.x
                        // TODO: generate `| null` union unless it comes from an optional field?
                        renderType(ctx, realT, paren);

                    case [{pack: ["haxe", "extern"], name: "EitherType"}, [aT, bT]]:
                        '${renderType(ctx, aT, true)} | ${renderType(ctx, bT, true)}';

                    default:
                        // TODO: do we want to handle more `type Name = Underlying` cases?
                        if (Generator.GEN_ENUM_TS || ab.meta.has(":expose") || ensureIncluded(t)) formatName(ctx, ab, params);
                        else renderType(ctx, ab.type.applyTypeParameters(ab.params, params), paren);
                }

            case TAnonymous(_.get() => anon):
                var fields = [];
                for (field in anon.fields) {
                    var opt = if (field.meta.has(":optional")) "?" else "";
                    fields.push('${field.name}$opt: ${renderType(ctx, field.type)}');
                }
                '{${fields.join(", ")}}';

            case TType(_.get() => dt, params):
                switch [dt, params] {
                    case [{pack: [], name: "Null"}, [realT]]: // Haxe 3.x
                        // TODO: generate `| null` union unless it comes from an optional field?
                        renderType(ctx, realT, paren);

                    default:
                        switch (dt.type) {
                            case TAnonymous(_) if (Generator.GEN_ENUM_TS || dt.meta.has(":expose") || ensureIncluded(t)):
                                formatName(ctx, dt, params);
                            default:
                                renderType(ctx, dt.type.applyTypeParameters(dt.params, params), paren);
                        }
                }

            case TFun(args, ret):
                wrap('(${renderArgs(ctx, args)}) => ${renderType(ctx, ret)}');

            case TDynamic(null):
                'any';

            case TDynamic(elemT):
                '{ [key: string]: ${renderType(ctx, elemT)} }';

            default:
                throw 'Cannot render type ${t.toString()} into a TypeScript declaration (TODO?)';
        }
    }

    static function formatName(ctx:Generator, t: { pack:Array<String>, name:String, meta:MetaAccess }, params:Array<Type>) {
        if (t.meta.has(":expose")) {
            var exposePath = Generator.getExposePath(t.meta);
            if (exposePath != null) {
                return exposePath.join('.');
            }
        }

        var dotName = haxe.macro.MacroStringTools.toDotPath(t.pack, t.name);
        // type parameters
        if (params.length > 0) {
            var genericParams = params.map(function(p) return renderType(ctx, p));
            dotName += '<${genericParams.join(',')}>';
        }
        return dotName;
    }
}
