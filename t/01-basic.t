use Test;
use lib 'lib';
use ONNX::Runtime;

plan 3;

# Test 1: Can we load the modules?
use-ok 'ONNX::Runtime::Types', 'Can load Types module';
use-ok 'ONNX::Runtime::API', 'Can load API module';
use-ok 'ONNX::Runtime', 'Can load main module';

# Note: Full testing requires an actual ONNX model file
# For now, we're just testing that the modules load correctly

done-testing;