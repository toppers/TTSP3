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
#  $Id: Memory.rb 29 2019-02-15 01:56:21Z fujisft-shigihara $
#
require "common/bin/CommonModule.rb"
require "common/bin/Config.rb"
require "common/bin/IMCodeElement.rb"
require "ttc/bin/sys_state/Memory.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: Memory
  # 概    要: メモリオブジェクトの情報を処理する共通クラス
  #===================================================================
  class Memory
    include CommonModule

    attr_accessor :hState, :sObjectID, :sObjectType

    #=================================================================
    # 概  要: メモリセクションの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, sObjectType, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      @cConf  = Config.new()
      @hState = {}

      @sObjectID   = sObjectID
      @sObjectType = sObjectType
      @aPath       = aPath + [@sObjectID]

      @hState[TSR_PRM_REGION]   = nil  # メモリリージョン名
      @hState[TSR_PRM_SECTION]  = nil  # セクション名
      @hState[TSR_PRM_BASE]     = nil  # 先頭番地
      @hState[TSR_PRM_SIZE]     = nil  # サイズ
      @hState[TSR_PRM_ATR]      = nil  # 属性
      @hState[TSR_PRM_FILE]     = nil  # オブジェクトファイル名
      @hState[TSR_PRM_PADDR]    = nil  # メモリ領域の物理空間の先頭番地

      @hState[TSR_PRM_DOMAIN]   = nil  # 所属ドメイン
      @hState[TSR_PRM_ACCESS1]  = nil  # 通常操作1のアクセス許可パターン
      @hState[TSR_PRM_ACCESS2]  = nil  # 通常操作2のアクセス許可パターン
      @hState[TSR_PRM_ACCESS3]  = nil  # 管理操作のアクセス許可パターン
      @hState[TSR_PRM_ACCESS4]  = nil  # 参照操作のアクセス許可パターン
      @hState[TSR_PRM_CLASS]   = nil   # クラス

      pre_attribute_check(hObjectInfo, aPath + [@sObjectID], bIsPre)
      store_object_info(hObjectInfo)
    end

    #=================================================================
    # 概  要: テストシナリオのドメイン情報を@hStateに代入
    #=================================================================
    def store_object_info(hObjectInfo)
      check_class(Hash, hObjectInfo)  # オブジェクト情報

      # 格納
      set_specified_attribute(hObjectInfo)
      hObjectInfo.each{|atr, val|
        case atr
        when TSR_PRM_TYPE
          # 何もしない

        when TSR_PRM_REGATR, TSR_PRM_SECATR, TSR_PRM_MEMATR, TSR_PRM_PMAATR
          @hState[TSR_PRM_ATR] = val

        else
          @hState[atr] = val
        end
      }
    end
  end

  #===================================================================
  # クラス名: MemoryRegion
  # 概    要: メモリリージョンの情報を処理するクラス
  #===================================================================
  class MemoryRegion < Memory
    #=================================================================
    # 概  要: メモリリージョンの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_MEMORY_REGION, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      cElement.set_config("#{API_ATT_REG}(\"#{@hState[TSR_PRM_REGION]}\", {#{@hState[TSR_PRM_ATR]}, #{@hState[TSR_PRM_BASE]}, #{@hState[TSR_PRM_SIZE]}});", IMC_NO_CLASS, IMC_NO_DOMAIN) # [IMCodeElement]メモリリージョンを生成する静的API
    end
  end

  #===================================================================
  # クラス名: MemorySection
  # 概    要: メモリセクションの情報を処理するクラス
  #===================================================================
  class MemorySection < Memory
    #=================================================================
    # 概  要: メモリセクションの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_MEMORY_SECTION, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # アクセス許可パターンを設定している場合
      if (!@hState[TSR_PRM_ACCESS1].nil?())
        cElement.set_config("#{API_ATT_SEC}(\"#{@hState[TSR_PRM_SECTION]}\", {#{@hState[TSR_PRM_ATR]}, \"#{@hState[TSR_PRM_REGION]}\"}, {#{@hState[TSR_PRM_ACCESS1]}, #{@hState[TSR_PRM_ACCESS2]}, #{@hState[TSR_PRM_ACCESS3]}, #{@hState[TSR_PRM_ACCESS4]}});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]メモリセクションを生成する静的API
      else
        cElement.set_config("#{API_ATT_SEC}(\"#{@hState[TSR_PRM_SECTION]}\", {#{@hState[TSR_PRM_ATR]}, \"#{@hState[TSR_PRM_REGION]}\"});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]メモリセクションを生成する静的API
      end
    end
  end

  #===================================================================
  # クラス名: MemoryModule
  # 概    要: メモリモジュールの情報を処理するクラス
  #===================================================================
  class MemoryModule < Memory
    #=================================================================
    # 概  要: メモリモジュールの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_MEMORY_MODULE, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # アクセス許可パターンを設定している場合
      if (!@hState[TSR_PRM_ACCESS1].nil?())
        cElement.set_config("#{API_ATT_MOD}(\"#{@hState[TSR_PRM_FILE]}\", {#{@hState[TSR_PRM_ACCESS1]}, #{@hState[TSR_PRM_ACCESS2]}, #{@hState[TSR_PRM_ACCESS3]}, #{@hState[TSR_PRM_ACCESS4]}});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]メモリモジュールを生成する静的API
      else
        cElement.set_config("#{API_ATT_MOD}(\"#{@hState[TSR_PRM_FILE]}\");", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]メモリモジュールを生成する静的API
      end
    end
  end

  #===================================================================
  # クラス名: MemoryArea
  # 概    要: メモリ領域の情報を処理するクラス
  #===================================================================
  class MemoryArea < Memory
    #=================================================================
    # 概  要: メモリ領域の初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_MEMORY_AREA, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # アクセス許可パターンを設定している場合
      if (!@hState[TSR_PRM_ACCESS1].nil?())
        cElement.set_config("#{API_ATT_MEM}({#{@hState[TSR_PRM_ATR]}, #{@hState[TSR_PRM_BASE]}, #{@hState[TSR_PRM_SIZE]}}, {#{@hState[TSR_PRM_ACCESS1]}, #{@hState[TSR_PRM_ACCESS2]}, #{@hState[TSR_PRM_ACCESS3]}, #{@hState[TSR_PRM_ACCESS4]}});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]メモリ領域を生成する静的API
      else
        cElement.set_config("#{API_ATT_MEM}({#{@hState[TSR_PRM_ATR]}, #{@hState[TSR_PRM_BASE]}, #{@hState[TSR_PRM_SIZE]}});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]メモリ領域を生成する静的API
      end
    end
  end

  #===================================================================
  # クラス名: PhysicalMemory
  # 概    要: 物理メモリ領域の情報を処理するクラス
  #===================================================================
  class PhysicalMemory < Memory
    #=================================================================
    # 概  要: 物理メモリ領域の初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_PHYSICAL_MEMORY, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # アクセス許可パターンを設定している場合
      if (!@hState[TSR_PRM_ACCESS1].nil?())
        cElement.set_config("#{API_ATT_PMA}({#{@hState[TSR_PRM_ATR]}, #{@hState[TSR_PRM_BASE]}, #{@hState[TSR_PRM_SIZE]}, #{@hState[TSR_PRM_PADDR]}}, {#{@hState[TSR_PRM_ACCESS1]}, #{@hState[TSR_PRM_ACCESS2]}, #{@hState[TSR_PRM_ACCESS3]}, #{@hState[TSR_PRM_ACCESS4]}});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]物理メモリ領域を生成する静的API
      else
        cElement.set_config("#{API_ATT_PMA}({#{@hState[TSR_PRM_ATR]}, #{@hState[TSR_PRM_BASE]}, #{@hState[TSR_PRM_SIZE]}, #{@hState[TSR_PRM_PADDR]}});", @hState[TSR_PRM_CLASS], @hState[TSR_PRM_DOMAIN]) # [IMCodeElement]物理メモリ領域を生成する静的API
      end
    end
  end
end
