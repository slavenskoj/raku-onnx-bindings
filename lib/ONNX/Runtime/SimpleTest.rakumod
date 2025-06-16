unit module ONNX::Runtime::SimpleTest;

use NativeCall;
use ONNX::Runtime::Types;
use ONNX::Runtime::API::Simple;

class SimpleRuntime is export {
    has $.api;
    has $.model-path;
    
    submethod BUILD(Str :$!model-path!) {
        note "SimpleRuntime BUILD: Starting..." if %*ENV<ONNX_DEBUG>;
        $!api = get-simple-api();
        note "SimpleRuntime BUILD: Got API" if %*ENV<ONNX_DEBUG>;
    }
}