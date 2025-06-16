#!/usr/bin/env raku

use lib 'test-precomp/lib';
use TestAttributes;

say "1. Module loaded";
my $api = TestAttributes::TestAPI.new;
say "2. API created";
say "3. API pointer: ", $api.api;
say "Done!";