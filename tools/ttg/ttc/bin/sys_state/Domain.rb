#!ruby -Ku
#
#  TTG
#      TOPPERS Test Generator
#
#  Copyright (C) 2015 by FUJI SOFT INCORPORATED
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
#  $Id: Domain.rb 47 2019-10-31 02:49:45Z fujisft-shigihara $
#
require "ttc/bin/class/TTCCommon.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: Domain
  # 概    要: ユーザドメインの情報を処理するクラス
  #===================================================================
  class Domain
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
            # 0以上の整数か文字列
            when TSR_PRM_ACCESS1, TSR_PRM_ACCESS2, TSR_PRM_ACCESS3, TSR_PRM_ACCESS4
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
    # 戻り値: なし
    #=================================================================
    def object_check(bIsPre = false)
      check_class(Bool, bIsPre)  # pre_conditionか

      aErrors = []
      ### T3_DOM001: ドメイン名に予約語である"KERNEL"か"NONE"を指定する
      if ((@sObjectID == TSR_STT_DOM_KERNEL) || (@sObjectID == TSR_STT_DOM_NONE))
        aErrors.push(YamlError.new("T3_DOM001: " + ERR_RESERVED_DOMAIN, @aPath))
      end

      # アクセス許可パターンのチェック
      if (bIsPre == true)
        ### T3_DOM002: access1～access4が揃って指定されていない(すべて省略も可)
        if (!((@hState[TSR_PRM_ACCESS1].nil?() && @hState[TSR_PRM_ACCESS2].nil?() &&
              @hState[TSR_PRM_ACCESS3].nil?() && @hState[TSR_PRM_ACCESS4].nil?()) ||
             (!@hState[TSR_PRM_ACCESS1].nil?() && !@hState[TSR_PRM_ACCESS2].nil?() &&
              !@hState[TSR_PRM_ACCESS3].nil?() && !@hState[TSR_PRM_ACCESS4].nil?())))
          aErrors.push(YamlError.new("T3_DOM002: " + ERR_NO_ALL_ACCESS_SET, @aPath))
        end
      end

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()

    end

    #=================================================================
    # 概　要: 補完を実行する
    #=================================================================
    def complement(cPrevObj)
      check_class(CPUState, cPrevObj)  # 直前の状態のオブジェクト

      super(cPrevObj)
    end

    #=================================================================
    # 概　要: オブジェクトのエイリアス変換テーブルを返す
    #=================================================================
    def get_alias(sTestID, nNum = nil)
      check_class(String, sTestID)      # テストID
      check_class(Integer, nNum, true)  # 識別番号

      # ドメイン名はエイリアス変換しない
      hResult = {}
      hResult[@sObjectID] = @sObjectID

      return hResult  # [Hash]エイリアス変換テーブル
    end

    #=================================================================
    # 概　要: オブジェクトを複製して返す
    #=================================================================
    def dup()
      cObjectInfo = super()

      # オブジェクトID複製
      cObjectInfo.sObjectID = safe_dup(@sObjectID)
      # オブジェクトタイプ複製
      cObjectInfo.sObjectType = safe_dup(@sObjectType)
      # パラメータ複製
      cObjectInfo.hState = safe_dup(@hState)

      return cObjectInfo  # [Object]複製したオブジェクト
    end
  end
end
