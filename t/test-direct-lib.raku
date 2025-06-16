#!/usr/bin/env raku

use NativeCall;

say "Testing direct library loading...";

# Use compile-time constant
constant LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

say "Library: ", LIB;

# Simple function test
sub get-ptr() returns Pointer is native(LIB) is symbol('OrtGetApiBase') { * }

say "\nCalling OrtGetApiBase...";
my $ptr = get-ptr();
say "Got pointer: ", $ptr;

say "\nDone!";