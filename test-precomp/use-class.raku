#!/usr/bin/env raku

use lib 'test-precomp/lib';
use TestClass;

say "1. Module loaded";
my $api = TestClass::API.new;
say "2. API created";
say "3. Data: ", $api.get-data().perl;
say "Done!";