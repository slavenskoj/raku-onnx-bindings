unit module ONNX::ScriptWrapper;

# This module provides a wrapper around the working ONNX Runtime scripts
# It avoids the precompilation issue by generating and running scripts dynamically

use File::Temp;

# Session class
class Session is export {
    has Str $.model-path;
    has @.input-names;
    has @.output-names;
    has $.script-template;
    
    submethod BUILD(:$!model-path!) {
        # Initialize with the script template
        $!script-template = q:to/END/;
        #!/usr/bin/env raku
        
        use NativeCall;
        
        constant ONNX_LIB = "%ONNX_LIB%";
        constant ORT_API_VERSION = 16;
        
        class OrtEnv is repr('CPointer') { }
        class OrtSession is repr('CPointer') { }
        class OrtSessionOptions is repr('CPointer') { }
        class OrtValue is repr('CPointer') { }
        class OrtMemoryInfo is repr('CPointer') { }
        class OrtAllocator is repr('CPointer') { }
        class OrtStatus is repr('CPointer') { }
        class OrtRunOptions is repr('CPointer') { }
        
        class OrtApiBase is repr('CStruct') {
            has Pointer $.GetApi;
            has Pointer $.GetVersionString;
        }
        
        sub OrtGetApiBase() returns OrtApiBase is native(ONNX_LIB) { * }
        
        # Get API
        my $api-base = OrtGetApiBase();
        my &get-api = nativecast(:(uint32 --> Pointer), $api-base.GetApi);
        my $api = get-api(ORT_API_VERSION);
        
        # Function pointers
        my %funcs;
        my %indices = (
            'CreateEnv' => 3,
            'CreateSessionOptions' => 10,
            'SetSessionGraphOptimizationLevel' => 23,
            'CreateSession' => 7,
            'SessionGetInputCount' => 30,
            'SessionGetOutputCount' => 31,
            'SessionGetInputName' => 36,
            'SessionGetOutputName' => 37,
            'GetAllocatorWithDefaultOptions' => 78,
            'CreateCpuMemoryInfo' => 64,
            'CreateTensorWithDataAsOrtValue' => 44,
            'GetTensorMutableData' => 46,
            'Run' => 9,
        );
        
        for %indices.kv -> $name, $idx {
            %funcs{$name} = nativecast(CArray[Pointer], $api)[$idx];
        }
        
        # Create environment
        my &create-env = nativecast(:(int32, Str, Pointer[OrtEnv] --> OrtStatus), %funcs<CreateEnv>);
        my $env-ptr = Pointer[OrtEnv].new;
        create-env(2, "RakuONNX", $env-ptr);
        my $env = $env-ptr.deref;
        
        # Create session options
        my &create-opts = nativecast(:(Pointer[OrtSessionOptions] --> OrtStatus), %funcs<CreateSessionOptions>);
        my $opts-ptr = Pointer[OrtSessionOptions].new;
        create-opts($opts-ptr);
        my $options = $opts-ptr.deref;
        
        # Set optimization
        my &set-opt = nativecast(:(OrtSessionOptions, int32 --> OrtStatus), %funcs<SetSessionGraphOptimizationLevel>);
        set-opt($options, 99);
        
        # Create session
        my &create-session = nativecast(:(OrtEnv, Str, OrtSessionOptions, Pointer[OrtSession] --> OrtStatus), %funcs<CreateSession>);
        my $sess-ptr = Pointer[OrtSession].new;
        create-session($env, "%MODEL_PATH%", $options, $sess-ptr);
        my $session = $sess-ptr.deref;
        
        # Create memory info
        my &create-mem = nativecast(:(int32, int32, Pointer[OrtMemoryInfo] --> OrtStatus), %funcs<CreateCpuMemoryInfo>);
        my $mem-ptr = Pointer[OrtMemoryInfo].new;
        create-mem(0, 0, $mem-ptr);
        my $memory-info = $mem-ptr.deref;
        
        # Get allocator
        my &get-alloc = nativecast(:(Pointer[OrtAllocator] --> OrtStatus), %funcs<GetAllocatorWithDefaultOptions>);
        my $alloc-ptr = Pointer[OrtAllocator].new;
        get-alloc($alloc-ptr);
        my $allocator = $alloc-ptr.deref;
        
        # Get input/output names
        my &get-input-count = nativecast(:(OrtSession, Pointer[size_t] --> OrtStatus), %funcs<SessionGetInputCount>);
        my &get-output-count = nativecast(:(OrtSession, Pointer[size_t] --> OrtStatus), %funcs<SessionGetOutputCount>);
        my &get-input-name = nativecast(:(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus), %funcs<SessionGetInputName>);
        my &get-output-name = nativecast(:(OrtSession, size_t, OrtAllocator, Pointer[Str] --> OrtStatus), %funcs<SessionGetOutputName>);
        
        my $in-count-ptr = Pointer[size_t].new;
        get-input-count($session, $in-count-ptr);
        my $in-count = $in-count-ptr.deref;
        
        my $out-count-ptr = Pointer[size_t].new;
        get-output-count($session, $out-count-ptr);
        my $out-count = $out-count-ptr.deref;
        
        my @input-names;
        for ^$in-count -> $i {
            my $name-ptr = Pointer[Str].new;
            get-input-name($session, $i, $allocator, $name-ptr);
            @input-names.push($name-ptr.deref);
        }
        
        my @output-names;
        for ^$out-count -> $i {
            my $name-ptr = Pointer[Str].new;
            get-output-name($session, $i, $allocator, $name-ptr);
            @output-names.push($name-ptr.deref);
        }
        
        # Read input data
        my @input-data = %INPUT_DATA%;
        
        # Create tensor
        my $c-array = CArray[num32].new;
        for @input-data.kv -> $i, $v {
            $c-array[$i] = $v.Num;
        }
        
        my $shape = CArray[int64].new;
        $shape[0] = @input-data.elems;
        
        my &create-tensor = nativecast(:(OrtMemoryInfo, Pointer, size_t, CArray[int64], size_t, int32, Pointer[OrtValue] --> OrtStatus), %funcs<CreateTensorWithDataAsOrtValue>);
        my $tensor-ptr = Pointer[OrtValue].new;
        create-tensor($memory-info, nativecast(Pointer, $c-array), @input-data.elems * 4, $shape, 1, 1, $tensor-ptr);
        
        # Run inference
        my $input-names-array = CArray[Str].new;
        $input-names-array[0] = @input-names[0];
        
        my $input-tensors = CArray[OrtValue].new;
        $input-tensors[0] = $tensor-ptr.deref;
        
        my $output-names-array = CArray[Str].new;
        $output-names-array[0] = @output-names[0];
        
        my $output-tensors = CArray[OrtValue].new;
        $output-tensors[0] = OrtValue;
        
        my &run = nativecast(:(OrtSession, OrtRunOptions, CArray[Str], CArray[OrtValue], size_t, CArray[Str], size_t, CArray[OrtValue] --> OrtStatus), %funcs<Run>);
        run($session, OrtRunOptions, $input-names-array, $input-tensors, 1, $output-names-array, 1, $output-tensors);
        
        # Get output
        my &get-data = nativecast(:(OrtValue, Pointer[Pointer] --> OrtStatus), %funcs<GetTensorMutableData>);
        my $data-ptr-ptr = Pointer[Pointer].new;
        get-data($output-tensors[0], $data-ptr-ptr);
        
        my $data = nativecast(CArray[num32], $data-ptr-ptr.deref);
        my @probs = (^10).map({ $data[$_] });
        
        # Output results
        say "INPUT_NAMES:", @input-names.join(",");
        say "OUTPUT_NAMES:", @output-names.join(",");
        say "RESULTS:", @probs.join(",");
        END
        
        # Get model info by running a quick script
        self!get-model-info();
    }
    
    method !get-model-info() {
        my $lib-path = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
        my $script = $!script-template;
        $script ~~ s:g/'%ONNX_LIB%'/$lib-path/;
        $script ~~ s:g/'%MODEL_PATH%'/$!model-path/;
        $script ~~ s:g/'%INPUT_DATA%'/[];/;
        
        # Create temp file
        my ($filename, $filehandle) = tempfile(:suffix('.raku'));
        $filehandle.print($script);
        $filehandle.close;
        
        # Run and capture output
        my $proc = run 'raku', $filename, :out, :err;
        my @lines = $proc.out.lines;
        
        for @lines -> $line {
            if $line.starts-with('INPUT_NAMES:') {
                @!input-names = $line.substr(12).split(',');
            } elsif $line.starts-with('OUTPUT_NAMES:') {
                @!output-names = $line.substr(13).split(',');
            }
        }
        
        unlink $filename;
    }
    
    method run(%inputs) {
        my $lib-path = "/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/lib/libonnxruntime.dylib";
        
        # Get input data
        my $input-name = @!input-names[0];
        my @data = %inputs{$input-name}.flat;
        
        # Generate script with actual data
        my $script = $!script-template;
        $script ~~ s:g/'%ONNX_LIB%'/$lib-path/;
        $script ~~ s:g/'%MODEL_PATH%'/$!model-path/;
        $script ~~ s:g/'%INPUT_DATA%'/@data.perl/;
        
        # Create temp file
        my ($filename, $filehandle) = tempfile(:suffix('.raku'));
        $filehandle.print($script);
        $filehandle.close;
        
        # Run and capture output
        my $proc = run 'raku', $filename, :out, :err;
        my @lines = $proc.out.lines;
        
        my %outputs;
        for @lines -> $line {
            if $line.starts-with('RESULTS:') {
                my @probs = $line.substr(8).split(',').map(*.Num);
                %outputs{@!output-names[0]} = @probs;
            }
        }
        
        unlink $filename;
        
        return %outputs;
    }
}

# Create session
sub create-session(Str :$model-path!) is export {
    return Session.new(:$model-path);
}

# Test function
sub test-script-wrapper() is export {
    say "ONNX::ScriptWrapper module loaded successfully!";
}