#!/usr/bin/env raku

use NativeCall;

constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

# Type definitions
class OrtStatus is repr('CPointer') { }
class OrtEnv is repr('CPointer') { }

# OrtApiBase
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

say "Testing CreateEnv directly...";

# Get API base
my $api-base = OrtGetApiBase();
say "✓ Got API base";

# Get API struct
my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
my $api-ptr = get-api(ORT_API_VERSION);
say "✓ Got API struct at ", $api-ptr;

# Get CreateEnv function (offset 3)
my $create-env-offset = 3 * nativesizeof(Pointer);
my $create-env-ptr-ptr = Pointer.new($api-ptr.Int + $create-env-offset);
my $create-env-ptr = nativecast(CArray[Pointer], $create-env-ptr-ptr)[0];
say "✓ Got CreateEnv function at ", $create-env-ptr;

# Call CreateEnv
my &create-env = nativecast(
    :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
    $create-env-ptr
);

my $env-ptr = Pointer[OrtEnv].new;
say "\nCalling CreateEnv...";
my $status = create-env(2, "TestEnv", $env-ptr); # 2 = ORT_LOGGING_LEVEL_WARNING

if $status {
    say "✗ CreateEnv returned error status: ", $status;
    
    # Try to get error message
    my $get-error-msg-offset = 2 * nativesizeof(Pointer);
    my $get-error-msg-ptr-ptr = Pointer.new($api-ptr.Int + $get-error-msg-offset);
    my $get-error-msg-ptr = nativecast(CArray[Pointer], $get-error-msg-ptr-ptr)[0];
    
    my &get-error-msg = nativecast(:(OrtStatus --> Str), $get-error-msg-ptr);
    my $msg = get-error-msg($status);
    say "  Error message: ", $msg;
} else {
    say "✓ CreateEnv succeeded!";
    my $env = $env-ptr.deref;
    say "  Environment created: ", $env;
}