#!/usr/bin/env raku

use NativeCall;

# Set library path
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

# OrtApiBase structure
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

# Test getting the API base
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

say "Testing ONNX Runtime API...";
say "Library path: ", ONNX_LIB;

# Check if library exists
if ONNX_LIB.IO.e {
    say "✓ Library file exists";
} else {
    say "✗ Library file not found!";
    exit 1;
}

# Try to get API base
my $api-base = OrtGetApiBase();
say "API Base: ", $api-base;

if $api-base {
    say "✓ Successfully got OrtApiBase";
    say "  GetApi pointer: ", $api-base.GetApi;
    say "  GetVersionString pointer: ", $api-base.GetVersionString;
    
    # Try to call GetVersionString if it's a valid pointer
    if $api-base.GetVersionString {
        # Cast to a function that returns Str
        my &get-version = nativecast(:(-->Str), $api-base.GetVersionString);
        my $version = get-version();
        say "  ONNX Runtime version: ", $version;
    }
} else {
    say "✗ Failed to get OrtApiBase";
}

say "\nConclusion: The ONNX Runtime C API requires using function pointers obtained through OrtGetApiBase.";
say "The current Raku bindings need to be updated to use this approach instead of direct function calls.";