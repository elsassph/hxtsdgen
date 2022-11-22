package hxtsdgen;

import haxe.macro.Type;
import hxtsdgen.ArgsRenderer.renderArgs;

using haxe.macro.Tools;

class TypeRenderer {

    public static function renderType(ctx:Selector, t:Type, paren = false):String {
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
                        ctx.ensureIncluded(t);
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
                        if (ab.meta.has(":expose") || ctx.ensureIncluded(t)) formatName(ctx, ab, params);
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
                            case TAnonymous(_) if (Generator.GEN_ENUM_TS || dt.meta.has(":expose") || ctx.ensureIncluded(t)):
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
              var msg = 'Cannot render type ${t.toString()} into a TypeScript declaration (TODO?)';
              if(Generator.THROW_ON_UNKNOWN)
                throw msg;
              else  {
                haxe.macro.Context.warning(msg, haxe.macro.Context.currentPos());
                return 'any';
              }
        }
    }

    static public function renderClass(ctx:Selector, cl:ClassType) {
        return formatName(ctx, cl, cl.params.map(function(tp) return tp.t));
    }

    static public function formatName(ctx:Selector, t: { pack:Array<String>, name:String, meta:MetaAccess }, params:Array<Type>) {
        var exposePath = CodeGen.getExposePath(t.meta);
        if (exposePath == null) exposePath = t.pack.concat([t.name]);
        var dotName = exposePath.join(
            #if hxtsdgen_namespaced '.' #else '_' #end
        );
        // type parameters
        if (params.length > 0) {
            var genericParams = params.map(function(p) return renderType(ctx, p));
            if(t.name == "Class"){
                dotName = '${genericParams.join('')}';
            } else {
                dotName += '<${genericParams.join(',')}>';
            }
        }
        return dotName;
    }
}
