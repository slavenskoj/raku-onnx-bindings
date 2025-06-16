unit module ONNX::Runtime::API;

use NativeCall;
use ONNX::Runtime::Types;

# Library path configuration
sub get-onnx-lib() {
    return %*ENV<ONNX_RUNTIME_LIB> if %*ENV<ONNX_RUNTIME_LIB>;
    
    # For macOS, check common locations
    my @paths = (
        # Local extracted version
        "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib",
        # Homebrew
        "/opt/homebrew/lib/libonnxruntime.dylib",
        "/usr/local/lib/libonnxruntime.dylib",
        # System
        "libonnxruntime.dylib",
        "onnxruntime"
    );
    
    my $found = @paths.first(*.IO.e);
    $found // "onnxruntime";
}

constant ONNX_LIB = get-onnx-lib();

# ORT API version for this binding
constant ORT_API_VERSION = 16;

# OrtApiBase structure - entry point to ONNX Runtime C API
class OrtApiBase is repr('CStruct') is export {
    has Pointer $.GetApi;          # Function pointer: (uint32_t version) -> OrtApi*
    has Pointer $.GetVersionString; # Function pointer: () -> const char*
}

# Get the API base - this is the main entry point
sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) is export { * }

# Forward declaration
class OrtApiWrapper { ... }

# Global API instance
my $ORT-API;
my $API-INITIALIZED = False;

# Initialize the API
sub ort-initialize-api() is export {
    return if $API-INITIALIZED;
    
    my $api-base = OrtGetApiBase();
    die "Failed to get OrtApiBase" unless $api-base;
    
    # Get version string
    if $api-base.GetVersionString {
        my &get-version = nativecast(:(-->Str), $api-base.GetVersionString);
        my $version = get-version();
        note "ONNX Runtime version: $version" if %*ENV<ONNX_DEBUG>;
    }
    
    # Get the API struct
    if $api-base.GetApi {
        my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
        my $api-ptr = get-api(ORT_API_VERSION);
        die "Failed to get OrtApi for version {ORT_API_VERSION}" unless $api-ptr;
        
        $ORT-API = OrtApiWrapper.new(:$api-ptr);
        $API-INITIALIZED = True;
    } else {
        die "GetApi function pointer is null";
    }
}

# OrtApi function wrapper
class OrtApiWrapper {
    has Pointer $.api-ptr;
    has %!functions;
    
    # Function indices from the C header (verified from extract-api-functions.py)
    has %!func-indices = (
        # OrtStatus functions
        'CreateStatus' => 0,
        'GetErrorCode' => 1,
        'GetErrorMessage' => 2,
        # OrtEnv functions  
        'CreateEnv' => 3,
        'CreateEnvWithCustomLogger' => 4,
        'EnableTelemetryEvents' => 5,
        'DisableTelemetryEvents' => 6,
        # OrtSession functions
        'CreateSession' => 7,
        'CreateSessionFromArray' => 8,
        'Run' => 9,
        # OrtSessionOptions functions
        'CreateSessionOptions' => 10,
        'SetOptimizedModelFilePath' => 11,
        'SetSessionGraphOptimizationLevel' => 23,
        # Session introspection
        'SessionGetInputCount' => 30,
        'SessionGetOutputCount' => 31,
        'SessionGetInputName' => 36,
        'SessionGetOutputName' => 37,
        'SessionGetInputTypeInfo' => 38,
        'SessionGetOutputTypeInfo' => 39,
        # Tensor operations
        'CreateTensorWithDataAsOrtValue' => 44,
        'GetTensorMutableData' => 46,
        'CastTypeInfoToTensorInfo' => 50,
        'GetTensorElementType' => 55,
        'GetDimensionsCount' => 56,
        'GetDimensions' => 57,
        # Memory and allocator
        'CreateCpuMemoryInfo' => 64,
        'GetAllocatorWithDefaultOptions' => 78,
        # Release functions (verified indices)
        'ReleaseEnv' => 77,
        'ReleaseStatus' => 78,
        'ReleaseMemoryInfo' => 79,
        'ReleaseSession' => 80,
        'ReleaseValue' => 81,
        'ReleaseTypeInfo' => 83,
        'ReleaseTensorTypeAndShapeInfo' => 84,
        'ReleaseSessionOptions' => 85,
    );
    
    method get-function(Str $func-name) {
        return %!functions{$func-name} if %!functions{$func-name}:exists;
        
        die "Unknown function: $func-name" unless %!func-indices{$func-name}:exists;
        
        my $index = %!func-indices{$func-name};
        
        # Calculate offset - each function pointer is 8 bytes on 64-bit systems
        my $offset = $index * nativesizeof(Pointer);
        my $func-ptr-ptr = Pointer.new($!api-ptr.Int + $offset);
        
        # Read the function pointer value
        my $func-ptr = nativecast(CArray[Pointer], $func-ptr-ptr)[0];
        
        %!functions{$func-name} = $func-ptr;
        return $func-ptr;
    }
    
    # Core environment functions
    method CreateEnv(int32 $log-level, Str $logid) returns OrtStatus {
        my &func = nativecast(
            :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
            self.get-function('CreateEnv')
        );
        my $env-ptr = Pointer[OrtEnv].new;
        my $status = func($log-level, $logid, $env-ptr);
        return $status;
    }
    
    method CreateEnvPtr(int32 $log-level, Str $logid, Pointer[OrtEnv] $env-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
            self.get-function('CreateEnv')
        );
        return func($log-level, $logid, $env-ptr);
    }
    
    method ReleaseEnv(OrtEnv $env) {
        my &func = nativecast(
            :(OrtEnv),
            self.get-function('ReleaseEnv')
        );
        func($env);
    }
    
    # Session options
    method CreateSessionOptions(Pointer[OrtSessionOptions] $options-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(Pointer[OrtSessionOptions] is rw --> OrtStatus),
            self.get-function('CreateSessionOptions')
        );
        return func($options-ptr);
    }
    
    method SetSessionGraphOptimizationLevel(OrtSessionOptions $options, int32 $level) returns OrtStatus {
        my &func = nativecast(
            :(OrtSessionOptions, int32 --> OrtStatus),
            self.get-function('SetSessionGraphOptimizationLevel')
        );
        return func($options, $level);
    }
    
    method ReleaseSessionOptions(OrtSessionOptions $options) {
        my &func = nativecast(
            :(OrtSessionOptions),
            self.get-function('ReleaseSessionOptions')
        );
        func($options);
    }
    
    # Session management
    method CreateSession(OrtEnv $env, Str $model-path, OrtSessionOptions $options, Pointer[OrtSession] $session-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] is rw --> OrtStatus),
            self.get-function('CreateSession')
        );
        return func($env, $model-path, $options, $session-ptr);
    }
    
    method ReleaseSession(OrtSession $session) {
        my &func = nativecast(
            :(OrtSession),
            self.get-function('ReleaseSession')
        );
        func($session);
    }
    
    # Memory info
    method CreateCpuMemoryInfo(int32 $alloc-type, int32 $mem-type, Pointer[OrtMemoryInfo] $info-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(int32, int32, Pointer[OrtMemoryInfo] is rw --> OrtStatus),
            self.get-function('CreateCpuMemoryInfo')
        );
        return func($alloc-type, $mem-type, $info-ptr);
    }
    
    method ReleaseMemoryInfo(OrtMemoryInfo $info) {
        my &func = nativecast(
            :(OrtMemoryInfo),
            self.get-function('ReleaseMemoryInfo')
        );
        func($info);
    }
    
    # Status handling
    method GetErrorCode(OrtStatus $status) returns int32 {
        my &func = nativecast(
            :(OrtStatus --> int32),
            self.get-function('GetErrorCode')
        );
        return func($status);
    }
    
    method GetErrorMessage(OrtStatus $status) returns Str {
        my &func = nativecast(
            :(OrtStatus --> Str),
            self.get-function('GetErrorMessage')
        );
        return func($status);
    }
    
    method ReleaseStatus(OrtStatus $status) {
        return unless $status;
        my &func = nativecast(
            :(OrtStatus),
            self.get-function('ReleaseStatus')
        );
        func($status);
    }
    
    # Session introspection
    method SessionGetInputCount(OrtSession $session, Pointer[size_t] $count-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
            self.get-function('SessionGetInputCount')
        );
        return func($session, $count-ptr);
    }
    
    method SessionGetOutputCount(OrtSession $session, Pointer[size_t] $count-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
            self.get-function('SessionGetOutputCount')
        );
        return func($session, $count-ptr);
    }
    
    method GetAllocatorWithDefaultOptions(Pointer[OrtAllocator] $allocator-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(Pointer[OrtAllocator] is rw --> OrtStatus),
            self.get-function('GetAllocatorWithDefaultOptions')
        );
        return func($allocator-ptr);
    }
    
    method SessionGetInputName(OrtSession $session, size_t $index, OrtAllocator $allocator, Pointer[Str] $name-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
            self.get-function('SessionGetInputName')
        );
        return func($session, $index, $allocator, $name-ptr);
    }
    
    method SessionGetOutputName(OrtSession $session, size_t $index, OrtAllocator $allocator, Pointer[Str] $name-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
            self.get-function('SessionGetOutputName')
        );
        return func($session, $index, $allocator, $name-ptr);
    }
    
    method SessionGetInputTypeInfo(OrtSession $session, size_t $index, Pointer[OrtTypeInfo] $type-info-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, size_t, Pointer[OrtTypeInfo] is rw --> OrtStatus),
            self.get-function('SessionGetInputTypeInfo')
        );
        return func($session, $index, $type-info-ptr);
    }
    
    method SessionGetOutputTypeInfo(OrtSession $session, size_t $index, Pointer[OrtTypeInfo] $type-info-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, size_t, Pointer[OrtTypeInfo] is rw --> OrtStatus),
            self.get-function('SessionGetOutputTypeInfo')
        );
        return func($session, $index, $type-info-ptr);
    }
    
    method ReleaseTypeInfo(OrtTypeInfo $type-info) {
        my &func = nativecast(
            :(OrtTypeInfo),
            self.get-function('ReleaseTypeInfo')
        );
        func($type-info);
    }
    
    method CastTypeInfoToTensorInfo(OrtTypeInfo $type-info, Pointer[OrtTensorTypeAndShapeInfo] $tensor-info-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtTypeInfo, Pointer[OrtTensorTypeAndShapeInfo] is rw --> OrtStatus),
            self.get-function('CastTypeInfoToTensorInfo')
        );
        return func($type-info, $tensor-info-ptr);
    }
    
    method GetDimensionsCount(OrtTensorTypeAndShapeInfo $tensor-info, Pointer[size_t] $count-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo, Pointer[size_t] is rw --> OrtStatus),
            self.get-function('GetDimensionsCount')
        );
        return func($tensor-info, $count-ptr);
    }
    
    method GetDimensions(OrtTensorTypeAndShapeInfo $tensor-info, CArray[int64] $dims, size_t $dims-count) returns OrtStatus {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo, CArray[int64], size_t --> OrtStatus),
            self.get-function('GetDimensions')
        );
        return func($tensor-info, $dims, $dims-count);
    }
    
    method GetTensorElementType(OrtTensorTypeAndShapeInfo $tensor-info, Pointer[int32] $type-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo, Pointer[int32] is rw --> OrtStatus),
            self.get-function('GetTensorElementType')
        );
        return func($tensor-info, $type-ptr);
    }
    
    method ReleaseTensorTypeAndShapeInfo(OrtTensorTypeAndShapeInfo $tensor-info) {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo),
            self.get-function('ReleaseTensorTypeAndShapeInfo')
        );
        func($tensor-info);
    }
    
    # Tensor creation
    method CreateTensorWithDataAsOrtValue(OrtMemoryInfo $info, Pointer $data, size_t $data-len, CArray[int64] $shape, size_t $shape-len, int32 $type, Pointer[OrtValue] $value-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] is rw --> OrtStatus),
            self.get-function('CreateTensorWithDataAsOrtValue')
        );
        return func($info, $data, $data-len, $shape, $shape-len, $type, $value-ptr);
    }
    
    method GetTensorMutableData(OrtValue $value, Pointer[Pointer] $data-ptr-ptr is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtValue, Pointer[Pointer] is rw --> OrtStatus),
            self.get-function('GetTensorMutableData')
        );
        return func($value, $data-ptr-ptr);
    }
    
    method ReleaseValue(OrtValue $value) {
        my &func = nativecast(
            :(OrtValue),
            self.get-function('ReleaseValue')
        );
        func($value);
    }
    
    # Run inference
    method Run(OrtSession $session, OrtRunOptions $run-options, CArray[Str] $input-names, CArray[OrtValue] $inputs, size_t $input-count, CArray[Str] $output-names, size_t $output-count, CArray[OrtValue] $outputs is rw) returns OrtStatus {
        my &func = nativecast(
            :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] is rw --> OrtStatus),
            self.get-function('Run')
        );
        return func($session, $run-options, $input-names, $inputs, $input-count, $output-names, $output-count, $outputs);
    }
}

# Helper function to check status
sub check-status(OrtStatus $status, Str $operation) is export {
    return unless $status;
    
    if $ORT-API {
        my $code = $ORT-API.GetErrorCode($status);
        my $message = $ORT-API.GetErrorMessage($status);
        $ORT-API.ReleaseStatus($status);
        die "ONNX Runtime error in $operation: [$code] $message";
    } else {
        die "ONNX Runtime error in $operation (API not initialized)";
    }
}

# Convenience wrapper functions that use the initialized API
sub ort-create-env(int32 $log-level, Str $logid, Pointer[OrtEnv] $env-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.CreateEnvPtr($log-level, $logid, $env-ptr);
}

sub ort-release-env(OrtEnv $env) is export {
    return unless $ORT-API && $env;
    $ORT-API.ReleaseEnv($env);
}

sub ort-create-session-options(Pointer[OrtSessionOptions] $options-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.CreateSessionOptions($options-ptr);
}

sub ort-set-session-graph-optimization-level(OrtSessionOptions $options, int32 $level) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SetSessionGraphOptimizationLevel($options, $level);
}

sub ort-release-session-options(OrtSessionOptions $options) is export {
    return unless $ORT-API && $options;
    $ORT-API.ReleaseSessionOptions($options);
}

sub ort-create-session(OrtEnv $env, Str $model-path, OrtSessionOptions $options, Pointer[OrtSession] $session-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.CreateSession($env, $model-path, $options, $session-ptr);
}

sub ort-release-session(OrtSession $session) is export {
    return unless $ORT-API && $session;
    $ORT-API.ReleaseSession($session);
}

sub ort-create-cpu-memory-info(int32 $alloc-type, int32 $mem-type, Pointer[OrtMemoryInfo] $info-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.CreateCpuMemoryInfo($alloc-type, $mem-type, $info-ptr);
}

sub ort-release-memory-info(OrtMemoryInfo $info) is export {
    return unless $ORT-API && $info;
    $ORT-API.ReleaseMemoryInfo($info);
}

sub ort-release-status(OrtStatus $status) is export {
    return unless $ORT-API && $status;
    $ORT-API.ReleaseStatus($status);
}

sub ort-get-error-code(OrtStatus $status) returns int32 is export {
    return 0 unless $ORT-API && $status;
    return $ORT-API.GetErrorCode($status);
}

sub ort-get-error-message(OrtStatus $status) returns Str is export {
    return "" unless $ORT-API && $status;
    return $ORT-API.GetErrorMessage($status);
}

sub ort-session-get-input-count(OrtSession $session, Pointer[size_t] $count-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SessionGetInputCount($session, $count-ptr);
}

sub ort-session-get-output-count(OrtSession $session, Pointer[size_t] $count-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SessionGetOutputCount($session, $count-ptr);
}

sub ort-get-allocator-with-default-options(Pointer[OrtAllocator] $allocator-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.GetAllocatorWithDefaultOptions($allocator-ptr);
}

sub ort-session-get-input-name(OrtSession $session, size_t $index, OrtAllocator $allocator, Pointer[Str] $name-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SessionGetInputName($session, $index, $allocator, $name-ptr);
}

sub ort-session-get-output-name(OrtSession $session, size_t $index, OrtAllocator $allocator, Pointer[Str] $name-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SessionGetOutputName($session, $index, $allocator, $name-ptr);
}

sub ort-session-get-input-type-info(OrtSession $session, size_t $index, Pointer[OrtTypeInfo] $type-info-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SessionGetInputTypeInfo($session, $index, $type-info-ptr);
}

sub ort-session-get-output-type-info(OrtSession $session, size_t $index, Pointer[OrtTypeInfo] $type-info-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.SessionGetOutputTypeInfo($session, $index, $type-info-ptr);
}

sub ort-release-type-info(OrtTypeInfo $type-info) is export {
    return unless $ORT-API && $type-info;
    $ORT-API.ReleaseTypeInfo($type-info);
}

sub ort-cast-type-info-to-tensor-info(OrtTypeInfo $type-info, Pointer[OrtTensorTypeAndShapeInfo] $tensor-info-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.CastTypeInfoToTensorInfo($type-info, $tensor-info-ptr);
}

sub ort-get-dimensions-count(OrtTensorTypeAndShapeInfo $tensor-info, Pointer[size_t] $count-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.GetDimensionsCount($tensor-info, $count-ptr);
}

sub ort-get-dimensions(OrtTensorTypeAndShapeInfo $tensor-info, CArray[int64] $dims, size_t $dims-count) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.GetDimensions($tensor-info, $dims, $dims-count);
}

sub ort-get-tensor-element-type(OrtTensorTypeAndShapeInfo $tensor-info, Pointer[int32] $type-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.GetTensorElementType($tensor-info, $type-ptr);
}

sub ort-release-tensor-type-and-shape-info(OrtTensorTypeAndShapeInfo $tensor-info) is export {
    return unless $ORT-API && $tensor-info;
    $ORT-API.ReleaseTensorTypeAndShapeInfo($tensor-info);
}

sub ort-create-tensor-with-data-as-ort-value(OrtMemoryInfo $info, Pointer $data, size_t $data-len, CArray[int64] $shape, size_t $shape-len, int32 $type, Pointer[OrtValue] $value-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.CreateTensorWithDataAsOrtValue($info, $data, $data-len, $shape, $shape-len, $type, $value-ptr);
}

sub ort-get-tensor-mutable-data(OrtValue $value, Pointer[Pointer] $data-ptr-ptr is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.GetTensorMutableData($value, $data-ptr-ptr);
}

sub ort-release-value(OrtValue $value) is export {
    return unless $ORT-API && $value;
    $ORT-API.ReleaseValue($value);
}

sub ort-run(OrtSession $session, OrtRunOptions $run-options, CArray[Str] $input-names, CArray[OrtValue] $inputs, size_t $input-count, CArray[Str] $output-names, size_t $output-count, CArray[OrtValue] $outputs is rw) returns OrtStatus is export {
    ort-initialize-api();
    return $ORT-API.Run($session, $run-options, $input-names, $inputs, $input-count, $output-names, $output-count, $outputs);
}