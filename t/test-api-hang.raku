#!/usr/bin/env raku

say "1. Starting test...";

use lib 'lib';
say "2. lib added to path";

use NativeCall;
say "3. NativeCall loaded";

use ONNX::Runtime::Types;
say "4. Types loaded";

# Try loading API module step by step
say "5. About to load API module...";

# First check if we can load the library directly
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

say "6. Can load library directly";

my $api-base = OrtGetApiBase();
say "7. Got API base: ", $api-base;

say "8. Now trying to load API module...";
use ONNX::Runtime::API;
say "9. API module loaded!";

say "Done!";