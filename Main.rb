# encoding: utf8
# [138] 1953025: Main
#==============================================================================
# ** Main
#------------------------------------------------------------------------------
#  This processing is executed after module and class definition is finished.
#==============================================================================

module Kernel
  
  def self.clean_exception(exception, tag)
    messages = []
    messages << "Tag: #{tag}" if tag
    messages << "Exception: #{exception.message}\n"
    messages << clean_backtrace_from(exception)
    messages.join("\n")
  end
  
  def self.clean_backtrace_from(exception)
    exception.backtrace.map do |line|
        line.sub(/^{(\d+)}/) { $RGSS_SCRIPTS[$1.to_i][1] }
    end.join("\n")
  end
  
  ThrownMessages = []
  
  def self.catch_error(tag = nil, objects = {})
    begin
      yield
    rescue Exception => e
      error_message = clean_exception(e, tag)
      return if ThrownMessages.include?(error_message)
      ThrownMessages.push(error_message)
      
      msgbox error_message
            
      i = 1
      objects.each do |key, object|
        msgbox [
          "#{i} of #{objects.length}, #{key}", 
          internal_inspect(object)
        ].join("\n")
        i += 1
      end
      
    end
  end
  
  def self.internal_inspect(object)
    case object
    when Array
      object.map do |o|
        internal_inspect(o)
      end.join("\n")
    when Hash
      object.map do |key, value|
        "#{key} : #{internal_inspect(value)}"
        end.join("\n")
    else
      object.inspect.gsub("@", "\n@")
    end
  end
  
  def self.inspect(object)
    msgbox(object.inspect)
  end 
end

rgss_main { SceneManager.run }
