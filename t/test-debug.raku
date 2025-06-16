#!/usr/bin/env raku

use lib 'lib';
use NativeCall;
use ONNX::Runtime::Types;
use ONNX::Runtime::API;

# Enable debug
%*ENV<ONNX_DEBUG> = "1";

say "Starting test...";

# Test API initialization
ort-initialize-api();
say "✓ API initialized";

# Test creating environment
my $env-ptr = Pointer[OrtEnv].new;
say "Creating environment...";
my $status = ort-create-env(ORT_LOGGING_LEVEL_WARNING, "TestEnv", $env-ptr);
say "Status: ", $status;

if $status {
    say "Error: ", ort-get-error-message($status);
    ort-release-status($status);
} else {
    say "✓ Environment created";
    my $env = $env-ptr.deref;
    say "Env: ", $env;
    ort-release-env($env);
}