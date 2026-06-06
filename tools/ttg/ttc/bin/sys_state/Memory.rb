#!ruby -Ku
#
#  TTG
#      TOPPERS Test Generator
#
#  Copyright (C) 2009-2012 by Center for Embedded Computing Systems
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#  Copyright (C) 2010-2011 by Graduate School of Information Science,
#                             Aichi Prefectural Univ., JAPAN
#  Copyright (C) 2015-2019 by FUJI SOFT INCORPORATED
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
#  $Id: Memory.rb 34 2019-02-18 05:15:27Z fujisft-shigihara $
#
require "ttc/bin/class/TTCCommon.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: Memory
  # 概    要: メモリオブジェクトの情報を処理する共通クラス
  #===================================================================
  class Memory
    include TTCModule
    include TTCModule::ObjectCommon

    #=================================================================
    # 概  要: 属性チェック
    #=================================================================
    def attribute_check()
      aErrors = []
      @hState.each{|sAtr, val|
        begin
          sAtr = get_real_attribute_name(sAtr)
          if (is_specified?(sAtr))
            case sAtr

            # 文字列
            when TSR_PRM_REGION, TSR_PRM_SECTION, TSR_PRM_FILE, TSR_PRM_DOMAIN, TSR_PRM_CLASS
              check_attribute_type(sAtr, val, String, false, @aPath)

            # 0以上の整数か文字列
            when TSR_PRM_BASE, TSR_PRM_SIZE, TSR_PRM_PADDR,
                 TSR_PRM_ACCESS1, TSR_PRM_ACCESS2, TSR_PRM_ACCESS3, TSR_PRM_ACCESS4
              unless (val.is_a?(String))
                check_attribute_unsigned(sAtr, val, @aPath)
              end

            # 属性
            when TSR_PRM_REGATR, TSR_PRM_SECATR, TSR_PRM_MEMATR, TSR_PRM_PMAATR
              check_attribute_type(sAtr, val, String, false, @aPath)
              check_attribute_multi(sAtr, val, GRP_AVAILABLE_OBJATR[@sObjectType], @aPath)

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

      # アクセス許可パターンのチェック
      if ((bIsPre == true) && @cConf.is_hrp?())
        ### T3_SEC001, T3_MOD001, T3_MEM001, T3_PMA001:
        ### access1～access4が揃って指定されていない(すべて省略も可)
        if (!((@hState[TSR_PRM_ACCESS1].nil?() && @hState[TSR_PRM_ACCESS2].nil?() &&
              @hState[TSR_PRM_ACCESS3].nil?() && @hState[TSR_PRM_ACCESS4].nil?()) ||
             (!@hState[TSR_PRM_ACCESS1].nil?() && !@hState[TSR_PRM_ACCESS2].nil?() &&
              !@hState[TSR_PRM_ACCESS3].nil?() && !@hState[TSR_PRM_ACCESS4].nil?())))
          case @sObjectType
          when TSR_OBJ_MEMORY_SECTION
            aErrors.push(YamlError.new("T3_SEC001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_MEMORY_MODULE
            aErrors.push(YamlError.new("T3_MOD001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_MEMORY_AREA
            aErrors.push(YamlError.new("T3_MEM001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_PHYSICAL_MEMORY
            aErrors.push(YamlError.new("T3_PMA001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          else
            abort(ERR_MSG % [__FILE__, __LINE__])
          end
        end
      end

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      # domain
      if (!is_specified?(TSR_PRM_DOMAIN))
        hMacro  = @cConf.get_macro()
        @hState[TSR_PRM_DOMAIN] = hMacro["DOM_NON_TASK"]
      end

      # FMP限定
      if (@cConf.is_fmp?())
        # class
        unless (is_specified?(TSR_PRM_CLASS))
          @hState[TSR_PRM_CLASS] = CFG_MCR_CLS_SELF_ALL
        end
      end
    end

    #=================================================================
    # 概　要: オブジェクトのエイリアス変換テーブルを返す
    #=================================================================
    def get_alias(sTestID, nNum = nil)
      check_class(String, sTestID)      # テストID
      check_class(Integer, nNum, true)  # 識別番号

      # メモリオブジェクトはエイリアス変換しない
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

    #=================================================================
    # 概  要: 内部保持用属性名からTESRYの属性名を取得する
    #=================================================================
    def get_real_attribute_name(sAtr)
      check_class(String, sAtr)  # 内部保持用属性名

      if (sAtr == TSR_PRM_ATR)
        sAtr = GRP_PRM_KEY_SC_ATR[@sObjectType]
      end

      return sAtr  # [String]TESRYの属性名
    end
  end

  #===================================================================
  # クラス名: MemoryRegion
  # 概    要: メモリリージョンの情報を処理するクラス
  #===================================================================
  class MemoryRegion < Memory
    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      super()

      # regatr
      unless (is_specified?(TSR_PRM_REGATR))
        @hState[TSR_PRM_ATR] = "ANY_ATT_REG"
      end
    end
  end

  #===================================================================
  # クラス名: MemorySection
  # 概    要: メモリセクションの情報を処理するクラス
  #===================================================================
  class MemorySection < Memory
    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      super()

      # secatr
      unless (is_specified?(TSR_PRM_SECATR))
        @hState[TSR_PRM_ATR] = "ANY_ATT_SEC"
      end
    end
  end

  #===================================================================
  # クラス名: MemoryArea
  # 概    要: メモリ領域の情報を処理するクラス
  #===================================================================
  class MemoryArea < Memory
    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      super()

      # secatr
      unless (is_specified?(TSR_PRM_MEMATR))
        @hState[TSR_PRM_ATR] = "ANY_ATT_MEM"
      end
    end
  end

  #===================================================================
  # クラス名: PhysicalMemory
  # 概    要: 物理メモリ領域の情報を処理するクラス
  #===================================================================
  class PhysicalMemory < Memory
    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      super()

      # secatr
      unless (is_specified?(TSR_PRM_PMAATR))
        @hState[TSR_PRM_ATR] = "ANY_ATT_PMA"
      end
    end
  end
end
