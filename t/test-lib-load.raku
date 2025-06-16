#!/usr/bin/env raku

use NativeCall;

say "Testing library loading...";

# Try direct path
my $lib-path = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

say "Library path: $lib-path";
say "File exists: ", $lib-path.IO.e;

# Simple struct
class TestStruct is repr('CStruct') {
    has Pointer $.ptr1;
    has Pointer $.ptr2;
}

# Try to define and call a function with constant
constant TEST_LIB = $lib-path;
sub test-get-base() returns TestStruct is native(TEST_LIB) is symbol('OrtGetApiBase') { * }

say "\nTrying to call OrtGetApiBase...";
my $result = test-get-base();
say "Result: ", $result;

if $result {
    say "ptr1: ", $result.ptr1;
    say "ptr2: ", $result.ptr2;
}

say "\nDone!";