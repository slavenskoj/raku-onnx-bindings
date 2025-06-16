unit module ONNX::Runtime::Direct;

use NativeCall;
use ONNX::Runtime::Types;

# Direct API without singleton pattern
constant ONNX_LIB = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
constant ORT_API_VERSION = 16;

# OrtApiBase
class OrtApiBase is repr('CStruct') {
    has Pointer $.GetApi;
    has Pointer $.GetVersionString;
}

sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }

# Direct API class without global state
class API is export {
    has $.api;
    has %!funcs;
    
    # Known good indices from testing
    has %!indices = (
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
        return %!funcs{$name} if %!funcs{$name}:exists;
        
        my $idx = %!indices{$name} or die "Unknown function: $name";
        my $offset = $idx * nativesizeof(Pointer);
        my $ptr = Pointer.new($!api.Int + $offset);
        my $func = nativecast(CArray[Pointer], $ptr)[0];
        
        %!funcs{$name} = $func;
        return $func;
    }
    
    method create-env(int32 $log-level, Str $logid, Pointer[OrtEnv] $env-ptr is rw) {
        my &func = nativecast(
            :(int32, Str, Pointer[OrtEnv] is rw --> OrtStatus),
            self.get-func('CreateEnv')
        );
        return func($log-level, $logid, $env-ptr);
    }
    
    method create-session-options(Pointer[OrtSessionOptions] $opts-ptr is rw) {
        my &func = nativecast(
            :(Pointer[OrtSessionOptions] is rw --> OrtStatus),
            self.get-func('CreateSessionOptions')
        );
        return func($opts-ptr);
    }
    
    method set-optimization-level(OrtSessionOptions $opts, int32 $level) {
        my &func = nativecast(
            :(OrtSessionOptions, int32 --> OrtStatus),
            self.get-func('SetSessionGraphOptimizationLevel')
        );
        return func($opts, $level);
    }
    
    method create-session(OrtEnv $env, Str $path, OrtSessionOptions $opts, Pointer[OrtSession] $sess-ptr is rw) {
        my &func = nativecast(
            :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] is rw --> OrtStatus),
            self.get-func('CreateSession')
        );
        return func($env, $path, $opts, $sess-ptr);
    }
    
    method get-input-count(OrtSession $sess, Pointer[size_t] $count-ptr is rw) {
        my &func = nativecast(
            :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
            self.get-func('SessionGetInputCount')
        );
        return func($sess, $count-ptr);
    }
    
    method get-output-count(OrtSession $sess, Pointer[size_t] $count-ptr is rw) {
        my &func = nativecast(
            :(OrtSession, Pointer[size_t] is rw --> OrtStatus),
            self.get-func('SessionGetOutputCount')
        );
        return func($sess, $count-ptr);
    }
    
    method get-allocator(Pointer[OrtAllocator] $alloc-ptr is rw) {
        my &func = nativecast(
            :(Pointer[OrtAllocator] is rw --> OrtStatus),
            self.get-func('GetAllocatorWithDefaultOptions')
        );
        return func($alloc-ptr);
    }
    
    method get-input-name(OrtSession $sess, size_t $idx, OrtAllocator $alloc, Pointer[Str] $name-ptr is rw) {
        my &func = nativecast(
            :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
            self.get-func('SessionGetInputName')
        );
        return func($sess, $idx, $alloc, $name-ptr);
    }
    
    method get-output-name(OrtSession $sess, size_t $idx, OrtAllocator $alloc, Pointer[Str] $name-ptr is rw) {
        my &func = nativecast(
            :(OrtSession, size_t, OrtAllocator, Pointer[Str] is rw --> OrtStatus),
            self.get-func('SessionGetOutputName')
        );
        return func($sess, $idx, $alloc, $name-ptr);
    }
    
    method create-cpu-memory-info(int32 $alloc-type, int32 $mem-type, Pointer[OrtMemoryInfo] $info-ptr is rw) {
        my &func = nativecast(
            :(int32, int32, Pointer[OrtMemoryInfo] is rw --> OrtStatus),
            self.get-func('CreateCpuMemoryInfo')
        );
        return func($alloc-type, $mem-type, $info-ptr);
    }
    
    method get-input-type-info(OrtSession $sess, size_t $idx, Pointer[OrtTypeInfo] $info-ptr is rw) {
        my &func = nativecast(
            :(OrtSession, size_t, Pointer[OrtTypeInfo] is rw --> OrtStatus),
            self.get-func('SessionGetInputTypeInfo')
        );
        return func($sess, $idx, $info-ptr);
    }
    
    method get-output-type-info(OrtSession $sess, size_t $idx, Pointer[OrtTypeInfo] $info-ptr is rw) {
        my &func = nativecast(
            :(OrtSession, size_t, Pointer[OrtTypeInfo] is rw --> OrtStatus),
            self.get-func('SessionGetOutputTypeInfo')
        );
        return func($sess, $idx, $info-ptr);
    }
    
    method cast-to-tensor-info(OrtTypeInfo $type-info, Pointer[OrtTensorTypeAndShapeInfo] $tensor-info-ptr is rw) {
        my &func = nativecast(
            :(OrtTypeInfo, Pointer[OrtTensorTypeAndShapeInfo] is rw --> OrtStatus),
            self.get-func('CastTypeInfoToTensorInfo')
        );
        return func($type-info, $tensor-info-ptr);
    }
    
    method get-dimensions-count(OrtTensorTypeAndShapeInfo $info, Pointer[size_t] $count-ptr is rw) {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo, Pointer[size_t] is rw --> OrtStatus),
            self.get-func('GetDimensionsCount')
        );
        return func($info, $count-ptr);
    }
    
    method get-dimensions(OrtTensorTypeAndShapeInfo $info, CArray[int64] $dims, size_t $count) {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo, CArray[int64], size_t --> OrtStatus),
            self.get-func('GetDimensions')
        );
        return func($info, $dims, $count);
    }
    
    method get-tensor-element-type(OrtTensorTypeAndShapeInfo $info, Pointer[int32] $type-ptr is rw) {
        my &func = nativecast(
            :(OrtTensorTypeAndShapeInfo, Pointer[int32] is rw --> OrtStatus),
            self.get-func('GetTensorElementType')
        );
        return func($info, $type-ptr);
    }
    
    method create-tensor(OrtMemoryInfo $mem-info, Pointer $data, size_t $data-len, CArray[int64] $shape, size_t $shape-len, int32 $type, Pointer[OrtValue] $value-ptr is rw) {
        my &func = nativecast(
            :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] is rw --> OrtStatus),
            self.get-func('CreateTensorWithDataAsOrtValue')
        );
        return func($mem-info, $data, $data-len, $shape, $shape-len, $type, $value-ptr);
    }
    
    method get-tensor-data(OrtValue $value, Pointer[Pointer] $data-ptr-ptr is rw) {
        my &func = nativecast(
            :(OrtValue, Pointer[Pointer] is rw --> OrtStatus),
            self.get-func('GetTensorMutableData')
        );
        return func($value, $data-ptr-ptr);
    }
    
    method run(OrtSession $sess, OrtRunOptions $opts, CArray[Str] $in-names, CArray[OrtValue] $inputs, size_t $in-count, CArray[Str] $out-names, size_t $out-count, CArray[OrtValue] $outputs is rw) {
        my &func = nativecast(
            :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] is rw --> OrtStatus),
            self.get-func('Run')
        );
        return func($sess, $opts, $in-names, $inputs, $in-count, $out-names, $out-count, $outputs);
    }
}