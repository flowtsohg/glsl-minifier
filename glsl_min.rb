# Copyright (c) 2013 Chananya Freiman (aka GhostWolf)

# Splits the source into chunks of arbitrary data, and functions
def get_chunks(source, data_types)
  chunks = []
  fn = source.index(/(#{data_types})\s+\w+\s*\(/, 0)
  lastfn = 0
  
  if not fn
    chunks.push(["dontcare", source])
  end
  
  while fn do
    if fn - lastfn > 0
      chunks.push(["dontcare", source[lastfn..fn-1]])
    end
  
    level = 1
    start = source.index("{", fn)
    
    match = source.match(/(#{data_types})\s+(\w+)\s*(\(.*?\))/, fn);
    index = start + 1
    
    while level > 0 and index < source.length do
      char = source[index]
      
      if char == "}"
        level -= 1
      elsif char == "{"
        level += 1
      end
      
      index += 1
    end
    
    chunks.push(["function", {"returntype" => match[1], "name" => match[2], "arguments" => match[3], "body" => source[start..index-1]}])
    
    fn = source.index(/#{data_types}\s+\w+\s*\(/, index)
    lastfn = index
  end
  
  return chunks
end

# Rename function arguments and local variables.
# TODO: it bugs if there are already variables that are one letter long
def rename_function_locals(data, data_types)
  names = [*("A".."Z"), *("a".."z")]
  
  data["arguments"].scan(/(in\s+|out\s+)?\w+\s+(\w+)/).each { |argument|
    name = names.shift()
    namereg = /\b#{argument[1]}\b/
    
    data["arguments"].sub!(namereg, name)
    data["body"].gsub!(namereg, name)
  }
  
  data["body"].scan(/(#{data_types}) (.*?);/m).each { |locals|
    locals[1].split("=")[0].split(",").each { |local|
      data["body"].gsub!(/\b#{local.strip()}\b/, names.shift())
    }
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
  
  return source.gsub("\n\n", "\n").gsub("\n", "\\n")
end

# Renames function arguments and local variables of all functions
def rename_locals(oldsource, data_types)
   source = ""
  
  get_chunks(oldsource, data_types).each { |chunk|
    data = chunk[1]
    
    if chunk[0] == "dontcare"
      source += data
    else
      rename_function_locals(data, data_types)
      source += "#{data["returntype"]} #{data["name"]}#{data["arguments"]}#{data["body"]}"
    end
  }
  
  return source
end

# Gets all the user defined type names
def get_struct_names(data)
  data.scan(/struct\s+(\w+)/).map { |match|
    match[0]
  }
end

# Gets all the defines and their values
def get_defines(data)
  data.scan(/#define\s+(\w+)\s+([^\n]+)/).map { |match|
    [match[0], match[1].strip()]
  }
end

# Gets the names of all functions
def get_function_names(data, data_types)
  data.scan(/(#{data_types})\s+(\w+)\s*\(/).map { |match|
    match[1]
  }
end

# Gets the names of all varyings
def get_varying_names(data, data_types)
  data.scan(/varying\s+(#{data_types})\s+(\w+)/).map { |match|
    match[1]
  }
end

# Minify shaders given in an array
def minify(paths)
  shaders = paths.map { |path| IO.read(path) }
  names = [*("AA".."ZZ")]
  data_types = ["void", "bool", "bvec2", "bvec3", "bvec4", "int", "ivec2", "ivec3", "ivec4", "uint", "uvec2", "uvec3", "uvec4", "float", "vec2", "vec3", "vec4", "double", "dvec2", "dvec3", "dvec4", "mat2", "mat2x2", "mat2x3", "mat2x4", "mat3", "mat3x2", "mat3x3", "mat3x4", "mat4", "mat4x2", "mat4x3", "mat4x4"]
  user_data_types = []
  defines = []
  functions = []
  varyings = []
  
  # Get struct names and define names and their values
  shaders.each { |shader|
    user_data_types += get_struct_names(shader)
    defines += get_defines(shader)
  }
  
  # Create a regex of all the known data types
  data_types_string = data_types.concat(user_data_types).join("|")
  
  # Get all function names
  shaders.each { |shader|
    functions += get_function_names(shader, data_types_string)
  }
  
  # Get all varying names
  shaders.each { |shader|
    varyings += get_varying_names(shader, data_types_string)
  }
  
  # Select new short names for all the functions
  function_map = functions.uniq().map { |function|
    [function, names.shift()]
  }
  
  # Select new short names for all user defined types
  user_data_type_map = user_data_types.uniq().map { |data_type|
    [data_type, names.shift()]
  }
  
  # Select new short names for all varyings
  varyings_map = varyings.uniq().map { |varying|
    [varying, names.shift()]
  }
  
  shaders.map { |shader|
    # Rewrite function names
    function_map.each { |function|
      if function[0] != "main"
      shader.gsub!(/\b#{function[0]}\b/, function[1])
      end
    }
    
    # Rewrite user defined type names
    user_data_type_map.each { |data_type|
      shader.gsub!(/\b#{data_type[0]}\b/, data_type[1])
    }
    
    # Rewrite varying names
    varyings_map.each { |varying|
      shader.gsub!(/\b#{varying[0]}\b/, varying[1])
    }
    
    # Remove the define lines from the source
    shader.gsub!(/#define\s+(\w+)\s+([^\n]+)/, "")
    
    # Inline defines
    defines.each { |define|
      shader.gsub!(/\b#{define[0]}\b/, define[1])
    }
    
    # Rename local variables, function arguments, and remove whitespace
    remove_whitespace(rename_locals(shader, data_types_string))
  }
end