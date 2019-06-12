import Sys.println;
import js.node.Os;
import sys.FileSystem;
import sys.io.File;
using StringTools;

class Main {
    static function main() {
        var programDir = haxe.io.Path.directory(Sys.programPath());
        var total = 0, failed = 0;

        function processFile(file:String, genEnums:Bool) {
            total++;
            println('Running test case `$file`...');
            var testCase = readTestCase('$programDir/cases/$file', genEnums);
            var tsOut = runTestCase(testCase.hx, genEnums);
            if (tsOut == null) {
                println("Haxe compilation failed!");
                println("---");
                failed++;
            } else if (testCase.dts != tsOut.dts || testCase.ets != tsOut.ets) {
                println("Output is different!");
                println('Expected:\n[d.ts]\n${testCase.dts}');
                if (testCase.ets != null) println('\n---\n[enums.ts]\n${testCase.ets}');
                println('\n---\nActual:\n[d.ts]\n${tsOut.dts}');
                if (tsOut.ets != null) println('\n---\n[enums.ts]\n${tsOut.ets}');
                failed++;
                println("---");
            }
        }

        var fileName = Sys.args()[0];
        if (fileName != null) {
            processFile(fileName, fileName.indexOf('-enums') > 0);
        } else {
            for (file in FileSystem.readDirectory('$programDir/cases')) {
                processFile(file, file.indexOf('-enums') > 0);
            }
        }

        println('Result: $total. Failed: $failed.');
        Sys.exit(if (failed > 0) 1 else 0);
    }

    static function readTestCase(path:String, genEnums:Bool) {
        var testCase = File.getContent(path).replace("\r\n", "\n");
        var parts = testCase.split("\n\n----\n\n");
        if (parts.length != (genEnums ? 3 : 2))
            throw 'Test case $path format is wrong!';
        var result = {
            hx: parts[0],
            dts: parts[1].trim(),
            ets: parts.length > 2 ? parts[2].trim() : null
        };
        return result;
    }

    static function runTestCase(hxCode:String, genEnums:Bool) {
        var cp = Os.tmpdir();
        var hxFile = '$cp/HxTsdGenTestCase.hx';
        var outFile = '$cp/HxTsdGenTestCase.js';
        var dtsFile = '$cp/HxTsdGenTestCase.d.ts';
        var etsFile = '$cp/HxTsdGenTestCase-enums.ts';
        File.saveContent(hxFile, hxCode);

        var args = [
            "-cp", cp,
            "-lib", "hxtsdgen",
            "-js", outFile,
            "-D", "hxtsdgen_skip_header",
            "HxTsdGenTestCase"
        ];
        if (genEnums) args = args.concat(["-D", "hxtsdgen_enums_ts"]);
        var code = Sys.command("haxe", args);

        var dts:String = null, ets:String = null;
        if (code == 0) {
            dts = FileSystem.exists(dtsFile) ? File.getContent(dtsFile).trim() : null;
            ets = FileSystem.exists(etsFile) ? File.getContent(etsFile).trim() : null;
        }

        try {
            FileSystem.deleteFile(hxFile);
            FileSystem.deleteFile(outFile);
            if (FileSystem.exists(dtsFile)) FileSystem.deleteFile(dtsFile);
            if (FileSystem.exists(etsFile)) FileSystem.deleteFile(etsFile);
        } catch (_:Any) {}

        return code == 0 ? { dts: dts, ets: ets } : null;
    }
}
