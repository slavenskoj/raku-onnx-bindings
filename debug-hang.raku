#!/usr/bin/env raku

say "1. Loading NativeCall...";
use NativeCall;
say "2. NativeCall loaded";

say "3. Loading Types...";
use lib 'lib';
use ONNX::Runtime::Types;
say "4. Types loaded";

say "5. Creating API base struct...";
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}
say "6. Struct created";

say "7. Defining native sub...";
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }
say "8. Native sub defined";

say "9. Calling OrtGetApiBase...";
my $base = OrtGetApiBase();
say "10. Got base: ", $base;

say "Done!";