File.umask 0022
ENV['LC_ALL'] = 'C'
Encoding.default_external = 'ascii-8bit' if RUBY_VERSION > '1.9'

require "pmux-gw/application"
require "pmux-gw/client_context"
require "pmux-gw/history"
require "pmux-gw/http_handler"
require "pmux-gw/logger_wrapper"
require "pmux-gw/pmux_handler"
require "pmux-gw/syslog_wrapper"
require "pmux-gw/version"
