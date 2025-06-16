#!/usr/bin/env raku

use lib 'test-precomp/lib';
use TestNative;

say "1. Module loaded";
my $result = get-test-result();
say "2. Got result: ", $result.perl;
say "Done!";