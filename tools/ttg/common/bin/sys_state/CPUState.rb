#!ruby -Ku
#
#  TTG
#      TOPPERS Test Generator
#
#  Copyright (C) 2009-2012 by Center for Embedded Computing Systems
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#  Copyright (C) 2010-2011 by Graduate School of Information Science,
#                             Aichi Prefectural Univ., JAPAN
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
#  $Id: CPUState.rb 72 2020-03-19 08:08:03Z fujisft-shigihara $
#
require "common/bin/CommonModule.rb"
require "common/bin/Config.rb"
require "common/bin/IMCodeElement.rb"
require "ttc/bin/sys_state/CPUState.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: CPUState
  # 概    要: CPU状態の情報を処理するクラス
  #===================================================================
  class CPUState
    include CommonModule

    attr_accessor :hState, :sObjectID, :sObjectType

    @@aAccess1 = []  # 通常操作1のアクセス許可パターン(累積)
    @@aAccess2 = []  # 通常操作2のアクセス許可パターン(累積)
    @@aAccess3 = []  # 管理操作のアクセス許可パターン(累積)
    @@aAccess4 = []  # 参照操作のアクセス許可パターン(累積)

    #=================================================================
    # 概  要: CPU状態の初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      @cConf  = Config.new()
      @hState = {}

      @sObjectID   = sObjectID
      @sObjectType = TSR_OBJ_CPU_STATE
      @aPath       = aPath + [@sObjectID]

      @hState[TSR_PRM_LOCCPU] = nil  # CPUロック状態
      @hState[TSR_PRM_DISDSP] = nil  # ディスパッチ禁止状態
      @hState[TSR_PRM_CHGIPM] = nil  # 割り込み優先度マスクの値
      @hState[TSR_PRM_SYSTIM] = nil  # システム時刻
      @hState[TSR_PRM_PRCID]  = nil  # プロセッサID

      @hState[TSR_PRM_ACCESS1] = nil  # 通常操作1のアクセス許可パターン
      @hState[TSR_PRM_ACCESS2] = nil  # 通常操作2のアクセス許可パターン
      @hState[TSR_PRM_ACCESS3] = nil  # 管理操作のアクセス許可パターン
      @hState[TSR_PRM_ACCESS4] = nil  # 参照操作のアクセス許可パターン

      pre_attribute_check(hObjectInfo, aPath + [@sObjectID], bIsPre)
      store_object_info(hObjectInfo)

      if (!@hState[TSR_PRM_ACCESS1].nil?())
        if (!@@aAccess1.include?(@hState[TSR_PRM_ACCESS1]))
          @@aAccess1.push(@hState[TSR_PRM_ACCESS1])
        end
        if (!@@aAccess2.include?(@hState[TSR_PRM_ACCESS2]))
          @@aAccess2.push(@hState[TSR_PRM_ACCESS2])
        end
        if (!@@aAccess3.include?(@hState[TSR_PRM_ACCESS3]))
          @@aAccess3.push(@hState[TSR_PRM_ACCESS3])
        end
        if (!@@aAccess4.include?(@hState[TSR_PRM_ACCESS4]))
          @@aAccess4.push(@hState[TSR_PRM_ACCESS4])
        end
      end
    end

    #=================================================================
    # 概  要: テストシナリオのCPU状態データを@hStateに代入
    #=================================================================
    def store_object_info(hObjectInfo)
      check_class(Hash, hObjectInfo)  # オブジェクト情報

      # 格納
      set_specified_attribute(hObjectInfo)
      hObjectInfo.each{|atr, val|
        if (atr != TSR_PRM_TYPE)
          @hState[atr] = val
        end
      }
    end

    #=================================================================
    # 概  要: CPU状態を参照するコードをcElementに格納する
    #=================================================================
    def gc_obj_ref(cElement, hProcUnitInfo, bContext)
      check_class(IMCodeElement, cElement) # エレメント
      check_class(Hash, hProcUnitInfo)     # 処理単位情報
      check_class(Bool, bContext)          # タスクコンテキストか

      # CPUロック状態
      cElement.set_syscall(hProcUnitInfo, "#{API_SNS_LOC}()", @hState[TSR_PRM_LOCCPU], TYP_BOOL_T)

      # ディスパッチ禁止状態
      cElement.set_syscall(hProcUnitInfo, "#{API_SNS_DSP}()", @hState[TSR_PRM_DISDSP], TYP_BOOL_T)

      # 割込み優先度マスク(タスクコンテキストからのみチェック可能)
      if (bContext == true)
        cElement.set_local_var(hProcUnitInfo[:id], VAR_INTPRI, TYP_PRI)
        cElement.set_svc_syscall(hProcUnitInfo, FNC_GET_IPM, "&#{VAR_INTPRI}")
        cElement.set_assert(hProcUnitInfo, VAR_INTPRI, @hState[TSR_PRM_CHGIPM])
      end

      # システム時刻
      if (!@hState[TSR_PRM_SYSTIM].nil?())
        cElement.set_local_var(hProcUnitInfo[:id], VAR_SYSTIM, TYP_SYSTIM)
        cElement.set_svc_syscall(hProcUnitInfo, FNC_GET_TIM, "&#{VAR_SYSTIM}")
        cElement.set_assert(hProcUnitInfo, VAR_SYSTIM, @hState[TSR_PRM_SYSTIM])
      end
    end

    #=================================================================
    # 概  要: プロセッサIDを返す
    #=================================================================
    def get_process_id()
      return @hState[TSR_PRM_PRCID] == nil ? 1 : @hState[TSR_PRM_PRCID] # [Integer]プロセッサID
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # HRP かつ アクセス許可パターンを設定している場合のみ
      if (@cConf.is_hrp?() && !@@aAccess1.empty?())
        cElement.set_config("#{API_SAC_SYS}({#{@@aAccess1.join('|')}, #{@@aAccess2.join('|')}, #{@@aAccess3.join('|')}, #{@@aAccess4.join('|')}}, {TACP_SHARED, TACP_SHARED, TACP_SHARED, TACP_SHARED});", IMC_NO_CLASS, TTG_MAIN_DOMAIN) # [IMCodeElement]システム状態のアクセス許可ベクタを設定する静的API（HRP3 3.4: sysstat2を明示）
      end
    end
  end
end
