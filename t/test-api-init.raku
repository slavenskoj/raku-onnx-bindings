#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime::API;
use ONNX::Runtime::Types;
use NativeCall;

say "Testing ONNX Runtime API initialization...";

# Test API initialization
try {
    ort-initialize-api();
    say "✓ API initialized successfully";
    
    # Test creating environment
    my $env-ptr = Pointer[OrtEnv].new;
    my $status = ort-create-env(ORT_LOGGING_LEVEL_WARNING, "test", $env-ptr);
    
    if $status {
        say "✗ Failed to create environment";
        say "  Error code: ", ort-get-error-code($status);
        say "  Error message: ", ort-get-error-message($status);
        ort-release-status($status);
    } else {
        say "✓ Environment created successfully";
        my $env = $env-ptr.deref;
        
        # Clean up
        ort-release-env($env);
        say "✓ Environment released successfully";
    }
    
    CATCH {
        default {
            say "✗ Error: ", .message;
            .backtrace.concise.say;
        }
    }
}

say "\nDone.";