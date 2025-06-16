unit module TestClass;

use NativeCall;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class TestStruct is repr('CStruct') {
    has Pointer $.ptr;
}

sub test-func() returns TestStruct is native(TEST_LIB) is symbol('OrtGetApiBase') { * }

class API is export {
    has $.data;
    
    method new() {
        say "API.new: Called";
        self.bless();
    }
    
    submethod BUILD() {
        say "API.BUILD: Before calling native function";
        my $result = test-func();
        say "API.BUILD: After calling native function";
        $!data = $result;
    }
    
    method get-data() {
        return $!data;
    }
}