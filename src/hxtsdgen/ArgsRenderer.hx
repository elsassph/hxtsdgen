package hxtsdgen;

import haxe.macro.Type;
import hxtsdgen.TypeRenderer.renderType;

class ArgsRenderer {

    public static function renderArgs(ctx:Selector, args:Array<{name:String, opt:Bool, t:Type}>):String {
        // here we handle haxe's crazy argument skipping:
        // we allow trailing optional args, but if there's non-optional
        // args after the optional ones, we consider them non-optional for TS
        var noOptionalUntil = 0;
        var hadOptional = true;
        for (i in 0...args.length) {
            var arg = args[i];
            if (arg.opt) {
                hadOptional = true;
            } else if (hadOptional && !arg.opt) {
                noOptionalUntil = i;
                hadOptional = false;
            }
        }

        var tsArgs = [];
        for (i in 0...args.length) {
            var arg = args[i];
            var name = if (arg.name != "") arg.name else 'arg$i';
            var opt = if (arg.opt && i >= noOptionalUntil) "?" else "";
            tsArgs.push('$name$opt: ${renderType(ctx, arg.t)}');
        }
        return tsArgs.join(", ");
    }
}
