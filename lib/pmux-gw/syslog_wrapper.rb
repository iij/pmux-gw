require 'singleton'
require 'syslog'

module Pmux
  module Gateway
    class SyslogWrapper
      include Singleton

      @@facility_map = {
        'user' => Syslog::LOG_USER,
        'daemon' => Syslog::LOG_DAEMON,
        'local0' => Syslog::LOG_LOCAL0,
        'local1' => Syslog::LOG_LOCAL1,
        'local2' => Syslog::LOG_LOCAL2,
        'local3' => Syslog::LOG_LOCAL3,
        'local4' => Syslog::LOG_LOCAL4,
        'local5' => Syslog::LOG_LOCAL5,
        'local6' => Syslog::LOG_LOCAL6,
        'local7' => Syslog::LOG_LOCAL7
      }

      def get_facility facility
        if !facility.nil? && @@facility_map.key?(facility)
          return @@facility_map[facility]
        end
        return Syslog::LOG_USER
      end

      def open use_syslog, facility_string
        if @syslog
          Syslog.close()
          @syslog = false
        end
        if use_syslog
          facility = get_facility(facility_string)
          Syslog.open("pmux-gw", Syslog::LOG_PID, facility)
          @syslog = true
        end
      end 

      def logging id, serverity, msg
        return if !@syslog
        case serverity
        when "debug"
          Syslog.debug("[#{id}] #{msg}")
        when "info"
          Syslog.info("[#{id}] #{msg}")
        when "warn"
          Syslog.warn("[#{id}] #{msg}")
        when "error"
          Syslog.error("[#{id}] #{msg}")
        when "fatal"
          Syslog.fatal("[#{id}] #{msg}")
        end
      end
    end
  end
end
