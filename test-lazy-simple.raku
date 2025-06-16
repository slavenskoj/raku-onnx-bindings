#!/usr/bin/env raku

use lib 'lib';

say "Testing lazy initialization approach...";

# First test: Can we load the module?
say "1. Loading ONNX::Runtime::Lazy...";
use ONNX::Runtime::Lazy;
say "2. Module loaded successfully";

# Second test: Can we create an instance?
say "3. Creating Runtime instance...";
my $rt = ONNX::Runtime::Lazy::Runtime.new(model-path => "models/mnist.onnx");
say "4. Instance created successfully";

# Third test: Does lazy initialization work?
say "5. Testing lazy initialization (this may hang)...";
try {
    my @names = $rt.input-names();
    say "6. Got input names: ", @names.perl;
    CATCH {
        default {
            say "6. Error during lazy initialization: ", .message;
        }
    }
}

say "Done!";