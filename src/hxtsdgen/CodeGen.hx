package hxtsdgen;

import haxe.io.Path;
import haxe.macro.Expr;
import haxe.macro.Type;
import hxtsdgen.Generator;
import hxtsdgen.DocRenderer.renderDoc;
import hxtsdgen.ArgsRenderer.renderArgs;
import hxtsdgen.TypeRenderer.renderType;

using haxe.macro.Tools;
using StringTools;

class CodeGen {

    var selector:Selector;
    var dtsDecl:Array<String>;
    var etsDecl:Array<String>;
    var etsExports:Array<String>;

    public function new(selector:Selector) {
        this.selector = selector;
        selector.onAutoInclude = generateSome;
    }

    public function generate() {
        dtsDecl = [];
        etsDecl = Generator.GEN_ENUM_TS ? [] : dtsDecl;
        etsExports = [];

        generateSome(selector.exposed);

        return {
            dts: dtsDecl,
            ets: etsDecl,
            exports: etsExports
        };
    }

    function generateSome(decl:Array<ExposeKind>) {
        for (e in decl) {
            switch (e) {
                case EClass(cl):
                    dtsDecl.push(generateClassDeclaration(cl, true));
                case EEnum(t):
                    var eDecl = generateEnumDeclaration(t, true);
                    if (eDecl != "") etsDecl.push(eDecl);
                case ETypedef(t, anon):
                    dtsDecl.push(generateTypedefDeclaration(t, anon, true));
                case EMethod(cl, f):
                    dtsDecl.push(generateFunctionDeclaration(cl, true, f));
            }
        }
    }

    static public function getExposePath(m:MetaAccess):Array<String> {
        return switch (m.extract(":expose")) {
            case [{params: [macro $v{(s:String)}]}]: s.split(".");
            case _: m.has(":native") ? getNativePath(m) : null;
        }
    }

    static function getNativePath(m:MetaAccess):Array<String> {
        return switch (m.extract(":native")) {
            case [{params: [macro $v{(s:String)}]}]: s.split(".");
            case _: null;
        }
    }

    static function wrapInNamespace(exposedPath:Array<String>, fn:String->String->String):String {
        var name = exposedPath.pop();
        return if (exposedPath.length == 0)
            fn(name, "");
        else
            'export namespace ${exposedPath.join(".")} {\n${fn(name, "\t")}\n}';
    }

    function generateFunctionDeclaration(cl:ClassType, isExport:Bool, f:ClassField):String {
        var exposePath = getExposePath(f.meta);
        if (exposePath == null)
            exposePath = cl.pack.concat([cl.name, f.name]);

        return wrapInNamespace(exposePath, function(name, indent) {
            var parts = [];
            if (f.doc != null)
                parts.push(renderDoc(f.doc, indent));

            switch [f.kind, f.type] {
                case [FMethod(_), TFun(args, ret)]:
                    var prefix = isExport ? "export function " : "function ";
                    parts.push(renderFunction(name, args, ret, f.params, indent, prefix));
                default:
                    throw new Error("This kind of field cannot be exposed to JavaScript", f.pos);
            }

            return parts.join("\n");
        });
    }

    function renderFunction(name:String, args:Array<{name:String, opt:Bool, t:Type}>, ret:Type, params:Array<TypeParameter>, indent:String, prefix:String):String {
        var tparams = renderTypeParams(params);
        return '$indent$prefix$name$tparams(${renderArgs(selector, args)}): ${renderType(selector, ret)};';
    }

    function renderTypeParams(params:Array<TypeParameter>):String {
        return
            if (params.length == 0) ""
            else "<" + params.map(function(t) return return t.name).join(", ") + ">";
    }

    function generateClassDeclaration(cl:ClassType, isExport:Bool):String {
        var exposePath = getExposePath(cl.meta);
        if (exposePath == null)
            exposePath = cl.pack.concat([cl.name]);

        return wrapInNamespace(exposePath, function(name, indent) {
            var parts = [];

            if (cl.doc != null)
                parts.push(renderDoc(cl.doc, indent));

            // TODO: maybe it's a good idea to output all-static class that is not referenced
            // elsewhere as a namespace for TypeScript
            var tparams = renderTypeParams(cl.params);
            var isInterface = cl.isInterface;
            var type = isInterface ? 'interface' : 'class';
            var export = isExport ? "export " : "";
            parts.push('$indent${export}$type $name$tparams {');

            {
                var indent = indent + "\t";
                generateConstructor(cl, isInterface, indent, parts);

                var fields = cl.fields.get();
                for (field in fields)
                    if (field.isPublic || isPropertyGetterSetter(fields, field))
                        addField(field, false, isInterface, indent, parts);

                fields = cl.statics.get();
                for (field in fields)
                    if (field.isPublic || isPropertyGetterSetter(fields, field))
                        addField(field, true, isInterface, indent, parts);
            }

            parts.push('$indent}');
            return parts.join("\n");
        });
    }

    function generateEnumDeclaration(t:ClassType, isExport:Bool):String {
        // TypeScript `const enum` are pure typing constructs (e.g. don't exist in JS either)
        // so it matches Haxe abstract enum well.

        // Unwrap abstract type
        var bt:BaseType = t;
        switch (t.kind) {
            case KAbstractImpl(_.get() => at): bt = at;
            default: // we keep what we have
        }

        var exposePath = getExposePath(t.meta);
        if (exposePath == null)
            exposePath = bt.pack.concat([bt.name]);

        return wrapInNamespace(exposePath, function(name, indent) {
            var parts = [];

            if (t.doc != null)
                parts.push(renderDoc(t.doc, indent));

            var export = isExport ? "export " : (exposePath.length == 0 ? "declare " : "");
            parts.push('$indent${export}const enum $name {');

            {
                var indent = indent + "\t";
                var added = 0;
                var fields = t.statics.get();
                for (field in fields)
                    if (field.isPublic)
                        added += addConstValue(field, indent, parts) ? 1 : 0;
                if (added == 0) return ""; // empty enum
            }

            if (Generator.GEN_ENUM_TS && isExport) {
                // this will be imported by the d.ts
                // - no package: enum name
                // - with package: root package (com.foo.Bar -> com)
                if (exposePath.length == 0) etsExports.push(name);
                else {
                    var ns = exposePath[0];
                    if (etsExports.indexOf(ns) < 0) etsExports.push(ns);
                }
            }

            parts.push('$indent}');
            return parts.join("\n");
        });
    }

    function generateTypedefDeclaration(t:DefType, anon:AnonType, isExport:Bool):String {
        var exposePath = getExposePath(t.meta);
        if (exposePath == null)
            exposePath = t.pack.concat([t.name]);

        return wrapInNamespace(exposePath, function(name, indent) {
            var parts = [];

            if (t.doc != null)
                parts.push(renderDoc(t.doc, indent));

            var tparams = renderTypeParams(t.params);
            var export = isExport ? "export " : "";
            parts.push('$indent${export}type $name$tparams = {');

            {
                var indent = indent + "\t";
                var fields = anon.fields;
                for (field in fields)
                    if (field.isPublic)
                        addField(field, false, true, indent, parts);
            }

            parts.push('$indent}');
            return parts.join("\n");
        });
    }

    function addConstValue(field:ClassField, indent:String, parts:Array<String>) {
        switch (field.kind) {
            case FVar(_, _):
                var expr = field.expr().expr;
                var value = switch (expr) {
                    case TCast(_.expr => TConst(c), _):
                        switch (c) {
                            case TInt(v): Std.string(v);
                            case TFloat(f): Std.string(f);
                            case TString(s): '"${escapeString(s)}"';
                            case TNull: null; // not allowed
                            case TBool(_): null; // not allowed
                            default: null;
                        }
                    default: null;
                };
                if (value != null) {
                    parts.push('$indent${field.name} = $value,');
                    return true;
                }
            default:
        }
        return false;
    }

    function escapeString(s:String) {
        return s.split('\\').join('\\\\')
            .split('"').join('\\"');
    }

    function addField(field:ClassField, isStatic:Bool, isInterface:Bool, indent:String, parts:Array<String>) {
        if (field.doc != null)
            parts.push(renderDoc(field.doc, indent));

        var prefix = if (isStatic) "static " else "";

        switch [field.kind, field.type] {
            case [FMethod(_), TFun(args, ret)]:
                parts.push(renderFunction(field.name, args, ret, field.params, indent, prefix));

            case [FVar(read, write), _]:
                switch (write) {
                    case AccNo|AccNever|AccCall:
                        prefix += "readonly ";
                    default:
                }
                if (read != AccCall) {
                    var option = isInterface && isNullable(field) ? "?" : "";
                    parts.push('$indent$prefix${field.name}$option: ${renderType(selector, field.type)};');
                }

            default:
        }
    }

    function generateConstructor(cl:ClassType, isInterface:Bool, indent:String, parts:Array<String>) {
        var privateCtor = true;
        if (cl.constructor != null) {
            var ctor = cl.constructor.get();
            privateCtor = false;
            if (ctor.doc != null)
                parts.push(renderDoc(ctor.doc, indent));
            switch (ctor.type) {
                case TFun(args, _):
                    var prefix = if (ctor.isPublic) "" else "private "; // TODO: should this really be protected?
                    parts.push('${indent}${prefix}constructor(${renderArgs(selector, args)});');
                default:
                    throw "wtf";
            }
        } else if (!isInterface) {
            parts.push('${indent}private constructor();');
        }
    }

    // For a given `method` looking like a `get_x`/`set_x`, look for a matching property
    function isPropertyGetterSetter(fields:Array<ClassField>, method:ClassField) {
        var re = new EReg('(get|set)_(.*)', '');
        if (re.match(method.name)) {
            var name = re.matched(2);
            for (field in fields) if (field.name == name && isProperty(field)) return true;
        }
        return false;
    }

    function isProperty(field) {
        return switch(field.kind) {
            case FVar(read, write): write == AccCall || read == AccCall;
            default: false;
        };
    }

    function renderGetter(field:ClassField, indent:String, prefix:String) {
        return renderFunction('get_${field.name}', [], field.type, field.params, indent, prefix);
    }

    function renderSetter(field:ClassField, indent:String, prefix:String) {
        var args = [{
            name: 'value',
            opt: false,
            t: field.type
        }];
        return renderFunction('set_${field.name}', args, field.type, field.params, indent, prefix);
    }

    function isNullable(field:ClassField) {
        return switch (field.type) {
            case TType(_.get() => _.name => 'Null', _): true;
            default: false;
        }
    }

}
