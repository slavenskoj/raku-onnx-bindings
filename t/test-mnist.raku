#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime::Simple;

# Test MNIST model
say "Creating runtime for MNIST model...";
my $rt = ONNX::Runtime::Simple::Runtime.new(model-path => "models/mnist.onnx");

say "Model loaded successfully!";
say "Inputs: ", $rt.input-names;
say "Input info: ", $rt.input-info;
say "\nOutputs: ", $rt.output-names;
say "Output info: ", $rt.output-info;

# Create sample input - 28x28 image with all zeros
my @image = (^28).map({ [(0.0) xx 28] });

say "\nRunning inference with zeros...";
my %outputs = $rt.run({ Input3 => @image });

say "Inference complete!";
say "Output shape: ", %outputs<Plus214_Output_0>.elems;
say "Predictions: ", %outputs<Plus214_Output_0>;