#!/usr/bin/env raku

use lib 'test-precomp/lib';

say "Test 1: Loading module...";
use TestClassInit;
say "Module loaded successfully";

say "\nTest 2: Creating WorkingClass instance...";
my $w = TestClassInit::WorkingClass.new;
say "Instance created";
say "Calling get-api method...";
my $api1 = $w.get-api();
say "API: ", $api1;

say "\nTest 3: Creating LazyClass instance...";
my $l = TestClassInit::LazyClass.new;
say "Instance created";
say "Accessing api property...";
my $api2 = $l.api();
say "API: ", $api2;

say "\nTest 4: Creating ProblemClass instance (this might hang)...";
my $p = TestClassInit::ProblemClass.new;
say "Instance created";
say "API: ", $p.api;

say "\nAll tests completed!";