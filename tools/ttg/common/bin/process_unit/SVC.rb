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
#  $Id: SVC.rb 29 2019-02-15 01:56:21Z fujisft-shigihara $
#
require "common/bin/process_unit/ProcessUnit.rb"
require "ttc/bin/process_unit/SVC.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: SVC
  # 概    要: 拡張サービスコールの情報を処理するクラス
  #===================================================================
  class SVC < ProcessUnit
    #=================================================================
    # 概  要: 拡張サービスコールの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_SVC, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      cElement.set_config("#{API_DEF_SVC}(#{@hState[TSR_PRM_FNCD]}, {#{KER_TA_NULL}, #{@sObjectID.downcase()}, TTSP_SVC_STACK_SIZE});", IMC_NO_CLASS, TTG_MAIN_DOMAIN) # [IMCodeElement] 拡張サービスコールを生成する静的API

    end

    #=================================================================
    # 概  要: パラメータをassertチェックするコードを返す
    #=================================================================
    def gc_assert_args(cElement, hProcUnitInfo)
      check_class(IMCodeElement, cElement) # エレメント
      check_class(Hash, hProcUnitInfo)     # 処理単位情報

      (1..5).each{|nCnt|
        cElement.set_assert(hProcUnitInfo, @cConf.get_svc_arg_name(nCnt), @hState[TSR_PRM_ARGS][nCnt - 1])
      }
    end
  end
end
