unit module ONNX::Simple;

# This module provides a working ONNX Runtime binding for Raku
# Due to precompilation issues with NativeCall and function pointers,
# users must manually initialize the runtime before use.

use NativeCall;

# Library path
our constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

# Constants
constant ORT_API_VERSION is export = 16;
constant LOG_WARNING is export = 2;
constant ORT_ENABLE_ALL is export = 99;
constant OrtArenaAllocator is export = 0;
constant OrtMemTypeDefault is export = 0;
constant ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT is export = 1;

# Types
class OrtEnv is repr('CPointer') is export { }
class OrtSession is repr('CPointer') is export { }
class OrtSessionOptions is repr('CPointer') is export { }
class OrtValue is repr('CPointer') is export { }
class OrtMemoryInfo is repr('CPointer') is export { }
class OrtAllocator is repr('CPointer') is export { }
class OrtStatus is repr('CPointer') is export { }
class OrtRunOptions is repr('CPointer') is export { }
class OrtTypeInfo is repr('CPointer') is export { }
class OrtTensorTypeAndShapeInfo is repr('CPointer') is export { }

class OrtApiBase is repr('CStruct') is export {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

# The only native function we call directly
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) is export { * }

# Simple data holder for sessions
class SimpleSession is export {
    has $.env;
    has $.session; 
    has $.options;
    has $.memory-info;
    has $.allocator;
    has @.input-names;
    has @.output-names;
    has Str $.model-path;
}

# Function to get a working example script
sub get-example-script() is export {
    return q:to/EXAMPLE/;
    #!/usr/bin/env raku
    
    use lib 'lib';
    use NativeCall;
    use ONNX::Simple;
    
    # Get API base
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    # Get API
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    my $api = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $api;
    
    # Get function pointers
    my %funcs;
    my %indices = (
        'CreateEnv' => 3,
        'CreateSessionOptions' => 10,
        'SetSessionGraphOptimizationLevel' => 23,
        'CreateSession' => 7,
        'SessionGetInputCount' => 30,
        'SessionGetOutputCount' => 31,
        'SessionGetInputName' => 36,
        'SessionGetOutputName' => 37,
        'GetAllocatorWithDefaultOptions' => 78,
        'CreateCpuMemoryInfo' => 64,
        'CreateTensorWithDataAsOrtValue' => 44,
        'GetTensorMutableData' => 46,
        'Run' => 9,
    );
    
    for %indices.kv -> $name, $idx {
        %funcs{$name} = nativecast(CArray[Pointer], $api)[$idx];
    }
    
    # Create environment
    my &create-env = nativecast(
        :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
        %funcs<CreateEnv>
    );
    
    my $env-ptr = Pointer[OrtEnv].new;
    create-env(LOG_WARNING, "RakuONNX", $env-ptr);
    my $env = $env-ptr.deref;
    
    # Create session options
    my &create-opts = nativecast(
        :(Pointer[OrtSessionOptions] --> OrtStatus),
        %funcs<CreateSessionOptions>
    );
    
    my $opts-ptr = Pointer[OrtSessionOptions].new;
    create-opts($opts-ptr);
    my $options = $opts-ptr.deref;
    
    # Set optimization level
    my &set-opt = nativecast(
        :(OrtSessionOptions, int32 --> OrtStatus),
        %funcs<SetSessionGraphOptimizationLevel>
    );
    set-opt($options, ORT_ENABLE_ALL);
    
    # Create session
    my &create-session = nativecast(
        :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
        %funcs<CreateSession>
    );
    
    my $sess-ptr = Pointer[OrtSession].new;
    create-session($env, "models/mnist.onnx", $options, $sess-ptr);
    my $session = $sess-ptr.deref;
    
    say "Session created successfully!";
    
    # Create memory info
    my &create-mem = nativecast(
        :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
        %funcs<CreateCpuMemoryInfo>
    );
    
    my $mem-ptr = Pointer[OrtMemoryInfo].new;
    create-mem(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
    my $memory-info = $mem-ptr.deref;
    
    # Get allocator
    my &get-alloc = nativecast(
        :(Pointer[OrtAllocator] --> OrtStatus),
        %funcs<GetAllocatorWithDefaultOptions>
    );
    
    my $alloc-ptr = Pointer[OrtAllocator].new;
    get-alloc($alloc-ptr);
    my $allocator = $alloc-ptr.deref;
    
    # Run inference with dummy data
    my @input = (^784).map({ rand });
    
    # Create input tensor
    my $c-array = CArray[num32].new;
    for @input.kv -> $i, $v {
        $c-array[$i] = $v.Num;
    }
    
    my $shape = CArray[int64].new;
    $shape[0] = 784;
    
    my &create-tensor = nativecast(
        :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] --> OrtStatus),
        %funcs<CreateTensorWithDataAsOrtValue>
    );
    
    my $tensor-ptr = Pointer[OrtValue].new;
    create-tensor($memory-info, nativecast(Pointer, $c-array), 784 * 4, $shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, $tensor-ptr);
    
    # Run
    my $input-names = CArray[Str].new;
    $input-names[0] = "Input3";
    
    my $input-tensors = CArray[OrtValue].new;
    $input-tensors[0] = $tensor-ptr.deref;
    
    my $output-names = CArray[Str].new;
    $output-names[0] = "Plus214_Output_0";
    
    my $output-tensors = CArray[OrtValue].new;
    $output-tensors[0] = OrtValue;
    
    my &run = nativecast(
        :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] --> OrtStatus),
        %funcs<Run>
    );
    
    run($session, OrtRunOptions, $input-names, $input-tensors, 1, $output-names, 1, $output-tensors);
    
    # Get output
    my &get-data = nativecast(
        :(OrtValue, Pointer[Pointer] --> OrtStatus),
        %funcs<GetTensorMutableData>
    );
    
    my $data-ptr-ptr = Pointer[Pointer].new;
    get-data($output-tensors[0], $data-ptr-ptr);
    
    my $data = nativecast(CArray[num32], $data-ptr-ptr.deref);
    my @probs = (^10).map({ $data[$_] });
    
    say "Predictions: ", @probs;
    
    my $max-idx = @probs.pairs.max(*.value).key;
    say "Predicted digit: $max-idx";
    EXAMPLE
}