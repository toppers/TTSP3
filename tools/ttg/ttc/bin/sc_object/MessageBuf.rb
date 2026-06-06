#!ruby -Ku
#
#  TTG
#      TOPPERS Test Generator
#
#  Copyright (C) 2019      by FUJI SOFT INCORPORATED
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
#  $Id: MessageBuf.rb 59 2019-12-05 03:44:37Z fujisft-shigihara $
#
require "ttc/bin/sc_object/SCObject.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: MessageBuf
  # 概    要: メッセージバッファの情報を処理するクラス
  #===================================================================
  class MessageBuf < SCObject
    #=================================================================
    # 概  要: 属性チェック
    #=================================================================
    def attribute_check()
      aErrors = []
      begin
        super()
      rescue TTCMultiError
        aErrors = $!.aErrors
      end

      begin
        # stsklist
        sAtr = TSR_PRM_STSKLIST
        if (is_specified?(sAtr))
          cProc = Proc.new(){|hData, aPath|
            # 要素のチェック
            if (hData.is_a?(Hash))
              # 必要な要素が指定されているかチェック
              unless (hData.has_key?(TSR_PRM_MSG) && hData.has_key?(TSR_PRM_MSGSZ))
                sErr = sprintf(ERR_REQUIRED_KEY, "#{TSR_PRM_MSG} and #{TSR_PRM_MSGSZ}")
                raise(YamlError.new(sErr, aPath))
              else
                aProcErrors = []
                hData.each{|atr, val|
                  begin
                    case atr
                    when TSR_PRM_MSG
                      if (val !~ /^\{\w[\w\s,]*\}$/)
                        aErrors.push(YamlError.new("T3_MBF005: " + ERR_VAR_INVALID_MSG_FORMAT, aPath))
                      end
                    when TSR_PRM_MSGSZ
                      check_attribute_unsigned(atr, val, aPath)
                    else
                      sErr = sprintf(ERR_UNDEFINED_KEY, atr)
                      raise(YamlError.new(sErr, aPath))
                    end
                  rescue YamlError
                    aProcErrors.push($!)
                  end
                }
                check_error(aProcErrors)
              end
            else
              sErr = sprintf(ERR_LIST_ITEM_INVALID_TYPE, sAtr, Hash, hData.class())
              raise(YamlError.new(sErr, aPath))
            end
          }
          attribute_check_task_list(sAtr, @hState[sAtr], cProc)
        end
      rescue TTCMultiError
        aErrors.concat($!.aErrors)
      end

      begin
        # rtsklist
        sAtr = TSR_PRM_RTSKLIST
        if (is_specified?(sAtr))
          cProc = Proc.new(){|hData, aPath|
            if (hData.is_a?(Hash))
              aProcErrors = []
              hData.each{|atr, val|
                begin
                  case atr
                  when TSR_VAR_V_MSG, TSR_VAR_V_MSGSZ
                    check_attribute_variable(atr, val, aPath)
                  else
                    sErr = sprintf(ERR_UNDEFINED_KEY, atr)
                    raise(YamlError.new(sErr, aPath))
                  end
                rescue YamlError
                  aProcErrors.push($!)
                end
              }
              check_error(aProcErrors)
            elsif (!hData.nil?())
              sErr = sprintf(ERR_LIST_ITEM_INVALID_TYPE_NIL, sAtr, Hash, hData.class())
              raise(YamlError.new(sErr, aPath))
            end
          }
          attribute_check_task_list(sAtr, @hState[sAtr], cProc)
        end
      rescue TTCMultiError
        aErrors.concat($!.aErrors)
      end

      begin
        # msglist
        sAtr = TSR_PRM_MSGLIST
        if (is_specified?(sAtr))
          check_attribute_type(sAtr, @hState[sAtr], Array, false, @aPath)
          aPath = @aPath + [sAtr]
          aTmpErrors = []
          @hState[sAtr].each_with_index{|hData, nIndex|
            # リストの要素がHashか
            unless (hData.is_a?(Hash))
              sErr = sprintf(ERR_LIST_INVALID_TYPE, sAtr, Hash, hData.class())
              raise(YamlError.new(sErr, aPath + [nIndex]))
            end
            # 要素の内容チェック
            hData.each{|atr, val|
              begin
                case atr
                when TSR_PRM_MSG
                  if (val !~ /^\{\w[\w\s,]*\}$/)
                    aErrors.push(YamlError.new("T3_MBF005: " + ERR_VAR_INVALID_V_MSG_FORMAT, aPath + [nIndex]))
                  end
                when TSR_PRM_MSGSZ
                  check_attribute_unsigned(atr, val, aPath + [nIndex])
                else
                  sErr = sprintf(ERR_UNDEFINED_KEY, atr)
                  raise(YamlError.new(sErr, aPath + [nIndex]))
                end
              rescue YamlError
                aTmpErrors.push($!)
              end
            }
          }
          check_error(aTmpErrors)
        end
      rescue YamlError
        aErrors.push($!)
      rescue TTCMultiError
        aErrors.concat($!.aErrors)
      end

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: オブジェクトチェック
    #=================================================================
    def object_check(bIsPre)
      check_class(Bool, bIsPre)  # pre_conditionか

      aErrors = []
      begin
        super(bIsPre)
      rescue TTCMultiError
        aErrors.concat($!.aErrors)
      end

      # msglistのサイズ，格納されたメッセージサイズの合計値
      nMsgCount = 0
      nTotalMsgSize = 0
      if (!@hState[TSR_PRM_MSGLIST].nil?())
        nMsgCount = @hState[TSR_PRM_MSGLIST].size()
        @hState[TSR_PRM_MSGLIST].each{|hData|
          nTotalMsgSize += hData[TSR_PRM_MSGSZ]
        }
      end

      ### T3_MBF001: 管理領域中の空き領域のサイズ(fmbfsz)が管理領域のサイズ(mbfsz)より大きい(fmbfszが整数で指定された場合のみ)
      if (!@hState[TSR_PRM_FMBFSZ].nil?() && @hState[TSR_PRM_FMBFSZ].is_a?(Integer) &&
          (@hState[TSR_PRM_FMBFSZ] > @hState[TSR_PRM_MBFSZ]))
        aErrors.push(YamlError.new("T3_MBF001: " + ERR_OVER_THAN_MBFSZ, @aPath))
      end
      ### T3_MBF002: 管理領域にメッセージを持っているのに受信待ちタスクがいる
      if (nMsgCount > 0 && !@hState[TSR_PRM_RTSKLIST].nil?() && !@hState[TSR_PRM_RTSKLIST].empty?())
        aErrors.push(YamlError.new("T3_MBF002: " + ERR_RECV_WAITING_HAVE_MSG, @aPath))
      end
      ### T3_MBF003: 管理領域以上のサイズのメッセージを持っている
      if (nTotalMsgSize > @hState[TSR_PRM_MBFSZ])
        aErrors.push(YamlError.new("T3_MBF003: " + ERR_MSGLIST_HAVE_OVER_SIZE, @aPath))
      end

      check_error(aErrors)
    end

    #=================================================================
    # 概  要: 初期値を補完する
    #=================================================================
    def complement_init_object_info()
      super()

      # mbfatr
      unless (is_specified?(TSR_PRM_MBFATR))
        @hState[TSR_PRM_ATR] = "ANY_ATT_MBF"
      end
      # maxmsz
      unless (is_specified?(TSR_PRM_MAXMSZ))
        @hState[TSR_PRM_MAXMSZ] = "ANY_MAX_MSIZE"
      end
      # maxmsz
      unless (is_specified?(TSR_PRM_MBFSZ))
        @hState[TSR_PRM_MBFSZ] = "ANY_MBF_SIZE"
      end
    end

    #=================================================================
    # 概  要: 受信待ちタスクリスト内の変数と型の組み合わせ一覧を返す
    #=================================================================
    def get_rtsklist_variable()
      hVars = {}
      unless (@hState[TSR_PRM_RTSKLIST].nil?())
        @hState[TSR_PRM_RTSKLIST].each{|hTask|
          hTask.each{|sTask, hData|
            unless (hData.nil?())
              hVars[sTask] = {}
              hData.each{|sAtr, sVarName|
                if (sAtr == TSR_VAR_V_MSG)
                  hVars[sTask][sVarName] = [TYP_UINT8_T]
                elsif (sAtr == TSR_VAR_V_MSGSZ)
                  hVars[sTask][sVarName] = [TYP_UINT_T]
                end
              }
            end
          }
        }
      end

      return hVars  # [Hash]受信待ちタスクリスト内の変数と型の組み合わせ一覧
    end
  end
end
