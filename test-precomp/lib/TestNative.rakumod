unit module TestNative;

use NativeCall;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class TestStruct is repr('CStruct') is export {
    has Pointer $.ptr;
}

sub test-func() returns TestStruct is native(TEST_LIB) is symbol('OrtGetApiBase') is export { * }

sub get-test-result() is export {
    say "In module: Before calling native function";
    my $result = test-func();
    say "In module: After calling native function";
    return $result;
}