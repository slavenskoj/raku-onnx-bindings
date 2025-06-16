#!/usr/bin/env raku

use lib 'lib';
use NativeCall;
use ONNX::Runtime::Types;
use ONNX::Runtime::API::Simple;

# Create ONNX Runtime
say "Creating API...";
my $api = ONNX::Runtime::API::Simple::SimpleAPI.new;

# Create environment
say "Creating environment...";
my $env-ptr = Pointer[OrtEnv].new;
my $status = $api.create-env(ORT_LOGGING_LEVEL_WARNING, "Test", $env-ptr);
die "Failed to create environment" if $status;
my $env = $env-ptr.deref;

# Create session options
say "Creating session options...";
my $opts-ptr = Pointer[OrtSessionOptions].new;
$status = $api.create-session-options($opts-ptr);
die "Failed to create session options" if $status;
my $opts = $opts-ptr.deref;

# Set optimization level
$status = $api.set-optimization-level($opts, ORT_ENABLE_ALL);
die "Failed to set optimization level" if $status;

# Create session
say "Creating session...";
my $sess-ptr = Pointer[OrtSession].new;
$status = $api.create-session($env, "models/mnist.onnx", $opts, $sess-ptr);
die "Failed to create session" if $status;
my $sess = $sess-ptr.deref;

# Get allocator
say "Getting allocator...";
my $alloc-ptr = Pointer[OrtAllocator].new;
$status = $api.get-allocator($alloc-ptr);
die "Failed to get allocator" if $status;
my $alloc = $alloc-ptr.deref;

# Get input count
say "Getting input info...";
my $in-count-ptr = Pointer[size_t].new;
$status = $api.get-input-count($sess, $in-count-ptr);
die "Failed to get input count" if $status;
my $in-count = $in-count-ptr.deref;
say "Input count: $in-count";

# Get input name
my $name-ptr = Pointer[Str].new;
$status = $api.get-input-name($sess, 0, $alloc, $name-ptr);
die "Failed to get input name" if $status;
my $input-name = $name-ptr.deref;
say "Input name: $input-name";

# Get input type info
my $type-info-ptr = Pointer[OrtTypeInfo].new;
$status = $api.get-input-type-info($sess, 0, $type-info-ptr);
die "Failed to get input type info" if $status;
my $type-info = $type-info-ptr.deref;

# Get tensor info
my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
$status = $api.cast-to-tensor-info($type-info, $tensor-info-ptr);
die "Failed to cast to tensor info" if $status;
my $tensor-info = $tensor-info-ptr.deref;

# Get dimensions
my $dims-count-ptr = Pointer[size_t].new;
$status = $api.get-dimensions-count($tensor-info, $dims-count-ptr);
die "Failed to get dimensions count" if $status;
my $dims-count = $dims-count-ptr.deref;

my $dims = CArray[int64].new;
$dims[$dims-count - 1] = 0;  # Allocate
$status = $api.get-dimensions($tensor-info, $dims, $dims-count);
die "Failed to get dimensions" if $status;

my @shape = (^$dims-count).map({ $dims[$_] });
say "Input shape: ", @shape;

# Create memory info
say "Creating memory info...";
my $mem-ptr = Pointer[OrtMemoryInfo].new;
$status = $api.create-cpu-memory-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
die "Failed to create memory info" if $status;
my $mem-info = $mem-ptr.deref;

# Create input tensor (28x28 zeros)
say "Creating input tensor...";
my @data = (0.0) xx (28 * 28);
my $c-array = CArray[num32].new;
for @data.kv -> $i, $v {
    $c-array[$i] = $v.Num;
}

my $shape-array = CArray[int64].new;
$shape-array[0] = 1;
$shape-array[1] = 28;
$shape-array[2] = 28;

my $tensor-ptr = Pointer[OrtValue].new;
$status = $api.create-tensor(
    $mem-info,
    nativecast(Pointer, $c-array),
    @data.elems * nativesizeof(num32),
    $shape-array,
    3,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
    $tensor-ptr
);
die "Failed to create tensor" if $status;
my $input-tensor = $tensor-ptr.deref;

# Get output info
say "Getting output info...";
my $out-count-ptr = Pointer[size_t].new;
$status = $api.get-output-count($sess, $out-count-ptr);
die "Failed to get output count" if $status;
my $out-count = $out-count-ptr.deref;
say "Output count: $out-count";

my $out-name-ptr = Pointer[Str].new;
$status = $api.get-output-name($sess, 0, $alloc, $out-name-ptr);
die "Failed to get output name" if $status;
my $output-name = $out-name-ptr.deref;
say "Output name: $output-name";

# Prepare for inference
say "Running inference...";
my $input-names = CArray[Str].new;
$input-names[0] = $input-name;

my $output-names = CArray[Str].new;
$output-names[0] = $output-name;

my $inputs = CArray[OrtValue].new;
$inputs[0] = $input-tensor;

my $outputs = CArray[OrtValue].new;
$outputs[0] = OrtValue;

# Run inference
$status = $api.run(
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

say "Inference complete!";

# Get output data
my $output-tensor = $outputs[0];
my $data-ptr-ptr = Pointer[Pointer].new;
$status = $api.get-tensor-data($output-tensor, $data-ptr-ptr);
die "Failed to get tensor data" if $status;

my $data-ptr = $data-ptr-ptr.deref;
my $out-array = nativecast(CArray[num32], $data-ptr);

say "\nOutput probabilities:";
for ^10 -> $i {
    say "Digit $i: ", $out-array[$i];
}

my $max-idx = (^10).max({ $out-array[$_] });
say "\nPredicted digit: $max-idx";