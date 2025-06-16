#!/usr/bin/env raku

use lib 'lib';
use ONNX::Wrapper;

say "Testing ONNX::Wrapper module...";

# Test that the module loads
test-wrapper();

# Create a session
say "\nCreating ONNX session for MNIST model...";
my $session;
try {
    $session = create-session(model-path => "models/mnist.onnx");
    say "Session created successfully!";
    say "Input names: ", $session.input-names;
    say "Output names: ", $session.output-names;
    CATCH {
        default {
            say "Failed to create session: $_";
            exit 1;
        }
    }
}

# Test inference
say "\nRunning inference with dummy data...";
my @dummy-input = (^784).map({ rand });

my %inputs = (
    'Input3' => @dummy-input,
);

my %outputs;
try {
    %outputs = $session.run(%inputs);
    say "Inference completed successfully!";
    CATCH {
        default {
            say "Failed to run inference: $_";
            $session.close;
            exit 1;
        }
    }
}

# Show results
say "\nResults:";
for %outputs.kv -> $name, @probs {
    say "Output '$name': ", @probs;
    
    # Find max probability
    my $max-idx = 0;
    my $max-prob = @probs[0];
    for 1..9 -> $i {
        if @probs[$i] > $max-prob {
            $max-prob = @probs[$i];
            $max-idx = $i;
        }
    }
    
    say "Predicted digit: $max-idx (probability: ", sprintf("%.2f%%", $max-prob * 100), ")";
}

# Clean up
say "\nClosing session...";
$session.close;

say "\nAll tests passed!";