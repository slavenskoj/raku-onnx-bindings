#!/usr/bin/env raku

use lib 'test-precomp/lib';

%*ENV<ONNX_DEBUG> = '1';

say "1. Loading module...";
use ExactTest;
say "2. Module loaded";

say "3. Getting API...";
my $api = get-simple-api();
say "4. Got API: ", $api.perl;

say "Done!";