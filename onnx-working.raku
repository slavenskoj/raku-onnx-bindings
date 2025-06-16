#!/usr/bin/env raku

use NativeCall;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;
constant ORT_LOGGING_LEVEL_WARNING = 2;
constant ORT_ENABLE_ALL = 99;
constant OrtArenaAllocator = 0;
constant OrtMemTypeDefault = 0;
constant ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT = 1;

# Basic types
class OrtEnv is repr('CPointer') {}
class OrtSession is repr('CPointer') {}
class OrtSessionOptions is repr('CPointer') {}
class OrtMemoryInfo is repr('CPointer') {}
class OrtAllocator is repr('CPointer') {}
class OrtValue is repr('CPointer') {}
class OrtTypeInfo is repr('CPointer') {}
class OrtTensorTypeAndShapeInfo is repr('CPointer') {}
class OrtStatus is repr('CPointer') {}
class OrtRunOptions is repr('CPointer') {}

# OrtApiBase
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

# Get the API
say "Getting API base...";
my $api-base = OrtGetApiBase();
die "Failed to get OrtApiBase" unless $api-base;

say "Getting API...";
my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
my $api = get-api(ORT_API_VERSION);
die "Failed to get OrtApi" unless $api;

# Function indices
my %indices = (
    'CreateEnv' => 3,
    'CreateSessionOptions' => 10,
    'SetSessionGraphOptimizationLevel' => 23,
    'CreateSession' => 7,
);

# Get function pointer
sub get-func($name) {
    my $idx = %indices{$name} or die "Unknown function: $name";
    my $offset = $idx * nativesizeof(Pointer);
    my $ptr = Pointer.new($api.Int + $offset);
    my $func = nativecast(CArray[Pointer], $ptr)[0];
    return $func;
}

# Create environment
say "Creating environment...";
my $env-ptr = Pointer[OrtEnv].new;
my &create-env = nativecast(
    :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
    get-func('CreateEnv')
);
my $status = create-env(ORT_LOGGING_LEVEL_WARNING, "Test", $env-ptr);
die "Failed to create environment" if $status;
my $env = $env-ptr.deref;
say "Environment created!";

# Create session options
say "Creating session options...";
my $opts-ptr = Pointer[OrtSessionOptions].new;
my &create-opts = nativecast(
    :(Pointer[OrtSessionOptions] is rw --> OrtStatus),
    get-func('CreateSessionOptions')
);
$status = create-opts($opts-ptr);
die "Failed to create session options" if $status;
my $opts = $opts-ptr.deref;
say "Session options created!";

# Set optimization level
say "Setting optimization level...";
my &set-opt = nativecast(
    :(OrtSessionOptions, int32 --> OrtStatus),
    get-func('SetSessionGraphOptimizationLevel')
);
$status = set-opt($opts, ORT_ENABLE_ALL);
die "Failed to set optimization level" if $status;
say "Optimization level set!";

# Create session
say "Creating session...";
my $sess-ptr = Pointer[OrtSession].new;
my &create-sess = nativecast(
    :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] is rw --> OrtStatus),
    get-func('CreateSession')
);
$status = create-sess($env, "models/mnist.onnx", $opts, $sess-ptr);
die "Failed to create session" if $status;
my $sess = $sess-ptr.deref;
say "Session created!";

say "\nModel loaded successfully!";
say "Ready for inference.";