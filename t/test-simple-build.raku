#!/usr/bin/env raku

use lib 'lib';

%*ENV<ONNX_DEBUG> = '1';

say "Loading types...";
use ONNX::Runtime::Types;

say "Loading API...";
use ONNX::Runtime::API::Simple;

say "Creating class...";
class TestRuntime {
    has $.api;
    
    submethod BUILD() {
        say "TestRuntime BUILD: Starting...";
        say "TestRuntime BUILD: About to call get-simple-api...";
        $!api = get-simple-api();
        say "TestRuntime BUILD: Got API: ", $!api.perl;
    }
}

say "Creating instance...";
my $rt = TestRuntime.new;
say "Instance created!";