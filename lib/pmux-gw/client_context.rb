module Pmux
  module Gateway
    class ClientContext
      # 処理に必要なクライアントの情報を保持するクラス
      def initialize request, response, mapper, command, detect_error
        @request = request
        @response = response
        @mapper = mapper
        @command = command
        @detect_error = detect_error
        @stdout_data = ""
        @stderr_data = ""
        @pmux_terminated = false
        @force_pmux_terminated = false
        @content_too_big = false
        @pid = nil
        @start_datetime = nil
        @end_datetime = nil
        @peername = nil
        @user = nil
        @status = "init"
      end 
    
      def set_pmux_handler pmux_handler
        @pmux_handler = pmux_handler
      end
    
      def append_stdout_data data
        @stdout_data << data
      end
    
      def append_stderr_data data
        @stderr_data << data
      end
    
      attr_reader :request, :response, :pmux_handler, :mapper, :command, :detect_error, :stdout_data, :stderr_data
      attr_accessor :pmux_terminated, :force_pmux_terminated, :content_too_big, :pid, :start_datetime, :end_datetime, :status, :peername, :user
    end
  end
end
