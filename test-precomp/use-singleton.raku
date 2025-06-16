#!/usr/bin/env raku

use lib 'test-precomp/lib';
use TestSingleton;

say "1. Module loaded";
my $api = get-api();
say "2. Got API: ", $api.perl;
say "Done!";