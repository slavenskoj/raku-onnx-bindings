unit module TestTypes;

use NativeCall;

# Basic types
class OrtEnv is repr('CPointer') is export {}
class OrtSession is repr('CPointer') is export {}
class OrtStatus is repr('CPointer') is export {}

# Constants
constant ORT_LOGGING_LEVEL_WARNING is export = 2;