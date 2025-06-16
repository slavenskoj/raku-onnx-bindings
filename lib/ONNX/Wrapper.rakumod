unit module ONNX::Wrapper;

use JSON::Fast;

# Session class that wraps communication with the server
class Session is export {
    has Proc::Async $.proc;
    has Promise $.ready;
    has Supplier $.responses = Supplier.new;
    has %.pending-requests;
    has Int $.request-id = 0;
    has $.session-id;
    has @.input-names;
    has @.output-names;
    has Str $.model-path;
    
    method new(Str :$model-path!) {
        # Look for the server script in several locations
        my @locations = (
            "onnx-runtime-server.raku".IO,
            $*PROGRAM.parent.add('onnx-runtime-server.raku'),
            $*PROGRAM.parent.parent.add('onnx-runtime-server.raku'),
            $*CWD.add('onnx-runtime-server.raku'),
        );
        
        my $server-script;
        for @locations -> $loc {
            if $loc.e {
                $server-script = $loc;
                last;
            }
        }
        
        die "Cannot find onnx-runtime-server.raku in any of: {@locations.map(*.Str).join(', ')}" 
            unless $server-script;
        
        my $proc = Proc::Async.new('raku', $server-script.Str, :w);
        
        self.bless(
            :$proc,
            :$model-path,
        );
    }
    
    submethod TWEAK() {
        # Setup response handling
        $!proc.stdout.lines.tap: -> $line {
            try {
                my %response = from-json($line);
                if %response<request-id>:exists {
                    if %!pending-requests{%response<request-id>}:exists {
                        %!pending-requests{%response<request-id>}.keep(%response);
                        %!pending-requests{%response<request-id>}:delete;
                    }
                } else {
                    # Handle responses without request-id (initial session creation)
                    $!responses.emit(%response);
                }
                CATCH {
                    default {
                        note "Error parsing server response: $_";
                    }
                }
            }
        };
        
        $!proc.stderr.tap: -> $line {
            note "ONNX Server: $line";
        };
        
        # Start the server
        $!ready = $!proc.start;
        
        # Create session
        my $response-promise = Promise.new;
        my $tap = $!responses.Supply.tap: -> %resp {
            if %resp<session-id>:exists {
                $!session-id = %resp<session-id>;
                @!input-names = %resp<input-names>;
                @!output-names = %resp<output-names>;
                $response-promise.keep(True);
                $tap.close;
            } elsif %resp<error>:exists {
                $response-promise.break(%resp<error>);
                $tap.close;
            }
        };
        
        # Send create-session command
        $!proc.put(to-json({
            command => 'create-session',
            model-path => $!model-path,
        }));
        
        # Wait for session creation
        await $response-promise;
    }
    
    method !send-request(%request) {
        my $id = ++$!request-id;
        %request<request-id> = $id;
        
        my $promise = Promise.new;
        %!pending-requests{$id} = $promise;
        
        $!proc.put(to-json(%request));
        
        return await $promise;
    }
    
    method run(%inputs) {
        # Convert inputs to the expected format
        my %formatted-inputs;
        for %inputs.kv -> $name, $data {
            %formatted-inputs{$name} = {
                data => $data.flat,
                shape => $data ~~ Array ?? [$data.elems] !! [1],  # Simple shape inference
            };
        }
        
        my %response = self!send-request({
            command => 'run-inference',
            session-id => $!session-id,
            inputs => %formatted-inputs,
        });
        
        die %response<error> if %response<error>:exists;
        
        return %response<outputs>;
    }
    
    method close() {
        if $!session-id {
            self!send-request({
                command => 'close-session',
                session-id => $!session-id,
            });
        }
        
        $!proc.close-stdin;
        await $!ready;
    }
}

# Convenience function to create a session
sub create-session(Str :$model-path!) is export {
    return Session.new(:$model-path);
}

# Test function
sub test-wrapper() is export {
    say "ONNX::Wrapper module loaded successfully!";
}