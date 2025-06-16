#!/usr/bin/env raku

use lib 'lib';

# Test if modules load
say "Testing ONNX Runtime Raku bindings...";

try {
    require ONNX::Runtime::Types;
    say "✓ Types module loaded";
}

try {
    require ONNX::Runtime::API;
    say "✓ API module loaded";
}

try {
    require ONNX::Runtime;
    say "✓ Main module loaded";
}

# Test if we can access the ONNX Runtime library
use ONNX::Runtime::API;

try {
    my $base = OrtGetApiBase();
    say "✓ Successfully called OrtGetApiBase()";
    say "✓ ONNX Runtime library is accessible";
    CATCH {
        default {
            say "✗ Could not access ONNX Runtime library";
            say "  Error: ", .message;
            say "\nMake sure ONNX Runtime is installed and accessible.";
            say "You can set ONNX_RUNTIME_LIB environment variable to point to the library.";
        }
    }
}

say "\nIf all checks passed, you're ready to use ONNX Runtime with Raku!";