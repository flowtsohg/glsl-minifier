# Copyright (c) 2013 Chananya Freiman (aka GhostWolf)

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
  
  oldsource.each_line { |line|
    line = line.strip().gsub(/\s{2,}|\t/, " ")
    
    if line[0] == "#"
      if need_newline
        source += "\n"
      end
      
      source += line + "\n"
      need_newline = false
    else
      source += line.sub("\n", "").gsub(/\s*({|}|=|\*|,|\+|\/|>|<|&|\||\[|\]|\(|\)|\-|!|;)\s*/, "\\1").gsub(/0(\.\d+)/, "\\1").gsub(/(\d+\.)[0]+/, "\\1")
      need_newline = true
    end
  }
  
  return source.gsub(/\n+/, "\n").gsub("\n", "\\n")
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
  data.scan(/#define\s+(\w+)\s+([^\n]+)/).map { |match|
    [match[0], match[1].strip()]
  }
end

# Gets the names of all functions
def get_function_names(data, datatypes)
  data.scan(/(?:#{datatypes})\s+(\w+)\s*\(/)
end

# Gets the names of all uniforms
def get_uniform_names(data, datatypes)
  data.scan(/uniform\s+(?:#{datatypes})\s+(\w+)/)
end

# Gets the names of all attributes
def get_attribute_names(data, datatypes)
  data.scan(/attribute\s+(?:#{datatypes})\s+(\w+)/)
end

# Gets the names of all varyings
def get_varying_names(data, datatypes)
  data.scan(/varying\s+(?:#{datatypes})\s+(\w+)/)
end

# Generate a old name to new name mapping and sort the names alphabetically
def gen_map(data, names, rewrite)
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

def group_list(list, keyword)
  map = {}
  data = ""
  
  list.each { |v|
    if not map[v[0]]
      map[v[0]] = []
    end
    
    map[v[0]].push(v[1])
  }
  
  map.each { |v|
    data += "#{keyword} #{v[0]} #{v[1].join(",")};\n"
  }
  
  return data
end

def group_globals(data, datatypes)
  source = ""
  
  outer = data.gsub(/(#if.*?#endif)/m, "")
  
  source += group_list(outer.scan(/uniform\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/), "uniform")
  source += group_list(outer.scan(/attribute\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/), "attribute")
  source += group_list(outer.scan(/varying\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/), "varying")
  
  data.split(/(#if.*?#endif)/m).each { |chunk|
  p chunk
    if chunk.start_with?("#")
      tokens = chunk.split(/(.*?\n)(.*?)(#endif)/m)
      
      source += tokens[1]
      
      source += group_list(tokens[2].scan(/uniform\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/), "uniform")
      source += group_list(tokens[2].scan(/attribute\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/), "attribute")
      source += group_list(tokens[2].scan(/varying\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/), "varying")
        
      tokens[2].gsub!(/uniform\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/, "")
      tokens[2].gsub!(/attribute\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/, "")
      tokens[2].gsub!(/varying\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/, "")
  
      source += tokens[2]
      source += tokens[3]
      source += "\n"
    else
      chunk.gsub!(/uniform\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/, "")
      chunk.gsub!(/attribute\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/, "")
      chunk.gsub!(/varying\s+(#{datatypes})\s+(\w+(\[\s*\d+\s*\])?)\s*;/, "")
      
      source += chunk
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
  
  # Get all function/uniform/attribute/varying names, and define names and their values
  shaders.each { |shader|
    functions += get_function_names(shader, datatypes_string)
    uniforms += get_uniform_names(shader, datatypes_string)
    attributes += get_attribute_names(shader, datatypes_string)
    varyings += get_varying_names(shader, datatypes_string)
    defines += get_defines(shader)
    members += get_member_names(shader, datatypes_string);
  }
  
  function_map = gen_map(functions, names, true)
  user_data_type_map = gen_map(user_datatypes, names, true)
  uniform_map = gen_map(uniforms, names, rewriteall)
  attribute_map = gen_map(attributes, names, rewriteall)
  varyings_map = gen_map(varyings, names, true)
  member_map = gen_map_map(members, [*("a".."z"), *("A".."Z"), *("aa".."zz")], true)
  
  shaders.map! { |shader|
    shader = group_globals(shader, datatypes_string)
    
    # Rewrite function names
    function_map.each { |function|
      if function[0] != "main"
        shader.gsub!(/\b#{function[0]}\b/, function[1])
      end
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
    
    # Rewrite struct member names
    shader = rename_members(shader, member_map, datatypes_string)
    
    # Remove the define lines from the source
    shader.gsub!(/#define\s+(\w+)\s+([^\n]+)/, "")
    
    # Inline defines
    defines.each { |define|
      shader.gsub!(/\b#{define[0]}\b/, define[1])
    }
    
    # Remove whitespace
    shader = remove_whitespace(shader)
    
    shader
  }
  
  return [shaders, uniform_map.concat(attribute_map), member_map]
end