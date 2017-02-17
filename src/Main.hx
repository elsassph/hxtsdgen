@:expose
class Main {
    /** ctor doc **/
    public function new(name:String, level:Int) {
        trace("hi");
    }

    public static var v1:Int;
    public static var v2(default,default):Int;
    public static var v3(default,null):Int;
    public static var v4(default,never):Int;

    public var b1:Int;
    public var b2(default,default):Int;
    public var b3(default,null):Int;
    public var b4(default,never):Int;

    /**
        Some doc
    **/
    public static function doStuff(debug:Bool):String {
        return "";
    }
}
