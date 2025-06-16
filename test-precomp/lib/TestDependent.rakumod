unit module TestDependent;

use NativeCall;
use TestTypes;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
}

sub OrtGetApiBase() returns OrtApiBase is native(TEST_LIB) { * }

class API is export {
    has $.api;
    
    submethod BUILD() {
        say "API.BUILD: Getting API base...";
        my $api-base = OrtGetApiBase();
        $!api = $api-base.GetApi;
        say "API.BUILD: Got API";
    }
    
    method create-env() {
        say "Creating environment with level ", ORT_LOGGING_LEVEL_WARNING;
        return OrtEnv;
    }
}