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
#  $Id: Domain.rb 72 2020-03-19 08:08:03Z fujisft-shigihara $
#
require "common/bin/CommonModule.rb"
require "common/bin/Config.rb"
require "common/bin/IMCodeElement.rb"
require "ttc/bin/sys_state/Domain.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: Domain
  # 概    要: ユーザドメインの情報を処理するクラス
  #===================================================================
  class Domain
    include CommonModule

    attr_accessor :hState, :sObjectID, :sObjectType

    @@hAccess1 = {}  # 通常操作1のアクセス許可パターン(ドメインごとの累積)
    @@hAccess2 = {}  # 通常操作2のアクセス許可パターン(ドメインごとの累積)
    @@hAccess3 = {}  # 管理操作のアクセス許可パターン(ドメインごとの累積)
    @@hAccess4 = {}  # 参照操作のアクセス許可パターン(ドメインごとの累積)

    #=================================================================
    # 概  要: ユーザドメインの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      @cConf  = Config.new()
      @hState = {}

      @sObjectID   = sObjectID
      @sObjectType = TSR_OBJ_DOMAIN
      @aPath       = aPath + [@sObjectID]

      @hState[TSR_PRM_ACCESS1] = nil  # 通常操作1のアクセス許可パターン
      @hState[TSR_PRM_ACCESS2] = nil  # 通常操作2のアクセス許可パターン
      @hState[TSR_PRM_ACCESS3] = nil  # 管理操作のアクセス許可パターン
      @hState[TSR_PRM_ACCESS4] = nil  # 参照操作のアクセス許可パターン

      pre_attribute_check(hObjectInfo, aPath + [@sObjectID], bIsPre)
      store_object_info(hObjectInfo)

      if (!@hState[TSR_PRM_ACCESS1].nil?())
        if (!@@hAccess1.has_key?(@sObjectID))
          @@hAccess1[@sObjectID] = []
          @@hAccess2[@sObjectID] = []
          @@hAccess3[@sObjectID] = []
          @@hAccess4[@sObjectID] = []
        end

        if (!@@hAccess1[@sObjectID].include?(@hState[TSR_PRM_ACCESS1]))
          @@hAccess1[@sObjectID].push(@hState[TSR_PRM_ACCESS1])
        end
        if (!@@hAccess2[@sObjectID].include?(@hState[TSR_PRM_ACCESS2]))
          @@hAccess2[@sObjectID].push(@hState[TSR_PRM_ACCESS2])
        end
        if (!@@hAccess3[@sObjectID].include?(@hState[TSR_PRM_ACCESS3]))
          @@hAccess3[@sObjectID].push(@hState[TSR_PRM_ACCESS3])
        end
        if (!@@hAccess4[@sObjectID].include?(@hState[TSR_PRM_ACCESS4]))
          @@hAccess4[@sObjectID].push(@hState[TSR_PRM_ACCESS4])
        end
      end
    end

    #=================================================================
    # 概  要: アクセス許可パターンを設定する
    #=================================================================
    def set_access_pattern(sDomain)
      check_class(String, sDomain)  # アクセスを許可するドメイン

      if (@hState[TSR_PRM_ACCESS1].nil?())
        @hState[TSR_PRM_ACCESS1] = "TACP(#{sDomain})"
        @hState[TSR_PRM_ACCESS2] = "TACP(#{sDomain})"
        @hState[TSR_PRM_ACCESS3] = "TACP(#{sDomain})"
        @hState[TSR_PRM_ACCESS4] = "TACP(#{sDomain})"
      end
    end

    #=================================================================
    # 概  要: テストシナリオのドメイン情報を@hStateに代入
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
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # すべてのドメイン情報を中間コードで管理
      cElement.set_domain(@sObjectID)

      # アクセス許可パターンを設定している場合
      if (!@hState[TSR_PRM_ACCESS1].nil?())
        cElement.set_config("#{API_ACV_DOM}({#{@@hAccess1[@sObjectID].join('|')}, #{@@hAccess2[@sObjectID].join('|')}, #{@@hAccess3[@sObjectID].join('|')}, #{@@hAccess4[@sObjectID].join('|')}});", IMC_NO_CLASS, @sObjectID)
      end
    end

    #=================================================================
    # 概  要: ドメイン情報を参照するコードをcElementに格納する
    #=================================================================
    def gc_obj_ref(cElement, hProcUnitInfo, bContext, bCpuLock)
      check_class(IMCodeElement, cElement) # エレメント
      check_class(Hash, hProcUnitInfo)     # 処理単位情報
      check_class(Bool, bContext)          # 未使用(SCObject側との対称性のため)
      check_class(Bool, bCpuLock)          # 未使用(SCObject側との対称性のため)

      # ドメイン内で指定できる最高のタスク優先度
      ### HRP2 R2.1.0時点では未サポート
    end
  end
end
