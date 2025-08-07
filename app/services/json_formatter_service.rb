class JsonFormatterService
  def self.pretty_format(data)
    return "No data available" if data.blank?
    
    begin
      # Convert to JSON with pretty formatting
      JSON.pretty_generate(data)
    rescue JSON::GeneratorError
      # Fallback if data isn't JSON-serializable
      data.inspect
    end
  end
end
