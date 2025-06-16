#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime;

say "Testing ONNX Runtime with MNIST model...";

# Create runtime instance
my $onnx = ONNX::Runtime.new(model-path => "models/mnist.onnx");

say "\nModel loaded successfully!";
say "Input names: ", $onnx.input-names;
say "Output names: ", $onnx.output-names;

say "\n✓ Test completed!";