import Sys.println;
import js.node.Os;
import sys.FileSystem;
import sys.io.File;
using StringTools;

class Main {
    static function main() {
        var programDir = haxe.io.Path.directory(Sys.programPath());
        var total = 0, failed = 0;

        function processFile(file) {
            total++;
            println('Running test case `$file`...');
            var testCase = readTestCase('$programDir/cases/$file');
            var tsOut = runTestCase(testCase.hx);
            if (tsOut == null) {
                println("Haxe compilation failed!");
                failed++;
            } else if (testCase.ts != tsOut) {
                println("Output is different!");
                println('Expected:\n${testCase.ts}');
                println('\n---\nActual:\n${tsOut}');
                failed++;
            }
        }

        var fileName = Sys.args()[0];
        if (fileName != null) {
            processFile(fileName);
        } else {
            for (file in FileSystem.readDirectory('$programDir/cases'))
                processFile(file);
        }

        println('Result: $total. Failed: $failed.');
        Sys.exit(if (failed > 0) 1 else 0);
    }

    static function readTestCase(path) {
        var testCase = File.getContent(path).replace("\r\n", "\n");
        var parts = testCase.split("\n\n----\n\n");
        if (parts.length != 2)
            throw 'Test case $path format is wrong!';
        return {hx: parts[0], ts: parts[1].trim()};
    }

    static function runTestCase(hxCode) {
        var cp = Os.tmpdir();
        var hxFile = '$cp/HxTsdGenTestCase.hx';
        var outFile = '$cp/HxTsdGenTestCase.js';
        var tsdFile = '$cp/HxTsdGenTestCase.d.ts';
        File.saveContent(hxFile, hxCode);

        var code = Sys.command("haxe", [
            "-cp", cp,
            "-lib", "hxtsdgen",
            "-js", outFile,
            "-D", "hxtsdgen-skip-header",
            "HxTsdGenTestCase"
        ]);

        var tsd = if (code == 0) File.getContent(tsdFile).trim() else null;

        try {
            FileSystem.deleteFile(hxFile);
            FileSystem.deleteFile(outFile);
            FileSystem.deleteFile(tsdFile);
        } catch (_:Any) {}

        return tsd;
    }
}
