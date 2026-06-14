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
require "ttc/bin/class/TTCCommon.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: SystemCycle
  # 概    要: システム周期(DEF_SCY)の情報を処理するクラス
  #===================================================================
  class SystemCycle
    include TTCModule
    include TTCModule::ObjectCommon

    #=================================================================
    # 概  要: 属性チェック
    #=================================================================
    def attribute_check()
      aErrors = []
      @hState.each{|sAtr, val|
        begin
          if (is_specified?(sAtr))
            case sAtr
            # 0以上の整数か文字列(マクロ・式)
            when TSR_PRM_SCYTIM
              unless (val.is_a?(String))
                check_attribute_unsigned(sAtr, val, @aPath)
              end

            else
              abort(ERR_MSG % [__FILE__, __LINE__])
            end
          end
        rescue TTCError
          aErrors.push($!)
        end
      }

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: オブジェクトチェック
    #=================================================================
    def object_check(bIsPre = false)
      check_class(Bool, bIsPre)  # pre_conditionか
      # 個別チェックなし(範囲・重複はカーネルのコンフィギュレータが検査)
    end

    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      # 補完なし
    end

    #=================================================================
    # 概　要: オブジェクトのエイリアス変換テーブルを返す
    #=================================================================
    def get_alias(sTestID, nNum = nil)
      check_class(String, sTestID)      # テストID
      check_class(Integer, nNum, true)  # 識別番号

      # システム周期はエイリアス変換しない
      hResult = {}
      hResult[@sObjectID] = @sObjectID

      return hResult  # [Hash]エイリアス変換テーブル
    end

    #=================================================================
    # 概　要: オブジェクトを複製して返す
    #=================================================================
    def dup()
      cObjectInfo = super()

      cObjectInfo.sObjectID   = safe_dup(@sObjectID)
      cObjectInfo.sObjectType = safe_dup(@sObjectType)
      cObjectInfo.hState      = safe_dup(@hState)

      return cObjectInfo  # [Object]複製したオブジェクト
    end
  end

  #===================================================================
  # クラス名: SystemOperationMode
  # 概    要: システム動作モード(CRE_SOM)の情報を処理するクラス
  #===================================================================
  class SystemOperationMode
    include TTCModule
    include TTCModule::ObjectCommon

    #=================================================================
    # 概  要: 属性チェック
    #=================================================================
    def attribute_check()
      aErrors = []
      @hState.each{|sAtr, val|
        begin
          if (is_specified?(sAtr))
            case sAtr
            # 属性・モードID参照(文字列)
            when TSR_PRM_SOMATR, TSR_PRM_NXTSOM
              check_attribute_type(sAtr, val, String, false, @aPath)

            else
              abort(ERR_MSG % [__FILE__, __LINE__])
            end
          end
        rescue TTCError
          aErrors.push($!)
        end
      }

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: オブジェクトチェック
    #=================================================================
    def object_check(bIsPre = false)
      check_class(Bool, bIsPre)  # pre_conditionか
      # 個別チェックなし
    end

    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      # somatrを省略した場合はTA_NULL(初期モード指定なし=システム周期停止
      # モードで起動)を補完する
      unless (is_specified?(TSR_PRM_SOMATR))
        @hState[TSR_PRM_SOMATR] = "TA_NULL"
      end
    end

    #=================================================================
    # 概　要: オブジェクトのエイリアス変換テーブルを返す
    #=================================================================
    def get_alias(sTestID, nNum = nil)
      check_class(String, sTestID)      # テストID
      check_class(Integer, nNum, true)  # 識別番号

      # システム動作モードIDはエイリアス変換しない
      hResult = {}
      hResult[@sObjectID] = @sObjectID

      return hResult  # [Hash]エイリアス変換テーブル
    end

    #=================================================================
    # 概　要: オブジェクトを複製して返す
    #=================================================================
    def dup()
      cObjectInfo = super()

      cObjectInfo.sObjectID   = safe_dup(@sObjectID)
      cObjectInfo.sObjectType = safe_dup(@sObjectType)
      cObjectInfo.hState      = safe_dup(@hState)

      return cObjectInfo  # [Object]複製したオブジェクト
    end
  end

  #===================================================================
  # クラス名: TimeWindow
  # 概    要: タイムウィンドウ(ATT_TWD)の情報を処理するクラス
  #===================================================================
  class TimeWindow
    include TTCModule
    include TTCModule::ObjectCommon

    #=================================================================
    # 概  要: 属性チェック
    #=================================================================
    def attribute_check()
      aErrors = []
      @hState.each{|sAtr, val|
        begin
          if (is_specified?(sAtr))
            case sAtr
            # ドメインID・動作モードID参照(文字列)
            when TSR_PRM_DOMID, TSR_PRM_SOMID
              check_attribute_type(sAtr, val, String, false, @aPath)

            # 0以上の整数か文字列(マクロ・式)
            when TSR_PRM_TWDORD, TSR_PRM_TWDLEN
              unless (val.is_a?(String))
                check_attribute_unsigned(sAtr, val, @aPath)
              end

            # 通知方法の指定（ATT_TWD 第5要素・文字列でそのまま埋め込む）
            when TSR_PRM_NOTIFY
              check_attribute_type(sAtr, val, String, false, @aPath)

            else
              abort(ERR_MSG % [__FILE__, __LINE__])
            end
          end
        rescue TTCError
          aErrors.push($!)
        end
      }

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: オブジェクトチェック
    #=================================================================
    def object_check(bIsPre = false)
      check_class(Bool, bIsPre)  # pre_conditionか
      # 個別チェックなし
    end

    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      # 補完なし
    end

    #=================================================================
    # 概　要: オブジェクトのエイリアス変換テーブルを返す
    #=================================================================
    def get_alias(sTestID, nNum = nil)
      check_class(String, sTestID)      # テストID
      check_class(Integer, nNum, true)  # 識別番号

      # タイムウィンドウIDはエイリアス変換しない
      hResult = {}
      hResult[@sObjectID] = @sObjectID

      return hResult  # [Hash]エイリアス変換テーブル
    end

    #=================================================================
    # 概　要: オブジェクトを複製して返す
    #=================================================================
    def dup()
      cObjectInfo = super()

      cObjectInfo.sObjectID   = safe_dup(@sObjectID)
      cObjectInfo.sObjectType = safe_dup(@sObjectType)
      cObjectInfo.hState      = safe_dup(@hState)

      return cObjectInfo  # [Object]複製したオブジェクト
    end
  end
end
