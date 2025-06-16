use ONNX::Runtime::Types;
use ONNX::Runtime::API;
use NativeCall;

class ONNX::Runtime {
    has OrtEnv $!env;
    has OrtSession $!session;
    has OrtSessionOptions $!session-options;
    has OrtMemoryInfo $!memory-info;
    has OrtAllocator $!allocator;
    has @!input-names;
    has @!output-names;
    has %!input-info;
    has %!output-info;
    has $.model-path;
    has $.log-level;
    
    submethod BUILD(Str :$!model-path!, :$!log-level = ORT_LOGGING_LEVEL_WARNING) {
        self!init-environment();
        self!load-model();
        self!query-model-info();
    }
    
    method !init-environment() {
        # Create environment
        my $env-ptr = Pointer[OrtEnv].new;
        my $status = ort-create-env($!log-level, "RakuONNX", $env-ptr);
        check-status($status, "Creating environment");
        $!env = $env-ptr.deref;
        
        # Create session options
        my $options-ptr = Pointer[OrtSessionOptions].new;
        $status = ort-create-session-options($options-ptr);
        check-status($status, "Creating session options");
        $!session-options = $options-ptr.deref;
        
        # Set some default options
        $status = ort-set-session-graph-optimization-level($!session-options, ORT_ENABLE_ALL);
        check-status($status, "Setting optimization level");
        
        # Create memory info for CPU
        my $mem-info-ptr = Pointer[OrtMemoryInfo].new;
        $status = ort-create-cpu-memory-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-info-ptr);
        check-status($status, "Creating memory info");
        $!memory-info = $mem-info-ptr.deref;
        
        # Get default allocator
        my $allocator-ptr = Pointer[OrtAllocator].new;
        $status = ort-get-allocator-with-default-options($allocator-ptr);
        check-status($status, "Getting allocator");
        $!allocator = $allocator-ptr.deref;
    }
    
    method !load-model() {
        # Create session from model file
        my $session-ptr = Pointer[OrtSession].new;
        my $status = ort-create-session($!env, $!model-path, $!session-options, $session-ptr);
        check-status($status, "Loading model from $!model-path");
        $!session = $session-ptr.deref;
    }
    
    method !query-model-info() {
        # Get input count
        my $input-count-ptr = Pointer[size_t].new;
        my $status = ort-session-get-input-count($!session, $input-count-ptr);
        check-status($status, "Getting input count");
        my $input-count = $input-count-ptr.deref;
        
        # Get output count
        my $output-count-ptr = Pointer[size_t].new;
        $status = ort-session-get-output-count($!session, $output-count-ptr);
        check-status($status, "Getting output count");
        my $output-count = $output-count-ptr.deref;
        
        # Get input names and info
        for ^$input-count -> $i {
            my $name-ptr = Pointer[Str].new;
            $status = ort-session-get-input-name($!session, $i, $!allocator, $name-ptr);
            check-status($status, "Getting input name $i");
            my $name = $name-ptr.deref;
            @!input-names.push($name);
            
            # Get type info
            my $type-info-ptr = Pointer[OrtTypeInfo].new;
            $status = ort-session-get-input-type-info($!session, $i, $type-info-ptr);
            check-status($status, "Getting input type info $i");
            my $type-info = $type-info-ptr.deref;
            
            # Get tensor info
            my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
            $status = ort-cast-type-info-to-tensor-info($type-info, $tensor-info-ptr);
            check-status($status, "Casting to tensor info");
            my $tensor-info = $tensor-info-ptr.deref;
            
            # Get dimensions
            my $dims-count-ptr = Pointer[size_t].new;
            $status = ort-get-dimensions-count($tensor-info, $dims-count-ptr);
            check-status($status, "Getting dimensions count");
            my $dims-count = $dims-count-ptr.deref;
            
            my $dims = CArray[int64].new;
            $dims[$dims-count - 1] = 0;  # Allocate array
            $status = ort-get-dimensions($tensor-info, $dims, $dims-count);
            check-status($status, "Getting dimensions");
            
            my @shape = (^$dims-count).map({ $dims[$_] });
            
            # Get element type
            my $elem-type-ptr = Pointer[int32].new;
            $status = ort-get-tensor-element-type($tensor-info, $elem-type-ptr);
            check-status($status, "Getting element type");
            my $elem-type = $elem-type-ptr.deref;
            
            %!input-info{$name} = {
                index => $i,
                shape => @shape,
                type => ONNXTensorElementDataType($elem-type),
            };
            
            # Clean up
            ort-release-tensor-type-and-shape-info($tensor-info);
            ort-release-type-info($type-info);
        }
        
        # Get output names and info
        for ^$output-count -> $i {
            my $name-ptr = Pointer[Str].new;
            $status = ort-session-get-output-name($!session, $i, $!allocator, $name-ptr);
            check-status($status, "Getting output name $i");
            my $name = $name-ptr.deref;
            @!output-names.push($name);
            
            # Get type info
            my $type-info-ptr = Pointer[OrtTypeInfo].new;
            $status = ort-session-get-output-type-info($!session, $i, $type-info-ptr);
            check-status($status, "Getting output type info $i");
            my $type-info = $type-info-ptr.deref;
            
            # Get tensor info
            my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
            $status = ort-cast-type-info-to-tensor-info($type-info, $tensor-info-ptr);
            check-status($status, "Casting to tensor info");
            my $tensor-info = $tensor-info-ptr.deref;
            
            # Get dimensions
            my $dims-count-ptr = Pointer[size_t].new;
            $status = ort-get-dimensions-count($tensor-info, $dims-count-ptr);
            check-status($status, "Getting dimensions count");
            my $dims-count = $dims-count-ptr.deref;
            
            my $dims = CArray[int64].new;
            $dims[$dims-count - 1] = 0;  # Allocate array
            $status = ort-get-dimensions($tensor-info, $dims, $dims-count);
            check-status($status, "Getting dimensions");
            
            my @shape = (^$dims-count).map({ $dims[$_] });
            
            # Get element type
            my $elem-type-ptr = Pointer[int32].new;
            $status = ort-get-tensor-element-type($tensor-info, $elem-type-ptr);
            check-status($status, "Getting element type");
            my $elem-type = $elem-type-ptr.deref;
            
            %!output-info{$name} = {
                index => $i,
                shape => @shape,
                type => ONNXTensorElementDataType($elem-type),
            };
            
            # Clean up
            ort-release-tensor-type-and-shape-info($tensor-info);
            ort-release-type-info($type-info);
        }
    }
    
    method run(%inputs, :%types = {}) {
        # Validate inputs
        for %inputs.kv -> $name, $data {
            die "Unknown input '$name'. Available inputs: @!input-names[]"
                unless %!input-info{$name}:exists;
        }
        
        # Create input tensors
        my @input-values;
        my $input-names = CArray[Str].new;
        my $input-tensors = CArray[OrtValue].new;
        
        for @!input-names.kv -> $idx, $name {
            $input-names[$idx] = $name;
            
            if %inputs{$name}:exists {
                my $data = %inputs{$name};
                my $info = %!input-info{$name};
                
                # Use provided type or default to model's expected type
                my $type = %types{$name} // $info<type>;
                
                # Create tensor from data
                my $tensor = self!create-tensor($data, $info<shape>, $type);
                @input-values.push($tensor);
                $input-tensors[$idx] = $tensor;
            } else {
                die "Missing required input: $name";
            }
        }
        
        # Prepare output arrays
        my $output-names = CArray[Str].new;
        my $output-tensors = CArray[OrtValue].new;
        
        for @!output-names.kv -> $idx, $name {
            $output-names[$idx] = $name;
            $output-tensors[$idx] = OrtValue;
        }
        
        # Run inference
        my $status = ort-run(
            $!session,
            OrtRunOptions,  # NULL run options
            $input-names,
            $input-tensors,
            @!input-names.elems,
            $output-names,
            @!output-names.elems,
            $output-tensors
        );
        check-status($status, "Running inference");
        
        # Extract outputs
        my %outputs;
        for @!output-names.kv -> $idx, $name {
            my $tensor = $output-tensors[$idx];
            my $info = %!output-info{$name};
            %outputs{$name} = self!extract-tensor-data($tensor, $info<shape>, $info<type>);
            ort-release-value($tensor);
        }
        
        # Clean up inputs
        for @input-values -> $tensor {
            ort-release-value($tensor);
        }
        
        return %outputs;
    }
    
    method !create-tensor(@data, @shape, $type) {
        # Flatten data if needed
        my @flat-data = @data.flat;
        
        # Create shape array
        my $shape-array = CArray[int64].new;
        for @shape.kv -> $i, $v {
            $shape-array[$i] = $v;
        }
        
        # Create appropriate C array based on type
        my ($c-array, $elem-size, $actual-type);
        
        given $type {
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
                $c-array = CArray[num32].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Num;
                }
                $elem-size = nativesizeof(num32);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE {
                $c-array = CArray[num64].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Num;
                }
                $elem-size = nativesizeof(num64);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8 {
                $c-array = CArray[int8].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(int8);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8 {
                $c-array = CArray[uint8].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(uint8);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16 {
                $c-array = CArray[int16].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(int16);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16 {
                $c-array = CArray[uint16].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(uint16);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 {
                $c-array = CArray[int32].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(int32);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32 {
                $c-array = CArray[uint32].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(uint32);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 {
                $c-array = CArray[int64].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(int64);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64 {
                $c-array = CArray[uint64].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v.Int;
                }
                $elem-size = nativesizeof(uint64);
                $actual-type = $type;
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL {
                # ONNX bool is stored as uint8
                $c-array = CArray[uint8].new;
                for @flat-data.kv -> $i, $v {
                    $c-array[$i] = $v ?? 1 !! 0;
                }
                $elem-size = nativesizeof(uint8);
                $actual-type = $type;
            }
            default {
                die "Unsupported tensor type: $type";
            }
        }
        
        # Create tensor
        my $tensor-ptr = Pointer[OrtValue].new;
        my $status = ort-create-tensor-with-data-as-ort-value(
            $!memory-info,
            nativecast(Pointer, $c-array),
            @flat-data.elems * $elem-size,
            $shape-array,
            @shape.elems,
            $actual-type,
            $tensor-ptr
        );
        check-status($status, "Creating tensor");
        
        return $tensor-ptr.deref;
    }
    
    method !extract-tensor-data($tensor, @shape, $type) {
        # Get data pointer
        my $data-ptr-ptr = Pointer[Pointer].new;
        my $status = ort-get-tensor-mutable-data($tensor, $data-ptr-ptr);
        check-status($status, "Getting tensor data");
        
        my $data-ptr = $data-ptr-ptr.deref;
        
        # Calculate total elements
        my $total-elements = [*] @shape;
        
        # Extract data based on type
        my @data;
        given $type {
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
                my $c-array = nativecast(CArray[num32], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE {
                my $c-array = nativecast(CArray[num64], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8 {
                my $c-array = nativecast(CArray[int8], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8 {
                my $c-array = nativecast(CArray[uint8], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16 {
                my $c-array = nativecast(CArray[int16], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16 {
                my $c-array = nativecast(CArray[uint16], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 {
                my $c-array = nativecast(CArray[int32], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32 {
                my $c-array = nativecast(CArray[uint32], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 {
                my $c-array = nativecast(CArray[int64], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64 {
                my $c-array = nativecast(CArray[uint64], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL {
                my $c-array = nativecast(CArray[uint8], $data-ptr);
                @data = (^$total-elements).map({ $c-array[$_] ?? True !! False });
            }
            default {
                die "Unsupported tensor type for extraction: $type";
            }
        }
        
        # Reshape if needed
        if @shape.elems > 1 {
            # Simple reshape for 2D arrays
            if @shape.elems == 2 {
                my @reshaped;
                for ^@shape[0] -> $i {
                    my @row;
                    for ^@shape[1] -> $j {
                        @row.push(@data[$i * @shape[1] + $j]);
                    }
                    @reshaped.push(@row);
                }
                return @reshaped;
            }
            # For now, return flat array for higher dimensions
            return @data;
        }
        
        return @data;
    }
    
    method input-names() { @!input-names }
    method output-names() { @!output-names }
    method input-info() { %!input-info }
    method output-info() { %!output-info }
    
    submethod DESTROY() {
        ort-release-memory-info($!memory-info) if $!memory-info;
        ort-release-session($!session) if $!session;
        ort-release-session-options($!session-options) if $!session-options;
        ort-release-env($!env) if $!env;
    }
}