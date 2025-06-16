#!/usr/bin/env raku

# Test script to verify distribution readiness
use JSON::Fast;

say "Testing ONNX::Runtime distribution...";

# Check META6.json
my $meta-file = 'META6.json'.IO;
if $meta-file.e {
    say "✓ META6.json exists";
    try {
        my $meta = from-json($meta-file.slurp);
        say "✓ META6.json is valid JSON";
        say "  Name: ", $meta<name>;
        say "  Version: ", $meta<version>;
        say "  Auth: ", $meta<auth>;
    }
    CATCH {
        say "✗ META6.json is not valid JSON";
    }
} else {
    say "✗ META6.json missing";
}

# Check required files
my @required-files = <
    LICENSE
    README.md
    Changes
    lib/ONNX/Runtime.rakumod
    lib/ONNX/Runtime/API.rakumod
    lib/ONNX/Runtime/Types.rakumod
>;

for @required-files -> $file {
    if $file.IO.e {
        say "✓ $file exists";
    } else {
        say "✗ $file missing";
    }
}

# Check tests
my @test-files = dir('t', test => *.ends-with('.t'));
if @test-files {
    say "✓ Found ", @test-files.elems, " test file(s)";
} else {
    say "✗ No test files found";
}

# Try to load modules
say "\nTrying to load modules...";
try {
    use lib 'lib';
    require ONNX::Runtime::Types;
    say "✓ ONNX::Runtime::Types loads";
}
try {
    use lib 'lib';
    require ONNX::Runtime::API;
    say "✓ ONNX::Runtime::API loads";
}
try {
    use lib 'lib';
    require ONNX::Runtime;
    say "✓ ONNX::Runtime loads";
}

say "\nDistribution check complete!";