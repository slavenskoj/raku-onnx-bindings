use Test;
use lib 'lib';
use ONNX::Runtime;
use ONNX::Runtime::Types;

plan 11;

# Test tensor type constants are accessible
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT.defined, 'Float type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE.defined, 'Double type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8.defined, 'Int8 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8.defined, 'UInt8 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16.defined, 'Int16 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16.defined, 'UInt16 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32.defined, 'Int32 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32.defined, 'UInt32 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64.defined, 'Int64 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64.defined, 'UInt64 type constant defined';
ok ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL.defined, 'Bool type constant defined';

# Note: Actual tensor creation and inference tests would require
# a real ONNX model file with known inputs/outputs

done-testing;