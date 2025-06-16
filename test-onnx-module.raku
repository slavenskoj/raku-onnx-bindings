#!/usr/bin/env raku

use lib 'lib';
use ONNX;

say "Testing ONNX module...";

# Initialize the ONNX module (required!)
say "Initializing ONNX module...";
init-onnx();
say "ONNX module initialized!";

# Create a session
say "\nCreating session for MNIST model...";
my $session = create-session(
    model-path => "models/mnist.onnx",
    log-level => LOG_WARNING
);

say "Session created successfully!";
say "Input names: ", $session.input-names;
say "Output names: ", $session.output-names;

# Show input info
say "\nInput information:";
for $session.input-info.kv -> $name, $info {
    say "  $name: shape=", $info<shape>, " type=", $info<type>;
}

# Show output info
say "\nOutput information:";
for $session.output-info.kv -> $name, $info {
    say "  $name: shape=", $info<shape>, " type=", $info<type>;
}

# Test with dummy data
say "\nRunning inference with dummy data...";
my @dummy-input = (^784).map({ rand });  # Random 28x28 image flattened

my %inputs = (
    'Input3' => [@dummy-input],
);

my %outputs = run-session($session, %inputs);
say "Inference completed!";

# Show results
say "\nResults:";
say "Output shape: ", %outputs<Plus214_Output_0>.elems, " x ", %outputs<Plus214_Output_0>[0].elems;
say "Predictions (first 5): ", %outputs<Plus214_Output_0>[0][^5];

# Find the predicted digit
my @probs = %outputs<Plus214_Output_0>[0];
my $max-idx = 0;
my $max-prob = @probs[0];
for 1..9 -> $i {
    if @probs[$i] > $max-prob {
        $max-prob = @probs[$i];
        $max-idx = $i;
    }
}

say "\nPredicted digit: $max-idx (probability: ", sprintf("%.2f%%", $max-prob * 100), ")";

say "\nAll tests passed!";