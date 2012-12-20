require 'yaml'
require 'etc'
require 'optparse'
require 'fileutils'

module Pmux
  module Gateway
    class Application
      def initialize
        @config_file_path = "/etc/pmux-gw/pmux-gw.conf"
        @foreground = false
        @reload = false
        @term = false
        @logger = nil
      end
    
      def argparse
        OptionParser.new do |opt|
          opt.on('-c [config_file_path]', '--config [config_file_path]') {|v| @config_file_path = v}
          opt.on('-F', '--foreground') {|v| @foreground = true}
          opt.parse!(ARGV)
        end
      end
    
      def daemonize
        if !@foreground
          exit!(0) if Process.fork
          Process.setsid
          exit!(0) if Process.fork
          STDIN.reopen("/dev/null", "r")
          STDOUT.reopen("/dev/null", "w")
          STDERR.reopen("/dev/null", "w")
        end
      end
    
      def load_config
        # コンフィグのロード、リロード処理
        # グローバル変数 $config はここで作る
        begin
          $config = YAML.load_file(@config_file_path)
        rescue Errno::ENOENT
          if @logger.nil?
            puts "not found config file (#{@config_file_path})"
          else
            @logger.logging("error", "not found config file (#{@config_file_path})")
          end
        rescue Errno::EACCES
          if @logger.nil?
            puts "can not access config file (#{@config_file_path})"
          else
            @logger.logging("error", "can not access config file (#{@config_file_path})")
          end
        rescue Exception => e
          # コンフィグ読み込み中に予期しないエラーが起きた
          if @logger.nil?
            puts "error occurred in config loading: #{e}"
            puts e.backtrace.join("\n") 
          else
            @logger.logging("error", "error occurred in config loading: #{e}")
            @logger.logging("error", e.backtrace.join("\n"))
          end
        end
        # 必要なディレクトリを作る
        # 作れなければ、ログに残して続行
        begin
          histdir = File.dirname($config["history_file_path"])
          logdir = File.dirname($config["log_file_path"])
          FileUtils.mkdir_p(histdir) unless File.exist?(histdir)
          FileUtils.mkdir_p(logdir) unless File.exist?(logdir)
          FileUtils.chown_R($config["user"], $config["group"], histdir)
          FileUtils.chown_R($config["user"], $config["group"], logdir)
        rescue Exception => e
          if @logger.nil?
            puts "error occurred in directory creating: #{e}"
            puts e.backtrace.join("\n")
          else
            @logger.logging("error", "error occurred in directory creating: #{e}")
            @logger.logging("error", e.backtrace.join("\n"))
          end
        end
      end
    
      def load_userdb
        $userdb = {} if $userdb.nil?
        # パスワードファイルの読み込み
        # パーミッションをチェックする
        # グローバル変数 $userdb はここで作る
        # $userdbがnilなら空のマップにする 
        # 読み込みに何らかの理由で失敗したらログに残し、前の状態から変更しない
        if $config["use_basic_auth"]
          return false if $config["password_file_path"].nil? || $config["password_file_path"] == ""
          stat = File.stat($config["password_file_path"])
          mode = "%o" % stat.mode
          if mode[-3, 3] != "600"
            if @logger.nil?
              puts "password file permission is not 600 (#{$config['password_file_path']})"
            else
              @logger.logging("error", "password file permission is not 600 (#{$config['password_file_path']})")
            end
            return false
          end
          begin
            $userdb = YAML.load_file($config["password_file_path"])
          rescue Errno::ENOENT
            if @logger.nil?
              puts "not found password file (#{$config['password_file_path']})"
            else
              @logger.logging("error", "not found password file (#{$config['password_file_path']})")
            end
          rescue Errno::EACCES
            if @logger.nil?
              puts "can not access password file (#{$config['password_file_path']})"
            else
              @logger.logging("error", "can not access password file (#{$config['password_file_path']})")
            end
          rescue Exception => e
            # password読み込み中に予期しないエラーが起きた
            if @logger.nil?
              puts "error occurred in password loading: #{e}"
              puts e.backtrace.join("\n")
            else
              @logger.logging("error", "error occurred in password loading: #{e}")
              @logger.logging("error", e.backtrace.join("\n"))
            end
          end
        end
        return true
      end
    
      def run
        argparse()
        daemonize()
    
        # シグナルを受るとフラグを設定するようにする
        Signal.trap(:INT) { @term = true }
        Signal.trap(:TERM) { @term = true }
        Signal.trap(:HUP) { @reload = true }
    
        # コンフィグの読み込み
        load_config()
    
        # ユーザーとグループの情報を取得する
        user = Etc.getpwnam($config["user"])
        group = Etc.getgrnam($config["group"])
    
        # ユーザー情報読み込み
        exit(1) if !load_userdb()

        # syslogラッパーインスタンス作成
        @syslog = SyslogWrapper.instance()

        # ロガーラッパーインスタンスの作成と初期化
        @logger = LoggerWrapper.instance()
        @logger.init(@foreground)
    
        # 履歴処理インスタンスの作成と初期化
        @history = History.instance()
        @history.init($config["history_file_path"], @logger)
    
        begin
          EM.run do
            # httpサーバーを開始する
            EM.start_server($config["bind_address"], $config["bind_port"], HttpHandler)
    
            # ユーザー権限を変更
            Process::GID.change_privilege(group.gid)
            Process::UID.change_privilege(user.uid) 
    
            # pmuxが読み込む環境変数を上書き
            ENV["USER"] = $config["user"]
            ENV["LOGNAME"] = $config["user"]
            ENV["HOME"] = user.dir
    
            # リソースリミットの設定
            soft, hard = Process.getrlimit(Process::RLIMIT_NPROC)
            proc_margin = 32
            if soft - proc_margin < $config["max_tasks"] || hard - proc_margin < $config["max_tasks"]
              proc_limit = $config["max_tasks"] + proc_margin
              Process.setrlimit(Process::RLIMIT_NPROC, proc_limit, proc_limit)
            end

            # syslogのオープン
            @syslog.open($config["use_syslog"],  $config["syslog_facility"])
    
            # ロガーのオープン
            @logger.open($config["log_file_path"], $config["log_level"])
    
            # シグナル受信フラグを処理する定期実行タイマー
            @periodic_timer = EM::PeriodicTimer.new(1) do
              # reloadフラグが立っていればリロードする
              if @reload 
                @logger.logging("info", "config reloading...")
                load_config()
                load_userdb()
                # syslogとロガーをリオープンと履歴処理インスタンスのリセット
                @syslog.open($config["use_syslog"], $config["syslog_facility"])
                @logger.open($config["log_file_path"], $config["log_level"])
                @history.reset($config["history_file_path"])
                @reload = false
              end
              # 終了フラグが立っていると終了処理
              if @term 
                HttpHandler.set_term()
                if HttpHandler.get_task_cnt() == 0:
                  @logger.logging("info", "shutdown...")
                  @periodic_timer.cancel()
                  @history.finish()
                  @logger.close()
                  EM.stop()
                end
              end
              sleep(1)
            end
          end
        rescue Exception => e
          # event machine内で予期せぬ例外で死んだ場合ログに残す
          @logger.logging("error", "error occurred in eventmachine: #{e}")
          @logger.logging("error", e.backtrace.join("\n"))
          @history.finish()
          @logger.close()
          raise e
        end
      end
    end
  end
end    
