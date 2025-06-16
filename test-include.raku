#!/usr/bin/env raku

# Include the ONNX library
EVALFILE 'onnx-lib.raku';

say "\nTesting ONNX Runtime with include file...";

# Create a session
say "Creating session for MNIST model...";
my $session = create-onnx-session("models/mnist.onnx", :log-level(LOG_WARNING));

say "Session created successfully!";
say "Input names: ", $session.input-names;
say "Output names: ", $session.output-names;

# Test with dummy data
say "\nRunning inference with dummy data...";
my @dummy-input = (^784).map({ rand });  # Random 28x28 image flattened

my %inputs = (
    'Input3' => @dummy-input,
);

my %outputs = run-onnx-session($session, %inputs);
say "Inference completed!";

# Show results
say "\nResults:";
my @probs = %outputs{$session.output-names[0]}[0];
say "Output probabilities: ", @probs;

# Find the predicted digit
my $max-idx = 0;
my $max-prob = @probs[0];
for 1..9 -> $i {
    if @probs[$i] > $max-prob {
        $max-prob = @probs[$i];
        $max-idx = $i;
    }
}

say "\nPredicted digit: $max-idx (probability: ", sprintf("%.2f%%", $max-prob * 100), ")";

say "\nTest completed successfully!";