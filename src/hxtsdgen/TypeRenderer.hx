package hxtsdgen;

import haxe.macro.Type;
using haxe.macro.Tools;

import hxtsdgen.ArgsRenderer.renderArgs;

class TypeRenderer {
    public static function renderType(t:Type):String {
        return switch (t) {
            case TInst(_.get() => cl, params):
                switch [cl, params] {
                    case [{pack: [], name: "String"}, _]:
                        "string";

                    case [{pack: [], name: "Array"}, [elemT]]:
                        renderType(elemT) + "[]";

                    case [{name: name, kind: KTypeParameter(_)}, _]:
                        name;

                    default:
                        // TODO: handle @:expose'd paths
                        haxe.macro.MacroStringTools.toDotPath(cl.pack, cl.name);
                }

            case TAbstract(_.get() => ab, params):
                switch [ab, params] {
                    case [{pack: [], name: "Int" | "Float"}, _]:
                        "number";

                    case [{pack: [], name: "Bool"}, _]:
                        "boolean";

                    case [{pack: [], name: "Void"}, _]:
                        "void";

                    case [{pack: ["haxe", "extern"], name: "EitherType"}, [aT, bT]]:
                        '${renderType(aT)} | ${renderType(bT)}';

                    default:
                        // TODO: do we want to have a `type Name = Underlying` here maybe?
                        renderType(ab.type.applyTypeParameters(ab.params, params));
                }

            case TAnonymous(_.get() => anon):
                var fields = [];
                for (field in anon.fields) {
                    var opt = if (field.meta.has(":optional")) "?" else "";
                    fields.push('${field.name}$opt: ${renderType(field.type)}');
                }
                '{${fields.join(", ")}}';

            case TType(_.get() => dt, params):
                switch [dt, params] {
                    case [{pack: [], name: "Null"}, [realT]]:
                        // TODO: generate `| null` union unless it comes from an optional field?
                        renderType(realT);

                    default:
                        // TODO: generate TS interface declarations
                        renderType(dt.type.applyTypeParameters(dt.params, params));
                }

            case TFun(args, ret):
                '(${renderArgs(args)}) => ${renderType(ret)}';

            case TDynamic(null):
                'any';

            case TDynamic(elemT):
                '{ [key: string]: ${renderType(elemT)} }';

            default:
                throw 'Cannot render type ${t.toString()} into a TypeScript declaration (TODO?)';
        }
    }
}
