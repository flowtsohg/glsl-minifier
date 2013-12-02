glsl-minifier
==================

A simple GLSL minifier.

It removes unneeded whitespace, renames function names, argument names, local variable names, varying variable names, and struct names.

Defines are inlined and removed from the source.

It works on a list of files in order to make the same changes on all of them and keep them working.
That is, the same new names will be given for functions/varyings/structs across all inputs.
This is useful for when there is shared code between shaders that is kept separately, yet other minifiers would delete it because it is unused.

Usage:
  `minify(["file1", "file2", ...])`
