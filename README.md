# ONNX Runtime Bindings for Raku

Native Raku bindings for [Open Neural Network Exchange (ONNX) Runtime](https://github.com/microsoft/onnxruntime/releases), allowing you to run [ONNX models](https://onnx.ai) directly in Raku using the C API.

**Access to Transformer Models** - Run [BERT](https://en.wikipedia.org/wiki/BERT_(language_model)), [GPT-2](https://en.wikipedia.org/wiki/GPT-2), RoBERTa, and other modern NLP models directly in Raku without Python dependencies

**Hugging Face Integration** - Any model from [Hugging Face](https://huggingface.co) can be exported to ONNX and used in Raku

**Production-Ready Deep Learning** - ONNX models are optimized for inference, offering better performance than Python for deployment

**This is an initial implementation focusing on core functionality and is in development and testing.**

## Status

⚠️ **Important**: Due to a bug in Raku's module precompilation system when using NativeCall with function pointers, the bindings cannot be packaged as a traditional Raku module. Instead, use the standalone scripts provided.

## Working Examples

The following scripts are fully functional and tested:

1. **`onnx-working.raku`** - Basic ONNX Runtime functionality demonstration
2. **`mnist-final.raku`** - Complete MNIST digit recognition example

## Usage

```bash
# Make scripts executable
chmod +x onnx-working.raku mnist-final.raku

# Run basic example
./onnx-working.raku

# Run MNIST example
./mnist-final.raku
```

## Features

- Load ONNX models
- Run inference
- Support for float32 tensors
- Automatic memory management
- Model introspection (input/output names and shapes)

## Requirements

- Raku (tested with Rakudo Star 2025.05)
- ONNX Runtime library (not included)
- An ONNX model file (MNIST model tested)

## Technical Details

ONNX Runtime uses a C API based on function pointers accessed through `OrtGetApiBase()`. The implementation:

1. Gets the API base structure
2. Retrieves the API version
3. Obtains function pointers by index
4. Uses these function pointers for all operations

## Known Issues

1. **Module Precompilation**: Raku's precompilation system hangs when modules use NativeCall to call function pointers during initialization. This is why the code is provided as standalone scripts.

2. **Limited Type Support**: Currently only supports float32 tensors. Other data types can be added following the same pattern.

## Example Output

```
$ ./mnist-final.raku
Getting API base...
API base retrieved successfully
Getting API version 16...
API retrieved successfully
Getting function pointers...
All function pointers retrieved successfully
Creating environment...
Environment created successfully
Creating session options...
Session options created successfully
Setting optimization level...
Optimization level set successfully
Creating session...
Session created successfully
Creating memory info...
Memory info created successfully
Getting allocator...
Allocator retrieved successfully
Model loaded successfully!
...
Predicted digit: 3 (confidence: 54.82%)
```

## Future Work

1. Report the precompilation bug to Raku developers
2. Add support for more tensor types
3. Create a workaround for the module issue
4. Add more examples and documentation

## Contributing

https://github.com/slavenskoj/raku-onnx-bindings

## Author

Danslav Slavenskoj

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- ONNX Runtime team for the C API
- Raku community for NativeCall support