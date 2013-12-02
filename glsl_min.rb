# Copyright (c) 2013 Chananya Freiman (aka GhostWolf)

# Split the source into function/other chunks
def parse_chunks(source, data_types)
  pass = source.split(/((?:#{data_types})\s+\w+\s*\(.*?\))/)
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
    
    chunks += [[head[0], "(" + head[1], body], [extra]]
  }
  
  return chunks
end

# Rename function arguments and local variables.
def rename_function_locals(data, data_types)
  names = [*("a".."z"), *("aa".."zz")]
  arguments = []
  locals = []
  
  # Grab all the argument names
  data[1].scan(/(?:in\s+|out\s+)?(?:#{data_types})\s+(\w+)/).each { |argument|
    arguments += argument
  }
  
  # Short names must always come before longer names
  arguments.sort!()
  
  data[2].scan(/(#{data_types}) (.*?);/m).each { |local_list|
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
  
  return source.gsub("\n\n", "\n").gsub("\n", "\\n")
end

# Renames function arguments and local variables of all functions
def rename_locals(oldsource, data_types)
  source = ""
  
  parse_chunks(oldsource, data_types).each_with_index { |chunk, i|
    rename_function_locals(chunk, data_types) if i % 2 != 0
    
    source += chunk.join("")
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
  names = [*("A".."Z"), *("AA".."ZZ")]
  data_types = ["void", "bool", "u?int", "float", "double", "(?:b|i|u|d)?vec[2-4]", "mat[2-4](?:x[2-4])?", "sampler[1-3]D", "samplerCube(?:Array)?", "sampler2DRect", "sampler[1-2]DArray", "samplerBuffer", "sampler2DMS(?:Array)?", "sampler[1-2]DShadow", "samplerCubeShadow", "sampler2DRectShadow", "sampler[1-2]DArrayShadow", "samplerCubeArrayShadow", "image[1-3]D", "imageCube(?:Array)?", "image2DRect", "image[1-2]DArray", "imageBuffer", "image2DMS(?:Array)?"]
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
  
  # Get all function and varying names
  shaders.each { |shader|
    functions += get_function_names(shader, data_types_string)
    varyings += get_varying_names(shader, data_types_string)
  }
  
  # Select new short names for all the functions
  function_map = functions.uniq().map { |function|
    [function, names.shift()]
  }
  
  # Short names must always come before longer names
  function_map.sort! { |a, b|
    a[0] <=> b[0]
  }
  
  # Select new short names for all user defined types
  user_data_type_map = user_data_types.uniq().map { |data_type|
    [data_type, names.shift()]
  }
  
  # Short names must always come before longer names
  user_data_type_map.sort! { |a, b|
    a[0] <=> b[0]
  }
  
  # Select new short names for all varyings
  varyings_map = varyings.uniq().map { |varying|
    [varying, names.shift()]
  }
  
  # Short names must always come before longer names
  varyings_map.sort! { |a, b|
    a[0] <=> b[0]
  }
  
  shaders.map { |shader|
    # Rewrite function names
    function_map.each { |function|
      if function[0] != "main"
        shader.gsub!(/\b#{function[0]}\b/, function[1])
      end
    }
    
    # Rename function arguments and local variables
    shader = rename_locals(shader, data_types_string)
    
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
    
    # Remove whitespace
    remove_whitespace(shader)
  }
end