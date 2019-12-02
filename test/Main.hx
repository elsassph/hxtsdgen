import Sys.println;
import js.node.Os;
import sys.FileSystem;
import sys.io.File;
using StringTools;

@:expose
class Main {
    static var failFast = false;
    static public function main() {
        var programDir = haxe.io.Path.directory(Sys.programPath());
        var total = 0, failed = 0;

        function processFile(file:String, genEnums:Bool, genTypes:Bool) {
            total++;
            var name = file.split('.txt')[0];
            println('Running test case `$name`...');
            var testCase = readTestCase('$programDir/cases/$file');
            var tsOut = runTestCase(name, testCase.hx, genEnums, genTypes);
            if (tsOut == null) {
                println("Haxe compilation failed!");
                println("---");
                failed++;
                if (failFast) throw 'failFast is enabled so aborting test.';
            } else if (testCase.dts != tsOut.dts || testCase.ets != tsOut.ets || testCase.its != tsOut.its) {
                println("Output is different!");
                println('Expected:\n[d.ts]\n${testCase.dts}');
                if (testCase.ets != "") println('---\n[enums.ts]\n${testCase.ets}');
                if (testCase.its != "") println('---\n[types.d.ts]\n${testCase.its}');
                println('---\nActual:\n[d.ts]\n${tsOut.dts}');
                if (tsOut.ets != "") println('---\n[enums.ts]\n${tsOut.ets}');
                if (tsOut.its != "") println('---\n[types.d.ts]\n${tsOut.its}');
                failed++;
                println("---");
                if (failFast) throw 'failFast is enabled so aborting test.';
            }
        }

        var fileName = Sys.args()[0];
        if (fileName != null) {
            processFile(fileName, fileName.indexOf('-enums') > 0, fileName.indexOf('-types') > 0);
        } else {
            for (file in FileSystem.readDirectory('$programDir/cases')) {
                processFile(file, file.indexOf('-enums') > 0, file.indexOf('-types') > 0);
            }
        }

        println('Result: $total. Failed: $failed.');
        Sys.exit(if (failed > 0) 1 else 0);
    }

    static function readTestCase(path:String) {
        var testCase = File.getContent(path).replace("\r\n", "\n");
        var parts = testCase.split("\n----\n");
        if (parts.length < 2) throw 'Invalid case $path';
        var result = {
            hx: parts[0],
            dts: parts[1].trim(),
            ets: parts.length > 2 ? parts[2].trim() : "",
            its: parts.length > 3 ? parts[3].trim() : ""
        };
        return result;
    }

    static function runTestCase(name:String, hxCode:String, genEnums:Bool, genTypes:Bool) {
        var cp = Os.tmpdir();
        var pkg = getPackage(hxCode);
        if (pkg.dir != null) FileSystem.createDirectory('$cp/${pkg.dir}');
        var hxFile = pkg.dir != null ? '$cp/${pkg.dir}/HxTsdGenTestCase.hx' : '$cp/HxTsdGenTestCase.hx';
        var outFile = '$cp/$name.js';
        var dtsFile = '$cp/$name.d.ts';
        var etsFile = '$cp/$name-enums.ts';
        var itsFile = '$cp/$name-types.d.ts';
        File.saveContent(hxFile, hxCode);

        var args = [
            "-cp", cp,
            "-lib", "hxtsdgen",
            "-js", outFile,
            "-D", "hxtsdgen_skip_header",
            "-D", "hxtsdgen_namespaced",
            "-D", "hxtsdgen_sort_fields",
            '${pkg.dot}HxTsdGenTestCase'
        ];
        if (genEnums) args = args.concat(["-D", "hxtsdgen_enums_ts"]);
        if (genTypes) args = args.concat(["-D", "hxtsdgen_types_ts"]);
        var code = Sys.command("haxe", args);

        var dts:String = null, ets:String = null, its:String = null;
        if (code == 0) {
            dts = FileSystem.exists(dtsFile) ? File.getContent(dtsFile).trim() : "";
            ets = FileSystem.exists(etsFile) ? File.getContent(etsFile).trim() : "";
            its = FileSystem.exists(itsFile) ? File.getContent(itsFile).trim() : "";
        }

        try {
            var programDir = haxe.io.Path.directory(Sys.programPath());
            FileSystem.deleteFile(hxFile);
            FileSystem.createDirectory('$programDir/out');
            FileSystem.rename(outFile, '$programDir/out/$name.js');
            if (FileSystem.exists(dtsFile)) FileSystem.rename(dtsFile, '$programDir/out/$name.d.ts');
            if (FileSystem.exists(etsFile)) FileSystem.rename(etsFile, '$programDir/out/$name-enums.ts');
            if (FileSystem.exists(itsFile)) FileSystem.rename(itsFile, '$programDir/out/$name-types.d.ts');
        } catch (_:Any) {}

        return code == 0 ? { dts: dts, ets: ets, its: its } : null;
    }

    static function getPackage(hxCode:String) {
        var rePkg = ~/package ([a-z0-9.]+);/i;
        if (rePkg.match(hxCode)) {
            var p = rePkg.matched(1);
            return {
                dir: p.split('.').join('/'),
                dot: p + '.'
            };
        }
        return { dir: null, dot: "" };
    }
}
