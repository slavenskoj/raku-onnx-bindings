#!/usr/bin/env raku

use MONKEY-SEE-NO-EVAL;
use lib 'lib';
use ONNXRuntime;

say "Loading ONNX Runtime...";

# Load and evaluate the ONNX runtime code
my $code = load-onnx-runtime();
EVAL $code;

# Now we can use the functions
say "\nCreating ONNX session...";
my $session = create-onnx-session("models/mnist.onnx");
say "Session created!";
say "Input names: ", $session<input-names>;

# Test inference
say "\nRunning inference...";
my @dummy-input = (^784).map({ rand });
my @probs = run-inference($session, @dummy-input);

say "Probabilities: ", @probs;

# Find max
my $max-idx = 0;
my $max-prob = @probs[0];
for 1..9 -> $i {
    if @probs[$i] > $max-prob {
        $max-prob = @probs[$i];
        $max-idx = $i;
    }
}

say "\nPredicted digit: $max-idx (", sprintf("%.2f%%", $max-prob * 100), ")";