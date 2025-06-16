unit module ONNX::Runtime::API;

use NativeCall;
use ONNX::Runtime::Types;

# Library name - adjust path as needed
# Users can set ONNX_RUNTIME_LIB environment variable to point to specific library
constant ONNX_LIB = %*ENV<ONNX_RUNTIME_LIB> // do {
    # Try common library names on different platforms
    given $*DISTRO.name {
        when /linux/ { 'onnxruntime' }
        when /darwin/ { 'onnxruntime' }
        when /win/ { 'onnxruntime' }
        default { 'onnxruntime' }
    }
};

# OrtApiBase structure to get the versioned API
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;  # Function pointer to get versioned API
    has Str $.GetVersionString;  # Function pointer to get version string
}

# Get the API base - this is the entry point
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) is export { * }

# Since the OrtApi struct contains many function pointers, we'll define
# a wrapper that provides easier access to the functions
class OrtApiWrapper {
    has OrtApi $!api;
    has Pointer $!api-ptr;
    
    # Function pointer signatures
    has &!CreateStatus;
    has &!GetErrorCode;
    has &!GetErrorMessage;
    has &!ReleaseStatus;
    has &!CreateEnv;
    has &!ReleaseEnv;
    has &!CreateSessionOptions;
    has &!ReleaseSessionOptions;
    has &!CreateSession;
    has &!ReleaseSession;
    has &!CreateCpuMemoryInfo;
    has &!ReleaseMemoryInfo;
    has &!CreateTensorAsOrtValue;
    has &!ReleaseValue;
    has &!Run;
    has &!GetTensorMutableData;
    has &!GetTensorTypeAndShape;
    has &!ReleaseTensorTypeAndShapeInfo;
    has &!GetDimensionsCount;
    has &!GetDimensions;
    has &!GetTensorElementType;
    has &!SessionGetInputCount;
    has &!SessionGetOutputCount;
    has &!SessionGetInputName;
    has &!SessionGetOutputName;
    has &!SessionGetInputTypeInfo;
    has &!SessionGetOutputTypeInfo;
    has &!ReleaseTypeInfo;
    has &!CastTypeInfoToTensorInfo;
    has &!CreateTensorWithDataAsOrtValue;
    has &!GetValueType;
    has &!TypeInfoGetOnnxType;
    has &!GetOnnxTypeFromTypeInfo;
    has &!AllocatorAlloc;
    has &!AllocatorFree;
    has &!AllocatorGetInfo;
    has &!GetAllocatorWithDefaultOptions;
    has &!SessionGetModelMetadata;
    has &!ReleaseModelMetadata;
    
    submethod BUILD() {
        # Get the API base
        my $base = OrtGetApiBase();
        
        # Get the versioned API (we want version 16)
        # This is complex because we need to call through function pointer
        # For now, we'll use a simplified approach
        
        # In practice, this would involve:
        # 1. Calling $base.GetApi(ORT_API_VERSION) to get the API struct
        # 2. Extracting function pointers from the struct
        # 3. Creating callable wrappers for each function
        
        # This is a placeholder - actual implementation would be more complex
        warn "OrtApiWrapper initialization not fully implemented yet";
    }
    
    # Status management
    method CreateStatus(Int $code, Str $msg) returns OrtStatus {
        &!CreateStatus ?? &!CreateStatus($code, $msg) !! OrtStatus;
    }
    
    method GetErrorCode(OrtStatus $status) returns Int {
        &!GetErrorCode ?? &!GetErrorCode($status) !! 0;
    }
    
    method GetErrorMessage(OrtStatus $status) returns Str {
        &!GetErrorMessage ?? &!GetErrorMessage($status) !! "";
    }
    
    method ReleaseStatus(OrtStatus $status) {
        &!ReleaseStatus($status) if &!ReleaseStatus;
    }
    
    # Environment management
    method CreateEnv(Int $log-level, Str $logid) returns OrtEnv {
        my $env-ptr = Pointer[OrtEnv].new;
        my $status = &!CreateEnv ?? &!CreateEnv($log-level, $logid, $env-ptr) !! OrtStatus;
        # Check status and return env
        $env-ptr.deref;
    }
    
    method ReleaseEnv(OrtEnv $env) {
        &!ReleaseEnv($env) if &!ReleaseEnv;
    }
}

# Direct function bindings (simplified approach for initial implementation)
# These bypass the function pointer complexity for now

sub ort-create-env(int32 $log-level, Str $logid, Pointer[OrtEnv] $out is rw) 
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtCreateEnv') is export { * }

sub ort-release-env(OrtEnv $env) 
    is native(ONNX_LIB) is symbol('OrtReleaseEnv') is export { * }

sub ort-create-session-options(Pointer[OrtSessionOptions] $out is rw) 
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtCreateSessionOptions') is export { * }

sub ort-release-session-options(OrtSessionOptions $options) 
    is native(ONNX_LIB) is symbol('OrtReleaseSessionOptions') is export { * }

sub ort-create-session(OrtEnv $env, Str $model-path, OrtSessionOptions $options, Pointer[OrtSession] $out is rw) 
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtCreateSession') is export { * }

sub ort-release-session(OrtSession $session) 
    is native(ONNX_LIB) is symbol('OrtReleaseSession') is export { * }

sub ort-release-status(OrtStatus $status) 
    is native(ONNX_LIB) is symbol('OrtReleaseStatus') is export { * }

sub ort-get-error-code(OrtStatus $status) 
    returns int32 is native(ONNX_LIB) is symbol('OrtGetErrorCode') is export { * }

sub ort-get-error-message(OrtStatus $status) 
    returns Str is native(ONNX_LIB) is symbol('OrtGetErrorMessage') is export { * }

# Memory info functions
sub ort-create-cpu-memory-info(int32 $alloc-type, int32 $mem-type, Pointer[OrtMemoryInfo] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtCreateCpuMemoryInfo') is export { * }

sub ort-release-memory-info(OrtMemoryInfo $info)
    is native(ONNX_LIB) is symbol('OrtReleaseMemoryInfo') is export { * }

# Tensor creation
sub ort-create-tensor-with-data-as-ort-value(
    OrtMemoryInfo $info,
    Pointer $p-data,
    size_t $p-data-len,
    CArray[int64] $shape,
    size_t $shape-len,
    int32 $type,
    Pointer[OrtValue] $out is rw
) returns OrtStatus is native(ONNX_LIB) is symbol('OrtCreateTensorWithDataAsOrtValue') is export { * }

sub ort-release-value(OrtValue $value)
    is native(ONNX_LIB) is symbol('OrtReleaseValue') is export { * }

# Session input/output info
sub ort-session-get-input-count(OrtSession $session, Pointer[size_t] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSessionGetInputCount') is export { * }

sub ort-session-get-output-count(OrtSession $session, Pointer[size_t] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSessionGetOutputCount') is export { * }

# Run inference
sub ort-run(
    OrtSession $session,
    OrtRunOptions $run-options,
    CArray[Str] $input-names,
    CArray[OrtValue] $inputs,
    size_t $input-count,
    CArray[Str] $output-names,
    size_t $output-count,
    CArray[OrtValue] $outputs is rw
) returns OrtStatus is native(ONNX_LIB) is symbol('OrtRun') is export { * }

# Get allocator
sub ort-get-allocator-with-default-options(Pointer[OrtAllocator] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtGetAllocatorWithDefaultOptions') is export { * }

# Session input/output names
sub ort-session-get-input-name(OrtSession $session, size_t $index, OrtAllocator $allocator, Pointer[Str] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSessionGetInputName') is export { * }

sub ort-session-get-output-name(OrtSession $session, size_t $index, OrtAllocator $allocator, Pointer[Str] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSessionGetOutputName') is export { * }

# Type info
sub ort-session-get-input-type-info(OrtSession $session, size_t $index, Pointer[OrtTypeInfo] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSessionGetInputTypeInfo') is export { * }

sub ort-session-get-output-type-info(OrtSession $session, size_t $index, Pointer[OrtTypeInfo] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSessionGetOutputTypeInfo') is export { * }

sub ort-release-type-info(OrtTypeInfo $info)
    is native(ONNX_LIB) is symbol('OrtReleaseTypeInfo') is export { * }

# Cast type info to tensor info
sub ort-cast-type-info-to-tensor-info(OrtTypeInfo $type-info, Pointer[OrtTensorTypeAndShapeInfo] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtCastTypeInfoToTensorInfo') is export { * }

sub ort-release-tensor-type-and-shape-info(OrtTensorTypeAndShapeInfo $info)
    is native(ONNX_LIB) is symbol('OrtReleaseTensorTypeAndShapeInfo') is export { * }

# Get tensor shape
sub ort-get-dimensions-count(OrtTensorTypeAndShapeInfo $info, Pointer[size_t] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtGetDimensionsCount') is export { * }

sub ort-get-dimensions(OrtTensorTypeAndShapeInfo $info, CArray[int64] $values, size_t $values-count)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtGetDimensions') is export { * }

sub ort-get-tensor-element-type(OrtTensorTypeAndShapeInfo $info, Pointer[int32] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtGetTensorElementType') is export { * }

# Get tensor data
sub ort-get-tensor-mutable-data(OrtValue $value, Pointer[Pointer] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtGetTensorMutableData') is export { * }

# Value type
sub ort-get-value-type(OrtValue $value, Pointer[int32] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtGetValueType') is export { * }

# Allocator functions
sub ort-allocator-alloc(OrtAllocator $allocator, size_t $size, Pointer[Pointer] $out is rw)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtAllocatorAlloc') is export { * }

sub ort-allocator-free(OrtAllocator $allocator, Pointer $p)
    is native(ONNX_LIB) is symbol('OrtAllocatorFree') is export { * }

# Session options
sub ort-set-session-graph-optimization-level(OrtSessionOptions $options, int32 $level)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSetSessionGraphOptimizationLevel') is export { * }

sub ort-set-intra-op-num-threads(OrtSessionOptions $options, int32 $num-threads)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSetIntraOpNumThreads') is export { * }

sub ort-set-inter-op-num-threads(OrtSessionOptions $options, int32 $num-threads)
    returns OrtStatus is native(ONNX_LIB) is symbol('OrtSetInterOpNumThreads') is export { * }

# Helper function to check status and throw on error
sub check-status(OrtStatus $status, Str $context = "ONNX Runtime operation") is export {
    if $status {
        my $code = ort-get-error-code($status);
        my $msg = ort-get-error-message($status);
        ort-release-status($status);
        die "$context failed: $msg (code: $code)";
    }
}