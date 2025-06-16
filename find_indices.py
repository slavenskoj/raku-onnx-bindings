#!/usr/bin/env python3
import re
import sys

# Read the header file
with open('/Volumes/2T/nlp/~~OnyxBindingsforRaku/onnxruntime-osx-universal2-1.16.3/include/onnxruntime_c_api.h', 'r') as f:
    content = f.read()

# Find the OrtApi struct
struct_match = re.search(r'struct OrtApi\s*\{(.*?)\n\};', content, re.DOTALL)
if not struct_match:
    print("Could not find struct OrtApi")
    sys.exit(1)

struct_content = struct_match.group(1)

# Find all function pointers - they match patterns like:
# OrtStatus*(ORT_API_CALL* CreateStatus)(...);
# void(ORT_API_CALL* ReleaseEnv)(...);
# ORT_CLASS_RELEASE(Env);

# First expand ORT_CLASS_RELEASE macros
# ORT_CLASS_RELEASE(X) expands to: void(ORT_API_CALL * ReleaseX)(_Frees_ptr_opt_ OrtX * input)
class_release_pattern = r'ORT_CLASS_RELEASE\((\w+)\)'
struct_content_expanded = re.sub(class_release_pattern, 
                                  lambda m: f'void(ORT_API_CALL* Release{m.group(1)})(_Frees_ptr_opt_ Ort{m.group(1)}* input)', 
                                  struct_content)

# Now find all function pointers
# Match patterns like: ReturnType(ORT_API_CALL* FunctionName)(params);
func_pattern = r'\w+[^(]*\([^)]*\*\s*(\w+)\)\s*\([^)]*\)[^;]*;'
functions = re.findall(func_pattern, struct_content_expanded)

# If that doesn't work well, try a simpler approach
if len(functions) < 100:
    print("First pattern didn't work well, trying alternative...")
    # Match anything that looks like (* FunctionName)
    func_pattern = r'\*\s*(\w+)\)'
    functions = re.findall(func_pattern, struct_content_expanded)

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

print(f"Total functions found in OrtApi struct: {len(functions)}")
print("\nIndices of requested Release functions:")
for i, func_name in enumerate(functions):
    if func_name in target_functions:
        print(f"{func_name}: index {i}")

# Also print first few functions to verify
print("\nFirst 10 functions in struct:")
for i in range(min(10, len(functions))):
    print(f"{i}: {functions[i]}")

# Look for Release functions specifically
print("\nSearching for Release functions...")
for target in target_functions:
    found = False
    for i, func_name in enumerate(functions):
        if func_name == target:
            print(f"Found {target} at index {i}")
            found = True
            break
    if not found:
        print(f"{target} NOT FOUND - checking similar names...")
        for i, func_name in enumerate(functions):
            if target.lower() in func_name.lower():
                print(f"  Similar: {func_name} at index {i}")