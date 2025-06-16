#!/usr/bin/env raku

use lib 'lib';
use ONNX::Runtime::API::Simple;

%*ENV<ONNX_DEBUG> = '1';

say "1. Getting simple API...";
my $api = get-simple-api();
say "2. Got API: ", $api;

say "\n3. Testing create-env...";
use NativeCall;
use ONNX::Runtime::Types;

my $env-ptr = Pointer[OrtEnv].new;
my $status = $api.create-env(ORT_LOGGING_LEVEL_WARNING, "Test", $env-ptr);
say "4. Status: ", $status;
say "5. Env: ", $env-ptr.deref if !$status;

say "\nDone!";