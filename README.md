glsl-minifier
==================

A GLSL minifier.

Features:
* Removes unneeded whitespace.
* Renames struct/function/function argument/function local variables/varying variable names.
* Optionally renames uniform variables, attribute variables, and struct members.
* Removes useless zeroes from numbers, converts hexadecimal numbers to decimal numbers, and changes decimal numbers to exponent representation if it's shorter.
* Inlines #defines
* Merges uniform/attribute/varying declarations to list declarations where possible.

It works on a list of files in order to make the same changes on all of them and keep them working.
That is, the same new names will be given across all inputs.
This is useful for when there is shared code between shaders that is kept separately.

Usage:
  `minify(["file1", "file2", ...], rewriteall)`

The second argument is a boolean, and controls whether uniforms/attribute/struct members will get renamed.

The function returns an array with three indices:

Index 0 is another array - the new shader sources for all inputs.  
Index 1 is a hash object that maps between uniform/attribute old/new names.  
Index 2 is a hash object that maps between struct member's old/new names.  

If rewriteall is false, the two hashes returned are identity, meaning every name points to itself `"name"=>"name"`.
