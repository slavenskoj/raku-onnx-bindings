unit module ONNX::Runtime::Factory;

use NativeCall;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;
constant ORT_LOGGING_LEVEL_WARNING = 2;
constant ORT_ENABLE_ALL = 99;
constant OrtArenaAllocator = 0;
constant OrtMemTypeDefault = 0;

# Types
class OrtEnv is repr('CPointer') is export { }
class OrtSession is repr('CPointer') is export { }
class OrtSessionOptions is repr('CPointer') is export { }
class OrtMemoryInfo is repr('CPointer') is export { }
class OrtAllocator is repr('CPointer') is export { }
class OrtStatus is repr('CPointer') is export { }

class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

# Runtime data holder (no initialization logic)
class RuntimeData is export {
    has $.api;
    has $.env;
    has $.session;
    has $.options;
    has $.memory-info;
    has $.allocator;
    has @.input-names;
    has @.output-names;
    has Str $.model-path;
}

# Factory function to create runtime
sub create-runtime(Str :$model-path!, :$log-level = ORT_LOGGING_LEVEL_WARNING) is export {
    # Get API
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
    my $api = get-api(ORT_API_VERSION);
    die "Failed to get OrtApi" unless $api;
    
    # Function table
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
    );
    
    for %indices.kv -> $name, $idx {
        my $func-ptr = nativecast(CArray[Pointer], $api)[$idx];
        die "Failed to get function pointer for $name at index $idx" unless $func-ptr;
        %funcs{$name} = $func-ptr;
    }
    
    # Create environment
    my &create-env = nativecast(
        :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
        %funcs<CreateEnv>
    );
    
    my $env-ptr = Pointer[OrtEnv].new;
    my $status = create-env($log-level, "RakuONNX", $env-ptr);
    die "Failed to create environment" if $status;
    my $env = $env-ptr.deref;
    
    # Create session options
    my &create-opts = nativecast(
        :(Pointer[OrtSessionOptions] --> OrtStatus),
        %funcs<CreateSessionOptions>
    );
    
    my $opts-ptr = Pointer[OrtSessionOptions].new;
    $status = create-opts($opts-ptr);
    die "Failed to create session options" if $status;
    my $options = $opts-ptr.deref;
    
    # Set optimization level
    my &set-opt-level = nativecast(
        :(OrtSessionOptions, int32 --> OrtStatus),
        %funcs<SetSessionGraphOptimizationLevel>
    );
    
    $status = set-opt-level($options, ORT_ENABLE_ALL);
    die "Failed to set optimization level" if $status;
    
    # Create session
    my &create-session = nativecast(
        :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
        %funcs<CreateSession>
    );
    
    my $sess-ptr = Pointer[OrtSession].new;
    $status = create-session($env, $model-path, $options, $sess-ptr);
    die "Failed to create session for $model-path" if $status;
    my $session = $sess-ptr.deref;
    
    # Create memory info
    my &create-mem-info = nativecast(
        :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
        %funcs<CreateCpuMemoryInfo>
    );
    
    my $mem-ptr = Pointer[OrtMemoryInfo].new;
    $status = create-mem-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
    die "Failed to create memory info" if $status;
    my $memory-info = $mem-ptr.deref;
    
    # Get allocator
    my &get-allocator = nativecast(
        :(Pointer[OrtAllocator] --> OrtStatus),
        %funcs<GetAllocatorWithDefaultOptions>
    );
    
    my $alloc-ptr = Pointer[OrtAllocator].new;
    $status = get-allocator($alloc-ptr);
    die "Failed to get allocator" if $status;
    my $allocator = $alloc-ptr.deref;
    
    # Get input/output info
    my @input-names;
    my @output-names;
    
    # Get input count
    my &get-input-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        %funcs<SessionGetInputCount>
    );
    
    my $in-count-ptr = Pointer[size_t].new;
    $status = get-input-count($session, $in-count-ptr);
    die "Failed to get input count" if $status;
    my $in-count = $in-count-ptr.deref;
    
    # Get input names
    my &get-input-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        %funcs<SessionGetInputName>
    );
    
    for ^$in-count -> $i {
        my $name-ptr = Pointer[Str].new;
        $status = get-input-name($session, $i, $allocator, $name-ptr);
        die "Failed to get input name $i" if $status;
        my $name = $name-ptr.deref;
        @input-names.push($name);
    }
    
    # Get output count
    my &get-output-count = nativecast(
        :(OrtSession, Pointer[size_t] --> OrtStatus),
        %funcs<SessionGetOutputCount>
    );
    
    my $out-count-ptr = Pointer[size_t].new;
    $status = get-output-count($session, $out-count-ptr);
    die "Failed to get output count" if $status;
    my $out-count = $out-count-ptr.deref;
    
    # Get output names
    my &get-output-name = nativecast(
        :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
        %funcs<SessionGetOutputName>
    );
    
    for ^$out-count -> $i {
        my $name-ptr = Pointer[Str].new;
        $status = get-output-name($session, $i, $allocator, $name-ptr);
        die "Failed to get output name $i" if $status;
        my $name = $name-ptr.deref;
        @output-names.push($name);
    }
    
    # Return runtime data
    return RuntimeData.new(
        :$api,
        :$env,
        :$session,
        :$options,
        :$memory-info,
        :$allocator,
        :@input-names,
        :@output-names,
        :$model-path,
    );
}