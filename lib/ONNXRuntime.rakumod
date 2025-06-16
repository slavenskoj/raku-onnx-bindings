unit module ONNXRuntime;

use NativeCall;

# Export the library path as a constant
constant ONNX_LIB is export = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";

# Simple include mechanism - user must call this
sub load-onnx-runtime() is export {
    # Return the code as a string to be EVALed
    return q:to/END/;
        use NativeCall;
        
        # Constants
        constant ORT_API_VERSION = 16;
        constant LOG_WARNING = 2;
        constant ORT_ENABLE_ALL = 99;
        constant OrtArenaAllocator = 0;
        constant OrtMemTypeDefault = 0;
        constant ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT = 1;
        
        # Types
        class OrtEnv is repr('CPointer') { }
        class OrtSession is repr('CPointer') { }
        class OrtSessionOptions is repr('CPointer') { }
        class OrtValue is repr('CPointer') { }
        class OrtMemoryInfo is repr('CPointer') { }
        class OrtAllocator is repr('CPointer') { }
        class OrtStatus is repr('CPointer') { }
        class OrtRunOptions is repr('CPointer') { }
        
        class OrtApiBase is repr('CStruct') {
            has Pointer $.GetApi;
            has Pointer $.GetVersionString;
        }
        
        # Get the library path from the module
        my $lib-path = %*ENV<ONNX_LIB_PATH> // ONNXRuntime::ONNX_LIB;
        
        # Create native sub dynamically
        my &OrtGetApiBase := nativecast(
            :(--> OrtApiBase),
            cglobal($lib-path, "OrtGetApiBase", Pointer)
        );
        
        # Initialize API
        my $api-base = OrtGetApiBase();
        my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
        my $API = get-api(ORT_API_VERSION);
        
        # Function table
        my %FUNCS;
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
            'GetTensorMutableData' => 46,
            'CreateTensorWithDataAsOrtValue' => 44,
            'Run' => 9,
        );
        
        for %indices.kv -> $name, $idx {
            %FUNCS{$name} = nativecast(CArray[Pointer], $API)[$idx];
        }
        
        # Export functions
        our sub create-onnx-session($model-path) {
            # Create environment
            my &create-env = nativecast(
                :(int32, Str, Pointer[OrtEnv] --> OrtStatus),
                %FUNCS<CreateEnv>
            );
            
            my $env-ptr = Pointer[OrtEnv].new;
            create-env(LOG_WARNING, "RakuONNX", $env-ptr);
            my $env = $env-ptr.deref;
            
            # Create session options
            my &create-opts = nativecast(
                :(Pointer[OrtSessionOptions] --> OrtStatus),
                %FUNCS<CreateSessionOptions>
            );
            
            my $opts-ptr = Pointer[OrtSessionOptions].new;
            create-opts($opts-ptr);
            my $options = $opts-ptr.deref;
            
            # Set optimization
            my &set-opt = nativecast(
                :(OrtSessionOptions, int32 --> OrtStatus),
                %FUNCS<SetSessionGraphOptimizationLevel>
            );
            set-opt($options, ORT_ENABLE_ALL);
            
            # Create session
            my &create-session = nativecast(
                :(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus),
                %FUNCS<CreateSession>
            );
            
            my $sess-ptr = Pointer[OrtSession].new;
            create-session($env, $model-path, $options, $sess-ptr);
            my $session = $sess-ptr.deref;
            
            # Create memory info
            my &create-mem = nativecast(
                :(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus),
                %FUNCS<CreateCpuMemoryInfo>
            );
            
            my $mem-ptr = Pointer[OrtMemoryInfo].new;
            create-mem(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
            my $memory-info = $mem-ptr.deref;
            
            # Get allocator
            my &get-alloc = nativecast(
                :(Pointer[OrtAllocator] --> OrtStatus),
                %FUNCS<GetAllocatorWithDefaultOptions>
            );
            
            my $alloc-ptr = Pointer[OrtAllocator].new;
            get-alloc($alloc-ptr);
            my $allocator = $alloc-ptr.deref;
            
            # Get input names
            my &get-in-count = nativecast(
                :(OrtSession, Pointer[size_t] --> OrtStatus),
                %FUNCS<SessionGetInputCount>
            );
            
            my $count-ptr = Pointer[size_t].new;
            get-in-count($session, $count-ptr);
            my $in-count = $count-ptr.deref;
            
            my &get-name = nativecast(
                :(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus),
                %FUNCS<SessionGetInputName>
            );
            
            my @input-names;
            for ^$in-count -> $i {
                my $name-ptr = Pointer[Str].new;
                get-name($session, $i, $allocator, $name-ptr);
                @input-names.push($name-ptr.deref);
            }
            
            # Return session data
            return {
                env => $env,
                session => $session,
                options => $options,
                memory-info => $memory-info,
                allocator => $allocator,
                input-names => @input-names,
                funcs => %FUNCS,
            };
        }
        
        our sub run-inference($sess, @input-data) {
            # Create input tensor
            my $c-array = CArray[num32].new;
            for @input-data.kv -> $i, $v {
                $c-array[$i] = $v.Num;
            }
            
            my $shape = CArray[int64].new;
            $shape[0] = 784;
            
            my &create-tensor = nativecast(
                :(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] --> OrtStatus),
                $sess<funcs><CreateTensorWithDataAsOrtValue>
            );
            
            my $tensor-ptr = Pointer[OrtValue].new;
            create-tensor(
                $sess<memory-info>,
                nativecast(Pointer, $c-array),
                784 * 4,
                $shape,
                1,
                ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
                $tensor-ptr
            );
            
            # Prepare inputs/outputs
            my $input-names = CArray[Str].new;
            $input-names[0] = $sess<input-names>[0];
            
            my $input-tensors = CArray[OrtValue].new;
            $input-tensors[0] = $tensor-ptr.deref;
            
            my $output-names = CArray[Str].new;
            $output-names[0] = "Plus214_Output_0";
            
            my $output-tensors = CArray[OrtValue].new;
            $output-tensors[0] = OrtValue;
            
            # Run
            my &run = nativecast(
                :(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] --> OrtStatus),
                $sess<funcs><Run>
            );
            
            run(
                $sess<session>,
                OrtRunOptions,
                $input-names,
                $input-tensors,
                1,
                $output-names,
                1,
                $output-tensors
            );
            
            # Get output
            my &get-data = nativecast(
                :(OrtValue, Pointer[Pointer] --> OrtStatus),
                $sess<funcs><GetTensorMutableData>
            );
            
            my $data-ptr-ptr = Pointer[Pointer].new;
            get-data($output-tensors[0], $data-ptr-ptr);
            
            my $data = nativecast(CArray[num32], $data-ptr-ptr.deref);
            my @probs = (^10).map({ $data[$_] });
            
            return @probs;
        }
        
        say "ONNX Runtime loaded!";
    END
}