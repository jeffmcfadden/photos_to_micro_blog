class Object

  # Returns true if the object is included in the array.
  # @param [Array] another_object the array or range to check for inclusion
  # @return [Boolean] true if the object is included in the array
  def in?(another_object)
    case another_object
    when Range
      another_object.cover?(self)
    else
      another_object.include?(self)
    end
  rescue NoMethodError
    raise ArgumentError.new("The parameter passed to #in? must respond to #include?")
  end
end

class File
  # Returns the size of the file in megabytes.
  # @return [Float] the size of the file in megabytes
  def mb_size
    size.to_f / 1024 / 1024
  end

  def self.mb_size(file)
    File.size(file).to_f / 1024 / 1024
  end

end

class String

  def blank?
    self.nil? || self.strip.empty?
  end
end