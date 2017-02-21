@:expose
class C<A,B> {
    public function f<T>(v:A):B return null;
}

/**
hi
**/
@:expose("ns.some")
class Some {
    /**hi**/
    public function new() {}

    public static function f() {}
}



@:expose
/**
    this is a class
**/
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
        Do cool stuff
    **/
    public function some(a:Int, b:Main):String {
        return "";
    }

    /**
        Some doc
    **/
    public static function doStuff(debug:Bool):String {
        return "";
    }

    /**hi**/
    @:expose("a.b.c")
    static function f() return 1;

    /**bye**/
    @:expose
    static function g() return 1;

    /**bye**/
    @:expose("some")
    static function h() return 1;

    static var i = 5;
}
