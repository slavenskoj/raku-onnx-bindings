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

# Create ONNX Runtime wrapper
class ONNXRuntime {
    has $.api;
    has %.funcs;
    has %.indices = (
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
    
    method new() {
        my $api-base = OrtGetApiBase();
        die "Failed to get OrtApiBase" unless $api-base;
        
        my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
        my $api = get-api(ORT_API_VERSION);
        die "Failed to get OrtApi" unless $api;
        
        self.bless(:$api);
    }
    
    method get-func($name) {
        return %.funcs{$name} if %.funcs{$name}:exists;
        
        my $idx = %.indices{$name} or die "Unknown function: $name";
        my $offset = $idx * nativesizeof(Pointer);
        my $ptr = Pointer.new($.api.Int + $offset);
        my $func = nativecast(CArray[Pointer], $ptr)[0];
        
        %.funcs{$name} = $func;
        return $func;
    }
}

# Create runtime
say "Initializing ONNX Runtime...";
my $ort = ONNXRuntime.new;

# Create environment
say "Creating environment...";
my $env-ptr = Pointer[OrtEnv].new;
my &create-env = nativecast(
    :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
    $ort.get-func('CreateEnv')
);
my $status = create-env(ORT_LOGGING_LEVEL_WARNING, "MNIST", $env-ptr);
die "Failed to create environment" if $status;
my $env = $env-ptr.deref;

# Create session options
say "Creating session options...";
my $opts-ptr = Pointer[OrtSessionOptions].new;
my &create-opts = nativecast(
    :(Pointer[OrtSessionOptions] is rw --> OrtStatus),
    $ort.get-func('CreateSessionOptions')
);
$status = create-opts($opts-ptr);
die "Failed to create session options" if $status;
my $opts = $opts-ptr.deref;

# Set optimization level
my &set-opt = nativecast(
    :(OrtSessionOptions, int32 --> OrtStatus),
    $ort.get-func('SetSessionGraphOptimizationLevel')
);
$status = set-opt($opts, ORT_ENABLE_ALL);
die "Failed to set optimization level" if $status;

# Create session
say "Loading MNIST model...";
my $sess-ptr = Pointer[OrtSession].new;
my &create-sess = nativecast(
    :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] is rw --> OrtStatus),
    $ort.get-func('CreateSession')
);
$status = create-sess($env, "models/mnist.onnx", $opts, $sess-ptr);
die "Failed to create session" if $status;
my $sess = $sess-ptr.deref;

# Get allocator
my $alloc-ptr = Pointer[OrtAllocator].new;
my &get-alloc = nativecast(
    :(Pointer[OrtAllocator] is rw --> OrtStatus),
    $ort.get-func('GetAllocatorWithDefaultOptions')
);
$status = get-alloc($alloc-ptr);
die "Failed to get allocator" if $status;
my $alloc = $alloc-ptr.deref;

# Get input info
my $in-count-ptr = Pointer[size_t].new;
my &get-in-count = nativecast(
    :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
    $ort.get-func('SessionGetInputCount')
);
$status = get-in-count($sess, $in-count-ptr);
die "Failed to get input count" if $status;
my $in-count = $in-count-ptr.deref;

my $name-ptr = Pointer[Str].new;
my &get-in-name = nativecast(
    :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
    $ort.get-func('SessionGetInputName')
);
$status = get-in-name($sess, 0, $alloc, $name-ptr);
die "Failed to get input name" if $status;
my $input-name = $name-ptr.deref;
say "Input: $input-name";

# Get output info
my $out-count-ptr = Pointer[size_t].new;
my &get-out-count = nativecast(
    :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
    $ort.get-func('SessionGetOutputCount')
);
$status = get-out-count($sess, $out-count-ptr);
die "Failed to get output count" if $status;
my $out-count = $out-count-ptr.deref;

my $out-name-ptr = Pointer[Str].new;
my &get-out-name = nativecast(
    :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
    $ort.get-func('SessionGetOutputName')
);
$status = get-out-name($sess, 0, $alloc, $out-name-ptr);
die "Failed to get output name" if $status;
my $output-name = $out-name-ptr.deref;
say "Output: $output-name";

# Create memory info
my $mem-ptr = Pointer[OrtMemoryInfo].new;
my &create-mem = nativecast(
    :(int32, int32, Pointer[OrtMemoryInfo] is rw --> OrtStatus),
    $ort.get-func('CreateCpuMemoryInfo')
);
$status = create-mem(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
die "Failed to create memory info" if $status;
my $mem-info = $mem-ptr.deref;

# Create input tensor (28x28 image)
say "\nCreating input tensor...";
my @image = (^28).map({ [(rand * 2 - 1) xx 28] });  # Random values between -1 and 1
my @flat = @image.flat;
my $c-array = CArray[num32].new;
for @flat.kv -> $i, $v {
    $c-array[$i] = $v.Num;
}

my $shape = CArray[int64].new;
$shape[0] = 1;
$shape[1] = 28;
$shape[2] = 28;

my $tensor-ptr = Pointer[OrtValue].new;
my &create-tensor = nativecast(
    :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] is rw --> OrtStatus),
    $ort.get-func('CreateTensorWithDataAsOrtValue')
);
$status = create-tensor(
    $mem-info,
    nativecast(Pointer, $c-array),
    @flat.elems * nativesizeof(num32),
    $shape,
    3,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
    $tensor-ptr
);
die "Failed to create tensor" if $status;
my $input-tensor = $tensor-ptr.deref;

# Prepare for inference
my $input-names = CArray[Str].new;
$input-names[0] = $input-name;

my $output-names = CArray[Str].new;
$output-names[0] = $output-name;

my $inputs = CArray[OrtValue].new;
$inputs[0] = $input-tensor;

my $outputs = CArray[OrtValue].new;
$outputs[0] = OrtValue;

# Run inference
say "Running inference...";
my &run = nativecast(
    :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] is rw --> OrtStatus),
    $ort.get-func('Run')
);
$status = run(
    $sess,
    OrtRunOptions,  # NULL
    $input-names,
    $inputs,
    1,
    $output-names,
    1,
    $outputs
);
die "Failed to run inference" if $status;

# Get output data
my $output-tensor = $outputs[0];
my $data-ptr-ptr = Pointer[Pointer].new;
my &get-data = nativecast(
    :(OrtValue, Pointer[Pointer] is rw --> OrtStatus),
    $ort.get-func('GetTensorMutableData')
);
$status = get-data($output-tensor, $data-ptr-ptr);
die "Failed to get tensor data" if $status;

my $data-ptr = $data-ptr-ptr.deref;
my $out-array = nativecast(CArray[num32], $data-ptr);

# Display results
say "\nPrediction probabilities:";
my @probs;
for ^10 -> $i {
    @probs.push($out-array[$i]);
    say "Digit $i: {$out-array[$i].fmt('%.4f')}";
}

my $max-idx = (^10).max({ @probs[$_] });
say "\nPredicted digit: $max-idx (confidence: {@probs[$max-idx].fmt('%.2f')})";

say "\nInference complete!";