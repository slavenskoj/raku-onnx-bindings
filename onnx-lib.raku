#!/usr/bin/env raku
# ONNX Runtime Library - Include this file to use ONNX Runtime
# Usage: EVALFILE 'onnx-lib.raku';

use NativeCall;

# Constants
our constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
our constant ORT_API_VERSION = 16;

# Logging levels
our enum LogLevel (
    LOG_VERBOSE => 0,
    LOG_INFO => 1,
    LOG_WARNING => 2,
    LOG_ERROR => 3,
    LOG_FATAL => 4,
);

# Other constants
our constant ORT_ENABLE_ALL = 99;
our constant OrtArenaAllocator = 0;
our constant OrtMemTypeDefault = 0;
our constant ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT = 1;

# Core types
class OrtEnv is repr('CPointer') is export { }
class OrtSession is repr('CPointer') is export { }
class OrtSessionOptions is repr('CPointer') is export { }
class OrtValue is repr('CPointer') is export { }
class OrtMemoryInfo is repr('CPointer') is export { }
class OrtAllocator is repr('CPointer') is export { }
class OrtStatus is repr('CPointer') is export { }
class OrtTypeInfo is repr('CPointer') is export { }
class OrtTensorTypeAndShapeInfo is repr('CPointer') is export { }
class OrtRunOptions is repr('CPointer') is export { }

# API Base structure
class OrtApiBase is repr('CStruct') is export {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

# Native function
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) is export { * }

# Global state
our $ONNX-API;
our %ONNX-FUNCS;

# Function indices
our %FUNCTION-INDICES = (
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
    'SessionGetInputTypeInfo' => 38,
    'SessionGetOutputTypeInfo' => 39,
    'CastTypeInfoToTensorInfo' => 50,
    'GetDimensionsCount' => 56,
    'GetDimensions' => 57,
    'GetTensorElementType' => 55,
    'CreateTensorWithDataAsOrtValue' => 44,
    'GetTensorMutableData' => 46,
    'Run' => 9,
);

# Initialize ONNX Runtime
sub init-onnx() is export {
    return if $ONNX-API.defined;
    
    say "Initializing ONNX Runtime API...";
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    $ONNX-API = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $ONNX-API;
    
    # Load all function pointers
    for %FUNCTION-INDICES.kv -> $name, $idx {
        my $func-ptr = nativecast(CArray[Pointer], $ONNX-API)[$idx];
        die "Failed to get function pointer for $name at index $idx" unless $func-ptr;
        %ONNX-FUNCS{$name} = $func-ptr;
    }
    
    say "ONNX Runtime API initialized successfully!";
}

# Session class
class ONNXSession is export {
    has $.env;
    has $.session;
    has $.options;
    has $.memory-info;
    has $.allocator;
    has @.input-names;
    has @.output-names;
    has %.input-info;
    has %.output-info;
    has Str $.model-path;
}

# Create a new ONNX session
sub create-onnx-session(Str $model-path, :$log-level = LOG_WARNING) is export {
    init-onnx() unless $ONNX-API.defined;
    
    # Create environment
    my &create-env = nativecast(
        :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
        %ONNX-FUNCS<CreateEnv>
    );
    
    my $env-ptr = Pointer[OrtEnv].new;
    my $status = create-env($log-level, "RakuONNX", $env-ptr);
    die "Failed to create environment" if $status;
    my $env = $env-ptr.deref;
    
    # Create session options
    my &create-opts = nativecast(
        :(Pointer[OrtSessionOptions] --> OrtStatus),
        %ONNX-FUNCS<CreateSessionOptions>
    );
    
    my $opts-ptr = Pointer[OrtSessionOptions].new;
    $status = create-opts($opts-ptr);
    die "Failed to create session options" if $status;
    my $options = $opts-ptr.deref;
    
    # Set optimization level
    my &set-opt-level = nativecast(
        :(OrtSessionOptions, int32 --> OrtStatus),
        %ONNX-FUNCS<SetSessionGraphOptimizationLevel>
    );
    
    $status = set-opt-level($options, ORT_ENABLE_ALL);
    die "Failed to set optimization level" if $status;
    
    # Create session
    my &create-session-func = nativecast(
        :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
        %ONNX-FUNCS<CreateSession>
    );
    
    my $sess-ptr = Pointer[OrtSession].new;
    $status = create-session-func($env, $model-path, $options, $sess-ptr);
    die "Failed to create session for $model-path" if $status;
    my $session = $sess-ptr.deref;
    
    # Create memory info
    my &create-mem-info = nativecast(
        :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
        %ONNX-FUNCS<CreateCpuMemoryInfo>
    );
    
    my $mem-ptr = Pointer[OrtMemoryInfo].new;
    $status = create-mem-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
    die "Failed to create memory info" if $status;
    my $memory-info = $mem-ptr.deref;
    
    # Get allocator
    my &get-allocator = nativecast(
        :(Pointer[OrtAllocator] --> OrtStatus),
        %ONNX-FUNCS<GetAllocatorWithDefaultOptions>
    );
    
    my $alloc-ptr = Pointer[OrtAllocator].new;
    $status = get-allocator($alloc-ptr);
    die "Failed to get allocator" if $status;
    my $allocator = $alloc-ptr.deref;
    
    # Query model info
    my (@input-names, @output-names, %input-info, %output-info);
    
    # Get counts
    my &get-input-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        %ONNX-FUNCS<SessionGetInputCount>
    );
    
    my &get-output-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        %ONNX-FUNCS<SessionGetOutputCount>
    );
    
    my $in-count-ptr = Pointer[size_t].new;
    $status = get-input-count($session, $in-count-ptr);
    die "Failed to get input count" if $status;
    my $in-count = $in-count-ptr.deref;
    
    my $out-count-ptr = Pointer[size_t].new;
    $status = get-output-count($session, $out-count-ptr);
    die "Failed to get output count" if $status;
    my $out-count = $out-count-ptr.deref;
    
    # Get input info
    my &get-input-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        %ONNX-FUNCS<SessionGetInputName>
    );
    
    for ^$in-count -> $i {
        my $name-ptr = Pointer[Str].new;
        $status = get-input-name($session, $i, $allocator, $name-ptr);
        die "Failed to get input name $i" if $status;
        my $name = $name-ptr.deref;
        @input-names.push($name);
        
        # Store basic info
        %input-info{$name} = {
            index => $i,
            shape => [784],  # Hardcoded for MNIST for now
            type => ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
        };
    }
    
    # Get output info
    my &get-output-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        %ONNX-FUNCS<SessionGetOutputName>
    );
    
    for ^$out-count -> $i {
        my $name-ptr = Pointer[Str].new;
        $status = get-output-name($session, $i, $allocator, $name-ptr);
        die "Failed to get output name $i" if $status;
        my $name = $name-ptr.deref;
        @output-names.push($name);
        
        # Store basic info
        %output-info{$name} = {
            index => $i,
            shape => [1, 10],  # Hardcoded for MNIST for now
            type => ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
        };
    }
    
    # Return session object
    return ONNXSession.new(
        :$env,
        :$session,
        :$options,
        :$memory-info,
        :$allocator,
        :@input-names,
        :@output-names,
        :%input-info,
        :%output-info,
        :$model-path,
    );
}

# Run inference
sub run-onnx-session(ONNXSession $sess, %inputs) is export {
    # Create input tensors
    my @input-values;
    my $input-names = CArray[Str].new;
    my $input-tensors = CArray[OrtValue].new;
    
    for $sess.input-names.kv -> $idx, $name {
        $input-names[$idx] = $name;
        
        if %inputs{$name}:exists {
            my @data = %inputs{$name}.flat;
            my $info = $sess.input-info{$name};
            
            # Create tensor for float data
            my $c-array = CArray[num32].new;
            for @data.kv -> $i, $v {
                $c-array[$i] = $v.Num;
            }
            
            # Shape array
            my $shape-array = CArray[int64].new;
            $shape-array[0] = $info<shape>[0];
            
            # Create tensor
            my &create-tensor = nativecast(
                :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] --> OrtStatus),
                %ONNX-FUNCS<CreateTensorWithDataAsOrtValue>
            );
            
            my $tensor-ptr = Pointer[OrtValue].new;
            my $status = create-tensor(
                $sess.memory-info,
                nativecast(Pointer, $c-array),
                @data.elems * nativesizeof(num32),
                $shape-array,
                1,
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                $tensor-ptr
            );
            die "Failed to create tensor" if $status;
            
            $input-tensors[$idx] = $tensor-ptr.deref;
        } else {
            die "Missing required input: $name";
        }
    }
    
    # Prepare outputs
    my $output-names = CArray[Str].new;
    my $output-tensors = CArray[OrtValue].new;
    
    for $sess.output-names.kv -> $idx, $name {
        $output-names[$idx] = $name;
        $output-tensors[$idx] = OrtValue;
    }
    
    # Run inference
    my &run = nativecast(
        :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] --> OrtStatus),
        %ONNX-FUNCS<Run>
    );
    
    my $status = run(
        $sess.session,
        OrtRunOptions,  # NULL
        $input-names,
        $input-tensors,
        $sess.input-names.elems,
        $output-names,
        $sess.output-names.elems,
        $output-tensors
    );
    die "Failed to run inference" if $status;
    
    # Extract outputs
    my %outputs;
    for $sess.output-names.kv -> $idx, $name {
        my $tensor = $output-tensors[$idx];
        
        # Get tensor data
        my &get-tensor-data = nativecast(
            :(OrtValue, Pointer[Pointer] --> OrtStatus),
            %ONNX-FUNCS<GetTensorMutableData>
        );
        
        my $data-ptr-ptr = Pointer[Pointer].new;
        $status = get-tensor-data($tensor, $data-ptr-ptr);
        die "Failed to get tensor data" if $status;
        
        my $data-ptr = $data-ptr-ptr.deref;
        my $c-array = nativecast(CArray[num32], $data-ptr);
        
        # Extract data (hardcoded for MNIST output shape [1, 10])
        my @output-data;
        my @row;
        for ^10 -> $i {
            @row.push($c-array[$i]);
        }
        @output-data.push(@row);
        
        %outputs{$name} = @output-data;
    }
    
    return %outputs;
}

# Export a simple test function
sub test-onnx-lib() is export {
    say "ONNX library loaded successfully!";
}

# Call test function to verify loading
test-onnx-lib();