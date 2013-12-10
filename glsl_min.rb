# Copyright (c) 2013 Chananya Freiman (aka GhostWolf)

def preprocess_defines(defines)
  rewrites = {}
  
  # Get inline values for simple number equation #defines
  # E.g.: 5 => 5, 5*2 => 10
  defines.each { |v|
    begin
      n = eval(v[2]).to_s()
      rewrites[v[1]] = n
      v[3] = n
    rescue
    end
  }
  
  # Get inline values for #define equations that have the previously inlined #defines in their values
  # E.g.: N/2 => 5/2 => 2.5, assuming N was inlined as 5
  defines.each { |v|
    if not v[3]
      begin
        s = v[2]
        rewrites.each { |k, n|
          s.gsub!(/\b#{k}\b/, n)
        }
        
        n = eval(s).to_s()
        v[3] = n
      rescue
      end
    end
  }
end

def inline_defines(defines, data)
  # First pass removes the inlined #define lines
  defines.each { |v|
    if v[3]
      data.sub!(v[0], "")
    end
  }
  
  # Second pass inlines the values
  defines.each { |v|
    if v[3]
      data.gsub!(/\b#{v[1]}\b/, v[3])
    end
  }
end

def rewrite_numbers(data)
  # Convert hexadecimal numbers to decimal numbers
  data.gsub!(/0x[0-9a-fA-F]+/) { |n|
    n.to_i(16)
  }
  
  # Remove useless zeroes
  data.gsub!(/\b\d*\.?\d+\b/) { |n|
    if n["."]
      n.to_f().to_s()
    else
      n.to_i().to_s()
    end
  }
  
  # Remove useless zeroes
  data.gsub!(/[0]+(\.\d+)/, "\\1")
  data.gsub!(/(\d+\.)[0]+/, "\\1")
  
  # Change integers to exponent representation if it's shorter
  data.gsub!(/(\d+?)(0+)/) {
    n = $1
    e = $2
    
    if e.size > 2
      "#{n}e#{(e.size - 1)}"
    else
      n + e
    end
  }
end

# Removes comments
def remove_comments(source)
  source.gsub!(/\/\/.*/, "")
  source.gsub!(/\/\*.*?\*\//m, "")
end

def parse_structs(data, datatypes)
  data.split(/(struct\s+(?:\w+)\s*{.*?}\s*;)/m)
end

def rename_struct_members(chunk, map, datatypes)
  map.each { |v|
    chunk.sub!(/\b#{v[0]}\b/, map[v[0]])
  }
end

# Rename the members of all structs
def rename_members(data, map, datatypes)
  source = ""
  
  parse_structs(data, datatypes).each_with_index { |chunk, i|
    rename_struct_members(chunk, map, datatypes) if i % 2 != 0
    
    source += chunk
  }
  
  map.each { |v|
    source.gsub!(/\.\b#{v[0]}\b/, ".#{map[v[0]]}")
  }
  
  return source
end

def get_member_names(data, datatypes)
  data.scan(/(struct\s+(?:\w+)\s*{.*?}\s*;)/m).collect { |struct|
    struct[0].scan(/(?:#{datatypes})\s+(\w+)\s*;/)
  }.flatten(1)
end

# Split the source into function/other chunks
def parse_functions(source, datatypes)
  pass = source.split(/((?:#{datatypes})\s+\w+\s*\(.*?\))/)
  chunks = [[pass[0]]]
  
  (1...pass.size).step(2) { |i|
    head = pass[i].split(/\(/)
    body_with_extra = pass[i + 1]
    
    start = body_with_extra.index("{")
    index = start + 1
    level = 1
    
    while level > 0 and index < body_with_extra.length do
      char = body_with_extra[index]
      
      if char == "}"
        level -= 1
      elsif char == "{"
        level += 1
      end
      
      index += 1
    end
    
    body = body_with_extra[0...index]
    extra = body_with_extra[index..body_with_extra.size]
    
    chunks +=  [[head[0], "(" + head[1], body], [extra]]
  }
  
  return chunks
end

# Rename function arguments and local variables.
def rename_function_locals(data, datatypes)
  names = [*("a".."z"), *("aa".."zz")]
  arguments = []
  locals = []
  
  # Grab all the argument names
  data[1].scan(/(?:in\s+|out\s+)?(?:#{datatypes})\s+(\w+)/).each { |argument|
    arguments += argument
  }
  
  # Short names must always come before longer names
  arguments.sort!()
  
  data[2].scan(/(#{datatypes}) (.*?);/m).each { |local_list|
    local_list[1].split("=")[0].split(",").each { |local|
      locals += [local.strip()]
    }
  }
  
  # Short names must always come before longer names
  locals.sort!()
  
  # Rename function arguments
  arguments.each { |argument|
    name = names.shift()
    reg = /\b#{argument}\b/
    
    data[1].sub!(reg, name)
    data[2].gsub!(reg, name)
  }
  
  # Rename function locals
  locals.each { |local|
    data[2].gsub!(/\b#{local.strip()}\b/, names.shift())
  }
end

# Removes useless whitespace from the source
def remove_whitespace(oldsource)
  need_newline = false
  source = ""
  
  oldsource = oldsource.sub(/^\n+/, "")
  
  oldsource.each_line { |line|
    line = line.strip().gsub(/\s{2,}|\t/, " ")
    
    if line[0] == "#"
      if need_newline
        source += "\n"
      end
      
      source += line + "\n"
      need_newline = false
    else
      source += line.sub("\n", "").gsub(/\s*({|}|=|\*|,|\+|\/|>|<|&|\||\[|\]|\(|\)|\-|!|;)\s*/, "\\1")
      need_newline = true
    end
  }
  
  return source.gsub(/\n+/, "\n").gsub("\n", "\\n")
end

def get_used_functions_in_function(used_functions, main_function, function_chunks)
  function_chunks.each { |f|
    match = main_function[2][/\b#{f[0]}\b/]
    
    if match
      used_functions[match] = 1
      
      get_used_functions_in_function(used_functions, function_chunks[match], function_chunks)
    end
  }
end

# Removes dead functions
def remove_dead_functions(shaders, datatypes)
  functions = []
  used_functions = {"main" => 1}
  function_chunks = {}
  main_chunks = []
  shaders.each { |shader|
    parse_functions(shader, datatypes).each_with_index { |chunk, i|
      if i % 2 != 0
        name = chunk[0].split(/\s+/)[1]
      
        if name != "main"
          function_chunks[name] = chunk
        else
          main_chunks.push(chunk)
        end
      end
    }
  }
  
  main_chunks.each { |main_function|
    get_used_functions_in_function(used_functions, main_function, function_chunks)
  }
  
  shaders.map! { |shader|
    source = ""
    
    parse_functions(shader, datatypes).each_with_index { |chunk, i|
      if i % 2 != 0
        if used_functions[chunk[0].split(/\s+/)[1]]
          source += chunk.join("")
        end
      else
        source += chunk.join("")
      end
    }
    
    source
  }
end

# Renames function arguments and local variables of all functions
def rename_locals(oldsource, datatypes)
  source = ""
  
  parse_functions(oldsource, datatypes).each_with_index { |chunk, i|
    rename_function_locals(chunk, datatypes) if i % 2 != 0
    
    source += chunk.join("")
  }
  
  return source
end

# Gets all the user defined type names
def get_struct_names(data)
  data.scan(/struct\s+(\w+)/)
end

# Gets all the defines and their values
def get_defines(data)
  data.scan(/(#define\s+(\w+)\s+([^\n]+))/).map { |match|
    [match[0], match[1], match[2].strip()]
  }
end

# Gets the names of all functions
def get_function_names(data, datatypes)
  data.scan(/(?:#{datatypes})\s+(\w+)\s*\(/)
end

# Gets the names of all variables with the given qualifier
def get_variable_names(data, qualifier, datatypes)
  data.scan(/#{qualifier}\s+(?:#{datatypes})\s+(\w+)\s*;/)
end

# Generate a old name to new name mapping and sort the names alphabetically
def gen_map(data, names, rewrite)
  # Select new short names for all the functions
  map = data.uniq().map { |v|
    if rewrite and v[0] != "main"
      [v[0], names.shift()]
    else
      [v[0], v[0]]
    end
  }
  
  # Short names must always come before longer names
  map.sort! { |a, b|
    a[0] <=> b[0]
  }
  
  map
end

# Generate a old name to new name mapping and sort the names alphabetically
def gen_map_map(data, names, rewrite)
  # Select new short names for all the functions
  map = data.uniq().map { |v|
    if rewrite
      [v[0], names.shift()]
    else
      [v[0], v[0]]
    end
  }
  
  # Short names must always come before longer names
  map.sort! { |a, b|
    a[0] <=> b[0]
  }
  
  mapmap = {}
  
  map.each { |v|
    mapmap[v[0]] = v[1]
  }
  
  mapmap
end

# Rewrite tokens based on a map generated by gen_map
def rewrite_map(map, data)
  map.each { |v|
    data.gsub!(/\b#{v[0]}\b/, v[1])
  }
end

def group_list(list)
  #p list
  map = {}
  data = ""
  
  list.each { |v|
    if not map[v[0]]
      map[v[0]] = {}
    end
    
    if not map[v[0]][v[1]]
      map[v[0]][v[1]] = []
    end
    
    map[v[0]][v[1]].push([v[2], v[3]])
  }
  
  map.each { |qualifier, v|
    v.each { |datatype, v|
      data += "#{qualifier} #{datatype} #{v.collect { |v| "#{v[0]}#{v[1]}"}.join(",")};"
    }
  }
  
  return data
end

def group_globals(data, datatypes)
  source = ""
  
  # All global variables in global scope can be combined, unless they exist in #ifdefs
  outer = data.gsub(/(#if.*?#endif)/m, "")
  
  source += group_list(outer.scan(/(uniform|attribute|varying|const)\s+(#{datatypes})\s+(\w+)(.*?);/))
  
  data.split(/(#if.*?#endif)/m).each { |chunk|
    # Do the same thing inside #ifdefs
    if chunk.start_with?("#if")
      tokens = chunk.split(/(.*?\n)(.*?)(#endif)/m)
      
      source += tokens[1]
      source += group_list(tokens[2].scan(/(uniform|attribute|varying|const)\s+(#{datatypes})\s+(\w+)(.*?);/))
      source += tokens[2].gsub(/(uniform|attribute|varying|const)\s+(#{datatypes})\s+(\w+)(.*?);/, "")
      source += tokens[3]
      source += "\n"
    else
      source += chunk.gsub(/(uniform|attribute|varying|const)\s+(#{datatypes})\s+(\w+)(.*?);/, "")
    end
  }
  
  return source
end

# Minify shaders given in an array
def minify(paths, rewriteall)
  shaders = paths.map { |path| IO.read(path) }
  names = [*("A".."Z"), *("AA".."ZZ")]
  datatypes = ["void", "bool", "u?int", "float", "double", "(?:b|i|u|d)?vec[2-4]", "mat[2-4](?:x[2-4])?", "sampler[1-3]D", "samplerCube(?:Array)?", "sampler2DRect", "sampler[1-2]DArray", "samplerBuffer", "sampler2DMS(?:Array)?", "sampler[1-2]DShadow", "samplerCubeShadow", "sampler2DRectShadow", "sampler[1-2]DArrayShadow", "samplerCubeArrayShadow", "image[1-3]D", "imageCube(?:Array)?", "image2DRect", "image[1-2]DArray", "imageBuffer", "image2DMS(?:Array)?"]
  user_datatypes = []
  defines = []
  functions = []
  uniforms = []
  attributes = []
  varyings = []
  constants = [];
  members = [];
  
  # Remove comments
  shaders.each { |shader|
    remove_comments(shader)
  }
  
  # Get struct names and define names and their values
  shaders.each { |shader|
    user_datatypes += get_struct_names(shader)
  }
  
  # Create a regex of all the known data types
  datatypes_string = datatypes.concat(user_datatypes).join("|")
  
  # Remove dead functions that are not in the call graph of the main() function in any of the inputs
  remove_dead_functions(shaders, datatypes_string)
  
  # Get all function/uniform/attribute/varying names, and define names and their values
  shaders.each { |shader|
    functions += get_function_names(shader, datatypes_string)
    uniforms += get_variable_names(shader, "uniform", datatypes_string)
    attributes += get_variable_names(shader, "attribute", datatypes_string)
    varyings += get_variable_names(shader, "varying", datatypes_string)
    constants += get_variable_names(shader, "const", datatypes_string)
    defines += get_defines(shader)
    members += get_member_names(shader, datatypes_string);
  }
  
  function_map = gen_map(functions, names, true)
  user_data_type_map = gen_map(user_datatypes, names, true)
  uniform_map = gen_map(uniforms, names, rewriteall)
  attribute_map = gen_map(attributes, names, rewriteall)
  varyings_map = gen_map(varyings, names, true)
  constants_map = gen_map(constants, names, true)
  member_map = gen_map_map(members, [*("a".."z"), *("A".."Z"), *("aa".."zz")], true)
  
  # Preprocess #defines to prepare them for inlining
  preprocess_defines(defines)
  
  shaders.map! { |shader|
    # Inline #defines
    inline_defines(defines, shader)
    
    shader = group_globals(shader, datatypes_string)
    
    # Rewrite function names
    function_map.each { |function|
      shader.gsub!(/\b#{function[0]}\b/, function[1])
    }
    
    # Rename function arguments and local variables
    shader = rename_locals(shader, datatypes_string)
    
    # Rewrite user defined type names
    user_data_type_map.each { |data_type|
      shader.gsub!(/\b#{data_type[0]}\b/, data_type[1])
    }
    
    # Rewrite uniform names
    rewrite_map(uniform_map, shader)
    
    # Rewrite attribute names
    rewrite_map(attribute_map, shader)
    
    # Rewrite varying names
    rewrite_map(varyings_map, shader)
    
    # Rewrite varying names
    rewrite_map(constants_map, shader)
    
    # Rewrite struct member names
    shader = rename_members(shader, member_map, datatypes_string)
    
    # Remove whitespace
    shader = remove_whitespace(shader)
    
    # Rewrite numbers
    rewrite_numbers(shader)
    
    shader
  }
  
  return [shaders, uniform_map.concat(attribute_map), member_map]
end