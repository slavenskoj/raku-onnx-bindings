unit module TestSingleton;

use NativeCall;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class TestStruct is repr('CStruct') {
    has Pointer $.ptr;
}

sub test-func() returns TestStruct is native(TEST_LIB) is symbol('OrtGetApiBase') { * }

class API {
    has $.data;
    
    submethod BUILD() {
        say "API.BUILD: Called";
        my $result = test-func();
        $!data = $result;
    }
}

# Global instance
my $API;

sub get-api() is export {
    say "get-api: Called";
    if !$API.defined {
        say "get-api: Creating new API instance...";
        $API = API.new;
        say "get-api: API instance created";
    }
    return $API;
}