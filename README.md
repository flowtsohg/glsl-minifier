glsl-minifier
==================

A GLSL minifier.


---------------------------------------

#### Features

* Removes unneeded whitespace.
* Renames structs/functions/function arguments/function local variables/varying variable/const variables.
* Optionally renames uniform variables, attribute variables, and struct members (read on to see how to access them).
* Removes useless zeroes from numbers, converts hexadecimal numbers to decimal numbers, and changes decimal numbers to exponent representation if it's shorter.  

```
0.10;
1.0;
0x1;
1000;
```
Becomes:  

```
.1;
1.;
1;
1e3;
```
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
* Replaces language keywords, functions, and vector sizzles with #defines in cases where it will minify the source.

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
That is, the same new names will be given across all inputs, dead functions are functions that can't be reached from a main() function from any of the inputs, and so on.
This is useful for when there is shared code between shaders that is kept separately.

The exception to this is creating #defines for keywords.
These defines will always share the same name, but might be created multiple times, since they are on a per-file basis.
For example, if the keyword "else" should be replaced in two distinct files, both will have the following line (assuming the name it got is A of course):  
`#define A else`  
This doesn't affect concatenation, since redefining #defines is valid in GLSL.

---------------------------------------

#### Usage

```
minify_sources(["source1", "source2", ...], rewriteall)
minify_files(["file1", "file2", ...], rewriteall)
```

The second argument is a boolean, and controls whether uniforms/attribute/struct members will get renamed.

The function returns an array with three indices:

Index 0 is an array of source outputs.  
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
`minified = [["struct A{float a;};uniform A B;"], {"Foo"=>"A", "foo"=>"B"}, {"something"=>"a"}]`

So to set the 'something' member of this uniform, we must use the returned maps:
`minified[1]["foo"] + "." + minified[2]["something"]` => `B.a`


---------------------------------------
Finally, for proof of concept, here's the output from an actual (quite big 451 liner) shader, created from 4 distinct files.
  
Vertex shader:
* File 1

```
vec3 B(vec3 d,vec3 c,vec3 a,vec3 b){vec3 e;e.x=dot(d,c);e.y=dot(d,a);e.z=dot(d,b);return e;}
```

* File 2

```
\n#define BW attribute\n#define EM vec3\n#define EN vec4\n#define OF normalize\nuniform mat4 O,U;uniform EM V,W;BW EM BE;BW EN BJ,BO,BG,BP;BW vec2 BK;varying EM BS,BT,BU,BV;varying vec2 BQ[4];\n#ifdef EXPLICITUV1\nBW vec2 BL;\n#endif\n#ifdef EXPLICITUV2\nBW vec2 BL,BM;\n#endif\n#ifdef EXPLICITUV3\nBW vec2 BL,BM,BN;\n#endif\nvoid C(EM c,EM b,EM d,EN a,EN h,out EM f,out EM e,out EM g){EN j=EN(c,1);EN i=EN(b,0);EN k=EN(d,0);EN l;mat4 m=A(a[0])*h[0];mat4 n=A(a[1])*h[1];mat4 o=A(a[2])*h[2];mat4 p=A(a[3])*h[3];l=EN(0);l+=m*j;l+=n*j;l+=o*j;l+=p*j;f=EM(l);l=EN(0);l+=m*i;l+=n*i;l+=o*i;l+=p*i;e=OF(EM(l));l=EN(0);l+=m*k;l+=n*k;l+=o*k;l+=p*k;g=OF(EM(l));}void main(){EM h,g,k;C(BE,EM(BJ),EM(BO),BG,BP,h,g,k);mat3 e=mat3(U);EM i=(U*EN(h,1)).xyz;EM f=OF(e*g);EM j=OF(e*k);EM a=OF(cross(f,j)*BJ.w);EM d=OF(W-i);BT=OF(B(d,j,a,f));EM b=OF(V-i);EM c=OF(b-W);BU=B(b,j,a,f);BV=B(c,j,a,f);BS=f;BQ[0]=BK;\n#ifdef EXPLICITUV1\nBQ[1]=BL;\n#endif\n#ifdef EXPLICITUV2\nBQ[1]=BL;BQ[2]=BM;\n#endif\n#ifdef EXPLICITUV3\nBQ[1]=BL;BQ[2]=BM;BQ[3]=BN;\n#endif\ngl_Position=O*EN(h,1);}
```

Fragment shader:
* File 1

```
\n#define CY else\n#define DM return\n#define EN vec4\n#define FG sampler2D\nuniform vec3 X;varying vec3 BS,BT,BU,BV;varying vec2 BQ[4];struct K{bool a,f,g,h,i,j,k,r;float b,c,d,m,n,o,p;vec3 e,s;EN l;mat4 q;};vec3 D(EN a,vec3 c,K b){if(b.b==.0){c*=a.rgb;}CY if(b.b==1.){c*=a.rgb*2.;}CY if(b.b==2.){c+=a.rgb*a.a;}CY if(b.b==6.){c+=a.rgb;}CY if(b.b==3.){c=mix(c,a.rgb,a.a);}CY if(b.b==4.){c+=a.a*X;}CY if(b.b==5.){c+=a.a*X;}DM c;}EN E(float a,EN b){if(a==3.){b=b.rrrr;}CY if(a==4.){b=b.gggg;}CY if(a==5.){b=b.bbbb;}CY if(a==2.){b=b.aaaa;}CY if(a==.0){b.a=1.;}DM b;}vec2 F(K a){if(a.n==1.){DM BQ[1];}CY if(a.n==2.){DM BQ[2];}CY if(a.n==3.){DM BQ[3];}DM BQ[0];}EN G(FG a,K b){DM texture2D(a,F(b));}EN H(FG a,K b){EN d=G(a,b);EN c=E(b.c,d);if(b.d==1.){c=EN(mix(X,c.rgb,d.a),1);}CY if(b.d==2.){c=EN(mix(X,c.rgb,d.a),1);}if(b.g){c=EN(1)-c;}if(b.j){c=clamp(c,.0,1.);}DM c;}vec3 I(FG a){EN c=texture2D(a,BQ[0]);vec3 b;b.xy=2.*c.wy-1.;b.z=sqrt(max(.0,1.-dot(b.xy,b.xy)));DM b;}EN J(FG d,K a,float e,float c,vec3 b){EN f;if(a.a){f=H(d,a);}CY{f=EN(0);}float g=pow(max(-dot(BV,b),.0),e)*c;DM f*g;}
```

* File 2

```
\n#define BY uniform\nBY float Y,Z,AA;BY vec4 AB;BY K AC,AE,AG,AI,AK,AM,AO,AQ,AS,AU,AW,AY,BA,BC;BY sampler2D AD,AF,AH,AJ,AL,AN,AP,AR,AT,AV,AX,AZ,BB,BD;void main(){vec3 b;vec4 f=AB;vec3 j;vec3 i;if(AW.a){j=I(AX);}else{j=BS;}float g=max(dot(j,BT),.0);if(g>.0){if(AC.a){vec4 d=H(AD,AC);b=D(d,b,AC);}if(AE.a){vec4 c=H(AF,AE);b=D(c,b,AE);}vec4 k=J(AH,AG,Y,Z,j);if(BA.a){vec4 h=H(BB,BA)*2.;i=h.rgb;}f.rgb=(b+k.rgb)*g;bool a=false;vec3 e;vec4 l;if(AK.a){l=H(AL,AK);if(AK.b==.0||AK.b==1.||AK.b==3.){f.rgb=D(l,f.rgb,AK);}else{e=D(l,e,AK);a=true;}}if(AM.a){l=H(AN,AM);if(!a&&(AM.b==.0||AM.b==1.||AM.b==3.)){f.rgb=D(l,f.rgb,AM);}else{e=D(l,e,AM);a=true;}}if(a){f.rgb+=e*AA;}}gl_FragColor=f;}
```
