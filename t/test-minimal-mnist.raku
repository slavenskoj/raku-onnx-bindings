#!/usr/bin/env raku

use NativeCall;

# Constants
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

# Types
class OrtStatus is repr('CPointer') { }
class OrtEnv is repr('CPointer') { }
class OrtSessionOptions is repr('CPointer') { }
class OrtSession is repr('CPointer') { }
class OrtMemoryInfo is repr('CPointer') { }
class OrtAllocator is repr('CPointer') { }
class OrtValue is repr('CPointer') { }
class OrtTypeInfo is repr('CPointer') { }
class OrtTensorTypeAndShapeInfo is repr('CPointer') { }
class OrtRunOptions is repr('CPointer') { }

# OrtApiBase
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

say "ONNX Runtime MNIST Test";
say "=" x 40;

# Get API
my $api-base = OrtGetApiBase();
my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
my $api = get-api(ORT_API_VERSION);
say "✓ Got API struct";

# Helper to get function from API struct
sub get-func($offset) {
    my $ptr = Pointer.new($api.Int + $offset * nativesizeof(Pointer));
    return nativecast(CArray[Pointer], $ptr)[0];
}

# Function indices (from onnxruntime_c_api.h)
my %funcs = (
    CreateEnv => 3,
    CreateSessionOptions => 10,
    SetSessionGraphOptimizationLevel => 23,
    CreateSession => 7,
    SessionGetInputCount => 30,
    SessionGetOutputCount => 31,
    GetAllocatorWithDefaultOptions => 78,
    SessionGetInputName => 36,
    SessionGetOutputName => 37,
    ReleaseEnv => 87,
    ReleaseSessionOptions => 95,
    ReleaseSession => 90,
);

# 1. Create environment
my &create-env = nativecast(
    :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
    get-func(%funcs<CreateEnv>)
);

my $env-ptr = Pointer[OrtEnv].new;
my $status = create-env(2, "MNISTTest", $env-ptr); # 2 = WARNING level
die "Failed to create environment" if $status;
my $env = $env-ptr.deref;
say "✓ Created environment";

# 2. Create session options
my &create-session-options = nativecast(
    :(Pointer[OrtSessionOptions] is rw --> OrtStatus),
    get-func(%funcs<CreateSessionOptions>)
);

my $options-ptr = Pointer[OrtSessionOptions].new;
$status = create-session-options($options-ptr);
die "Failed to create session options" if $status;
my $options = $options-ptr.deref;
say "✓ Created session options";

# 3. Skip optimization level for now
# my &set-opt-level = nativecast(
#     :(OrtSessionOptions, int32 --> OrtStatus),
#     get-func(%funcs<SetSessionGraphOptimizationLevel>)
# );
# 
# $status = set-opt-level($options, 3); # 3 = ORT_ENABLE_ALL
# die "Failed to set optimization level" if $status;
# say "✓ Set optimization level";

# 4. Create session
my &create-session = nativecast(
    :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] is rw --> OrtStatus),
    get-func(%funcs<CreateSession>)
);

my $session-ptr = Pointer[OrtSession].new;
say "Loading model: models/mnist.onnx";
$status = create-session($env, "models/mnist.onnx", $options, $session-ptr);
die "Failed to create session" if $status;
my $session = $session-ptr.deref;
say "✓ Created session";

# 5. Get input/output counts
my &get-input-count = nativecast(
    :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
    get-func(%funcs<SessionGetInputCount>)
);

my &get-output-count = nativecast(
    :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
    get-func(%funcs<SessionGetOutputCount>)
);

my $input-count-ptr = Pointer[size_t].new;
my $output-count-ptr = Pointer[size_t].new;

$status = get-input-count($session, $input-count-ptr);
if $status {
    say "Failed to get input count, status: ", $status;
    # Get error message
    my &get-error-msg = nativecast(:(OrtStatus --> Str), get-func(2));
    say "Error: ", get-error-msg($status);
    die "Failed to get input count";
}
my $input-count = $input-count-ptr.deref;

$status = get-output-count($session, $output-count-ptr);
if $status {
    say "Failed to get output count, status: ", $status;
    # Get error message
    my &get-error-msg = nativecast(:(OrtStatus --> Str), get-func(2));
    say "Error: ", get-error-msg($status);
    die "Failed to get output count";
}
my $output-count = $output-count-ptr.deref;

say "\nModel info:";
say "  Inputs: $input-count";
say "  Outputs: $output-count";

# 6. Get allocator
my &get-allocator = nativecast(
    :(Pointer[OrtAllocator] is rw --> OrtStatus),
    get-func(%funcs<GetAllocatorWithDefaultOptions>)
);

my $allocator-ptr = Pointer[OrtAllocator].new;
$status = get-allocator($allocator-ptr);
die "Failed to get allocator" if $status;
my $allocator = $allocator-ptr.deref;

# 7. Get input/output names
my &get-input-name = nativecast(
    :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
    get-func(%funcs<SessionGetInputName>)
);

my &get-output-name = nativecast(
    :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
    get-func(%funcs<SessionGetOutputName>)
);

say "\nInput names:";
for ^$input-count -> $i {
    my $name-ptr = Pointer[Str].new;
    $status = get-input-name($session, $i, $allocator, $name-ptr);
    die "Failed to get input name $i" if $status;
    say "  [$i]: ", $name-ptr.deref;
}

say "\nOutput names:";
for ^$output-count -> $i {
    my $name-ptr = Pointer[Str].new;
    $status = get-output-name($session, $i, $allocator, $name-ptr);
    die "Failed to get output name $i" if $status;
    say "  [$i]: ", $name-ptr.deref;
}

# Cleanup
my &release-session = nativecast(:(OrtSession), get-func(%funcs<ReleaseSession>));
my &release-options = nativecast(:(OrtSessionOptions), get-func(%funcs<ReleaseSessionOptions>));
my &release-env = nativecast(:(OrtEnv), get-func(%funcs<ReleaseEnv>));

release-session($session);
release-options($options);
release-env($env);

say "\n✓ Test completed successfully!";