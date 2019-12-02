# 0.3.0

- Control generated code header with `-D hxtsdgen_skip_header` or macro to override
- Support and include `extend/implements` types
- Don't throw on unrecognised classes
- Warn when class is referenced but not exposed
- Make contructors `protected` instead of `private` to support Haxe's access rules
- Added option to export `typedef/interface` separately `-D hxtsdgen_types_ts`
- Haxe packages are now flattened, unless `-D hxtsdgen_namespaced`

# 0.2.0

- Fixed support of `@:native` meta and extern classes

# 0.1.2

- Initial haxelib release
