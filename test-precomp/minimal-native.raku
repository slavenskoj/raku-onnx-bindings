#!/usr/bin/env raku

# Minimal test case for NativeCall precompilation

use NativeCall;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class TestStruct is repr('CStruct') {
    has Pointer $.ptr;
}

sub test-func() returns TestStruct is native(TEST_LIB) is symbol('OrtGetApiBase') { * }

say "1. Before calling native function";
my $result = test-func();
say "2. After calling native function";
say "3. Result: ", $result.perl;
say "Done!";