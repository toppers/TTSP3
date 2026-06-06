#!ruby -Ku
#
#  TTG
#      TOPPERS Test Generator
#
#  Copyright (C) 2009-2012 by Center for Embedded Computing Systems
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#  Copyright (C) 2010-2011 by Graduate School of Information Science,
#                             Aichi Prefectural Univ., JAPAN
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
#  $Id: Execption.rb 28 2019-02-12 01:50:02Z fujisft-shigihara $
#
#  [改変] 2026-06-06: FMP3 3.4.0対応．FMPプロファイルではDEF_EXCを
#  例外発生プロセッサ専用のクラス（CLS_PRC<n>）に配置するように変更．
#  FMP3 3.4.0のコンフィギュレータは「DEF_EXCを記述したクラスの割付け
#  可能プロセッサ＝例外発生プロセッサ」を要求するため（E_RSATR）．
#  マイグレーション可能クラス（CLS_ALL_PRC<n>等）への配置は不可．
#  固定クラスへの配置は旧FMP3でも正当なため後方互換．
#
require "common/bin/process_unit/ProcessUnit.rb"
require "ttc/bin/process_unit/Execption.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: CPUException(RubyのExceptionと重複するため)
  # 概    要: CPU例外ハンドラの情報を処理するクラス
  #===================================================================
  class CPUException < ProcessUnit
    #=================================================================
    # 概  要: CPU例外ハンドラの初期化
    #=================================================================
    def initialize(sObjectID, hObjectInfo, aPath, bIsPre)
      check_class(String, sObjectID)  # オブジェクトID
      check_class(Hash, hObjectInfo)  # オブジェクト情報
      check_class(Array, aPath)       # ルートからのパス
      check_class(Bool, bIsPre)       # pre_condition内か

      super(sObjectID, hObjectInfo, TSR_OBJ_EXCEPTION, aPath, bIsPre)
    end

    #=================================================================
    # 概  要: コンフィグファイルに出力するコード作成
    #=================================================================
    def gc_config(cElement)
      check_class(IMCodeElement, cElement) # エレメント

      # [改変] FMPでは例外発生プロセッサ専用クラス（CLS_PRC<n>）に配置する
      sClass = @hState[TSR_PRM_CLASS]
      if (@cConf.is_fmp?())
        nPrcid = @hState[TSR_PRM_PRCID].nil?() ? @cConf.get_main_prcid() : @hState[TSR_PRM_PRCID]
        sClass = "CLS_PRC#{nPrcid}"
      end
      cElement.set_config("#{API_DEF_EXC}(#{@hState[TSR_PRM_EXCNO]}, {#{KER_TA_NULL}, #{@sObjectID.downcase}});", sClass, @hState[TSR_PRM_DOMAIN])
    end
  end
end
