#!/usr/bin/env raku

use lib 'lib';
use ONNX::ScriptWrapper;

say "Testing ONNX::ScriptWrapper module...";

# Test module loading
test-script-wrapper();

# Create a session
say "\nCreating session...";
my $session = create-session(model-path => "models/mnist.onnx");
say "Session created!";
say "Input names: ", $session.input-names;
say "Output names: ", $session.output-names;

# Run inference
say "\nRunning inference...";
my @dummy-input = (^784).map({ rand });
my %inputs = (
    'Input3' => @dummy-input,
);

my %outputs = $session.run(%inputs);
say "Inference completed!";

# Show results
for %outputs.kv -> $name, @probs {
    say "\nOutput '$name':";
    say "Probabilities: ", @probs.map({ sprintf("%.4f", $_) }).join(", ");
    
    my $max-idx = @probs.pairs.max(*.value).key;
    say "Predicted digit: $max-idx (", sprintf("%.2f%%", @probs[$max-idx] * 100), ")";
}

say "\nTest completed!";