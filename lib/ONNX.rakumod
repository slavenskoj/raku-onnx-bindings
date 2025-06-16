unit module ONNX;

use NativeCall;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

# Logging levels
enum LogLevel is export (
    :LOG_VERBOSE(0),
    :LOG_INFO(1), 
    :LOG_WARNING(2),
    :LOG_ERROR(3),
    :LOG_FATAL(4)
);

# Other constants
constant ORT_ENABLE_ALL = 99;
constant OrtArenaAllocator = 0;
constant OrtMemTypeDefault = 0;
constant ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT = 1;

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

# Direct native function export (this works with precompilation)
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) is export { * }

# Session holder class with no initialization logic
class Session is export {
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
    has $.api;
    has %.funcs;
}

# Module state (NOT initialized during compilation)
my $MODULE-STATE = {
    initialized => False,
    api => Pointer,
    funcs => {},
};

# Function indices
my %FUNCTION-INDICES = (
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

# Initialize the module (must be called explicitly)
sub init-onnx() is export {
    return if $MODULE-STATE<initialized>;
    
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    $MODULE-STATE<api> = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $MODULE-STATE<api>;
    
    # Load all function pointers
    for %FUNCTION-INDICES.kv -> $name, $idx {
        my $func-ptr = nativecast(CArray[Pointer], $MODULE-STATE<api>)[$idx];
        die "Failed to get function pointer for $name at index $idx" unless $func-ptr;
        $MODULE-STATE<funcs>{$name} = $func-ptr;
    }
    
    $MODULE-STATE<initialized> = True;
}

# Get a function pointer
sub get-func(Str $name) {
    die "ONNX module not initialized. Call init-onnx() first!" unless $MODULE-STATE<initialized>;
    return $MODULE-STATE<funcs>{$name} // die "Unknown function: $name";
}

# Create a new session
sub create-session(Str :$model-path!, :$log-level = LOG_WARNING) is export {
    die "ONNX module not initialized. Call init-onnx() first!" unless $MODULE-STATE<initialized>;
    
    # Create environment
    my &create-env = nativecast(
        :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
        get-func('CreateEnv')
    );
    
    my $env-ptr = Pointer[OrtEnv].new;
    my $status = create-env($log-level, "RakuONNX", $env-ptr);
    die "Failed to create environment" if $status;
    my $env = $env-ptr.deref;
    
    # Create session options
    my &create-opts = nativecast(
        :(Pointer[OrtSessionOptions] --> OrtStatus),
        get-func('CreateSessionOptions')
    );
    
    my $opts-ptr = Pointer[OrtSessionOptions].new;
    $status = create-opts($opts-ptr);
    die "Failed to create session options" if $status;
    my $options = $opts-ptr.deref;
    
    # Set optimization level
    my &set-opt-level = nativecast(
        :(OrtSessionOptions, int32 --> OrtStatus),
        get-func('SetSessionGraphOptimizationLevel')
    );
    
    $status = set-opt-level($options, ORT_ENABLE_ALL);
    die "Failed to set optimization level" if $status;
    
    # Create session
    my &create-session-func = nativecast(
        :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
        get-func('CreateSession')
    );
    
    my $sess-ptr = Pointer[OrtSession].new;
    $status = create-session-func($env, $model-path, $options, $sess-ptr);
    die "Failed to create session for $model-path" if $status;
    my $session = $sess-ptr.deref;
    
    # Create memory info
    my &create-mem-info = nativecast(
        :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
        get-func('CreateCpuMemoryInfo')
    );
    
    my $mem-ptr = Pointer[OrtMemoryInfo].new;
    $status = create-mem-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
    die "Failed to create memory info" if $status;
    my $memory-info = $mem-ptr.deref;
    
    # Get allocator
    my &get-allocator = nativecast(
        :(Pointer[OrtAllocator] --> OrtStatus),
        get-func('GetAllocatorWithDefaultOptions')
    );
    
    my $alloc-ptr = Pointer[OrtAllocator].new;
    $status = get-allocator($alloc-ptr);
    die "Failed to get allocator" if $status;
    my $allocator = $alloc-ptr.deref;
    
    # Query model info
    my (@input-names, @output-names, %input-info, %output-info);
    
    # Get input count
    my &get-input-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        get-func('SessionGetInputCount')
    );
    
    my $in-count-ptr = Pointer[size_t].new;
    $status = get-input-count($session, $in-count-ptr);
    die "Failed to get input count" if $status;
    my $in-count = $in-count-ptr.deref;
    
    # Get output count
    my &get-output-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        get-func('SessionGetOutputCount')
    );
    
    my $out-count-ptr = Pointer[size_t].new;
    $status = get-output-count($session, $out-count-ptr);
    die "Failed to get output count" if $status;
    my $out-count = $out-count-ptr.deref;
    
    # Get input names and info
    my &get-input-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        get-func('SessionGetInputName')
    );
    
    my &get-input-type-info = nativecast(
        :(OrtSession, size_t, Pointer[OrtTypeInfo] --> OrtStatus),
        get-func('SessionGetInputTypeInfo')
    );
    
    my &cast-to-tensor-info = nativecast(
        :(OrtTypeInfo, Pointer[OrtTensorTypeAndShapeInfo] --> OrtStatus),
        get-func('CastTypeInfoToTensorInfo')
    );
    
    my &get-dims-count = nativecast(
        :(OrtTensorTypeAndShapeInfo, Pointer[size_t] --> OrtStatus),
        get-func('GetDimensionsCount')
    );
    
    my &get-dims = nativecast(
        :(OrtTensorTypeAndShapeInfo, CArray[int64], size_t --> OrtStatus),
        get-func('GetDimensions')
    );
    
    my &get-elem-type = nativecast(
        :(OrtTensorTypeAndShapeInfo, Pointer[int32] --> OrtStatus),
        get-func('GetTensorElementType')
    );
    
    for ^$in-count -> $i {
        # Get name
        my $name-ptr = Pointer[Str].new;
        $status = get-input-name($session, $i, $allocator, $name-ptr);
        die "Failed to get input name $i" if $status;
        my $name = $name-ptr.deref;
        @input-names.push($name);
        
        # Get type info
        my $type-info-ptr = Pointer[OrtTypeInfo].new;
        $status = get-input-type-info($session, $i, $type-info-ptr);
        die "Failed to get input type info $i" if $status;
        my $type-info = $type-info-ptr.deref;
        
        # Get tensor info
        my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
        $status = cast-to-tensor-info($type-info, $tensor-info-ptr);
        die "Failed to cast to tensor info" if $status;
        my $tensor-info = $tensor-info-ptr.deref;
        
        # Get dimensions
        my $dims-count-ptr = Pointer[size_t].new;
        $status = get-dims-count($tensor-info, $dims-count-ptr);
        die "Failed to get dimensions count" if $status;
        my $dims-count = $dims-count-ptr.deref;
        
        my $dims = CArray[int64].new;
        $dims[$dims-count - 1] = 0;  # Allocate
        $status = get-dims($tensor-info, $dims, $dims-count);
        die "Failed to get dimensions" if $status;
        
        my @shape = (^$dims-count).map({ $dims[$_] });
        
        # Get element type
        my $type-ptr = Pointer[int32].new;
        $status = get-elem-type($tensor-info, $type-ptr);
        die "Failed to get element type" if $status;
        my $elem-type = $type-ptr.deref;
        
        %input-info{$name} = {
            index => $i,
            shape => @shape,
            type => $elem-type,
        };
    }
    
    # Get output names and info
    my &get-output-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        get-func('SessionGetOutputName')
    );
    
    my &get-output-type-info = nativecast(
        :(OrtSession, size_t, Pointer[OrtTypeInfo] --> OrtStatus),
        get-func('SessionGetOutputTypeInfo')
    );
    
    for ^$out-count -> $i {
        # Get name
        my $name-ptr = Pointer[Str].new;
        $status = get-output-name($session, $i, $allocator, $name-ptr);
        die "Failed to get output name $i" if $status;
        my $name = $name-ptr.deref;
        @output-names.push($name);
        
        # Get type info
        my $type-info-ptr = Pointer[OrtTypeInfo].new;
        $status = get-output-type-info($session, $i, $type-info-ptr);
        die "Failed to get output type info $i" if $status;
        my $type-info = $type-info-ptr.deref;
        
        # Get tensor info
        my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
        $status = cast-to-tensor-info($type-info, $tensor-info-ptr);
        die "Failed to cast to tensor info" if $status;
        my $tensor-info = $tensor-info-ptr.deref;
        
        # Get dimensions
        my $dims-count-ptr = Pointer[size_t].new;
        $status = get-dims-count($tensor-info, $dims-count-ptr);
        die "Failed to get dimensions count" if $status;
        my $dims-count = $dims-count-ptr.deref;
        
        my $dims = CArray[int64].new;
        $dims[$dims-count - 1] = 0;  # Allocate
        $status = get-dims($tensor-info, $dims, $dims-count);
        die "Failed to get dimensions" if $status;
        
        my @shape = (^$dims-count).map({ $dims[$_] });
        
        # Get element type
        my $type-ptr = Pointer[int32].new;
        $status = get-elem-type($tensor-info, $type-ptr);
        die "Failed to get element type" if $status;
        my $elem-type = $type-ptr.deref;
        
        %output-info{$name} = {
            index => $i,
            shape => @shape,
            type => $elem-type,
        };
    }
    
    # Return session object
    return Session.new(
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
        api => $MODULE-STATE<api>,
        funcs => $MODULE-STATE<funcs>,
    );
}

# Helper to create tensor
sub create-tensor($memory-info, @data, @shape, $type, %funcs) {
    # Flatten data
    my @flat = @data.flat;
    
    # Create shape array
    my $shape-array = CArray[int64].new;
    for @shape.kv -> $i, $v {
        $shape-array[$i] = $v;
    }
    
    # Create data array based on type
    my ($c-array, $elem-size);
    
    given $type {
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
            $c-array = CArray[num32].new;
            for @flat.kv -> $i, $v {
                $c-array[$i] = $v.Num;
            }
            $elem-size = nativesizeof(num32);
        }
        default {
            die "Unsupported tensor type: $type (only FLOAT supported for now)";
        }
    }
    
    # Create tensor
    my &create-tensor-func = nativecast(
        :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] --> OrtStatus),
        %funcs<CreateTensorWithDataAsOrtValue>
    );
    
    my $tensor-ptr = Pointer[OrtValue].new;
    my $status = create-tensor-func(
        $memory-info,
        nativecast(Pointer, $c-array),
        @flat.elems * $elem-size,
        $shape-array,
        @shape.elems,
        $type,
        $tensor-ptr
    );
    die "Failed to create tensor" if $status;
    
    return $tensor-ptr.deref;
}

# Helper to extract tensor data
sub extract-tensor-data($tensor, @shape, $type, %funcs) {
    # Get data pointer
    my &get-tensor-data = nativecast(
        :(OrtValue, Pointer[Pointer] --> OrtStatus),
        %funcs<GetTensorMutableData>
    );
    
    my $data-ptr-ptr = Pointer[Pointer].new;
    my $status = get-tensor-data($tensor, $data-ptr-ptr);
    die "Failed to get tensor data" if $status;
    
    my $data-ptr = $data-ptr-ptr.deref;
    
    # Calculate total elements
    my $total = [*] @shape;
    
    # Extract data
    my @data;
    given $type {
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
            my $c-array = nativecast(CArray[num32], $data-ptr);
            @data = (^$total).map({ $c-array[$_] });
        }
        default {
            die "Unsupported tensor type for extraction: $type";
        }
    }
    
    # Simple reshape for 2D
    if @shape.elems == 2 {
        my @reshaped;
        for ^@shape[0] -> $i {
            my @row = @data[$i * @shape[1] ..^ ($i + 1) * @shape[1]];
            @reshaped.push(@row);
        }
        return @reshaped;
    }
    
    return @data;
}

# Run inference on a session
sub run-session(Session $session, %inputs) is export {
    die "ONNX module not initialized. Call init-onnx() first!" unless $MODULE-STATE<initialized>;
    
    # Create input tensors
    my @input-values;
    my $input-names = CArray[Str].new;
    my $input-tensors = CArray[OrtValue].new;
    
    for $session.input-names.kv -> $idx, $name {
        $input-names[$idx] = $name;
        
        if %inputs{$name}:exists {
            my $data = %inputs{$name};
            my $info = $session.input-info{$name};
            
            # Create tensor
            my $tensor = create-tensor($session.memory-info, $data, $info<shape>, $info<type>, $session.funcs);
            @input-values.push($tensor);
            $input-tensors[$idx] = $tensor;
        } else {
            die "Missing required input: $name";
        }
    }
    
    # Prepare outputs
    my $output-names = CArray[Str].new;
    my $output-tensors = CArray[OrtValue].new;
    
    for $session.output-names.kv -> $idx, $name {
        $output-names[$idx] = $name;
        $output-tensors[$idx] = OrtValue;
    }
    
    # Run inference
    my &run = nativecast(
        :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] --> OrtStatus),
        $session.funcs<Run>
    );
    
    my $status = run(
        $session.session,
        OrtRunOptions,  # NULL
        $input-names,
        $input-tensors,
        $session.input-names.elems,
        $output-names,
        $session.output-names.elems,
        $output-tensors
    );
    die "Failed to run inference" if $status;
    
    # Extract outputs
    my %outputs;
    for $session.output-names.kv -> $idx, $name {
        my $tensor = $output-tensors[$idx];
        my $info = $session.output-info{$name};
        %outputs{$name} = extract-tensor-data($tensor, $info<shape>, $info<type>, $session.funcs);
    }
    
    return %outputs;
}