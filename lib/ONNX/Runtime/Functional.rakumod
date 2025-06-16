unit module ONNX::Runtime::Functional;

use NativeCall;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

# Types
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

# State storage
my $API;
my %FUNCS;

# Initialize API on first use
sub get-api() is export {
    return $API if $API;
    
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    $API = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $API;
    
    return $API;
}

# Get function by index
sub get-func(Str $name, Int $idx) is export {
    return %FUNCS{$name} if %FUNCS{$name}:exists;
    
    my $api = get-api();
    my $func-ptr = nativecast(CArray[Pointer], $api)[$idx];
    die "Failed to get function pointer for $name at index $idx" unless $func-ptr;
    
    %FUNCS{$name} = $func-ptr;
    return $func-ptr;
}

# Test function
sub test-create-env() is export {
    say "Getting CreateEnv function...";
    my $func = get-func('CreateEnv', 3);
    say "Got function at ", $func;
    return True;
}