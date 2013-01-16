require 'singleton'
require 'date'
require 'cgi'

module Pmux
  module Gateway 
    class History
      include Singleton
    
      @@date_format = "%Y_%m_%d"
   
      def init history_file_path, logger
        @syslog_wrapper = SyslogWrapper.instance()
        @history_file_path = history_file_path
        @logger = logger
        @last_rotate = Date.today()
        @file_path = build_file_path(@last_rotate)
        @fp = nil
        @reset = false
      end
    
      def reset history_file_path
        @history_file_path = history_file_path
        @reset = true
      end

      def finish
        @fp.close() if !@fp.nil?
      end
    
      def build_file_path d
        return "#{@history_file_path}-#{d.strftime(@@date_format)}"
      end
    
      def build_id cc
        # peername, pid, mapper, start_datetimeからユニークなidを作る
        # 内部的に使うだけなので文字列をつなげただけのもの
        return "#{cc.peername}#{cc.pid}#{cc.mapper}#{cc.start_datetime.to_s}"
      end
    
      def rotate
        # 日付が変わっていればローテート処理
        if @fp.nil?
          begin
            @fp = open(@file_path, "a")
          rescue Errno::ENOENT => e
            @logger.logging("error", "not found history file (#{@file_path})")
            @logger.logging("error", "error: #{e}")
          rescue Errno::EACCES => e
            @logger.logging("error", "can not access history file (#{@file_path})")
            @logger.logging("error", "error: #{e}")
          end
        end
        new_last_rotate = Date.today()
        if new_last_rotate.day != @last_rotate.day || @reset
          if !@fp.nil?
            @fp.close()
            @fp = nil
          else
            @logger.logging("error", "can not close file, file object is nil")
          end
          begin
            @file_path = build_file_path(new_last_rotate)
            @fp = open(@file_path, "a") 
            @last_rotate = new_last_rotate
            @reset = false
          rescue Errno::ENOENT => e
            @logger.logging("error", "not found history file (#{@file_path})")
            @logger.logging("error", "error: #{e}")
          rescue Errno::EACCES => e
            @logger.logging("error", "can not access history file (#{@file_path})")
            @logger.logging("error", "error: #{e}")
          end
        end
      end
    
      def save cc
        # idを作成する
        id = build_id(cc)
        # rotateを行う
        rotate()
        # historyに追加書き込み
        # フォーマット(タブ区切り):
        #   id\tpeername\tpid\tmapper\tstart_datetime\tend_datetime\tstatus\tcommand\n
        if !cc.end_datetime.nil?
          elapsed = ((cc.end_datetime - cc.start_datetime) * 86400).to_f
        else
          elapsed = nil
        end
        if !@fp.nil?
          msg = "#{id}\t#{cc.peername}\t#{cc.user}\t#{cc.pid}\t#{cc.mapper}\t#{cc.start_datetime.to_s}\t#{cc.end_datetime.to_s}\t#{elapsed}\t#{cc.status}\t#{cc.command}\n"
          @fp.write(msg)
          @fp.flush()
          @syslog_wrapper.logging("history", "info", msg);
        else
          @logger.logging("error", "can not write file, file object is nil")
        end
      end
    
      def is_skip elems, peername, pid, mapper, start_datetime
        return true if !peername.nil? && peername != "" &&  /#{peername}/ !~ elems[1]
        return true if !pid.nil? && pid != "" && /#{pid}/ !~ elems[3]
        return true if !mapper.nil? && mapper != "" && /#{mapper}/ !~ elems[4]
        return true if !start_datetime.nil? && start_datetime != "" && start_datetime != elems[5] 
      end
    
      def load peername, pid, mapper, start_datetime, start_date, end_date, need_command = false, html_escape = false
        # 指定された期間のログファイルからデータを読み込む
        # フォーマット(タブ区切り):
        #   id\tpeername\tuser\tpid\tmapper\tstart_datetime\tend_datetime\telapsed\tstatus\tcommand\n
        # ヒストリの順番はhistory_id_orderに保存し
        # ヒストリの内容はhistoryに保存する
        history_id_order = []
        history = {}
        while (end_date - start_date).to_i >= 0 do
          file_path = build_file_path(start_date)
          begin
            open(file_path) {|file|
              while line = file.gets() do
                elems = line.chomp().split("\t")
                next if is_skip(elems, peername, pid, mapper, start_datetime)
                id = elems.shift()
                command = elems.pop() if !need_command
                elems.unshift(start_date.to_s)
                elems.each_with_index { |e, i| elems[i] = CGI.escapeHTML(e) } if html_escape
                if history.key?(id)
                  # すでにidが存在しているのでmapだけを更新
                  history[id] = elems
                else 
                  # idが存在していないのでmapを更新してリストにidを追加
                  history_id_order << id
                  history[id] = elems
                end
              end
            }
          rescue Errno::ENOENT => e
            @logger.logging("info", "not found history file (#{file_path})")
            @logger.logging("info", "error: #{e}")
          rescue Errno::EACCES => e
            @logger.logging("info", "can not access history file (#{file_path})")
            @logger.logging("info", "error: #{e}")
          end
          start_date += 1
        end
        return [ history, history_id_order.reverse! ]
      end
    end
 end
end   
