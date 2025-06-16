#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime;
use ONNX::Runtime::Types;

# This example demonstrates using different tensor data types

sub MAIN() {
    say "ONNX Runtime Tensor Types Example";
    say "=================================\n";
    
    # Show supported tensor types
    say "Supported tensor types:";
    say "  - Float32 (ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)";
    say "  - Float64/Double (ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE)";
    say "  - Int8 (ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8)";
    say "  - UInt8 (ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8)";
    say "  - Int16 (ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16)";
    say "  - UInt16 (ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16)";
    say "  - Int32 (ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32)";
    say "  - UInt32 (ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32)";
    say "  - Int64 (ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64)";
    say "  - UInt64 (ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64)";
    say "  - Bool (ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL)";
    say "";
    
    # Example: Creating tensors with different types
    example-float-tensors();
    example-integer-tensors();
    example-bool-tensors();
}

sub example-float-tensors() {
    say "\n--- Float Tensor Examples ---";
    
    # Float32 tensor
    my @float32-data = [1.5, 2.7, 3.14, 4.2];
    say "Float32 data: @float32-data[]";
    
    # Float64/Double tensor
    my @float64-data = [1.234567890123456, 2.345678901234567, 3.456789012345678];
    say "Float64 data: @float64-data[]";
    
    # If you have a model that accepts float inputs, you could use:
    # my %inputs = (
    #     float_input => @float32-data,
    #     double_input => @float64-data
    # );
    # my %outputs = $onnx.run(%inputs);
}

sub example-integer-tensors() {
    say "\n--- Integer Tensor Examples ---";
    
    # 8-bit integers
    my @int8-data = [-128, -64, 0, 63, 127];
    my @uint8-data = [0, 64, 128, 192, 255];
    say "Int8 data: @int8-data[]";
    say "UInt8 data: @uint8-data[]";
    
    # 16-bit integers
    my @int16-data = [-32768, -1000, 0, 1000, 32767];
    my @uint16-data = [0, 1000, 32768, 50000, 65535];
    say "Int16 data: @int16-data[]";
    say "UInt16 data: @uint16-data[]";
    
    # 32-bit integers
    my @int32-data = [-2147483648, -1000000, 0, 1000000, 2147483647];
    my @uint32-data = [0, 1000000, 2147483648, 3000000000, 4294967295];
    say "Int32 data: ", @int32-data[^3], "...";
    say "UInt32 data: ", @uint32-data[^3], "...";
    
    # 64-bit integers
    my @int64-data = [-9223372036854775808, 0, 9223372036854775807];
    my @uint64-data = [0, 9223372036854775808, 18446744073709551615];
    say "Int64 data: ", @int64-data[^2], "...";
    say "UInt64 data: ", @uint64-data[^2], "...";
}

sub example-bool-tensors() {
    say "\n--- Boolean Tensor Examples ---";
    
    my @bool-data = [True, False, True, True, False];
    say "Bool data: @bool-data[]";
    
    # Boolean tensors are useful for masks and conditions
    my @mask = [
        [True,  False, True],
        [False, True,  False],
        [True,  True,  False]
    ];
    say "2D boolean mask:";
    for @mask -> @row {
        say "  ", @row.map({ $_ ?? "T" !! "F" }).join(" ");
    }
}

# Example with a hypothetical model that uses different tensor types
sub example-multi-type-model(Str $model-path) {
    return unless $model-path.IO.e;
    
    say "\n--- Multi-Type Model Example ---";
    my $onnx = ONNX::Runtime.new(model-path => $model-path);
    
    # Display input types
    say "Model inputs:";
    for $onnx.input-info.kv -> $name, $info {
        my $type-name = type-name-for($info<type>);
        say "  $name: $type-name, shape: $info<shape>";
    }
    
    # Prepare inputs with appropriate types
    my %inputs;
    my %types;
    
    for $onnx.input-info.kv -> $name, $info {
        my @shape = $info<shape>;
        my $total-elements = [*] @shape;
        
        # Generate appropriate dummy data based on type
        given $info<type> {
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT {
                %inputs{$name} = (^$total-elements).map({ rand });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 {
                %inputs{$name} = (^$total-elements).map({ (-100..100).pick });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 {
                %inputs{$name} = (^$total-elements).map({ (-1000..1000).pick });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL {
                %inputs{$name} = (^$total-elements).map({ Bool.pick });
            }
            when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8 {
                %inputs{$name} = (^$total-elements).map({ (0..255).pick });
            }
            default {
                # Default to float
                %inputs{$name} = (^$total-elements).map({ rand });
            }
        }
    }
    
    # Run inference
    my %outputs = $onnx.run(%inputs);
    
    say "\nOutputs:";
    for %outputs.kv -> $name, $data {
        my $preview = $data.flat[^min(5, $data.flat.elems)].join(", ");
        say "  $name: [$preview, ...]";
    }
}

sub type-name-for($type) {
    given $type {
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT { "float32" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE { "float64" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8 { "int8" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8 { "uint8" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16 { "int16" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16 { "uint16" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 { "int32" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32 { "uint32" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 { "int64" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64 { "uint64" }
        when ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL { "bool" }
        default { "unknown" }
    }
}

# Example: Image processing with uint8 data
sub example-image-processing() {
    say "\n--- Image Processing Example ---";
    
    # Images are typically uint8 with values 0-255
    # Shape: [batch, channels, height, width] or [batch, height, width, channels]
    
    # Create a small "image" (3x3 RGB)
    my @image = [
        # Red channel
        [[255, 128, 0],
         [128, 255, 128],
         [0, 128, 255]],
        # Green channel
        [[0, 128, 255],
         [128, 255, 128],
         [255, 128, 0]],
        # Blue channel
        [[128, 0, 128],
         [0, 255, 0],
         [128, 0, 128]]
    ];
    
    say "Sample 3x3 RGB image (as uint8 values):";
    for ^3 -> $c {
        say "Channel $c:";
        for @image[$c] -> @row {
            say "  ", @row.join(" ");
        }
    }
    
    # If you have an image classification model:
    # my %inputs = (
    #     image => @image.flat,  # Flatten to 1D array
    # );
    # my %types = (
    #     image => ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8
    # );
    # my %outputs = $onnx.run(%inputs, :%types);
}

# Call the image processing example
example-image-processing();