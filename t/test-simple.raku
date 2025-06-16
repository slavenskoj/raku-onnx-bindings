#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime;

# Enable debug output
%*ENV<ONNX_DEBUG> = "1";

say "Creating ONNX Runtime instance...";
my $onnx = ONNX::Runtime.new(model-path => "models/mnist.onnx");
say "Done!";