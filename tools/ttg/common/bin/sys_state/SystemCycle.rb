#!ruby -Ku
#
#  TTG
#      TOPPERS Test Generator
#
#  Copyright (C) 2015-2020 by FUJI SOFT INCORPORATED
#
#  上記著作権者は，以下の(1)～(4)の条件を満たす場合に限り，本ソフトウェ
#  ア（本ソフトウェアを改変したものを含む．以下同じ）を使用・複製・改
#  変・再配布（以下，利用と呼ぶ）することを無償で許諾する．
#  (1) 本ソフトウェアをソースコードの形で利用する場合には，上記の著作
#      権表示，この利用条件および下記の無保証規定が，そのままの形でソー
#      スコード中に含まれていること．
#  (2) 本ソフトウェアを，ライブラリ形式など，他のソフトウェア開発に使
#      用できる形で再配布する場合には，再配布に伴うドキュメント（利用
#      者マニュアルなど）に，上記の著作権表示，この利用条件および下記
#      の無保証規定を掲載すること．
#  (3) 本ソフトウェアを，機器に組み込むなど，他のソフトウェア開発に使
#      用できない形で再配布する場合には，次のいずれかの条件を満たすこ
#      と．
#    (a) 再配布に伴うドキュメント（利用者マニュアルなど）に，上記の著
#        作権表示，この利用条件および下記の無保証規定を掲載すること．
#    (b) 再配布の形態を，別に定める方法によって，TOPPERSプロジェクトに
#        報告すること．
#  (4) 本ソフトウェアの利用により直接的または間接的に生じるいかなる損
#      害からも，上記著作権者およびTOPPERSプロジェクトを免責すること．
#      また，本ソフトウェアのユーザまたはエンドユーザからのいかなる理
#      由に基づく請求からも，上記著作権者およびTOPPERSプロジェクトを
#      免責すること．
#
#  本ソフトウェアは，無保証で提供されているものである．上記著作権者お
#  よびTOPPERSプロジェクトは，本ソフトウェアに関して，特定の使用目的
#  に対する適合性も含めて，いかなる保証も行わない．また，本ソフトウェ
#  アの利用により直接的または間接的に生じたいかなる損害に関しても，そ
#  の責任を負わない．
#
#  本ファイルは TTSP3 のカバレッジ向上（HRP3 時間区画スケジューリング
#  のテスト生成）のために新規追加したものである【改変】．
#
require "common/bin/CommonModule.rb"
require "common/bin/Config.rb"
require "common/bin/IMCodeElement.rb"
require "ttc/bin/sys_state/SystemCycle.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: SystemCycle
  # 概    要: システム周期(DEF_SCY)の情報を処理するクラス
  #===================================================================
  class SystemCycle
    include CommonModule

    attr_accessor :hState, :sObjectID, :sObjectType

    #=================================================================
    # 概  要: システム周期の初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      @cConf  = Config.new()
      @hState = {}

      @sObjectID   = sObjectID
      @sObjectType = TSR_OBJ_SYSTEM_CYCLE
      @aPath       = aPath + [@sObjectID]

      @hState[TSR_PRM_SCYTIM] = nil  # システム周期の時間

      pre_attribute_check(hObjectInfo, aPath + [@sObjectID], bIsPre)
      store_object_info(hObjectInfo)
    end

    #=================================================================
    # 概  要: テストシナリオの情報を@hStateに代入
    #=================================================================
    def store_object_info(hObjectInfo)
      check_class(Hash, hObjectInfo)  # オブジェクト情報

      set_specified_attribute(hObjectInfo)
      hObjectInfo.each{|atr, val|
        if (atr != TSR_PRM_TYPE)
          @hState[atr] = val
        end
      }
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # システム周期を定義する静的API(保護ドメインの外に記述)［NGKI5013］
      cElement.set_config("#{API_DEF_SCY}({#{@hState[TSR_PRM_SCYTIM]}});", IMC_NO_CLASS, IMC_NO_DOMAIN) # [IMCodeElement]システム周期を定義する静的API
    end
  end

  #===================================================================
  # クラス名: SystemOperationMode
  # 概    要: システム動作モード(CRE_SOM)の情報を処理するクラス
  #===================================================================
  class SystemOperationMode
    include CommonModule

    attr_accessor :hState, :sObjectID, :sObjectType

    #=================================================================
    # 概  要: システム動作モードの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      @cConf  = Config.new()
      @hState = {}

      @sObjectID   = sObjectID
      @sObjectType = TSR_OBJ_SYSTEM_OPERATION_MODE
      @aPath       = aPath + [@sObjectID]

      @hState[TSR_PRM_SOMATR] = nil  # システム動作モード属性
      @hState[TSR_PRM_NXTSOM] = nil  # 次のシステム動作モード

      pre_attribute_check(hObjectInfo, aPath + [@sObjectID], bIsPre)
      store_object_info(hObjectInfo)
    end

    #=================================================================
    # 概  要: テストシナリオの情報を@hStateに代入
    #=================================================================
    def store_object_info(hObjectInfo)
      check_class(Hash, hObjectInfo)  # オブジェクト情報

      set_specified_attribute(hObjectInfo)
      hObjectInfo.each{|atr, val|
        if (atr != TSR_PRM_TYPE)
          @hState[atr] = val
        end
      }
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # システム動作モードを生成する静的API(保護ドメインの外に記述)
      # ［NGKI5022］．nxtsomは省略可［NGKI5029］．
      if (!@hState[TSR_PRM_NXTSOM].nil?())
        cElement.set_config("#{API_CRE_SOM}(#{@sObjectID}, {#{@hState[TSR_PRM_SOMATR]}, #{@hState[TSR_PRM_NXTSOM]}});", IMC_NO_CLASS, IMC_NO_DOMAIN) # [IMCodeElement]システム動作モードを生成する静的API
      else
        cElement.set_config("#{API_CRE_SOM}(#{@sObjectID}, {#{@hState[TSR_PRM_SOMATR]}});", IMC_NO_CLASS, IMC_NO_DOMAIN) # [IMCodeElement]システム動作モードを生成する静的API
      end
    end
  end

  #===================================================================
  # クラス名: TimeWindow
  # 概    要: タイムウィンドウ(ATT_TWD)の情報を処理するクラス
  #===================================================================
  class TimeWindow
    include CommonModule

    attr_accessor :hState, :sObjectID, :sObjectType

    #=================================================================
    # 概  要: タイムウィンドウの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      @cConf  = Config.new()
      @hState = {}

      @sObjectID   = sObjectID
      @sObjectType = TSR_OBJ_TIME_WINDOW
      @aPath       = aPath + [@sObjectID]

      @hState[TSR_PRM_DOMID]  = nil  # 割り当てる保護ドメイン
      @hState[TSR_PRM_SOMID]  = nil  # 割り当てるシステム動作モード
      @hState[TSR_PRM_TWDORD] = nil  # システム周期内での順序
      @hState[TSR_PRM_TWDLEN] = nil  # タイムウィンドウの長さ
      @hState[TSR_PRM_NOTIFY] = nil  # 通知方法の指定（省略可）

      pre_attribute_check(hObjectInfo, aPath + [@sObjectID], bIsPre)
      store_object_info(hObjectInfo)
    end

    #=================================================================
    # 概  要: テストシナリオの情報を@hStateに代入
    #=================================================================
    def store_object_info(hObjectInfo)
      check_class(Hash, hObjectInfo)  # オブジェクト情報

      set_specified_attribute(hObjectInfo)
      hObjectInfo.each{|atr, val|
        if (atr != TSR_PRM_TYPE)
          @hState[atr] = val
        end
      }
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # タイムウィンドウを登録する静的API(保護ドメインの外に記述)
      # ［NGKI5041］．通知方法の指定（第5要素）は省略可［NGKI5097］．
      # notify を指定した場合は通知ハンドラ等が登録され，twd_start の通知
      # 呼出し経路（domain.c の nfyhdr != NULL 分岐）を駆動できる．
      sNotify = @hState[TSR_PRM_NOTIFY].nil?() ? "" : ", #{@hState[TSR_PRM_NOTIFY]}"
      cElement.set_config("#{API_ATT_TWD}({#{@hState[TSR_PRM_DOMID]}, #{@hState[TSR_PRM_SOMID]}, #{@hState[TSR_PRM_TWDORD]}, #{@hState[TSR_PRM_TWDLEN]}#{sNotify}});", IMC_NO_CLASS, IMC_NO_DOMAIN) # [IMCodeElement]タイムウィンドウを登録する静的API
    end
  end
end
