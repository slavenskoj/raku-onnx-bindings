unit module ONNX::Runtime::Lazy;

use NativeCall;
use ONNX::Runtime::Types;
use ONNX::Runtime::Direct;

# Lazy initialization approach
class Runtime is export {
    has $.env;
    has $.session;
    has $.options;
    has $.memory-info;
    has $.allocator;
    has @.input-names;
    has @.output-names;
    has %.input-info;
    has %.output-info;
    has Str $.model-path is required;
    has $.api;
    has Bool $!initialized = False;
    has $.log-level;
    
    method new(Str :$model-path!, :$log-level = ORT_LOGGING_LEVEL_WARNING) {
        self.bless(:$model-path, :$log-level);
    }
    
    method !ensure-initialized() {
        return if $!initialized;
        
        $!api = ONNX::Runtime::Direct::API.new;
        
        # Create environment
        my $env-ptr = Pointer[OrtEnv].new;
        my $status = $!api.create-env($!log-level, "RakuONNX", $env-ptr);
        die "Failed to create environment" if $status;
        $!env = $env-ptr.deref;
        
        # Create session options
        my $opts-ptr = Pointer[OrtSessionOptions].new;
        $status = $!api.create-session-options($opts-ptr);
        die "Failed to create session options" if $status;
        $!options = $opts-ptr.deref;
        
        # Set optimization level
        $status = $!api.set-optimization-level($!options, ORT_ENABLE_ALL);
        die "Failed to set optimization level" if $status;
        
        # Create session
        my $sess-ptr = Pointer[OrtSession].new;
        $status = $!api.create-session($!env, $!model-path, $!options, $sess-ptr);
        die "Failed to create session for $!model-path" if $status;
        $!session = $sess-ptr.deref;
        
        # Create memory info
        my $mem-ptr = Pointer[OrtMemoryInfo].new;
        $status = $!api.create-cpu-memory-info(OrtArenaAllocator, OrtMemTypeDefault, $mem-ptr);
        die "Failed to create memory info" if $status;
        $!memory-info = $mem-ptr.deref;
        
        # Get allocator
        my $alloc-ptr = Pointer[OrtAllocator].new;
        $status = $!api.get-allocator($alloc-ptr);
        die "Failed to get allocator" if $status;
        $!allocator = $alloc-ptr.deref;
        
        # Query model info
        self!query-model-info();
        
        $!initialized = True;
    }
    
    method !query-model-info() {
        # Get input count
        my $in-count-ptr = Pointer[size_t].new;
        my $status = $!api.get-input-count($!session, $in-count-ptr);
        die "Failed to get input count" if $status;
        my $in-count = $in-count-ptr.deref;
        
        # Get output count
        my $out-count-ptr = Pointer[size_t].new;
        $status = $!api.get-output-count($!session, $out-count-ptr);
        die "Failed to get output count" if $status;
        my $out-count = $out-count-ptr.deref;
        
        # Get input names and info
        for ^$in-count -> $i {
            my $name-ptr = Pointer[Str].new;
            $status = $!api.get-input-name($!session, $i, $!allocator, $name-ptr);
            die "Failed to get input name $i" if $status;
            my $name = $name-ptr.deref;
            @!input-names.push($name);
            
            # Get type info
            my $type-info-ptr = Pointer[OrtTypeInfo].new;
            $status = $!api.get-input-type-info($!session, $i, $type-info-ptr);
            die "Failed to get input type info $i" if $status;
            my $type-info = $type-info-ptr.deref;
            
            # Get tensor info
            my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
            $status = $!api.cast-to-tensor-info($type-info, $tensor-info-ptr);
            die "Failed to cast to tensor info" if $status;
            my $tensor-info = $tensor-info-ptr.deref;
            
            # Get dimensions
            my $dims-count-ptr = Pointer[size_t].new;
            $status = $!api.get-dimensions-count($tensor-info, $dims-count-ptr);
            die "Failed to get dimensions count" if $status;
            my $dims-count = $dims-count-ptr.deref;
            
            my $dims = CArray[int64].new;
            $dims[$dims-count - 1] = 0;  # Allocate
            $status = $!api.get-dimensions($tensor-info, $dims, $dims-count);
            die "Failed to get dimensions" if $status;
            
            my @shape = (^$dims-count).map({ $dims[$_] });
            
            # Get element type
            my $type-ptr = Pointer[int32].new;
            $status = $!api.get-tensor-element-type($tensor-info, $type-ptr);
            die "Failed to get element type" if $status;
            my $elem-type = $type-ptr.deref;
            
            %!input-info{$name} = {
                index => $i,
                shape => @shape,
                type => ONNXTensorElementDataType($elem-type),
            };
        }
        
        # Get output names and info
        for ^$out-count -> $i {
            my $name-ptr = Pointer[Str].new;
            $status = $!api.get-output-name($!session, $i, $!allocator, $name-ptr);
            die "Failed to get output name $i" if $status;
            my $name = $name-ptr.deref;
            @!output-names.push($name);
            
            # Get type info
            my $type-info-ptr = Pointer[OrtTypeInfo].new;
            $status = $!api.get-output-type-info($!session, $i, $type-info-ptr);
            die "Failed to get output type info $i" if $status;
            my $type-info = $type-info-ptr.deref;
            
            # Get tensor info
            my $tensor-info-ptr = Pointer[OrtTensorTypeAndShapeInfo].new;
            $status = $!api.cast-to-tensor-info($type-info, $tensor-info-ptr);
            die "Failed to cast to tensor info" if $status;
            my $tensor-info = $tensor-info-ptr.deref;
            
            # Get dimensions
            my $dims-count-ptr = Pointer[size_t].new;
            $status = $!api.get-dimensions-count($tensor-info, $dims-count-ptr);
            die "Failed to get dimensions count" if $status;
            my $dims-count = $dims-count-ptr.deref;
            
            my $dims = CArray[int64].new;
            $dims[$dims-count - 1] = 0;  # Allocate
            $status = $!api.get-dimensions($tensor-info, $dims, $dims-count);
            die "Failed to get dimensions" if $status;
            
            my @shape = (^$dims-count).map({ $dims[$_] });
            
            # Get element type
            my $type-ptr = Pointer[int32].new;
            $status = $!api.get-tensor-element-type($tensor-info, $type-ptr);
            die "Failed to get element type" if $status;
            my $elem-type = $type-ptr.deref;
            
            %!output-info{$name} = {
                index => $i,
                shape => @shape,
                type => ONNXTensorElementDataType($elem-type),
            };
        }
    }
    
    method input-names() {
        self!ensure-initialized();
        return @!input-names;
    }
    
    method output-names() {
        self!ensure-initialized();
        return @!output-names;
    }
    
    method input-info() {
        self!ensure-initialized();
        return %!input-info;
    }
    
    method output-info() {
        self!ensure-initialized();
        return %!output-info;
    }
    
    method run(%inputs) {
        self!ensure-initialized();
        
        # Create input tensors
        my @input-values;
        my $input-names = CArray[Str].new;
        my $input-tensors = CArray[OrtValue].new;
        
        for @!input-names.kv -> $idx, $name {
            $input-names[$idx] = $name;
            
            if %inputs{$name}:exists {
                my $data = %inputs{$name};
                my $info = %!input-info{$name};
                
                # Create tensor
                my $tensor = self!create-tensor($data, $info<shape>, $info<type>);
                @input-values.push($tensor);
                $input-tensors[$idx] = $tensor;
            } else {
                die "Missing required input: $name";
            }
        }
        
        # Prepare outputs
        my $output-names = CArray[Str].new;
        my $output-tensors = CArray[OrtValue].new;
        
        for @!output-names.kv -> $idx, $name {
            $output-names[$idx] = $name;
            $output-tensors[$idx] = OrtValue;
        }
        
        # Run inference
        my $status = $!api.run(
            $!session,
            OrtRunOptions,  # NULL
            $input-names,
            $input-tensors,
            @!input-names.elems,
            $output-names,
            @!output-names.elems,
            $output-tensors
        );
        die "Failed to run inference" if $status;
        
        # Extract outputs
        my %outputs;
        for @!output-names.kv -> $idx, $name {
            my $tensor = $output-tensors[$idx];
            my $info = %!output-info{$name};
            %outputs{$name} = self!extract-tensor-data($tensor, $info<shape>, $info<type>);
        }
        
        return %outputs;
    }
    
    method !create-tensor(@data, @shape, $type) {
        # Flatten data
        my @flat = @data.flat;
        
        # Create shape array
        my $shape-array = CArray[int64].new;
        for @shape.kv -> $i, $v {
            $shape-array[$i] = $v;
        }
        
        # Create data array based on type
        my ($c-array, $elem-size);
        
        given $type {
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
                $c-array = CArray[num32].new;
                for @flat.kv -> $i, $v {
                    $c-array[$i] = $v.Num;
                }
                $elem-size = nativesizeof(num32);
            }
            default {
                die "Unsupported tensor type: $type (only FLOAT supported for now)";
            }
        }
        
        # Create tensor
        my $tensor-ptr = Pointer[OrtValue].new;
        my $status = $!api.create-tensor(
            $!memory-info,
            nativecast(Pointer, $c-array),
            @flat.elems * $elem-size,
            $shape-array,
            @shape.elems,
            $type,
            $tensor-ptr
        );
        die "Failed to create tensor" if $status;
        
        return $tensor-ptr.deref;
    }
    
    method !extract-tensor-data($tensor, @shape, $type) {
        # Get data pointer
        my $data-ptr-ptr = Pointer[Pointer].new;
        my $status = $!api.get-tensor-data($tensor, $data-ptr-ptr);
        die "Failed to get tensor data" if $status;
        
        my $data-ptr = $data-ptr-ptr.deref;
        
        # Calculate total elements
        my $total = [*] @shape;
        
        # Extract data
        my @data;
        given $type {
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
                my $c-array = nativecast(CArray[num32], $data-ptr);
                @data = (^$total).map({ $c-array[$_] });
            }
            default {
                die "Unsupported tensor type for extraction: $type";
            }
        }
        
        # Simple reshape for 2D
        if @shape.elems == 2 {
            my @reshaped;
            for ^@shape[0] -> $i {
                my @row = @data[$i * @shape[1] ..^ ($i + 1) * @shape[1]];
                @reshaped.push(@row);
            }
            return @reshaped;
        }
        
        return @data;
    }
}