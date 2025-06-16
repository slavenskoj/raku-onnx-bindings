#!/usr/bin/env raku

use lib 'test-precomp/lib';
use TestTypes;
use TestDependent;

say "1. Modules loaded";
my $api = TestDependent::API.new;
say "2. API created";
my $env = $api.create-env();
say "3. Env: ", $env.perl;
say "Done!";