#!/usr/bin/env raku

use lib 'lib';
use NativeCall;
use ONNX::Runtime::Types;
use ONNX::Runtime::Direct;

# Create API
say "Creating API...";
my $api = ONNX::Runtime::Direct::API.new;
say "API created!";

# Create environment
say "Creating environment...";
my $env-ptr = Pointer[OrtEnv].new;
my $status = $api.create-env(ORT_LOGGING_LEVEL_WARNING, "Test", $env-ptr);
die "Failed to create environment" if $status;
my $env = $env-ptr.deref;
say "Environment created!";

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
say "Session created!";

# Get allocator
say "Getting allocator...";
my $alloc-ptr = Pointer[OrtAllocator].new;
$status = $api.get-allocator($alloc-ptr);
die "Failed to get allocator" if $status;
my $alloc = $alloc-ptr.deref;

# Get input info
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

# Create memory info
say "Creating memory info...";
my $mem-ptr = Pointer[OrtMemoryInfo].new;
$status = $api.create-cpu-memory-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
die "Failed to create memory info" if $status;
my $mem-info = $mem-ptr.deref;

# Create test tensor
say "Creating test tensor...";
my @data = (0.0) xx (28 * 28);
my $c-array = CArray[num32].new;
for @data.kv -> $i, $v {
    $c-array[$i] = $v.Num;
}

my $shape = CArray[int64].new;
$shape[0] = 1;
$shape[1] = 28;
$shape[2] = 28;

my $tensor-ptr = Pointer[OrtValue].new;
$status = $api.create-tensor(
    $mem-info,
    nativecast(Pointer, $c-array),
    @data.elems * nativesizeof(num32),
    $shape,
    3,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
    $tensor-ptr
);
die "Failed to create tensor" if $status;
say "Tensor created!";

say "\nAll tests passed!";