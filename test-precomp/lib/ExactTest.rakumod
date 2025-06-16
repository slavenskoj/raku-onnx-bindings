unit module ExactTest;

use NativeCall;

constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

class OrtApiBase is repr('CStruct') is export {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) is export { * }

class SimpleAPI {
    has $.api;
    has %!funcs;
    
    has %!indices = (
        'CreateEnv' => 3,
        'CreateSessionOptions' => 10,
        'SetSessionGraphOptimizationLevel' => 23,
        'CreateSession' => 7,
    );
    
    submethod BUILD() {
        note "SimpleAPI BUILD: Getting API base..." if %*ENV<ONNX_DEBUG>;
        my $api-base = OrtGetApiBase();
        die "Failed to get OrtApiBase" unless $api-base;
        
        note "SimpleAPI BUILD: Got API base, getting API..." if %*ENV<ONNX_DEBUG>;
        my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
        $!api = get-api(ORT_API_VERSION);
        die "Failed to get OrtApi" unless $!api;
        note "SimpleAPI BUILD: Got API at ", $!api if %*ENV<ONNX_DEBUG>;
    }
}

my $API;

sub get-simple-api() is export {
    note "get-simple-api: Called" if %*ENV<ONNX_DEBUG>;
    if !$API.defined {
        note "get-simple-api: Creating new API instance..." if %*ENV<ONNX_DEBUG>;
        $API = SimpleAPI.new;
        note "get-simple-api: API instance created: ", $API.perl if %*ENV<ONNX_DEBUG>;
    } else {
        note "get-simple-api: Returning existing API instance" if %*ENV<ONNX_DEBUG>;
    }
    return $API;
}