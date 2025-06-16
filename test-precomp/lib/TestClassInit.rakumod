unit module TestClassInit;

use NativeCall;

constant TEST_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
}

sub OrtGetApiBase() returns OrtApiBase is native(TEST_LIB) { * }

# Test 1: Class with native call in method (should work)
class WorkingClass is export {
    has $.api;
    
    method get-api() {
        say "WorkingClass: Getting API...";
        my $api-base = OrtGetApiBase();
        $!api = $api-base.GetApi;
        say "WorkingClass: Got API";
        return $!api;
    }
}

# Test 2: Class with native call in BUILD (might hang)
class ProblemClass is export {
    has $.api;
    
    submethod BUILD() {
        say "ProblemClass BUILD: Getting API...";
        my $api-base = OrtGetApiBase();
        $!api = $api-base.GetApi;
        say "ProblemClass BUILD: Got API";
    }
}

# Test 3: Class with lazy initialization
class LazyClass is export {
    has $.api;
    has Bool $!initialized = False;
    
    method api() {
        unless $!initialized {
            say "LazyClass: First access, getting API...";
            my $api-base = OrtGetApiBase();
            $!api = $api-base.GetApi;
            $!initialized = True;
            say "LazyClass: Got API";
        }
        return $!api;
    }
}