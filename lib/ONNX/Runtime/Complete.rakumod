unit module ONNX::Runtime::Complete;

use NativeCall;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

# Logging levels
constant ORT_LOGGING_LEVEL_VERBOSE = 0;
constant ORT_LOGGING_LEVEL_INFO = 1;
constant ORT_LOGGING_LEVEL_WARNING = 2;
constant ORT_LOGGING_LEVEL_ERROR = 3;
constant ORT_LOGGING_LEVEL_FATAL = 4;

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

# API Base structure
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

# Module state (avoid initialization during precompilation)
my $MODULE-API;
my %MODULE-FUNCS;

# Get API instance
sub get-module-api() {
    return $MODULE-API if $MODULE-API;
    
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    $MODULE-API = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $MODULE-API;
    
    return $MODULE-API;
}

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
);

# Get function pointer
sub get-module-func(Str $name) {
    return %MODULE-FUNCS{$name} if %MODULE-FUNCS{$name}:exists;
    
    my $idx = %FUNCTION-INDICES{$name};
    die "Unknown function: $name" unless $idx.defined;
    
    my $api = get-module-api();
    my $func-ptr = nativecast(CArray[Pointer], $api)[$idx];
    die "Failed to get function pointer for $name at index $idx" unless $func-ptr;
    
    %MODULE-FUNCS{$name} = $func-ptr;
    return $func-ptr;
}

# Simple runtime class with manual initialization
class Runtime is export {
    has Str $.model-path is required;
    has $.log-level = ORT_LOGGING_LEVEL_WARNING;
    has $.env;
    has $.session;
    has $.options;
    has $.memory-info;
    has $.allocator;
    has @.input-names;
    has @.output-names;
    has Bool $!initialized = False;
    
    method initialize() {
        return if $!initialized;
        
        # Create environment
        my &create-env = nativecast(
            :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
            get-module-func('CreateEnv')
        );
        
        my $env-ptr = Pointer[OrtEnv].new;
        my $status = create-env($!log-level, "RakuONNX", $env-ptr);
        die "Failed to create environment" if $status;
        $!env = $env-ptr.deref;
        
        # Create session options
        my &create-opts = nativecast(
            :(Pointer[OrtSessionOptions] --> OrtStatus),
            get-module-func('CreateSessionOptions')
        );
        
        my $opts-ptr = Pointer[OrtSessionOptions].new;
        $status = create-opts($opts-ptr);
        die "Failed to create session options" if $status;
        $!options = $opts-ptr.deref;
        
        # Set optimization level
        my &set-opt-level = nativecast(
            :(OrtSessionOptions, int32 --> OrtStatus),
            get-module-func('SetSessionGraphOptimizationLevel')
        );
        
        $status = set-opt-level($!options, ORT_ENABLE_ALL);
        die "Failed to set optimization level" if $status;
        
        # Create session
        my &create-session = nativecast(
            :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
            get-module-func('CreateSession')
        );
        
        my $sess-ptr = Pointer[OrtSession].new;
        $status = create-session($!env, $!model-path, $!options, $sess-ptr);
        die "Failed to create session for $!model-path" if $status;
        $!session = $sess-ptr.deref;
        
        # Create memory info
        my &create-mem-info = nativecast(
            :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
            get-module-func('CreateCpuMemoryInfo')
        );
        
        my $mem-ptr = Pointer[OrtMemoryInfo].new;
        $status = create-mem-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
        die "Failed to create memory info" if $status;
        $!memory-info = $mem-ptr.deref;
        
        # Get allocator
        my &get-allocator = nativecast(
            :(Pointer[OrtAllocator] --> OrtStatus),
            get-module-func('GetAllocatorWithDefaultOptions')
        );
        
        my $alloc-ptr = Pointer[OrtAllocator].new;
        $status = get-allocator($alloc-ptr);
        die "Failed to get allocator" if $status;
        $!allocator = $alloc-ptr.deref;
        
        # Query model info
        self!query-model-info();
        
        $!initialized = True;
    }
    
    method !query-model-info() {
        # Get input count
        my &get-input-count = nativecast(
            :(OrtSession, Pointer[size_t] --> OrtStatus),
            get-module-func('SessionGetInputCount')
        );
        
        my $in-count-ptr = Pointer[size_t].new;
        my $status = get-input-count($!session, $in-count-ptr);
        die "Failed to get input count" if $status;
        my $in-count = $in-count-ptr.deref;
        
        # Get output count
        my &get-output-count = nativecast(
            :(OrtSession, Pointer[size_t] --> OrtStatus),
            get-module-func('SessionGetOutputCount')
        );
        
        my $out-count-ptr = Pointer[size_t].new;
        $status = get-output-count($!session, $out-count-ptr);
        die "Failed to get output count" if $status;
        my $out-count = $out-count-ptr.deref;
        
        # Get input names
        my &get-input-name = nativecast(
            :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
            get-module-func('SessionGetInputName')
        );
        
        for ^$in-count -> $i {
            my $name-ptr = Pointer[Str].new;
            $status = get-input-name($!session, $i, $!allocator, $name-ptr);
            die "Failed to get input name $i" if $status;
            my $name = $name-ptr.deref;
            @!input-names.push($name);
        }
        
        # Get output names  
        my &get-output-name = nativecast(
            :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
            get-module-func('SessionGetOutputName')
        );
        
        for ^$out-count -> $i {
            my $name-ptr = Pointer[Str].new;
            $status = get-output-name($!session, $i, $!allocator, $name-ptr);
            die "Failed to get output name $i" if $status;
            my $name = $name-ptr.deref;
            @!output-names.push($name);
        }
    }
    
    method input-names() {
        self.initialize() unless $!initialized;
        return @!input-names;
    }
    
    method output-names() {
        self.initialize() unless $!initialized;
        return @!output-names;
    }
}