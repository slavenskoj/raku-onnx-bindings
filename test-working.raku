#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime::Working;

say "Testing ONNX Runtime Working module...";

# Create session
say "Creating session...";
my $session = ONNX::Runtime::Working::Session.new(
    model-path => "models/mnist.onnx",
    log-level => ONNX::Runtime::Working::WARNING
);

say "Session created successfully!";
say "Input names: ", $session.input-names;
say "Output names: ", $session.output-names;

# Test with dummy data
say "\nTesting inference with dummy data...";
my @dummy-input = (^784).map({ rand });  # Random 28x28 image flattened

my %inputs = (
    'Input3' => [@dummy-input],
);

my %outputs = $session.run(%inputs);
say "Inference completed!";

say "\nOutput shape: ", %outputs<Plus214_Output_0>.elems, " x ", %outputs<Plus214_Output_0>[0].elems;
say "First few predictions: ", %outputs<Plus214_Output_0>[0][^5];

say "\nAll tests passed!";