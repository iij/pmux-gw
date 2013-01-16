require 'socket'
require 'date'
require 'cgi'
require 'base64'
require 'erb'
require 'eventmachine'
require 'evma_httpserver'
require 'em_pessimistic'

module Pmux
  module Gateway 
    class HttpHandler < EM::Connection
      include EM::HttpServer
    
      @@static_resources = [ "/css", "/js", "/img" ]
      @@param_attr = [
        { "name" => "mapper",       "multi" => false, "required" => true,  "gwoptonly" => false, "default" => nil },
        { "name" => "ship-file",    "multi" => true,  "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "file",         "multi" => true,  "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "file-glob",    "multi" => true,  "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "reducer",      "multi" => false, "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "num-r",        "multi" => false, "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "ff",           "multi" => false, "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "storage",      "multi" => false, "required" => false, "gwoptonly" => false, "default" => ["glusterfs"] },
        { "name" => "locator-host", "multi" => false, "required" => false, "gwoptonly" => false, "default" => ["127.0.0.1"] },
        { "name" => "locator-port", "multi" => false, "required" => false, "gwoptonly" => false, "default" => nil },
        { "name" => "detect-error", "multi" => false, "required" => false, "gwoptonly" => true,  "default" => nil }
      ]
      @@ext_mimetype_map = {
        ".js" => "text/javascript",
        ".css" => "text/css",
        ".png" => "text/png"
      }
      @@date_format = "%Y/%m/%d"
      @@term = false
      @@task_cnt = 0
      @@history_template = nil
    
      def self.get_task_cnt
         return @@task_cnt
      end
    
      def self.set_term
         @@term = true
      end
    
      # httpのリクエストを受けて、pmuxとの橋渡しをするクラス
      def initialize *args
        super
        @resource_map = {
          "/pmux" => method(:resource_pmux),
          "/existence" => method(:resource_existence),
          "/history" => method(:resource_history),
          "/task" => method(:resource_task)
        }
        @logger = LoggerWrapper.instance()
        @history = History.instance()
        @auth_user = nil
        @volume_prefix = nil
        @cc = nil
      end
    
      def post_init
        super
        no_environment_strings
        @logger.logging("debug", "connected to client")
      end
    
      def unbind
        super
        @logger.logging("debug", "client is closed")
        if !@cc.nil?
          @@task_cnt -= 1
          @cc.end_datetime = DateTime.now().new_offset(Rational(9, 24))
          # pmuxが終わっていないのにクライアントとの接続が切れたらpmuxを終了する
          if !@cc.pmux_terminated
            @cc.pmux_handler.close_connection()
            @cc.force_pmux_terminated = true
            @cc.status = "disconnected"
          else
            @cc.status = "done"
          end
          @history.save(@cc)
        end
      end
    
      def parse_http_headers
        @headers = {}
        for line in @http_headers.split("\000")
           key, value = line.split(":", 2)
           @headers[key.strip().downcase()] = value.strip()
        end
      end
    
      def get_auth
        auth = nil
        if @headers.key?("authorization")
          auth = @headers["authorization"]
        elsif @headers.key?("proxy-authorization")
          auth = @headers["proxy-authorization"]
        end
        return false if auth.nil?
        type, string = auth.split(' ')
        return false if type.downcase() != "basic"
        @auth_user, @auth_pass = Base64.decode64(string).split(':', 2)
        return true
      end
    
      def get_param_values(name, default)
        return @params[name] if @params.key?(name) && @params[name].length > 0
        return default
      end
    
      def get_param_value(name, default)
        vals = get_param_values(name, default)
        return vals[0] if !vals.nil?
        return nil
      end
    
      def get_user_volume_prefix
         if $userdb.key?(@auth_user) && $userdb[@auth_user]["password"] == @auth_pass
             @volume_prefix = $userdb[@auth_user]["volume-prefix"]
             return true
         end
         return false
      end
    
      def is_detect_error
        # エラー検出モードかどうかの判定
        if @detect_error.nil? 
          if get_param_value("detect-error", ["off"]) == "on"
            @logger.logging("debug", "mode is decect-error")
            return true
          end
          return false
        else
          return @detect_error
        end 
      end
    
      def build_command
        # パラメータからpmuxコマンドの生成する
        mapper = nil
        opt_list = [$config["pmux_path"]]
        file_list = []
        for attr in @@param_attr
          if !attr["multi"]
            val = get_param_value(attr["name"], attr["default"])
          else
            val = get_param_values(attr["name"], attr["default"])
          end
          if attr["required"]
            if val.nil?
              @logger.logging("info", "patameter error #{attr['name']}")
              return nil, nil, "#{attr['name']} is required"
            else
              if attr["name"] == "mapper"
                mapper = val
              end
            end
          end
          if !val.nil? && !attr["gwoptonly"]
            if !attr["multi"]
              opt_list << "--#{attr['name']}=#{val}"
            elsif attr["name"] == 'file'
              for f in val
                f = [$config["glusterfs_root"], @volume_prefix, f].join(File::SEPARATOR) 
                file_list << f 
              end
            elsif attr["name"] == 'file-glob'
              for fg in val
                 fg = [$config["glusterfs_root"], @volume_prefix, fg].join(File::SEPARATOR) 
                 file_list << Dir.glob(fg)
              end
            elsif attr["name"] == 'ship-file'
              for f in val
                f = [$config["glusterfs_root"], @volume_prefix, f].join(File::SEPARATOR) 
                opt_list << "--#{attr['name']}=#{f}"
              end
            else
              for v in val
                opt_list << "--#{attr['name']}=#{v}"
              end
            end
          end
        end
        return nil, nil, "file of file-glob is required" if file_list.length < 1
        opt_list << file_list
        @logger.logging("debug", opt_list.join(" "))
        return [ mapper, opt_list.join(" "), nil ]
      end
    
      def base_response(args)
        @response.status = args[:status]
        @response.content_type(args[:content_type])
        @response.content = args[:content]
        @response.send_response
        @logger.logging("info", "(response) peer: #{@peer_ip} - #{@peer_port}, path: #{@http_path_info}, response: #{@response.status}")
      end
     
      def success_response(args = {:status => 200, :content_type => "text/html", :content => ""})
        base_response(args)
      end
    
      def error_response(args = {:status => 400, :content_type => "text/html", :content => ""})
        base_response(args)
      end
    
      def resource_static path
        @logger.logging("debug", "requested static resource (#{path})")
        ext = File.extname(path)
        if !@@ext_mimetype_map.key?(ext)
          error_response({:status => 404,
                          :content_type => "text/plain",
                          :content => "not found #{@http_path_info} resource"}) 
          return
        end
        f = nil
        begin
          f = open(path)
          success_response({:status => 200,
                            :content_type => @@ext_mimetype_map[ext],
                            :content => f.read}) 
        rescue Exception
          error_response({:status => 404,
                          :content_type => "text/plain",
                          :content => "not found #{@http_path_info} resource"}) 
        ensure
          if !f.nil?
            f.close()
          end
        end
        return
      end 
    
      def resource_pmux
        # task数が閾値を超えていた場合はbusyを返す
        if @@task_cnt >= $config["max_tasks"]
          error_response({:status => 503,
                          :content_type => "text/plain",
                          :content => "number of tasks exceeded the limit"}) 
          return
        end
    
        # 認証処理
        if $config["use_basic_auth"]
          if @auth_user.nil?
            error_response({:status => 401,
                            :content_type => "text/plain",
                            :content => "need user authentication"}) 
            return
          end
          if !get_user_volume_prefix()
            error_response({:status => 403,
                            :content_type => "text/plain",
                            :content => "user authentication failure"}) 
            return
          end
        end
        @volume_prefix = "" if @volume_prefix.nil?
    
        # リソース/pmuxが呼ばれた際の処理
        if @http_protocol == "HTTP/1.0" && !is_detect_error()
          error_response({:status => 400,
                          :content_type => "text/plain",
                          :content => "HTTP/1.0 is not support chunked"}) 
          return
        end
        mapper, cmd, err = build_command()
        if mapper.nil? || cmd.nil?
          error_response({:status => 400,
                          :content_type => "text/plain",
                          :content => err})
          return
        end
        @cc = ClientContext.new(self, @response, mapper, cmd, is_detect_error())
        @cc.set_pmux_handler(EMPessimistic.popen3(cmd, PmuxHandler, @cc))
        @@task_cnt += 1
        #ステータス情報を保存しておく
        @cc.pid = @cc.pmux_handler.get_status.pid
        @cc.status = "runnning"
        @cc.start_datetime = DateTime.now().new_offset(Rational(9, 24))
        @cc.peername = "#{@peer_ip} - #{@peer_port}"
        @cc.user = @auth_user
        #ヒストリー情報を更新する
        @history.save(@cc)
      end 
    
      def resource_existence
        # リソース/existenceが呼ばれた際の処理
        success_response({:status => 204,
                          :content_type => "text/html",
                          :content => ""}) 
      end 
    
      def resource_history
        default_start_date = default_end_date = Date.today()
        client = get_param_value("client", [""])
        pid = get_param_value("pid", [""])
        mapper = get_param_value("mapper", [""])
        start_date_str = get_param_value("start-date", [default_start_date.strftime(@@date_format)])
        end_date_str = get_param_value("end-date", [default_end_date.strftime(@@date_format)])
        begin
          start_date = Date.strptime(start_date_str, @@date_format)
          end_date = Date.strptime(end_date_str, @@date_format)
          # end dateの方が過去の時間を指定されたら、start dateとend dateを自動的に入れ替える
          if (end_date - start_date).to_i < 0
            tmp_date = start_date
            start_date = end_date
            end_date = tmp_date
          end
        rescue ArgumentError
          # start dateとend dateがパースできない場合はデフォルトにする
          logger.logging("info", "can not parse date format")
          start_date = default_start_date
          end_date = default_end_date
        end
        history, history_id_order = @history.load(client, pid, mapper, "", start_date, end_date, false, true)
        labels = ["date", "client", "user", "pid", "mapper", "start", "end", "elapsed", "status", "detail" ]
        # templateがまだ読み込まれてなければtemplateを読み込む
        if @@history_template.nil?
          begin 
            template_file_path = [File.dirname(__FILE__), "template", "history.tmpl"].join(File::SEPARATOR) 
            @@template = File.read(template_file_path)
          rescue Exception => e
            @logger.logging("error", "can not load template file (#{template_file_path}) : #{e}")
            @logger.logging("error", e.backtrace.join("\n"))
            success_response({:status => 404,
                              :content_type => "text/html",
                              :content => "can not load template file (#{template_file_path}) : #{e}"}) 
            return
          end
        end
        content = ERB.new(@@template, nil, '-').result(binding)
        success_response({:status => 200,
                          :content_type => "text/html",
                          :content => content}) 
      end
    
      def resource_task
        client = get_param_value("client", [""])
        pid = get_param_value("pid", [""])
        mapper = get_param_value("mapper", [""])
        start_datetime = get_param_value("start-datetime", [""])
        date_str = get_param_value("date", [""])
        if client == "" || pid == "" || mapper == "" || start_datetime == "" || date_str == ""
          error_response({:status => 400,
                          :content_type => "text/plain",
                          :content => "client and pid and mapper and start-datetime and date is required"})
          return
        end
        begin
          start_date = Date.parse(date_str)
          end_date = Date.parse(date_str)
        rescue ArgumentError
          error_response({:status => 400,
                          :content_type => "text/plain",
                          :content => "invalid date string"})
          return
        end
        history, history_id_order = @history.load(client, pid, mapper, start_datetime, start_date, end_date, true, false)
        if history_id_order.length < 1
          error_response({:status => 404,
                          :content_type => "text/plain",
                          :content => "not found task"})
          return
        end
        elems = history[history_id_order[0]]
        date = elems.shift()
        labels = ["client", "user", "pid", "mapper", "start", "end", "elapsed", "status", "command"]
        content = ""
        for i in 0..elems.length - 1 do
           content += "#{labels[i]}\t#{elems[i]}\n";
        end
        success_response({:status => 200,
                          :content_type => "text/plain",
                          :content => content}) 
      end
    
      def process_http_request
        # responseオブジェクトを作る
        @response = EM::DelegatedHttpResponse.new(self)
        begin
          # httpのリクエストを受けた際の処理
          # tcp keepaliveの設定と、chunkが利用可能かどうかのチェック
          # 所定のリソースハンドラーへルーティングする処理を行う
          set_sock_opt(Socket::SOL_SOCKET, 9, 1) # socket.SO_KEEPALIVE
          set_sock_opt(Socket::SOL_TCP, 4, 1) # socket.TCP_KEEPIDLE
          set_sock_opt(Socket::SOL_TCP, 5, 1) # socket.TCP_KEEPINTVL
          set_sock_opt(Socket::SOL_TCP, 6, 10) # socket.TCP_KEEPCNT
    
          # 終了フラグが立っている場合は503を返す
          if @@term
            error_response({:status => 503,
                            :content_type => "text/plain",
                            :content => "apllication is terminating"}) 
            return
          end
    
          # 接続元情報の取得
          @peer_port, @peer_ip = Socket.unpack_sockaddr_in(get_peername())
    
          # ヘッダ文字列をパースする
          parse_http_headers()
    
          # 認証情報の取得
          get_auth()
    
          # パラメータのデコード
          case @http_request_method
          when "GET"
            @params = @http_query_string.nil? ? Hash.new : CGI.parse(@http_query_string)
          when "POST"
            @params = @http_post_content.nil? ? Hash.new : CGI.parse(@http_post_content)
          else
            error_response({:status => 400,
                            :content_type => "text/plain",
                            :content => "unsupport method #{@http_request_method}"}) 
            return
          end
    
          # 指定されたリソースを処理するメソッドへルーティング
          @logger.logging("info", "(request) peer: #{@peer_ip} - #{@peer_port}, path: #{@http_path_info}, headers: #{@headers.inspect} params: #{@params.inspect}")
    
          # staticなリソースの場合
          for prefix in @@static_resources
              if !@http_path_info.index(prefix).nil?
                  resource_static([File.dirname(__FILE__), "static", @http_path_info].join(File::SEPARATOR))
                  return
              end
          end     
    
          # そうでない場合
          if @resource_map.key?(@http_path_info)
            @resource_map[@http_path_info].call
          else
            error_response({:status => 404,
                            :content_type => "text/plain",
                            :content => "not found #{@http_path_info} resource"}) 
            return
          end
        rescue Exception => e
          # 予期しない例外は500を返し、ログに残しておく
          @logger.logging("error", "error occurred in http handler: #{e}")
          @logger.logging("error", e.backtrace.join("\n"))
          error_response({:status => 500,
                          :content_type => "text/plain",
                          :content => "error: #{e}"}) 
        end
      end
    end
  end
end

