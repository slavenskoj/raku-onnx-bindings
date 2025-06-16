#!/usr/bin/env python3
import re

# Read the header file
with open('/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/include/onnxruntime_c_api.h', 'r') as f:
    content = f.read()

# Find the OrtApi struct
struct_match = re.search(r'struct OrtApi\s*\{(.*?)\n\};', content, re.DOTALL)
if not struct_match:
    print("Could not find struct OrtApi")
    exit(1)

struct_content = struct_match.group(1)

# Split by semicolons to get individual declarations
# Remove comments and normalize whitespace
lines = struct_content.split(';')
declarations = []

for line in lines:
    # Remove comments
    line = re.sub(r'/\*.*?\*/', '', line, flags=re.DOTALL)
    line = re.sub(r'//.*$', '', line, flags=re.MULTILINE)
    
    # Normalize whitespace
    line = ' '.join(line.split())
    
    if line.strip():
        declarations.append(line.strip())

# Now process each declaration to find function names
function_names = []
for decl in declarations:
    # Look for ORT_CLASS_RELEASE pattern
    class_release = re.search(r'ORT_CLASS_RELEASE\((\w+)\)', decl)
    if class_release:
        function_names.append(f'Release{class_release.group(1)}')
    else:
        # Look for function pointer pattern: (* FunctionName)
        func_match = re.search(r'\*\s*(\w+)\s*\)', decl)
        if func_match:
            function_names.append(func_match.group(1))

# Find the Release functions we're looking for
target_functions = [
    'ReleaseEnv',
    'ReleaseStatus',  
    'ReleaseMemoryInfo',
    'ReleaseSession',
    'ReleaseValue',
    'ReleaseTypeInfo',
    'ReleaseTensorTypeAndShapeInfo',
    'ReleaseSessionOptions'
]

print(f"Total function declarations found: {len(function_names)}")
print("\nIndices of requested Release functions:")
for target in target_functions:
    for i, func_name in enumerate(function_names):
        if func_name == target:
            print(f"{target}: index {i}")
            break

# Print surrounding functions for verification
print("\nVerification - showing functions around each Release function:")
for target in target_functions:
    for i, func_name in enumerate(function_names):
        if func_name == target:
            print(f"\n{target} at index {i}:")
            if i > 0:
                print(f"  [{i-1}] {function_names[i-1]}")
            print(f"  [{i}] {function_names[i]} <---")
            if i < len(function_names) - 1:
                print(f"  [{i+1}] {function_names[i+1]}")
            break

# Show a range of functions around index 70-90 for better context
print("\n\nFunctions from index 70 to 90:")
for i in range(70, min(91, len(function_names))):
    marker = ""
    if function_names[i] in target_functions:
        marker = " <--- FOUND"
    print(f"  [{i}] {function_names[i]}{marker}")