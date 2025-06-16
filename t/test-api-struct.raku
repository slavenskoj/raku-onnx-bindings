#!/usr/bin/env raku

use NativeCall;

constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

say "Testing ONNX Runtime API structure...";

my $api-base = OrtGetApiBase();
say "API Base: ", $api-base;
say "GetApi: ", $api-base.GetApi;
say "GetVersionString: ", $api-base.GetVersionString;

# Get version
if $api-base.GetVersionString {
    my &get-version = nativecast(:(-->Str), $api-base.GetVersionString);
    my $version = get-version();
    say "Version: ", $version;
}

# Get API struct
if $api-base.GetApi {
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    my $api-ptr = get-api(16); # ORT_API_VERSION = 16
    say "API pointer: ", $api-ptr;
    
    if $api-ptr {
        say "✓ Got API struct pointer";
        
        # Try to read first few function pointers
        say "\nFirst few function pointers:";
        for ^10 -> $i {
            my $offset = $i * nativesizeof(Pointer);
            my $ptr = Pointer.new($api-ptr.Int + $offset);
            my $func-ptr = nativecast(CArray[Pointer], $ptr)[0];
            say "  Function[$i]: ", $func-ptr;
        }
    }
}