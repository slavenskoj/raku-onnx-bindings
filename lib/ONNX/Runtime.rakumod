unit module ONNX::Runtime;

# Simple ONNX Runtime module that uses a subprocess to avoid precompilation issues

use JSON::Fast;

# Session class
class Session is export {
    has $.session-id;
    has @.input-names;
    has @.output-names;
    has Str $.model-path;
    has $.server-script;
    
    submethod BUILD(:$!model-path!) {
        # Find the server script
        my @locations = (
            "onnx-runtime-server.raku".IO,
            $*CWD.add('onnx-runtime-server.raku'),
        );
        
        for @locations -> $loc {
            if $loc.e {
                $!server-script = $loc.Str;
                last;
            }
        }
        
        die "Cannot find onnx-runtime-server.raku" unless $!server-script;
        
        # Create session using a single command
        my $proc = run 'raku', $!server-script, :in, :out, :err;
        
        # Send create-session command
        $proc.in.put(to-json({
            command => 'create-session',
            model-path => $!model-path,
        }));
        $proc.in.close;
        
        # Read response
        my $response-line = $proc.out.get;
        my %response = from-json($response-line);
        
        if %response<error>:exists {
            die "Failed to create session: {%response<error>}";
        }
        
        $!session-id = %response<session-id>;
        @!input-names = %response<input-names>;
        @!output-names = %response<output-names>;
    }
    
    method run(%inputs) {
        # Run inference using a new subprocess
        my $proc = run 'raku', $!server-script, :in, :out, :err;
        
        # First recreate the session
        $proc.in.put(to-json({
            command => 'create-session',
            model-path => $!model-path,
        }));
        
        # Read session response
        my $session-line = $proc.out.get;
        my %session-resp = from-json($session-line);
        my $session-id = %session-resp<session-id>;
        
        # Format inputs
        my %formatted-inputs;
        for %inputs.kv -> $name, $data {
            %formatted-inputs{$name} = {
                data => $data.flat.Array,
                shape => [$data.flat.elems],
            };
        }
        
        # Send inference command
        $proc.in.put(to-json({
            command => 'run-inference',
            session-id => $session-id,
            inputs => %formatted-inputs,
        }));
        $proc.in.close;
        
        # Read inference response
        my $inference-line = $proc.out.get;
        my %response = from-json($inference-line);
        
        if %response<error>:exists {
            die "Inference failed: {%response<error>}";
        }
        
        return %response<outputs>;
    }
}

# Create a new session
sub create-session(Str :$model-path!) is export {
    return Session.new(:$model-path);
}

# Test function
sub test-onnx-runtime() is export {
    say "ONNX::Runtime module loaded successfully!";
    
    # Test that we can find the server script
    my @locations = (
        "onnx-runtime-server.raku".IO,
        $*CWD.add('onnx-runtime-server.raku'),
    );
    
    my $found = False;
    for @locations -> $loc {
        if $loc.e {
            say "Found server script at: ", $loc;
            $found = True;
            last;
        }
    }
    
    die "Cannot find onnx-runtime-server.raku" unless $found;
}