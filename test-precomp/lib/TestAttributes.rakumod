unit module TestAttributes;

use NativeCall;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class TestStruct is repr('CStruct') {
    has Pointer $.ptr;
}

sub test-func() returns TestStruct is native(TEST_LIB) is symbol('OrtGetApiBase') { * }

class TestAPI is export {
    has $.api;
    has %.funcs;
    has %.indices = (
        'CreateEnv' => 3,
        'CreateSession' => 7,
    );
    
    method new() {
        say "TestAPI.new: Called";
        self.bless();
    }
    
    submethod BUILD() {
        say "TestAPI.BUILD: Before calling native function";
        my $result = test-func();
        say "TestAPI.BUILD: After calling native function";
        $!api = $result.ptr;
        say "TestAPI.BUILD: Done";
    }
}