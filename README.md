glsl-minifier
==================

A GLSL minifier.


---------------------------------------

Features:
* Removes unneeded whitespace.
* Renames structs/functions/function arguments/function local variables/varying variable/const variables.
* Optionally renames uniform variables, attribute variables, and struct members (read on to see how to access them).
* Removes useless zeroes from numbers, converts hexadecimal numbers to decimal numbers, and changes decimal numbers to exponent representation if it's shorter.  
`0.10 => .1`  
`1.0 => 1.`  
`0x1 => 1`  
`1000 => 1e3`

* Inlines #defines.  

```
#define FIRST 5
#define SECOND FIRST*2
FIRST;SECOND;
```
Becomes:
`5;10;`
* Merges uniform/attribute/varying/const declarations to list declarations where possible.  

```
uniform vec3 a;
uniform vec3 b;
uniform vec3 c;
#ifdef COND
attribute float d;
attribute float e;
#endif
```
Becomes:
```
uniform vec3 a,b,c;
#ifdef COND
attribute float d,e;
#endif
```
* Removes dead functions.

```c
// Will be removed
void Dead() {

}

void Alive2() {

}

void Alive1() {
  Alive2();
}

void main() {
  Alive1();
}
```
* Replaces language keywords, functions, and vector fiels with #defines in cases where it will minify the source.

```
float;float;float;float;float;float;
.rgba;.rgba;.rgba;.rgba;.rgba;.rgba;
uniform;
```
Becomes:

```
#define A float
#define B rgba
A;A;A;A;A;A;
.B;.B;.B;.B;.B;
uniform // Only one use, #define will take more space, so not replaced
```

---------------------------------------

All the features work on a list of files in order to make the same changes on all of them and keep them working.
That is, the same new names will be given across all inputs, dead functions will only be functions that can't be reach from a main() function from any of the inputs, and so on.
This is useful for when there is shared code between shaders that is kept separately.

---------------------------------------

Usage:
  `minify(["file1", "file2", ...], rewriteall)`

The second argument is a boolean, and controls whether uniforms/attribute/struct members will get renamed.

The function returns an array with three indices:

Index 0 is another array - the new shader sources for all inputs.  
Index 1 is a hash object that maps between uniform/attribute old/new names.  
Index 2 is a hash object that maps between struct member's old/new names.  

If rewriteall is false, the two hashes returned are identity, meaning every name points to itself: `"name"=>"name"`.

All member name changes are synchronized across all structs.  
That is, if struct Foo has a member called "member", and struct Bar has a member called "member", then both of them will be renamed to "a".  
This allows to use the struct member old/new name map easily when setting uniforms.  
For example, let's assume we have the following code:  

```
struct Foo {
  float something;
};
 
uniform Foo foo;
```

Now let's assume it got renamed to this:
```
struct A {
  float a;
};
 
uniform A B;
```
The array returned by this minify call will be the following:  
`minified = ["struct A{float a;};uniform A B;", {"Foo"=>"A", "foo"=>"B"}, {"something"=>"a"}]`

So to set the 'something' member of this uniform, we must use the returned maps:
`minified[1]["foo"] + "." + minified[2]["something"]` => `B.a`
