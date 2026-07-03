lines = File.readlines("core/include/gnuradio-4.0/thread/thread_affinity.hpp")

# Fix 1: Move firstElement outside platform guard — make it always defined
lines.each_with_index do |line, i|
  if line.include?("namespace detail {") && !line.include?("//")
    indent = line[/^\s*/]
    lines.insert(i+1, "#{indent}template<typename Tp, typename... Us>\n")
    lines.insert(i+2, "#{indent}constexpr decltype(auto) firstElement(Tp&& t, Us&&...) noexcept {\n")
    lines.insert(i+3, "#{indent}    return std::forward<Tp>(t);\n")
    lines.insert(i+4, "#{indent}}\n")
    puts "Fix 1: Added firstElement at line #{i+2}"
    break
  end
end

# Fix 2: Uncomment handle parameter name in getThreadName(const void*)
lines.each_with_index do |line, i|
  if line.include?("getThreadName(const void*")
    lines[i] = line.sub("/*handle*/", "handle")
    puts "Fix 2: Uncommented handle param at line #{i+1}"
    break
  end
end

# Fix 3: Remove duplicate firstElement definition in POSIX section
posix_start = -1
posix_end = -1
lines.each_with_index do |line, i|
  if line =~ /firstElement\(Tp&& t/ && i > 30
    # Check context: is this the POSIX version?
    if i >= 2 && (lines[i-1].include?("_POSIX_THREADS") || lines[i-2].include?("_POSIX_THREADS"))
      posix_start = i - 1  # template line before firstElement
      # Find closing brace
      depth = 0
      (i-1..i+8).each do |j|
        next if j >= lines.length
        depth += lines[j].count("{") - lines[j].count("}")
        if depth <= 0 && j >= i
          posix_end = j
          break
        end
      end
      break
    end
  end
end

if posix_start >= 0 && posix_end >= 0
  puts "Fix 3: Removing POSIX firstElement at lines #{posix_start+1}-#{posix_end+1}"
  (posix_start..posix_end).reverse_each { |j| lines.delete_at(j) }
end

# Fix 4: Handle GetLastError sign-conversion warnings
lines.each_with_index do |line, i|
  if line.include?("GetLastError()") && line.include?("system_error")
    next if line.include?("static_cast<int>")
    lines[i] = line.sub("GetLastError()", "static_cast<int>(GetLastError())")
  end
  # Fix 5: Fix wideLen and len sign-conversion warnings
  if line.include?("std::string name(len - 1")
    lines[i] = line.sub("len - 1", "static_cast<std::size_t>(len) - 1")
  end
  if line.include?("std::wstring wideName(wideLen,")
    lines[i] = line.sub("wideName(wideLen", "wideName(static_cast<std::size_t>(wideLen)")
  end
end

File.write("core/include/gnuradio-4.0/thread/thread_affinity.hpp", lines.join)
puts "All fixes applied"