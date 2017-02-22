package hxtsdgen;

using StringTools;

class DocRenderer {
    public static function renderDoc(doc:String, indent:String):String {
        var parts = [];
        parts.push('$indent/**');
        var lines = doc.split("\n");
        for (line in lines) {
            line = line.trim();
            if (line.length > 0) { // TODO: don't skip empty lines betwen non-empty ones
                if (line.charCodeAt(0) != "*".code)
                    line = '* $line';
                parts.push('$indent $line');
            }
        }
        parts.push('$indent */');
        return parts.join("\n");
    }
}
