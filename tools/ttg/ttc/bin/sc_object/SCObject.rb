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
#  $Id: SCObject.rb 72 2020-03-19 08:08:03Z fujisft-shigihara $
#
require "ttc/bin/sc_object/SCObject.rb"

#=====================================================================
# CommonModule
#=====================================================================
module CommonModule
  #===================================================================
  # クラス名: SCObject
  # 概    要: 同期・通信オブジェクトの情報を処理するクラス
  #===================================================================
  class SCObject
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
            # 0以上の整数
            when TSR_PRM_DTQCNT, TSR_PRM_PDQCNT, TSR_PRM_MAXSEM, TSR_PRM_ISEMCNT, TSR_PRM_SEMCNT,
                 TSR_PRM_IFLGPTN, TSR_PRM_FLGPTN, TSR_PRM_BLKCNT, TSR_PRM_FBLKCNT, TSR_PRM_BLKSZ,
                 TSR_PRM_MAXMSZ, TSR_PRM_MBFSZ, TSR_PRM_MSGSZ
              check_attribute_unsigned(sAtr, val, @aPath)

            # 文字列
            when TSR_PRM_CLASS, TSR_PRM_PROCID, TSR_PRM_DOMAIN, TSR_PRM_HTSKID
              check_attribute_type(sAtr, val, String, false, @aPath)

            # 0以上の整数か文字列
            when TSR_PRM_ACCESS1, TSR_PRM_ACCESS2, TSR_PRM_ACCESS3, TSR_PRM_ACCESS4, TSR_PRM_FMBFSZ, TSR_PRM_KERMPF,
                 TSR_PRM_DTQMB, TSR_PRM_PDQMB, TSR_PRM_MPF, TSR_PRM_MPFMB
              unless (val.is_a?(String))
                check_attribute_unsigned(sAtr, val, @aPath)
              end

            # 属性
            when TSR_PRM_SEMATR, TSR_PRM_FLGATR, TSR_PRM_DTQATR, TSR_PRM_PDQATR, TSR_PRM_MBXATR, TSR_PRM_MPFATR, TSR_PRM_MTXATR, TSR_PRM_MBFATR
              check_attribute_type(sAtr, val, String, false, @aPath)
              check_attribute_multi(sAtr, val, GRP_AVAILABLE_OBJATR[@sObjectType], @aPath)

            # 優先度
            when TSR_PRM_MAXDPRI, TSR_PRM_MAXMPRI, TSR_PRM_CEILPRI
              check_attribute_range(sAtr, val, TTC_MAX_PRI, TTC_MIN_PRI, @aPath)

            # spnstat
            when TSR_PRM_SPNSTAT
              check_attribute_type(sAtr, val, String, false, @aPath)
              check_attribute_enum(sAtr, val, GRP_ENUM_SPNSTAT, @aPath)

            # mtxstat
            when TSR_PRM_MTXSTAT
              check_attribute_type(sAtr, val, String, false, @aPath)
              check_attribute_enum(sAtr, val, GRP_ENUM_MTXSTAT, @aPath)

            # list
            when TSR_PRM_WTSKLIST, TSR_PRM_STSKLIST, TSR_PRM_RTSKLIST, TSR_PRM_DATALIST, TSR_PRM_MSGLIST
              # それぞれのクラスでチェックする

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
    # 概  要: タスクリスト系の属性チェック共通部
    #=================================================================
    def attribute_check_task_list(sAtr, aTaskList, cProc)
      check_class(String, sAtr)             # 属性名
      check_class(Object, aTaskList, true)  # タスクリスト
      check_class(Proc, cProc)              # 要素の内容チェック処理

      check_attribute_type(sAtr, aTaskList, Array, false, @aPath)

      aErrors = []
      aPath   = @aPath + [sAtr]
      aTaskList.each_with_index{|hTask, nIndex|
        # リストの要素がHashか
        unless (hTask.is_a?(Hash))
          sErr = sprintf(ERR_LIST_INVALID_TYPE, sAtr, Hash, hTask.class())
          raise(YamlError.new(sErr, aPath + [nIndex]))
        end
        # 要素のHashのサイズが1か
        if (hTask.size() != 1)
          sErr = sprintf(ERR_LIST_MUST_BE_SINGLE, sAtr, hTask.size())
          raise(YamlError.new(sErr, aPath + [nIndex]))
        end
        # 要素の内容チェック
        hTask.each{|sTask, hVal|
          begin
            cProc.call(hVal, aPath + [nIndex, sTask])
          rescue YamlError
            aErrors.push($!)
          rescue TTCMultiError
            aErrors.concat($!.aErrors)
          end
        }
      }
      check_error(aErrors)
    end

    #=================================================================
    # 概  要: オブジェクトチェック
    #=================================================================
    def object_check(bIsPre = false)
      check_class(Bool, bIsPre)  # pre_conditionか

      aErrors = []

      ### T3_SCO001: wtsklist，stsklist，rtsklistのタスク名が重複している
      [TSR_PRM_WTSKLIST, TSR_PRM_STSKLIST, TSR_PRM_RTSKLIST].each{|sAtr|
        aTask = []
        unless (@hState[sAtr].nil?())
          @hState[sAtr].each{|hTask|
            hTask.each_key{|sTask|
              if (aTask.include?(sTask))
                sErr = sprintf("T3_SCO001: " + ERR_TASK_NAME_DUPLICATE, sTask)
                aErrors.push(YamlError.new(sErr, @aPath + [sAtr]))
              end
              aTask.push(sTask)
            }
          }
        end
      }

      # アクセス許可パターンのチェック
      if ((bIsPre == true) && @cConf.is_hrp?())
        ### T3_SEM003, T3_EVT001, T3_DTQ004, T3_PDQ004, T3_MPF001, T3_MTX001，T3_MBF004:
        ### access1～access4が揃って指定されていない(すべて省略も可)
        if (!((@hState[TSR_PRM_ACCESS1].nil?() && @hState[TSR_PRM_ACCESS2].nil?() &&
              @hState[TSR_PRM_ACCESS3].nil?() && @hState[TSR_PRM_ACCESS4].nil?()) ||
             (!@hState[TSR_PRM_ACCESS1].nil?() && !@hState[TSR_PRM_ACCESS2].nil?() &&
              !@hState[TSR_PRM_ACCESS3].nil?() && !@hState[TSR_PRM_ACCESS4].nil?())))
          case @sObjectType
          when TSR_OBJ_SEMAPHORE
            aErrors.push(YamlError.new("T3_SEM003: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_EVENTFLAG
            aErrors.push(YamlError.new("T3_EVT001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_DATAQUEUE
            aErrors.push(YamlError.new("T3_DTQ004: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_P_DATAQUEUE
            aErrors.push(YamlError.new("T3_PDQ004: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_MEMORYPOOL
            aErrors.push(YamlError.new("T3_MPF001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_MUTEX
            aErrors.push(YamlError.new("T3_MTX001: " + ERR_NO_ALL_ACCESS_SET, @aPath))
          when TSR_OBJ_MESSAGEBUF
            aErrors.push(YamlError.new("T3_MBF004: " + ERR_NO_ALL_ACCESS_SET, @aPath))
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
      # FMP限定
      if (@cConf.is_fmp?())
        # class
        unless (is_specified?(TSR_PRM_CLASS))
          @hState[TSR_PRM_CLASS] = CFG_MCR_CLS_SELF_ALL
        end
      end

      # HRP限定
      if (@cConf.is_hrp?())
        # domain
        if (!is_specified?(TSR_PRM_DOMAIN))
          hMacro  = @cConf.get_macro()
          @hState[TSR_PRM_DOMAIN] = hMacro["DOM_NON_TASK"]
        end
      end
    end

    #=================================================================
    # 概　要: 補完を実行する
    #=================================================================
    def complement(cPrevObj)
      check_class(SCObject, cPrevObj)  # 直前の状態のオブジェクト

      super(cPrevObj)
    end

    #=================================================================
    # 概　要: エイリアスを実行する
    #=================================================================
    def alias(hAlias)
      check_class(Hash, hAlias)   # エイリアス変換テーブル

      super(hAlias)

      # stsklist
      unless (@hState[TSR_PRM_STSKLIST].nil?())
        aTmp = @hState[TSR_PRM_STSKLIST].dup()
        @hState[TSR_PRM_STSKLIST] = []
        aTmp.each{|hTask|
          hTmp = hTask
          hTask = {}
          hTmp.each{|sTask, hData|
            hTask[hAlias[sTask]] = hData
          }
          @hState[TSR_PRM_STSKLIST].push(hTask)
        }
      end
      # rtsklist
      unless (@hState[TSR_PRM_RTSKLIST].nil?())
        aTmp = @hState[TSR_PRM_RTSKLIST].dup()
        @hState[TSR_PRM_RTSKLIST] = []
        aTmp.each{|hTask|
          hTmp = hTask
          hTask = {}
          hTmp.each{|sTask, hData|
            unless (hData.nil?())
              hData.each{|atr, val|
                hData[atr] = alias_replace(val, hAlias)
              }
            end
            hTask[hAlias[sTask]] = hData
          }
          @hState[TSR_PRM_RTSKLIST].push(hTask)
        }
      end
      # wtsklist
      unless (@hState[TSR_PRM_WTSKLIST].nil?())
        aTmp = @hState[TSR_PRM_WTSKLIST].dup()
        @hState[TSR_PRM_WTSKLIST] = []
        aTmp.each{|hTask|
          hTmp = hTask
          hTask = {}
          hTmp.each{|sTask, hData|
            unless (hData.nil?())
              hData.each{|atr, val|
                if (atr == TSR_VAR_VAR)
                  hData[atr] = alias_replace(val, hAlias)
                end
              }
            end
            hTask[hAlias[sTask]] = hData
          }
          @hState[TSR_PRM_WTSKLIST].push(hTask)
        }
      end
      # msglist
      unless (@hState[TSR_PRM_MSGLIST].nil?())
        @hState[TSR_PRM_MSGLIST].each{|hData|
          hData.each{|atr, val|
            if (atr == TSR_VAR_MSG)
              hData[atr] = alias_replace(val, hAlias)
            end
          }
        }
      end
    end

    #=================================================================
    # 概　要: オブジェクトのエイリアス変換テーブルを返す
    #=================================================================
    def get_alias(sTestID, nNum = nil)
      check_class(String, sTestID)      # テストID
      check_class(Integer, nNum, true)  # 識別番号

      hResult = {}

      # オブジェクトID
      if (@sObjectType == TSR_OBJ_SPINLOCK)
        if (@cConf.is_hrp?())
          # 【暫定対応】スピンロックのアクセス許可パターン設定が重複してしまうため，
          #             他のオブジェクト同様テストケースごとにスピンロックを生成する
          #hResult[@sObjectID] = "#{TTG_LBL_SPINLOCK}_#{@hState[TSR_PRM_CLASS]}_#{@hState[TSR_PRM_DOMAIN]}_#{nNum}"
          hResult[@sObjectID] = alias_str(@sObjectID, sTestID)
        else
          hResult[@sObjectID] = "#{TTG_LBL_SPINLOCK}_#{@hState[TSR_PRM_CLASS]}_#{nNum}"
        end
      else
        hResult[@sObjectID] = alias_str(@sObjectID, sTestID)
      end

      # 変数名
      aVarNames = get_variable_names()
      aVarNames.each{|sVarName|
        hResult[sVarName] = alias_str(sVarName, sTestID)
      }

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
    # 概  要: オブジェクト内に存在する変数名一覧を返す
    #=================================================================
    def get_variable_names()
      aVarNames = []

      # rtsklist
      hVars = get_rtsklist_variable()
      hVars.each_value{|hVar|
        aVarNames.concat(hVar.keys())
      }

      # wtsklist
      hVars = get_wtsklist_variable()
      hVars.each_value{|hVar|
        aVarNames.concat(hVar.keys())
      }

      # msglist
      hVars = get_msglist_variable()
      aVarNames.concat(hVars.keys())

      return aVarNames.uniq().sort()  # [Array]オブジェクト内に存在する変数名一覧
    end

    #=================================================================
    # 概  要: 受信待ちタスクリスト内の変数と型の組み合わせ一覧を返す
    #=================================================================
    def get_rtsklist_variable()
      return {}  # [Hash]受信待ちタスクリスト内の変数と型の組み合わせ一覧
    end

    #=================================================================
    # 概  要: 待ちタスクリスト内の変数と型の組み合わせ一覧を返す
    #=================================================================
    def get_wtsklist_variable()
      return {}  # [Hash]待ちタスクリスト内の変数と型の組み合わせ一覧
    end

    #=================================================================
    # 概  要: メッセージリスト内の変数と型の組み合わせ一覧を返す
    #=================================================================
    def get_msglist_variable()
      return {}  # [Hash]メッセージリスト内の変数と型の組み合わせ一覧
    end

    #=================================================================
    # 概  要: 内部保持用属性名からTESRYの属性名を取得する
    #=================================================================
    def get_real_attribute_name(sAtr)
      check_class(String, sAtr)  # 内部保持用属性名

      case sAtr
      when TSR_PRM_ATR
        sAtr = GRP_PRM_KEY_SC_ATR[@sObjectType]
      when TSR_PRM_DATACNT
        sAtr = GRP_PRM_KEY_SC_DATACNT[@sObjectType]
      when TSR_PRM_MB
        sAtr = GRP_PRM_KEY_SC_MB[@sObjectType]
      end

      return sAtr  # [String]TESRYの属性名
    end
  end
end
