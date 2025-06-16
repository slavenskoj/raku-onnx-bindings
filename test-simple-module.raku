#!/usr/bin/env raku

use lib 'lib';
use ONNX::Simple;

say "Testing ONNX::Simple module...";

# Test that we can load the module and access exports
say "OrtGetApiBase available: ", &OrtGetApiBase.defined;
say "Library path: ", ONNX::Simple::ONNX_LIB;

# Get and display the example script
say "\nExample script:";
say "=" x 60;
my $example = get-example-script();
say $example;
say "=" x 60;

# Save the example
"onnx-example.raku".IO.spurt($example);
say "\nExample saved to onnx-example.raku";

say "\nModule test completed!";