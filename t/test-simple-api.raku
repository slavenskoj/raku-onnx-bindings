#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime::Simple;

say "Testing Simple ONNX Runtime API...";
say "=" x 40;

# Load model
say "\nLoading MNIST model...";
my $onnx = ONNX::Runtime::Simple.new(model-path => "models/mnist.onnx");

say "✓ Model loaded successfully!";

# Display model info
say "\nModel information:";
say "  Input names: ", $onnx.input-names;
say "  Output names: ", $onnx.output-names;

for $onnx.input-info.kv -> $name, $info {
    say "\nInput '$name':";
    say "  Shape: ", $info<shape>;
    say "  Type: ", $info<type>;
}

for $onnx.output-info.kv -> $name, $info {
    say "\nOutput '$name':";
    say "  Shape: ", $info<shape>;
    say "  Type: ", $info<type>;
}

# Create test input (random 28x28 image)
say "\nCreating test input...";
my @input-data;
for ^1 -> $batch {
    my @batch-data;
    for ^1 -> $channel {
        my @channel-data;
        for ^28 -> $row {
            my @row-data;
            for ^28 -> $col {
                @row-data.push(rand);
            }
            @channel-data.push(@row-data);
        }
        @batch-data.push(@channel-data);
    }
    @input-data.push(@batch-data);
}

# Run inference
say "\nRunning inference...";
my %inputs = (
    Input3 => @input-data
);

my %outputs = $onnx.run(%inputs);

# Display results
say "\n✓ Inference completed!";
for %outputs.kv -> $name, $data {
    say "\nOutput '$name':";
    say "  Shape: [", $data.elems, "]";
    say "  Values: ", $data[0];
    
    # Find predicted digit
    my @scores = $data[0];
    my $max-score = @scores.max;
    my $predicted = (^10).first({ @scores[$_] == $max-score });
    say "  Predicted digit: $predicted (confidence: {$max-score.fmt('%.3f')})";
}

say "\n✓ Test completed successfully!";