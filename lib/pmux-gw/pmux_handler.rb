require 'eventmachine'

module Pmux
  module Gateway
    class PmuxHandler < EventMachine::Connection
      # pmuxを実行した結果を処理するクラス
      def initialize(*args)
        @logger = LoggerWrapper.instance()
        @cc = args.shift()
      end
    
      def post_init
        @logger.logging("debug", "post init pmux handler")
        # エラー検出モードでない場合はpmuxを実行した段階でheaderを送信する
        if !@cc.detect_error
          @cc.response.chunks ||= []
          @cc.response.content_type("application/octet-stream")
          @cc.response.status = 200
          @cc.response.send_headers
        end
      end
    
      def receive_data(data)
        @logger.logging("debug", "received data from stdout")
        if @cc.detect_error
          # エラー検出モードの場合は長さが規定値を超えるまでバッファする
          # 超えた場合はpmuxの実行を終了する
          if @cc.stdout_data.length > $config["max_content_size"]
            close_connection()
            @cc.content_too_big = true
          else
            @cc.append_stdout_data(data)
          end
        else
          # エラー検出モードでない場合はchunkデータとしてレスポンスを返す
          if data.length > 0
             @cc.response.chunk(data)
             @cc.response.send_body
          end
        end
      end
    
      def receive_stderr data
        @logger.logging("debug", "received data from stderr")
        @cc.append_stderr_data(data)
      end
    
      def unbind
        # クライアントとの接続が切れている場合は何もできない
        if @cc.force_pmux_terminated
          @logger.logging("info", "peer: #{@cc.peername}, command: #{@cc.command}, response: force termination")
          return
        end
        retcode = get_status.exitstatus
        if @cc.detect_error
          # エラー検出モードの場合はバッフしていた情報を返す
          # ただし、コンテントが規定値を超えていた場合はその旨を返し、
          # pmux実行のステータスコードが0でない場合はその値とstderrを返す
          @cc.response.content_type("application/octet-stream")
          if @cc.content_too_big
            @cc.response.status = 507
            @cc.response.content = "#{retcode}\r\ntoo big response data size with detect error (#{@cc.stdout_data.length} byte)"
          elsif retcode == 0
            @cc.response.status = 200
            @cc.response.content = @cc.stdout_data
          else
            @cc.response.status = 500
            @cc.response.content = "#{retcode}\r\n#{@cc.stderr_data}"
          end
          @cc.response.send_response
        else
          # エラー検出モードでない場合はchunkの終端を送る
          # chunkの場合はsend_responseの処理を分離しているので
          # (eventmachine_httpserverのコード参照)
          # keepaliveの処理と思われる部分をそのまま持ってきた
          @cc.response.send_trailer
          @cc.response.close_connection_after_writing unless (
            @cc.response.keep_connection_open and (@cc.response.status || "200 OK") == "200 OK")
        end
        @logger.logging("info", "(response) peer: #{@cc.peername}, pid: #{@cc.pid}, command: #{@cc.command}, response: #{@cc.response.status}")
        @cc.pmux_terminated = true
        @logger.logging("debug", "pmux terminated ")
      end
    end
  end
end
