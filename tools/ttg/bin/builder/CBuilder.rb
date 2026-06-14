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
#  $Id: CBuilder.rb 72 2020-03-19 08:08:03Z fujisft-shigihara $
#
require "bin/builder/CodeBuilder.rb"
require "bin/product/CCode.rb"

module TTG
  #===================================================================
  # クラス名: CBuilder
  # 概    要: 中間コードからCコードを生成して返す
  #===================================================================
  class CBuilder < CodeBuilder
    include CommonModule

    #=================================================================
    # 概  要: 中間コードからc/h/cfgファイルを生成する
    #=================================================================
    def build(cImCode)
      check_class(IntermediateCode, cImCode) # 中間コードのインスタンス

      @aGlobalVar       = cImCode.aGlobalVar.dup()
      @aCode            = cImCode.aCode.dup()
      @hProcUnitInfo    = cImCode.hProcUnitInfo.dup()
      @nStack           = cImCode.nStack
      @aHeader          = cImCode.aHeader.dup()
      @hConfig          = cImCode.hConfig.dup()
      @aDomainID        = cImCode.aDomainID.dup()
      @aTskpriForSubpri = cImCode.aTskpriForSubpri.dup()
      @cConf            = Config.new() # コンフィグを取得
      @sFileName        = @cConf.get_out_file()

      @hEnumData     = Hash.new()  # enum宣言用ハッシュ

      sCCode      = make_c()
      sHeaderCode = make_header()
      sCfgCode    = make_cfg()

      @@cCode = CCode.new(sCCode, sHeaderCode, sCfgCode)
    end

    #=================================================================
    # 概  要: cfgファイル用文字列を生成して返す
    #=================================================================
    def make_cfg()
      # 出力コードの臨時文字列
      if (@cConf.is_hrp?())
        sCfgCode = <<-EOS
#{VERSION}
INCLUDE("tecsgen.cfg");
INCLUDE("ttsp_svc.cfg");
INCLUDE("ttsp_target.cfg");
#include "#{@sFileName}.h"

        EOS
      else
        sCfgCode = <<-EOS
#{VERSION}
INCLUDE("tecsgen.cfg");
INCLUDE("ttsp_target.cfg");
#include "#{@sFileName}.h"

        EOS
      end

      # スタック領域をTTGが用意する場合，標準RAMリージョンに配置する
      if (@cConf.is_hrp?() && @cConf.is_stack_share_mode?())
        if (@cConf.is_fmp?())  # HRMP3
          (1..@cConf.get_prc_num()).each{|nPrcid|
            sCfgCode += "#{API_ATT_SEC}(\".ttg_stack_section_CLS_ALL_PRC#{nPrcid}\", {#{KER_TA_NOWRITE}|#{KER_TA_NOREAD}, TTSP_STANDARD_RAM_REGION});#{TTG_NL}"
          }
        else
          sCfgCode += "#{API_ATT_SEC}(\".ttg_stack_section\", {#{KER_TA_NOWRITE}|#{KER_TA_NOREAD}, TTSP_STANDARD_RAM_REGION});#{TTG_NL}"
        end
      end

      hNoClassData = {}
      hNoDomainData = {}
      aNoClassDomainData = []
      if (@cConf.is_asp?())
        @hConfig.each{|sClassID, aClassData|
          # 静的APIの記述
          aClassData.each{|sCode|
            sCfgCode.concat("#{sCode}#{TTG_NL}")
          }
        }
      elsif (@cConf.is_fmp?() && @cConf.is_hrp?())  # HRMP
        @hConfig.each{|sClassID, hClassData|
          if (sClassID == IMC_NO_CLASS)
            hClassData.each{|sDomainID, aDomainData|
              if (sDomainID == IMC_NO_DOMAIN)
                aNoClassDomainData.concat(aDomainData)
              else
                if (!hNoClassData.has_key?(sDomainID))
                  hNoClassData[sDomainID] = []
                end
                hNoClassData[sDomainID].concat(aDomainData)
              end
            }
            next
          end

          sCfgCode.concat("CLASS(#{sClassID}){#{TTG_NL}")

          hClassData.each{|sDomainID, aDomainData|
            if ((sDomainID == IMC_NO_DOMAIN) && (sClassID != IMC_NO_CLASS))
              if (!hNoDomainData.has_key?(sClassID))
                hNoDomainData[sClassID] = []
              end
              hNoDomainData[sClassID].concat(aDomainData)
              next
            end

            if (sDomainID == TSR_STT_DOM_KERNEL)
              sCfgCode.concat("#{TTG_TB}KERNEL_DOMAIN {#{TTG_NL}")
            else
              sCfgCode.concat("#{TTG_TB}DOMAIN(#{sDomainID}) {#{TTG_NL}")
            end

            # 静的APIの記述
            aDomainData.each{|sCode|
              sCfgCode.concat("#{TTG_TB}#{TTG_TB}#{sCode}#{TTG_NL}")
            }

            sCfgCode.concat("#{TTG_TB}}#{TTG_NL}")
          }
          sCfgCode.concat("}#{TTG_NL}")
        }

      elsif (@cConf.is_fmp?())
        @hConfig.sort.each{|sClassID, aClassData|
          # どのクラスにも属さない処理単位は，後回し
          if (sClassID == IMC_NO_CLASS)
            next
          end

          # クラス宣言開始
          sCfgCode.concat("CLASS(#{sClassID}){#{TTG_NL}")

          # 静的APIの記述
          aClassData.each{|sCode|
            sCfgCode.concat("#{TTG_TB}#{sCode}#{TTG_NL}")
          }

          # クラス宣言終わり
          sCfgCode.concat("}#{TTG_NL}")
        }
      elsif (@cConf.is_hrp?())
        @hConfig.each{|sDomainID, aDomainData|
          # どのドメインにも属さない処理単位は，後回し
          if (sDomainID == IMC_NO_DOMAIN)
            next
          end

          if (sDomainID == TSR_STT_DOM_KERNEL)
            sCfgCode.concat("KERNEL_DOMAIN {#{TTG_NL}")
          else
            sCfgCode.concat("DOMAIN(#{sDomainID}) {#{TTG_NL}")
          end

          # 静的APIの記述
          aDomainData.each{|sCode|
            sCfgCode.concat("#{TTG_TB}#{sCode}#{TTG_NL}")
          }

          sCfgCode.concat("}#{TTG_NL}")

          # 出力したドメインを一覧から削除
          @aDomainID.delete(sDomainID)
        }
      end

      # FMPの場合で，どのクラスにも属さない処理単位
      if (@cConf.is_fmp?())
        if (@cConf.is_hrp?())  # HRMP
          hNoClassData.each{|sDomainID, aDomainData|
            if (sDomainID == TSR_STT_DOM_KERNEL)
              sCfgCode.concat("KERNEL_DOMAIN {#{TTG_NL}")
            else
              sCfgCode.concat("DOMAIN(#{sDomainID}) {#{TTG_NL}")
            end
            aDomainData.each{|sCode|
              sCfgCode.concat("#{TTG_TB}#{sCode}#{TTG_NL}")
            }
            sCfgCode.concat("}#{TTG_NL}")
          }
        else
          @hConfig.each{|sClassID, aClassData|
            if (sClassID == IMC_NO_CLASS)
              aClassData.each{|sCode|
                sCfgCode.concat("#{sCode}#{TTG_NL}")
              }
            end
          }
        end

        # サブ優先度が指定されたタスクが存在する場合，対象の現在優先度の設定を行う
        @aTskpriForSubpri.each{|nTskpri|
          sCfgCode.concat("#{API_ENA_SPR}(#{nTskpri});#{TTG_NL}")
        }
      end

      # HRPの場合で，どのドメインにも属さない処理単位
      if (@cConf.is_hrp?())
        sTecsMod = ""
        if (@cConf.is_fmp?())  # HRMP
          hNoDomainData.each{|sClassID, aClassData|
            sCfgCode.concat("CLASS(#{sClassID}){#{TTG_NL}")
            aClassData.each{|sCode|
              sCfgCode.concat("#{TTG_TB}#{sCode}#{TTG_NL}")
            }
            sCfgCode.concat("}#{TTG_NL}")
          }
        else
          @hConfig.each{|sDomainID, aDomainData|
            if (sDomainID == IMC_NO_DOMAIN)
              aDomainData.each{|sCode|
                sCfgCode.concat("#{sCode}#{TTG_NL}")
              }
            end
          }
          sTecsMod = "#{TTG_NL}#{TTG_TB}ATT_MOD(\"prb_str.o\");#{TTG_NL}#{TTG_TB}ATT_MOD(\"init_tecs.o\");"
        end

        # ドメイン一覧にドメインが残っている場合
        # (オブジェクトが所属しないドメインがある場合)
        @aDomainID.each{|sDomainID|
          sCfgCode.concat("DOMAIN(#{sDomainID}) {#{TTG_NL}")
          sCfgCode.concat("}#{TTG_NL}")
        }

        sCfgCode += <<-EOS
KERNEL_DOMAIN {#{sTecsMod}
	ATT_MOD("ttsp_target_test.o");
}
ATT_MOD("out.o");
ATT_MOD("ttsp_test_lib.o");
ATT_MOD("log_output.o");
ATT_MOD("vasyslog.o");
ATT_MOD("t_perror.o");
ATT_MOD("strerror.o");
ATT_MOD("libc.a");
        EOS

        # ドメインにもクラスにも所属しないオブジェクトがある場合(HRMP)
        aNoClassDomainData.each{|sCode|
          sCfgCode.concat("#{sCode}#{TTG_NL}")
        }
      end

      return sCfgCode  # [String]cfgファイル用文字列
    end

    #=================================================================
    # 概  要: hファイル用文字列を生成して返す
    #=================================================================
    def make_header()
      # 出力コードの臨時文字列
      sHeaderCode = <<-EOS
#{VERSION}
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

      EOS

      sHeaderCode.concat("#include \"ttsp_target_test.h\"#{TTG_NL}#{TTG_NL}")

      # 共有スタックの定義
      if (@cConf.is_stack_share_mode?())
        if (!@cConf.is_hrp?())
          sHeaderCode.concat("#define TTSP_STACK_SHARE#{TTG_NL}")
          nNum = 1
          while nNum <= @nStack
            sHeaderCode.concat("extern STK_T ttg_stack_#{nNum}[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];#{TTG_NL}")
            nNum += 1
          end
        else
          sHeaderCode.concat("#define TTSP_STACK_SHARE_HRP#{TTG_NL}")
          sHeaderCode.concat("#{TTG_NL}#define TTG_STACK_NUM #{@nStack}")
          sHeaderCode.concat("#{TTG_NL}#define TTG_DOMAIN_NUM #{@aDomainID.size() + 1}#{TTG_NL}#{TTG_NL}")
        end
      end

      # enumの定義
      if (!@hEnumData.empty?())
        @hEnumData.each{|sEnumID, aTestID|
          sHeaderCode.concat("enum #{sEnumID}{")
          # 先頭に無効値を入れる
          sHeaderCode.concat("#{TTG_NL}#{TTG_TB}#{sEnumID.sub("ENUM_", "")}_#{TTG_ENUM_INVALID},")
          aTestID.each{|sTestID|
            sHeaderCode.concat("#{TTG_NL}#{TTG_TB}#{sTestID},")
          }
          sHeaderCode.chop!()
          sHeaderCode.concat("#{TTG_NL}};#{TTG_NL}")
        }
        sHeaderCode.concat("#{TTG_NL}")
      end

      @aHeader.sort.each{|sObjID, aArgs|
        if (aArgs.empty?())
          sHeaderCode.concat("extern void #{sObjID}(#{TYP_VOID});#{TTG_NL}")
        else
          # 拡張サービスコールは戻り値がある
          if (sObjID =~ /^#{TTG_LBL_SVC.downcase()}/)
            sHeaderCode.concat("extern #{TYP_ER_UINT} #{sObjID}(#{aArgs.join(', ')});#{TTG_NL}")
          else
            sHeaderCode.concat("extern void #{sObjID}(#{aArgs.join(', ')});#{TTG_NL}")
          end
        end
      }

      # グローバル変数のextern宣言(タイムイベント通知/エラー通知用)
      @aGlobalVar.each{|sVarName, sVarType, snVarValue|
        sHeaderCode.concat("extern #{sVarType} #{sVarName};#{TTG_NL}")
      }

      sHeaderCode.concat("#{TTG_NL}#endif /* TOPPERS_TTG_HEADER */")

      return sHeaderCode  # [String]hファイル用文字列
    end

    #=================================================================
    # 概  要: cファイル用文字列を生成して返す
    #=================================================================
    def make_c()
      # 出力コードの臨時文字列
      sCCode = <<-EOS
#{VERSION}
#include <kernel.h>
#include <t_syslog.h>
#include "syssvc/syslog.h"
#include "kernel_cfg.h"
#include "ttsp_test_lib.h"
#include "#{@sFileName}.h"

      EOS

      # メモリ保護ありの場合，特権となる必要のある関数をSVCへ置き換える
      if (@cConf.is_hrp?())
        sTemp = <<-EOS
#define ttsp_target_gain_tick() cal_svc(TTSP_FN_GAIN_TICK, 0, 0, 0, 0, 0)
#define ttsp_cpuexc_raise(excno) cal_svc(TTSP_FN_CPUEXC_RAISE, (excno), 0, 0, 0, 0)
#define ttsp_int_raise(intno) cal_svc(TTSP_FN_INT_RAISE, (intno), 0, 0, 0, 0)
#define ttsp_value_sync(proc_id, var_name, target_var, target_val) cal_svc(TTSP_FN_VALUE_SYNC, (intptr_t)(proc_id), (intptr_t)(var_name), (intptr_t)(target_var), (intptr_t)(target_val), 0)
#define ttsp_simt_advance(time) cal_svc(TTSP_FN_SIMT_ADVANCE, (intptr_t)(time), 0, 0, 0, 0)

        EOS

        sCCode.concat(sTemp)
      end

      # 共有スタックの定義
      if (@cConf.is_stack_share_mode?() && !@cConf.is_hrp?())
        nNum = 1
        while nNum <= @nStack
          sCCode.concat("STK_T ttg_stack_#{nNum}[COUNT_STK_T(TTSP_TASK_STACK_SIZE)];#{TTG_NL}")
          nNum += 1
        end
      end

      # GCOVを取得する場合
      if (@cConf.enable_gcov?())
        sGcov = <<-EOS

extern void #{FNC_GCOV_INIT}(void);
extern void #{FNC_GCOV_PAUSE}(void);
extern void #{FNC_GCOV_RESUME}(void);
extern void #{FNC_GCOV_DUMP}(void);
        EOS

        sCCode.concat(sGcov)
      end


      sCCode.concat(make_global_var())
      sCCode.concat(make_function())

      return sCCode  # [String]cファイル用文字列
    end

    #=================================================================
    # 概  要: 関数のコード文字列を生成して返す
    #=================================================================
    def make_function()
      # ローカル変数の記述
      @hFuncCode = make_local_var() # 処理速度向上のためインスタンス変数として引数渡ししない

      # プレコードを追加
      @hProcUnitInfo.each{|sObjID, hObjData|
        bPreChk = false
        hObjData[:precode].each{|sCode|
          @hFuncCode[sObjID].push("#{TTG_TB}#{sCode}#{TTG_NL}")
          bPreChk = true
        }
        # プレコードがある場合，最後に改行を入れる
        if (bPreChk == true)
          @hFuncCode[sObjID].push("#{TTG_NL}")
        end
      }

      # bootcntが0でない処理単位は複数回起動用静的変数のインクリメント処理
      # (割込みサービスルーチンの場合はmake_block_codet内でインクリメントする)
      @hProcUnitInfo.each{|sObjID, hObjData|
        if ((hObjData[:fbootcnt] > TTG_MAIN_BOOTCNT) && !(sObjID =~ /^#{TTG_LBL_ISR}_.+/))
          @hFuncCode[sObjID].push("#{TTG_TB}#{VAR_BOOTCNT}++;#{TTG_NL}#{TTG_NL}")
        end
      }

      # テストシナリオ対象外の件数を減算
      nCnt = 0
      nTotal = @aCode.size()
      @aCode.each{|hScenarioes|
        hScenarioes.each{|sScenarioID, aScenario|
          GRP_IGNORE_LABEL.each{|sIgnoreLabel|
            if (sScenarioID.include?(sIgnoreLabel))
              nTotal -= 1
              break
            end
          }
        }
      }

      @aCode.each{|hScenarioes|
        hScenarioes.each{|sScenarioID, aScenario|
          bChk = false
          GRP_IGNORE_LABEL.each{|sIgnoreLabel|
            if (sScenarioID.include?(sIgnoreLabel))
              bChk = true
              break
            end
          }
          if (bChk == false)
            nCnt += 1
            if (@cConf.is_no_progress_bar_mode?() == true)
              $stderr.puts "[IMC][#{"%5.1f" % (100 * nCnt.to_f / nTotal.to_f)}\% (#{"%4d" % nCnt}/#{"%4d" % nTotal})] #{sScenarioID}"
            else
              print_progress("IMC", sScenarioID, nCnt, nTotal)
            end
          end

          # テストケース毎の処理
          aScenario.each{|hScenarioData|
            hScenarioData.each{|sConditionID, aConditionData|
              if (sConditionID == IMC_TTG_MAIN)
                make_block_code(aConditionData)
              else
                aConditionData.each{|hBlock|
                  hBlock.each{|sBlockID, aBlockData|
                    make_block_code(aBlockData, sScenarioID)
                  }
                }
              end
            }
          }
        }
      }
      # プログレスバー用表示のリセット
      if (@cConf.is_no_progress_bar_mode?() != true)
        finish_progress("IMC", nTotal)
      end

      # ポストコードを追加
      @hProcUnitInfo.each{|sObjID, hObjData|
        hObjData[:postcode].each{|sCode|
          @hFuncCode[sObjID].push("#{TTG_TB}#{sCode}#{TTG_NL}")
        }
      }

      # 出力コードを保持する文字列
      sFuncCode = ""

      # ヘッダをハッシュ化する
      hHeader = {}
      @aHeader.each{|aFuncInfo|
        hHeader[aFuncInfo[0]] = aFuncInfo[1]
      }

      # 処理単位ごとに分けたハッシュを，出力する形のコードに作る
      @hFuncCodeLow = @hFuncCode.sort_by{|key, val| key.downcase }
      @hFuncCodeLow.each{|sObjectID, aCode|
        # 関数宣言開始
        if (hHeader[sObjectID.downcase].empty?())
          sFuncCode.concat("void #{sObjectID.downcase}(#{TYP_VOID}){#{TTG_NL}")
        else
          # 拡張サービスコールは戻り値がある
          if (sObjectID =~ /^#{TTG_LBL_SVC}/)
            sFuncCode.concat("#{TYP_ER_UINT} #{sObjectID.downcase}(#{hHeader[sObjectID.downcase].join(', ')}){#{TTG_NL}")
          else
            sFuncCode.concat("void #{sObjectID.downcase}(#{hHeader[sObjectID.downcase].join(', ')}){#{TTG_NL}")
          end
        end

        # 内部コードの記述
        aCode.each{ |sCode|
          sFuncCode.concat("#{sCode}")
        }

        # 関数宣言終わり
        # 拡張サービスコールは戻り値がある
        if (sObjectID =~ /^#{TTG_LBL_SVC}/)
          sFuncCode.concat("#{TTG_TB}return(E_OK);#{TTG_NL}}#{TTG_NL}#{TTG_NL}")
        else
          sFuncCode.concat("}#{TTG_NL}#{TTG_NL}")
        end
      }

      return sFuncCode  # [String]関数のコード
    end

    #=================================================================
    # 概  要: グローバル変数のコードを生成して返す
    #=================================================================
    def make_global_var()

      # 出力コードの臨時文字列
      sGlobalCode = ""

      @aGlobalVar.each{|sVarName, sVarType, snVarValue|
        # :valueの値が存在するかどうか判別
        if (snVarValue.nil?())
          sGlobalCode.concat("#{sVarType} #{sVarName};#{TTG_NL}")
        else
          sGlobalCode.concat("#{sVarType} #{sVarName} = #{snVarValue};#{TTG_NL}")
        end
      }

      # 改行
      sGlobalCode.concat("#{TTG_NL}")

      return sGlobalCode  # [String]グローバル変数のコード
    end

    #=================================================================
    # 概  要: ローカル変数のコードを生成して返す
    #=================================================================
    def make_local_var()

      # 出力前のコードを保持するハッシュ
      hLocalCode = {}

      @hProcUnitInfo.each{|sObjID, hObjData|
        # キーに対する値がない場合，新しいキーを作る
        # (ここで全処理単位に対する@hFuncCodeのキーが作成される)
        if (hLocalCode[sObjID].nil?())
          hLocalCode[sObjID] = []
        end

        hObjData[:localvar].each{|sVarName, hVarData|
          # :valueの値が存在するかどうか判別
          if (hVarData[:value].nil?())
            hLocalCode[sObjID].push("#{TTG_TB}#{hVarData[:type]} #{sVarName};#{TTG_NL}")
          else
            hLocalCode[sObjID].push("#{TTG_TB}#{hVarData[:type]} #{sVarName} = #{hVarData[:value]};#{TTG_NL}")
          end
        }

        # 複数回起動用静的変数の宣言
        if (hObjData[:fbootcnt] > TTG_MAIN_BOOTCNT)
          hLocalCode[sObjID].push("#{TTG_TB}static int #{VAR_BOOTCNT} = -1;#{TTG_NL}")
        end

        # 改行
        hLocalCode[sObjID].push("#{TTG_NL}")
      }

      return hLocalCode  # [String]ローカル変数のコード
    end

    #=================================================================
    # 概  要: ブロックの実行コードを生成する
    #=================================================================
    def make_block_code(aBlockData, sTestID = nil)
      check_class(Array,  aBlockData)    # ブロックのコードのデータ
      check_class(String, sTestID, true) # テストID

      # ブロックごとに改行を出すためのオブジェクトリスト
      aObjList = []

      #nPrcID, sAttrはCコード生成時は使用しない
      aBlockData.each{|sObjID, sCode, nBootCnt, nPrcID, sAttr|
        # 改行を入れるオブジェクリスト挿入
        aObjList.push(sObjID)

        # 割込みハンドラ，割込みサービスルーチン，CPU例外ハンドラ，拡張サービスコール用処理
        if ((sObjID =~ /^#{TTG_LBL_INTHDR}_.+/) || (sObjID =~ /^#{TTG_LBL_ISR}_.+/) ||
            (sObjID =~ /^#{TTG_LBL_EXCEPTION}_.+/) || (sObjID =~ /^#{TTG_LBL_SVC}_.+/))
          # 必要な文字列作成
          # (割込みサービスルーチンの場合，オブジェクトIDから本来のIDの部分を除去する)
          if (sObjID =~ /^#{TTG_LBL_ISR}_.+/)
            sEnumID       = "ENUM_#{TTG_LBL_ISR}"
            sEnumElement  = "#{TTG_LBL_ISR}_#{sTestID}"
            sIfTestID     = "#{TTG_TB}if (#{TTG_LBL_ISR}_#{VAR_BOOTCNT} == #{sEnumElement}) {#{TTG_NL}"
            sEndIfTestID  = "#{TTG_TB}} \/* #{TTG_LBL_ISR}_#{VAR_BOOTCNT} == #{sEnumElement} *\/#{TTG_NL}"
          else
            sEnumObjID    = sObjID
            sEnumID       = "ENUM_#{sEnumObjID}"
            sEnumElement  = "#{sEnumObjID}_#{sTestID}"
            sIfTestID     = "#{TTG_TB}if (#{sEnumObjID}_#{VAR_BOOTCNT} == #{sEnumObjID}_#{sTestID}) {#{TTG_NL}"
            sEndIfTestID  = "#{TTG_TB}} \/* #{sEnumObjID}_#{VAR_BOOTCNT} == #{sEnumObjID}_#{sTestID} *\/#{TTG_NL}"
          end

          sIfBootcnt    = "#{TTG_TB}#{TTG_TB}\/* #{sTestID} *\/#{TTG_NL}#{TTG_TB}#{TTG_TB}if (#{VAR_BOOTCNT} == #{nBootCnt}) {#{TTG_NL}"
          sInitBootcnt  = "#{TTG_TB}#{TTG_TB}#{TTG_TB}#{VAR_BOOTCNT} = -1; \/* #{sTestID} *\/#{TTG_NL}#{TTG_NL}"
          sEndIfBootcnt = "#{TTG_NL}#{TTG_TB}#{TTG_TB}} \/* #{VAR_BOOTCNT} == #{nBootCnt} (#{sTestID}) *\/#{TTG_NL}"

          # enumデータの初期処理
          if (!@hEnumData.has_key?(sEnumID))
            @hEnumData[sEnumID] = [sEnumElement]
          # データがなければ追加
          elsif (!@hEnumData[sEnumID].include?(sEnumElement))
            @hEnumData[sEnumID].push(sEnumElement)
          end

          # テストID毎の起動
          if (!@hFuncCode[sObjID].include?(sIfTestID))
            @hFuncCode[sObjID].push(sIfTestID)

            # 割込みサービスルーチンの場合にif文の内側で行う処理
            if (sObjID =~ /^#{TTG_LBL_ISR}_.+/)
              # bootcntが0でない場合，bootcntをインクリメント
              # (他のテスト内でのISR起動時にインクリメントされるのを避ける)
              if (@hProcUnitInfo[sObjID][:fbootcnt] > TTG_MAIN_BOOTCNT)
                @hFuncCode[sObjID].push("#{TTG_TB}#{TTG_TB}#{VAR_BOOTCNT}++;#{TTG_NL}#{TTG_NL}")
              end

              # 明示的な割込み要求クリア処理
              # (他のテスト内でのISR起動時にクリア関数が実行されるのを避ける)
              if (sTestID.include?(TTG_LBL_CHK_ENAINT))
                # テストIDにTTG_LBL_CHK_ENAINTが含まれる場合
                snIntNo = sObjID.gsub(/^#{TTG_LBL_ISR}_(.+)_#{TTG_LBL_CHK_ENAINT}$/, "\\1")
              else
                # テストIDにTTG_LBL_CHK_ENAINTが含まれない場合
                snIntNo = sObjID.gsub(/^#{TTG_LBL_ISR}_(.+)_#{sTestID}_.+$/, "\\1")
              end
              # 取り出した割込み番号でクリア関数実行
              @hFuncCode[sObjID].push("#{TTG_TB}#{TTG_TB}#{FNC_CLEAR_INT_REQ}(#{snIntNo});#{TTG_NL}#{TTG_NL}")
            end
          end

            # 複数回起動
            if (@hProcUnitInfo["#{sObjID}"][:fbootcnt] == TTG_MAIN_BOOTCNT)
              @hFuncCode[sObjID].push("#{TTG_TB}#{TTG_TB}#{sCode}#{TTG_NL}")
            else
              if (!@hFuncCode[sObjID].include?(sIfBootcnt))
                @hFuncCode[sObjID].push(sIfBootcnt)
                @hFuncCode[sObjID].delete(sInitBootcnt)
                @hFuncCode[sObjID].push(sInitBootcnt)
              end

              @hFuncCode[sObjID].push("#{TTG_TB}#{TTG_TB}#{TTG_TB}#{sCode}#{TTG_NL}")

              if (@hFuncCode[sObjID].include?(sEndIfBootcnt))
                @hFuncCode[sObjID].delete(sEndIfBootcnt)
              end

              @hFuncCode[sObjID].push(sEndIfBootcnt)
            end

          if (@hFuncCode[sObjID].include?(sEndIfTestID))
            @hFuncCode[sObjID].delete(sEndIfTestID)
          end

          @hFuncCode[sObjID].push(sEndIfTestID)
        # 通常のソースコード
        else
          # 必要な文字列作成
          sIfBootcnt    = "#{TTG_TB}if (#{VAR_BOOTCNT} == #{nBootCnt}) {#{TTG_NL}"
          sEndIfBootcnt = "#{TTG_TB}} \/* #{VAR_BOOTCNT} == #{nBootCnt} *\/#{TTG_NL}"

          # 複数回起動の確認
          if (@hProcUnitInfo[sObjID][:fbootcnt] == TTG_MAIN_BOOTCNT)
            @hFuncCode[sObjID].push("#{TTG_TB}#{sCode}#{TTG_NL}")
          else
            if (!@hFuncCode[sObjID].include?(sIfBootcnt))
              @hFuncCode[sObjID].push(sIfBootcnt)
            end

            @hFuncCode[sObjID].push("#{TTG_TB}#{TTG_TB}#{sCode}#{TTG_NL}")

            if (@hFuncCode[sObjID].include?(sEndIfBootcnt))
              @hFuncCode[sObjID].delete(sEndIfBootcnt)
            end

            @hFuncCode[sObjID].push(sEndIfBootcnt)
          end
        end
      }

      # ブロック内のオブジェクト毎に改行を入れる
      aObjList.uniq.each{|sObjID|
        @hFuncCode[sObjID].push("#{TTG_NL}")
      }
    end

    #=================================================================
    # 概  要: 生成したコードをファイル化する
    #=================================================================
    def output_code_file(cCCode, sFileName)
      check_class(CCode, cCCode)    # CCodeのインスタンス
      check_class(String, sFileName) # 出力時のファイル名

      cCCode.output_code_file(sFileName)
    end

    #=================================================================
    # 概  要: 生成したコードクラスを返す
    #=================================================================
    def get_result()
      return @@cCode  # [CCode]生成したコードクラス
    end
  end
end
