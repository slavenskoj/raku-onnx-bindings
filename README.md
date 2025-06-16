# ONNX Runtime Bindings for Raku

Native Raku bindings for [Open Neural Network Exchange (ONNX) Runtime](https://github.com/microsoft/onnxruntime/releases), allowing you to run [ONNX models](https://onnx.ai) directly in Raku using the C API.

**Access to Transformer Models** - Run [BERT](https://en.wikipedia.org/wiki/BERT_(language_model)), [GPT-2](https://en.wikipedia.org/wiki/GPT-2), RoBERTa, and other modern NLP models directly in Raku without Python dependencies

**Hugging Face Integration** - Any model from [Hugging Face](https://huggingface.co) can be exported to ONNX and used in Raku

**Production-Ready Deep Learning** - ONNX models are optimized for inference, offering better performance than Python for deployment

**This is an initial implementation focusing on core functionality and is in development and testing.**

## Features

- Load and run [ONNX models](https://onnx.ai)
- Query model input/output information
- Support for multiple tensor types:
  - Float32, Float64 (Double)
  - Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64
  - Boolean
- Automatic memory management
- High-level Raku interface

## Prerequisites

1. Install ONNX Runtime library:
   - macOS: Download from [ONNX Runtime releases](https://github.com/microsoft/onnxruntime/releases)
   - Linux: `apt install libonnxruntime` or download from releases
   - Windows: Download from releases

2. Ensure the library is in your system's library path:
   - macOS: Copy to `/usr/local/lib/` or set `DYLD_LIBRARY_PATH`
   - Linux: Copy to `/usr/lib/` or set `LD_LIBRARY_PATH`
   - Windows: Copy to system directory or set `PATH`

## Installation

### From zef ecosystem

```bash
zef install ONNX::Runtime
```

### From source

```bash
# Clone the repository
git clone https://github.com/slavenskoj/raku-onnx-raku-bindings.git
cd raku-onnx-raku-bindings

# Install with zef
zef install .
```

### Setting library path

If ONNX Runtime is not in your system's default library path, set the environment variable:

```bash
export ONNX_RUNTIME_LIB=/path/to/libonnxruntime.so  # Linux
export ONNX_RUNTIME_LIB=/path/to/libonnxruntime.dylib  # macOS
set ONNX_RUNTIME_LIB=C:\path\to\onnxruntime.dll  # Windows
```

## Usage

### Basic Example

```raku
use ONNX::Runtime;

# Load a model
my $onnx = ONNX::Runtime.new(
    model-path => "path/to/model.onnx",
    log-level => ORT_LOGGING_LEVEL_WARNING
);

# Query model information
say "Inputs: ", $onnx.input-names;
say "Outputs: ", $onnx.output-names;

# Prepare input data
my %inputs = (
    input_name => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],  # 2x3 tensor
);

# Run inference
my %outputs = $onnx.run(%inputs);

# Process results
for %outputs.kv -> $name, $data {
    say "$name: ", $data;
}
```

### Russian Accent Detection Example

```raku
use ONNX::Runtime;

# Load the Russian accent detection model
my $onnx = ONNX::Runtime.new(model-path => "russian_accent.onnx");

# Load audio samples (16kHz)
my @audio-samples = load-audio-file("speech.wav");

# Run inference
my %outputs = $onnx.run(input => @audio-samples);

# Get probability
my $probability = %outputs<output>[0];
say "Russian accent probability: {$probability.fmt('%.2%')}";
```

### Using Different Tensor Types

```raku
use ONNX::Runtime;
use ONNX::Runtime::Types;

my $onnx = ONNX::Runtime.new(model-path => "model.onnx");

# Integer tensor input
my @int-data = [1, 2, 3, 4, 5];
my %inputs = (
    int_input => @int-data,
    float_input => [1.5, 2.5, 3.5]
);

# Explicitly specify types if needed
my %types = (
    int_input => ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32,
    float_input => ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT
);

my %outputs = $onnx.run(%inputs, :%types);
```

### Image Processing with UInt8

```raku
# Images are typically uint8 (0-255)
my @image-data = load-image-as-array("photo.jpg");  # Returns uint8 values

my %inputs = (
    image => @image-data  # Shape: [1, 3, 224, 224] for RGB image
);

my %outputs = $onnx.run(%inputs);
```

## API Reference

### ONNX::Runtime

Main class for loading and running ONNX models.

#### Constructor

```raku
my $onnx = ONNX::Runtime.new(
    model-path => Str,    # Path to ONNX model file (required)
    log-level => Int      # Logging level (optional, default: WARNING)
);
```

#### Methods

- `input-names()` - Returns list of input tensor names
- `output-names()` - Returns list of output tensor names
- `input-info()` - Returns hash with detailed input information
- `output-info()` - Returns hash with detailed output information
- `run(%inputs)` - Run inference with given inputs

### Logging Levels

- `ORT_LOGGING_LEVEL_VERBOSE` (0)
- `ORT_LOGGING_LEVEL_INFO` (1)
- `ORT_LOGGING_LEVEL_WARNING` (2)
- `ORT_LOGGING_LEVEL_ERROR` (3)
- `ORT_LOGGING_LEVEL_FATAL` (4)

## Current Limitations

1. String tensors not yet supported
2. Basic tensor reshaping (full N-dimensional support coming)
3. CPU execution only (GPU support planned)
4. No custom operators yet

## Development Status

This is an initial implementation focusing on core functionality:
- ✅ Basic model loading
- ✅ Tensor creation and inference
- ✅ Input/output querying
- ✅ Error handling
- ✅ Multiple data type support (float32/64, int8-64, uint8-64, bool)
- ⏳ String tensor support
- ⏳ GPU execution providers
- ⏳ Advanced tensor operations
- ⏳ Model optimization options

## Project Structure

```
onnx-raku-bindings/
├── lib/
│   ├── ONNX/
│   │   ├── Runtime.rakumod          # High-level API
│   │   └── Runtime/
│   │       ├── API.rakumod          # Low-level C bindings
│   │       └── Types.rakumod        # Type definitions
├── t/
│   └── 01-basic.t                   # Basic tests
├── examples/
│   └── basic-usage.raku             # Usage examples
├── onnxruntime-osx-universal2-1.16.3/  # ONNX Runtime library
└── README.md
```

## Contributing

https://github.com/slavenskoj/raku-onnx-bindings

## Author

Danslav Slavenskoj

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- ONNX Runtime team for the C API
- Raku community for NativeCall support