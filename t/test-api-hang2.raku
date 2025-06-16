#!/usr/bin/env raku

say "1. Starting test...";

use lib 'lib';
say "2. lib added to path";

# Test loading modules one by one
{
    say "3. Testing Types module...";
    use ONNX::Runtime::Types;
    say "4. Types loaded OK";
}

{
    say "5. Testing API module...";
    # Set debug env var
    %*ENV<ONNX_DEBUG> = '1';
    
    # Try to load just the API module
    require ONNX::Runtime::API;
    say "6. API module loaded OK";
}

say "Done!";