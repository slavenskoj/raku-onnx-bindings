#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime;

# This example shows how to use the ONNX Runtime Raku bindings
# You'll need an actual ONNX model file to run this

sub MAIN(Str $model-path = "model.onnx") {
    # Check if model file exists
    unless $model-path.IO.e {
        note "Model file '$model-path' not found!";
        note "Please provide a valid ONNX model file.";
        exit 1;
    }
    
    say "Loading ONNX model from: $model-path";
    
    # Create ONNX Runtime instance
    my $onnx = ONNX::Runtime.new(
        model-path => $model-path,
        log-level => ORT_LOGGING_LEVEL_WARNING
    );
    
    # Display model information
    say "\nModel Information:";
    say "Input names: ", $onnx.input-names;
    say "Output names: ", $onnx.output-names;
    
    say "\nInput details:";
    for $onnx.input-info.kv -> $name, $info {
        say "  $name:";
        say "    Shape: ", $info<shape>;
        say "    Type: ", $info<type>;
    }
    
    say "\nOutput details:";
    for $onnx.output-info.kv -> $name, $info {
        say "  $name:";
        say "    Shape: ", $info<shape>;
        say "    Type: ", $info<type>;
    }
    
    # Example inference (adjust based on your model's inputs)
    say "\nRunning inference...";
    
    # Prepare input data
    # This is just an example - adjust based on your model's requirements
    my %inputs;
    
    for $onnx.input-names -> $input-name {
        my $info = $onnx.input-info{$input-name};
        my @shape = $info<shape>;
        
        # Generate dummy data based on shape
        # In real usage, you'd provide actual input data
        my $total-elements = [*] @shape;
        my @data = (^$total-elements).map({ rand });
        
        # For 2D inputs, reshape the data
        if @shape.elems == 2 {
            my @reshaped;
            for ^@shape[0] -> $i {
                my @row = @data[$i * @shape[1] ..^ ($i + 1) * @shape[1]];
                @reshaped.push(@row);
            }
            %inputs{$input-name} = @reshaped;
        } else {
            %inputs{$input-name} = @data;
        }
        
        say "Created input '$input-name' with shape @shape[]";
    }
    
    # Run inference
    my %outputs = $onnx.run(%inputs);
    
    say "\nInference complete!";
    say "Output shapes:";
    for %outputs.kv -> $name, $data {
        my $shape = $data ~~ Array[Array] ?? "({$data.elems}, {$data[0].elems})" !! "({$data.elems})";
        say "  $name: $shape";
    }
    
    # Display first few values of each output
    say "\nOutput samples:";
    for %outputs.kv -> $name, $data {
        my @flat = $data.flat;
        my $preview = @flat[^min(5, @flat.elems)].map(*.fmt("%.4f")).join(", ");
        say "  $name: [$preview, ...]";
    }
}

# Example usage for specific models:

sub example-russian-accent-model() {
    # For the Russian accent detection model mentioned in the spec
    my $onnx = ONNX::Runtime.new(model-path => "russian_accent.onnx");
    
    # Load audio samples (16kHz)
    # In practice, you'd load this from a WAV file
    my @audio-samples = (^16000).map({ sin($_ * 0.1) * 0.5 + rand * 0.1 });
    
    my %inputs = (
        input => @audio-samples,  # Adjust input name based on your model
    );
    
    my %outputs = $onnx.run(%inputs);
    
    # Assuming the output is a probability
    my $russian-accent-probability = %outputs<output>[0];  # Adjust output name
    say "Russian accent probability: {$russian-accent-probability.fmt('%.2%')}";
}

sub example-image-classification() {
    # For image classification models
    my $onnx = ONNX::Runtime.new(model-path => "resnet50.onnx");
    
    # Image data would typically be loaded and preprocessed
    # This is just dummy data for the example
    my @image-data;
    for ^3 -> $c {      # 3 channels (RGB)
        for ^224 -> $h {    # 224 height
            for ^224 -> $w {    # 224 width
                @image-data.push(rand);
            }
        }
    }
    
    my %inputs = (
        input => [@image-data],  # Shape: [1, 3, 224, 224]
    );
    
    my %outputs = $onnx.run(%inputs);
    
    # Get top predictions
    my @logits = %outputs<output>.flat;
    my @top-indices = @logits.pairs.sort(*.value).reverse[^5].map(*.key);
    
    say "Top 5 predicted classes: @top-indices[]";
}