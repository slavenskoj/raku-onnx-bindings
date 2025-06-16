#!/usr/bin/env raku

# ONNX Runtime Server
# This script acts as a server that can be called by the wrapper module
# It accepts JSON commands via STDIN and returns JSON responses via STDOUT

use NativeCall;
use JSON::Fast;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;
constant LOG_WARNING = 2;
constant ORT_ENABLE_ALL = 99;
constant OrtArenaAllocator = 0;
constant OrtMemTypeDefault = 0;
constant ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT = 1;

# Types
class OrtEnv is repr('CPointer') { }
class OrtSession is repr('CPointer') { }
class OrtSessionOptions is repr('CPointer') { }
class OrtValue is repr('CPointer') { }
class OrtMemoryInfo is repr('CPointer') { }
class OrtAllocator is repr('CPointer') { }
class OrtStatus is repr('CPointer') { }
class OrtTypeInfo is repr('CPointer') { }
class OrtTensorTypeAndShapeInfo is repr('CPointer') { }
class OrtRunOptions is repr('CPointer') { }

class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

# Global state
my %sessions;
my $session-counter = 0;
my $api;
my %funcs;

# Initialize ONNX Runtime
sub init-runtime() {
    return if $api.defined;
    
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    $api = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $api;
    
    # Function indices
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
    
    for %indices.kv -> $name, $idx {
        %funcs{$name} = nativecast(CArray[Pointer], $api)[$idx];
    }
}

# Create a new session
sub create-session($model-path) {
    init-runtime();
    
    # Create environment
    my &create-env = nativecast(
        :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
        %funcs<CreateEnv>
    );
    
    my $env-ptr = Pointer[OrtEnv].new;
    my $status = create-env(LOG_WARNING, "RakuONNX", $env-ptr);
    return { error => "Failed to create environment" } if $status;
    my $env = $env-ptr.deref;
    
    # Create session options
    my &create-opts = nativecast(
        :(Pointer[OrtSessionOptions] --> OrtStatus),
        %funcs<CreateSessionOptions>
    );
    
    my $opts-ptr = Pointer[OrtSessionOptions].new;
    $status = create-opts($opts-ptr);
    return { error => "Failed to create session options" } if $status;
    my $options = $opts-ptr.deref;
    
    # Set optimization level
    my &set-opt = nativecast(
        :(OrtSessionOptions, int32 --> OrtStatus),
        %funcs<SetSessionGraphOptimizationLevel>
    );
    $status = set-opt($options, ORT_ENABLE_ALL);
    
    # Create session
    my &create-session-func = nativecast(
        :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
        %funcs<CreateSession>
    );
    
    my $sess-ptr = Pointer[OrtSession].new;
    $status = create-session-func($env, $model-path, $options, $sess-ptr);
    return { error => "Failed to create session for $model-path" } if $status;
    my $session = $sess-ptr.deref;
    
    # Create memory info
    my &create-mem = nativecast(
        :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
        %funcs<CreateCpuMemoryInfo>
    );
    
    my $mem-ptr = Pointer[OrtMemoryInfo].new;
    $status = create-mem(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
    return { error => "Failed to create memory info" } if $status;
    my $memory-info = $mem-ptr.deref;
    
    # Get allocator
    my &get-alloc = nativecast(
        :(Pointer[OrtAllocator] --> OrtStatus),
        %funcs<GetAllocatorWithDefaultOptions>
    );
    
    my $alloc-ptr = Pointer[OrtAllocator].new;
    $status = get-alloc($alloc-ptr);
    return { error => "Failed to get allocator" } if $status;
    my $allocator = $alloc-ptr.deref;
    
    # Get session info
    my &get-input-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        %funcs<SessionGetInputCount>
    );
    
    my &get-output-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        %funcs<SessionGetOutputCount>
    );
    
    my &get-input-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        %funcs<SessionGetInputName>
    );
    
    my &get-output-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        %funcs<SessionGetOutputName>
    );
    
    # Get counts
    my $in-count-ptr = Pointer[size_t].new;
    $status = get-input-count($session, $in-count-ptr);
    my $in-count = $in-count-ptr.deref;
    
    my $out-count-ptr = Pointer[size_t].new;
    $status = get-output-count($session, $out-count-ptr);
    my $out-count = $out-count-ptr.deref;
    
    # Get names
    my @input-names;
    for ^$in-count -> $i {
        my $name-ptr = Pointer[Str].new;
        $status = get-input-name($session, $i, $allocator, $name-ptr);
        @input-names.push($name-ptr.deref);
    }
    
    my @output-names;
    for ^$out-count -> $i {
        my $name-ptr = Pointer[Str].new;
        $status = get-output-name($session, $i, $allocator, $name-ptr);
        @output-names.push($name-ptr.deref);
    }
    
    # Store session
    my $session-id = "session-{++$session-counter}";
    %sessions{$session-id} = {
        env => $env,
        session => $session,
        options => $options,
        memory-info => $memory-info,
        allocator => $allocator,
        input-names => @input-names,
        output-names => @output-names,
    };
    
    return {
        session-id => $session-id,
        input-names => @input-names,
        output-names => @output-names,
    };
}

# Run inference
sub run-inference($session-id, %inputs) {
    return { error => "Unknown session: $session-id" } unless %sessions{$session-id}:exists;
    
    my $sess = %sessions{$session-id};
    
    # Create input tensors
    my $input-names = CArray[Str].new;
    my $input-tensors = CArray[OrtValue].new;
    
    for $sess<input-names>.kv -> $idx, $name {
        $input-names[$idx] = $name;
        
        if %inputs{$name}:exists {
            my @data = %inputs{$name}<data>.flat;
            my @shape = %inputs{$name}<shape> // [784];  # Default for MNIST
            
            # Create tensor
            my $c-array = CArray[num32].new;
            for @data.kv -> $i, $v {
                $c-array[$i] = $v.Num;
            }
            
            my $shape-array = CArray[int64].new;
            for @shape.kv -> $i, $v {
                $shape-array[$i] = $v;
            }
            
            my &create-tensor = nativecast(
                :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] --> OrtStatus),
                %funcs<CreateTensorWithDataAsOrtValue>
            );
            
            my $tensor-ptr = Pointer[OrtValue].new;
            my $status = create-tensor(
                $sess<memory-info>,
                nativecast(Pointer, $c-array),
                @data.elems * nativesizeof(num32),
                $shape-array,
                @shape.elems,
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                $tensor-ptr
            );
            return { error => "Failed to create tensor for $name" } if $status;
            
            $input-tensors[$idx] = $tensor-ptr.deref;
        } else {
            return { error => "Missing input: $name" };
        }
    }
    
    # Prepare outputs
    my $output-names = CArray[Str].new;
    my $output-tensors = CArray[OrtValue].new;
    
    for $sess<output-names>.kv -> $idx, $name {
        $output-names[$idx] = $name;
        $output-tensors[$idx] = OrtValue;
    }
    
    # Run
    my &run = nativecast(
        :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] --> OrtStatus),
        %funcs<Run>
    );
    
    my $status = run(
        $sess<session>,
        OrtRunOptions,
        $input-names,
        $input-tensors,
        $sess<input-names>.elems,
        $output-names,
        $sess<output-names>.elems,
        $output-tensors
    );
    return { error => "Failed to run inference" } if $status;
    
    # Extract outputs
    my %outputs;
    for $sess<output-names>.kv -> $idx, $name {
        my $tensor = $output-tensors[$idx];
        
        # Get data
        my &get-data = nativecast(
            :(OrtValue, Pointer[Pointer] --> OrtStatus),
            %funcs<GetTensorMutableData>
        );
        
        my $data-ptr-ptr = Pointer[Pointer].new;
        $status = get-data($tensor, $data-ptr-ptr);
        return { error => "Failed to get tensor data" } if $status;
        
        my $data-ptr = $data-ptr-ptr.deref;
        my $c-array = nativecast(CArray[num32], $data-ptr);
        
        # For MNIST, output is [1, 10]
        my @data = (^10).map({ $c-array[$_] });
        %outputs{$name} = @data;
    }
    
    return { outputs => %outputs };
}

# Main server loop
sub MAIN() {
    # Read JSON commands from STDIN and write JSON responses to STDOUT
    for $*IN.lines -> $line {
        my %request;
        try {
            %request = from-json($line);
            CATCH {
                default {
                    say to-json({ error => "Invalid JSON: $_" });
                    next;
                }
            }
        }
        
        my %response;
        given %request<command> {
            when 'create-session' {
                %response = create-session(%request<model-path>);
            }
            when 'run-inference' {
                %response = run-inference(%request<session-id>, %request<inputs>);
            }
            when 'close-session' {
                if %sessions{%request<session-id>}:exists {
                    %sessions{%request<session-id>}:delete;
                    %response = { success => True };
                } else {
                    %response = { error => "Unknown session: {%request<session-id>}" };
                }
            }
            when 'ping' {
                %response = { pong => True };
            }
            default {
                %response = { error => "Unknown command: {%request<command>}" };
            }
        }
        
        say to-json(%response);
        $*OUT.flush;
    }
}