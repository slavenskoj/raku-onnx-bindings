#!/usr/bin/env python3

import re

# Read the header file
with open('/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/include/onnxruntime_c_api.h', 'r') as f:
    content = f.read()

# Find the OrtApi struct
struct_match = re.search(r'struct OrtApi \{(.*?)\};', content, re.DOTALL)
if struct_match:
    struct_content = struct_match.group(1)
    
    # Split by semicolons to get individual declarations
    lines = struct_content.split(';')
    
    functions = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Extract function name
        # Look for patterns like: (ORT_API_CALL* FunctionName)
        match1 = re.search(r'\(ORT_API_CALL\*\s*(\w+)\)', line)
        if match1:
            functions.append(match1.group(1))
            continue
            
        # Look for ORT_API2_STATUS patterns
        match2 = re.search(r'ORT_API2_STATUS\s*\((\w+)', line)
        if match2:
            functions.append(match2.group(1))
            continue
    
    print(f'Found {len(functions)} functions in OrtApi struct:')
    print()
    
    # Find specific functions we're interested in
    important_funcs = [
        'CreateStatus', 'GetErrorCode', 'GetErrorMessage',
        'CreateEnv', 'CreateEnvWithCustomLogger', 
        'EnableTelemetryEvents', 'DisableTelemetryEvents',
        'CreateSession', 'CreateSessionFromArray', 'Run',
        'CreateSessionOptions', 'SetOptimizedModelFilePath',
        'SetSessionGraphOptimizationLevel',
        'SessionGetInputCount', 'SessionGetOutputCount',
        'SessionGetInputName', 'SessionGetOutputName',
        'GetAllocatorWithDefaultOptions',
        'ReleaseEnv', 'ReleaseSession', 'ReleaseSessionOptions'
    ]
    
    for i, func in enumerate(functions):
        if func in important_funcs:
            print(f'{i}: {func}')