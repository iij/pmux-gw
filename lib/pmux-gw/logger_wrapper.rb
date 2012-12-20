require 'singleton'
require 'logger'

module Pmux
  module Gateway
    class LoggerWrapper
      include Singleton
    
      @@log_level_map = {
        'debug' => Logger::DEBUG,
        'info' => Logger::INFO,
        'warn' => Logger::WARN,
        'error' => Logger::ERROR,
        'fatal' => Logger::FATAL
      }

      def init foreground
        @syslog_wrapper = SyslogWrapper.instance()
        @foreground = foreground
        @logger = nil
        @serverity = Logger::INFO
      end
    
      def fixup_level level
        return level if @@log_level_map.key?(level)
        return "info"
      end

      def open log_file_path, log_level
        # ログをオープンする
        # すでに開いている状態で呼ばれるとリオープンする
        @serverity = @@log_level_map[fixup_level(log_level)]
        old_logger = @logger
        @logger = nil
        begin
          @logger = Logger.new(log_file_path, 'daily')
          @logger.level = @serverity
          old_logger.close() if !old_logger.nil?
        rescue Errno::ENOENT => e
          @logger = old_logger if !old_logger.nil?
          logging("error", "not found log file (#{log_file_path})")
          logging("error", "error: #{e}")
        rescue Errno::EACCES => e
          @logger = old_logger if !old_logger.nil?
          logging("error", "can not access log file (#{log_file_path})")
          logging("error", "error: #{e}")
        end
      end
    
      def close()
        @logger.close if !@logger.nil?
      end
    
      def logging serverity, msg
        serverity = fixup_level(serverity)
        if !@logger.nil?
          case serverity
          when "debug"
            @logger.debug(msg)
          when "info"
            @logger.info(msg) 
          when "warn"
            @logger.warn(msg) 
          when "error"
            @logger.error(msg) 
          when "fatal"
            @logger.fatal(msg) 
          end
        end
        @syslog_wrapper.logging("log", serverity, msg) if @@log_level_map[serverity] >= @serverity
        puts "[#{serverity}] #{msg}" if @foreground && @@log_level_map[serverity] >= @serverity
      end
    end
  end
end
