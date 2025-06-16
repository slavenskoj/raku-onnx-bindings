unit module ONNX::Runtime::Types;

use NativeCall;

# API Version
constant ORT_API_VERSION = 16;

# Opaque pointer types for ONNX Runtime structures
class OrtStatus is repr('CPointer') is export { }
class OrtEnv is repr('CPointer') is export { }
class OrtSessionOptions is repr('CPointer') is export { }
class OrtSession is repr('CPointer') is export { }
class OrtMemoryInfo is repr('CPointer') is export { }
class OrtValue is repr('CPointer') is export { }
class OrtTypeInfo is repr('CPointer') is export { }
class OrtTensorTypeAndShapeInfo is repr('CPointer') is export { }
class OrtModelMetadata is repr('CPointer') is export { }
class OrtAllocator is repr('CPointer') is export { }
class OrtApi is repr('CPointer') is export { }
class OrtThreadingOptions is repr('CPointer') is export { }
class OrtRunOptions is repr('CPointer') is export { }
class OrtCustomOpDomain is repr('CPointer') is export { }
class OrtMapTypeInfo is repr('CPointer') is export { }
class OrtSequenceTypeInfo is repr('CPointer') is export { }
class OrtOptionalTypeInfo is repr('CPointer') is export { }

# Error codes
enum OrtErrorCode is export (
    ORT_OK => 0,
    ORT_FAIL => 1,
    ORT_INVALID_ARGUMENT => 2,
    ORT_NO_SUCHFILE => 3,
    ORT_NO_MODEL => 4,
    ORT_ENGINE_ERROR => 5,
    ORT_RUNTIME_EXCEPTION => 6,
    ORT_INVALID_PROTOBUF => 7,
    ORT_MODEL_LOADED => 8,
    ORT_NOT_IMPLEMENTED => 9,
    ORT_INVALID_GRAPH => 10,
    ORT_EP_FAIL => 11,
);

# Logging levels
enum OrtLoggingLevel is export (
    ORT_LOGGING_LEVEL_VERBOSE => 0,
    ORT_LOGGING_LEVEL_INFO => 1,
    ORT_LOGGING_LEVEL_WARNING => 2,
    ORT_LOGGING_LEVEL_ERROR => 3,
    ORT_LOGGING_LEVEL_FATAL => 4,
);

# Tensor element data types
enum ONNXTensorElementDataType is export (
    ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED => 0,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT => 1,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8 => 2,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8 => 3,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16 => 4,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16 => 5,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 => 6,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 => 7,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING => 8,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL => 9,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16 => 10,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE => 11,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32 => 12,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64 => 13,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX64 => 14,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX128 => 15,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16 => 16,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT8E4M3FN => 17,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT8E4M3FNUZ => 18,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT8E5M2 => 19,
    ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT8E5M2FNUZ => 20,
);

# ONNX value types
enum ONNXType is export (
    ONNX_TYPE_UNKNOWN => 0,
    ONNX_TYPE_TENSOR => 1,
    ONNX_TYPE_SEQUENCE => 2,
    ONNX_TYPE_MAP => 3,
    ONNX_TYPE_OPAQUE => 4,
    ONNX_TYPE_SPARSETENSOR => 5,
    ONNX_TYPE_OPTIONAL => 6,
);

# Graph optimization levels
enum GraphOptimizationLevel is export (
    ORT_DISABLE_ALL => 0,
    ORT_ENABLE_BASIC => 1,
    ORT_ENABLE_EXTENDED => 2,
    ORT_ENABLE_ALL => 99,
);

# Execution modes
enum ExecutionMode is export (
    ORT_SEQUENTIAL => 0,
    ORT_PARALLEL => 1,
);

# Memory types
enum OrtMemType is export (
    OrtMemTypeCPUInput => -2,
    OrtMemTypeCPUOutput => -1,
    OrtMemTypeCPU => -1,
    OrtMemTypeDefault => 0,
);

# Allocator types
enum OrtAllocatorType is export (
    OrtInvalidAllocator => -1,
    OrtDeviceAllocator => 0,
    OrtArenaAllocator => 1,
);

# Memory info device types
enum OrtMemoryInfoDeviceType is export (
    OrtMemoryInfoDeviceType_CPU => 0,
    OrtMemoryInfoDeviceType_GPU => 1,
    OrtMemoryInfoDeviceType_FPGA => 2,
);

# Platform-specific character type
our constant ORTCHAR_T = $*DISTRO.is-win ?? 'utf16' !! 'utf8';

# Helper to convert Raku string to platform-specific ONNX string
sub to-ort-string(Str $str) is export {
    $*DISTRO.is-win ?? $str.encode('utf16') !! $str;
}