#!ruby -w
#
# 引数に与えたASP/FMP向けのTESRYファイルに対して，HRP/HRMPにおけるドメ
# インの組み合わせを行ったTESRYデータを作成する．
#

if (__FILE__ == $0)
  TOOL_ROOT = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(TOOL_ROOT)
end
require "fileutils"
require "tesry_formatter.rb"
require "is_normal_testcase.rb"

IGNORE_API   = ["chg_spr", "rot_rdq", "mrot_rdq"]

NONE_DOM_OBJ = ["SEMAPHORE", "EVENTFLAG", "DATAQUEUE", "P_DATAQUEUE", "MEMORYPOOL", "SPINLOCK", "MUTEX", "MESSAGEBUF"]
USER_DOM_OBJ = ["TASK", "ALARM", "CYCLE"].concat(NONE_DOM_OBJ)

USER_DOM1_ID   = "DOM1"
USER_DOM1_DATA = {USER_DOM1_ID => {"type" => "DOMAIN"}}
USER_DOM2_ID   = "DOM2"
USER_DOM2_DATA = {USER_DOM2_ID => {"type" => "DOMAIN"}}
USER_DOM_ACP  = {"access1" => "TACP_KERNEL",
                 "access2" => "TACP_KERNEL",
                 "access3" => "TACP_KERNEL",
                 "access4" => "TACP_KERNEL"}

SYS_ACP_API = ["dis_dsp", "ena_dsp", "chg_som",
               "loc_cpu", "unl_cpu", "dis_int", "ena_int", "clr_int", "ras_int", "chg_ipm",
               "set_tim", "adj_tim", "set_dft", "att_mem", "att_pma", "cfg_int", "def_svc",
               "get_tim", "get_ipm", "prb_int", "ref_int", "ref_sys", "get_som", "ref_cfg", "ref_ver"]
DOM_ACP_API = ["dis_ter", "ena_ter",
               "get_lod", "mget_lod", "get_nth", "mget_nth"]

ACP_TABLE = {"1" => ["act_tsk", "mact_tsk", "can_act", "mig_tsk", "wup_tsk", "can_wup", 
                     "sig_sem", "set_flg", "clr_flg", "snd_dtq", "psnd_dtq", "tsnd_dtq", "fsnd_dtq", "snd_pdq", "psnd_pdq", "tsnd_pdq",
                     "loc_mtx", "ploc_mtx", "tloc_mtx", "unl_mtx", "snd_mbf", "psnd_mbf", "tsnd_mbf", "loc_spn", "try_spn", "unl_spn", 
                     "get_mpf", "pget_mpf", "tget_mpf", "sta_cyc", "msta_cyc", "sta_alm", "msta_alm", "rot_rdq", "mrot_rdq", "dis_dsp", "ena_dsp", "chg_som"],
             "2" => ["chg_pri", "chg_spr", "rel_wai", "sus_tsk", "rsm_tsk", "ras_ter", "wai_sem", "pol_sem", "twai_sem",
                     "wai_flg", "pol_flg", "twai_flg", "rcv_dtq", "prcv_dtq", "trcv_dtq", "rcv_pdq", "prcv_pdq", "trcv_pdq", 
                     "rcv_mbf", "prcv_mbf", "trcv_mbf", "rel_mpf", "stp_cyc", "stp_alm", "dis_ter", "ena_ter", "loc_cpu", "unl_cpu", 
                     "dis_int", "ena_int", "clr_int", "ras_int", "chg_ipm"],
             "3" => ["ter_tsk", "ini_sem", "ini_flg", "ini_dtq", "ini_pdq", "ini_mtx", "ini_mbf", "ini_mpf", "set_tim", "adj_tim"],
             "4" => ["ref_mem", "prb_mem", "get_tst", "get_pri", "ref_tsk", "prb_mem", "ref_sem", "ref_flg", "ref_dtq", 
                     "ref_pdq", "ref_mtx", "ref_mbf", "ref_spn", "ref_mpf", "ref_cyc", "ref_alm", "ref_isr", "get_lod", 
                     "mget_lod", "get_nth", "mget_nth", "get_tim", "get_ipm", "prb_int", "ref_int", "get_som"]}


if (ARGV.size() == 0)
  abort("Argument error !")
end
aTargetFile = []
ARGV.each{|sArg|
  if (FileTest.file?(sArg))
    aTargetFile.push(sArg)
  elsif (FileTest.directory?(sArg))
    aTargetFile.concat(Dir.glob("#{sArg}/**/*.yaml"))
  else
    abort("invalid argument: #{sArg}")
  end
}

# APIに必要なアクセスが許可されたドメインID取得
def get_user_domain(sApiName)
  if (SYS_ACP_API.include?(sApiName))
    ACP_TABLE.each{|nAcpNo, aApiList|
      if (aApiList.include?(sApiName))
        return "DOM_SYS_ACP#{nAcpNo}"
      end
    }
  elsif (DOM_ACP_API.include?(sApiName))
    ACP_TABLE.each{|nAcpNo, aApiList|
      if (aApiList.include?(sApiName))
        return "DOM_ACP#{nAcpNo}"
      end
    }
  else
    return USER_DOM1_ID
  end
end

# APIに対するアクセス許可パターン取得
def get_acp(sApiName, sDomainID)
  ACP_TABLE.each{|nAcpNo, aApiList|
    if (aApiList.include?(sApiName))
      # 対象の操作種別のみユーザドメインから許可したアクセス許可パターンとする
      hAcp = Marshal.load(Marshal.dump(USER_DOM_ACP))
      hAcp["access#{nAcpNo}"] = "TACP(#{sDomainID})"
      return hAcp
    end
  }
  abort("invalid API: #{sApiName}")
end

# do/post_condition以下の時間指定有無を調整する
def generalize_do_post(hData)
  # do/post_condition以下に時間指定があるかチェックする
  bIsTimeSet = false
  hData.each{|snKey, shVal|
    if (snKey.is_a?(Integer) || snKey.include?("_TIME"))
      bIsTimeSet = true
      break
    end
  }

  # 時間指定がない場合ダミーの時間指定を入れる
  if (bIsTimeSet == false)
    hData = {:DUMMY => hData}
  end

  return hData
end

# H1 / HM1
# ユーザ -> ユーザ
def expand_H1_HM1(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  hOrgTestScenario.each{|sCondition, hData|
    if (sCondition == "pre_condition")
      hData.each{|sObjID, sObjInfo|
        if (USER_DOM_OBJ.include?(sObjInfo["type"]))
          # テストに関係ないタイムイベントハンドラはカーネルドメインとする
          if ($aHandler.include?(sObjID))
            sObjInfo["domain"] = "KERNEL"
          # それ以外はすべてユーザドメインとする
          else
            sObjInfo["domain"] = USER_DOM1_ID
          end
        end
      }

      # ユーザドメイン定義
      hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
    end
  }

  hExTesryInfo["#{sTestID}_#{sProfile}1"] = hOrgTestScenario
end

# H2 / HM2
# カーネル -> ユーザ
def expand_H2_HM2(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  hDomainInfo = {}
  hOrgTestScenario.each{|sCondition, hData|
    if (sCondition == "pre_condition")
      hData.each{|sObjID, sObjInfo|
        if (USER_DOM_OBJ.include?(sObjInfo["type"]))
          # テストに関係ないタイムイベントハンドラはカーネルドメインとする
          if ($aHandler.include?(sObjID) && ![$sCaller, $sArg1].include?(sObjID))
            sObjInfo["domain"] = "KERNEL"
          else
            # API発行先が処理単位の場合
            if (!NONE_DOM_OBJ.include?($hObjType[$sArg1]))
              # API発行元のみカーネルドメインとする
              if (sObjID == $sCaller)
                sObjInfo["domain"] = "KERNEL"
              # API発行先，その他はユーザドメインとする
              else
                sObjInfo["domain"] = USER_DOM1_ID
              end
            # API発行先が処理単位以外の場合
            else
              # API発行先のみはユーザドメインとする
              if (sObjID == $sArg1)
                sObjInfo["domain"] = USER_DOM1_ID
              # API発行元，その他はカーネルドメインとする
              else
                sObjInfo["domain"] = "KERNEL"
              end
            end
          end

          # タスクのドメイン情報を保持
          if (sObjInfo["type"] == "TASK")
            hDomainInfo[sObjID] = sObjInfo["domain"]
          end
        end
      }

      # エラー通知が設定されているタイムイベント通知の，元の通知対象オブジェクトはタイムイベント通知と同じドメインとする
      $hTenTargetWithError.each{|sTenID, sTargetID|
        hData[sTargetID]["domain"] = hData[sTenID]["domain"]
        hDomainInfo[sTargetID] = hData[sTenID]["domain"]
      }

      # ユーザドメイン定義
      hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
    end

    # pre_conditionを含む各condition
    if (sCondition.include?("condition") && !hData.nil?)
      hData = generalize_do_post(hData)

      hData.each{|snlTime, hPostData|
        if (!hPostData.nil?)
          # 対象のconditionで，同一優先度のrunningとreadyが混在し，porderが指定されているかチェック
          hPOrderTask = {}
          $aSamePriorityInfo.each{|hPriInfo|
            if ((hPriInfo[:CONDITION] == sCondition) && (hPriInfo[:TIME] == snlTime))
              hPriInfo[:RUNNING].each{|sPrcID, sRunningID|
                if (!hPriInfo[:PORDER][sPrcID].empty?)
                  hPOrderTask[sPrcID] = []
                  if (!sRunningID.nil?)
                    hPOrderTask[sPrcID].push(sRunningID)
                  end
                  hPOrderTask[sPrcID].concat(hPriInfo[:PORDER][sPrcID])
                end
              }
            end
          }

          hPOrderTask.each{|sPrcID, aPOrderTask|
            # porderをドメイン毎の数値に置き換える
            hNewPOrder = {"KERNEL" => 1, USER_DOM1_ID => 1}
            aPOrderTask.each{|sTaskID|
              sDomID = hDomainInfo[sTaskID]
              # porderが指定されているタスクだけ設定する
              if (hPostData.has_key?(sTaskID) && hPostData[sTaskID].has_key?("porder"))
                hPostData[sTaskID]["porder"] = hNewPOrder[sDomID]
              end
              hNewPOrder[sDomID] += 1
            }
          }
        end
      }
    end
  }

  hExTesryInfo["#{sTestID}_#{sProfile}2"] = hOrgTestScenario
end

# H3 / HM3
# ユーザ -> カーネル
def expand_H3_HM3(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  # 第1引数がない/オブジェクトではない場合
  if (!$hObjType.has_key?($sArg1))
    hOrgTestScenario.each{|sCondition, hData|
      if (sCondition == "pre_condition")
        sCpuState = nil
        sDomainID = get_user_domain(sApiName)
        hData.each{|sObjID, sObjInfo|
          if (USER_DOM_OBJ.include?(sObjInfo["type"]))
            # テストに関係ないタイムイベントハンドラはカーネルドメインとする
            if ($aHandler.include?(sObjID))
              sObjInfo["domain"] = "KERNEL"
            # それ以外はすべてユーザドメインとする
            else
              sObjInfo["domain"] = sDomainID
            end
          end

          if (sObjInfo["type"] == "CPU_STATE")
            sCpuState = sObjID
          end
        }

        # APIに応じてアクセス権を付与する
        if (SYS_ACP_API.include?(sApiName))
          # システム状態
          hAcp = get_acp(sApiName, sDomainID)
          if (sCpuState.nil?)
            hData.merge!({"CPU_STATE" => {"type" => "CPU_STATE"}.merge!(hAcp)})
          elsif (!hData[sCpuState].has_key?("access1"))
            hData[sCpuState].merge!(hAcp)
          else
            hAcp.each{|sParam, sValue|
              hData[sCpuState][sParam] += "|#{sValue}"
            }
          end
          hData.merge!({sDomainID => {"type" => "DOMAIN"}})
        elsif (DOM_ACP_API.include?(sApiName))
          # 保護ドメイン
          hData.merge!({sDomainID => {"type" => "DOMAIN"}})
          hData[sDomainID].merge!(get_acp(sApiName, sDomainID))
          # 通常操作1と参照操作はデフォルトで許可されるので許可しておく
          hData[sDomainID]["access1"] = "TACP(#{sDomainID})"
          hData[sDomainID]["access3"] = "TACP(#{sDomainID})"
        else
          hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
        end
      end
    }

  # 第1引数がオブジェクトの場合
  else
    hDomainInfo = {}
    hRunning2ReadyTask = {}
    hOrgTestScenario.each{|sCondition, hData|
      if (sCondition == "pre_condition")
        sRunningPri = nil
        hData.each{|sObjID, sObjInfo|
          if (USER_DOM_OBJ.include?(sObjInfo["type"]))
            # テストに関係ないタイムイベントハンドラはカーネルドメインとする
            if ($aHandler.include?(sObjID) && ![$sCaller, $sArg1].include?(sObjID))
              sObjInfo["domain"] = "KERNEL"
            else
              # API発行先が処理単位の場合
              if (!NONE_DOM_OBJ.include?($hObjType[$sArg1]))
                # API発行元のみユーザドメインとする
                if (sObjID == $sCaller)
                  sObjInfo["domain"] = USER_DOM1_ID
                  sRunningPri = hTestScenario["pre_condition"][sObjID]["tskpri"]
                # API発行先，その他はカーネルドメインとする
                else
                  sObjInfo["domain"] = "KERNEL"
                end
              # API発行先が処理単位以外の場合
              else
                # API発行先のみはカーネルドメインとする
                if (sObjID == $sArg1)
                  sObjInfo["domain"] = "KERNEL"
                # API発行元，その他はユーザドメインとする
                else
                  sObjInfo["domain"] = USER_DOM1_ID
                end
              end

              # 対象オブジェクトにユーザドメインからのアクセス権を付与する
              if (sObjID == $sArg1)
                sObjInfo.merge!(get_acp(sApiName, USER_DOM1_ID))
              end
            end

            # タスクのドメイン情報を保持
            if (sObjInfo["type"] == "TASK")
              hDomainInfo[sObjID] = sObjInfo["domain"]
            end
          end
        }

        # エラー通知が設定されているタイムイベント通知の，元の通知対象オブジェクトはタイムイベント通知と同じドメインとする
        $hTenTargetWithError.each{|sTenID, sTargetID|
          hData[sTargetID]["domain"] = hData[sTenID]["domain"]
          hDomainInfo[sTargetID] = hData[sTenID]["domain"]
        }

        # ユーザドメイン定義
        hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))

        # runningのタスク(ユーザドメイン)と同一優先度のreadyのタスク(カーネルドメイン)が存在したらユーザドメインへ変更する【NGKI0588】
        hData.each{|sObjID, sObjInfo|
          if ((sObjInfo["type"] == "TASK") && (sObjInfo["domain"] == "KERNEL") && (sObjInfo["tskstat"] == "ready") && 
              (hTestScenario["pre_condition"][sObjID]["tskpri"] == sRunningPri))
            sObjInfo["domain"] = USER_DOM1_ID
            hDomainInfo[sObjID] = sObjInfo["domain"]
          end
        }
      end

      # pre_conditionを含む各condition
      if (sCondition.include?("condition") && !hData.nil?)
        hData = generalize_do_post(hData)

        hData.each{|snlTime, hPostData|
          if (!hPostData.nil?)
            # 対象のconditionで，同一優先度のrunningとreadyが混在するかチェック
            hPOrderTask = {}
            $aSamePriorityInfo.each{|hPriInfo|
              if ((hPriInfo[:CONDITION] == sCondition) && (hPriInfo[:TIME] == snlTime))
                hPriInfo[:RUNNING].each{|sPrcID, sRunningID|
                  hRunning2ReadyTask[sPrcID] = []

                  # runinngのタスクがユーザドメインの場合に，カーネルドメインのreadyが存在したら入れ替える【NGKI0588】
                  if (!sRunningID.nil? && (hDomainInfo[sRunningID] == USER_DOM1_ID))
                    sSwapTask = nil
                    if (!hPriInfo[:PORDER][sPrcID].empty?)
                      hPriInfo[:PORDER][sPrcID].each{|sTaskID|
                        if (hDomainInfo[sTaskID] == "KERNEL")
                          sSwapTask = sTaskID
                          break
                        end
                      }
                    else
                      hPriInfo[:READY][sPrcID].each{|sTaskID|
                        if (hDomainInfo[sTaskID] == "KERNEL")
                          sSwapTask = sTaskID
                          break
                        end
                      }
                    end

                    # 入れ替え対象のタスクが存在した場合，入れ替える
                    if (!sSwapTask.nil?)
                      # running -> ready
                      if (hPostData.has_key?(sRunningID))
                        hPostData[sRunningID]["tskstat"] = "ready"
                      else
                        hPostData[sRunningID] = {"tskstat" => "ready"}
                      end
                      # ready -> running
                      if (hPostData.has_key?(sSwapTask))
                        hPostData[sSwapTask]["tskstat"] = "running"
                      else
                        hPostData[sSwapTask] = {"tskstat" => "running"}
                      end

                      # runningでなくなったタスクIDを保持
                      hRunning2ReadyTask[sPrcID].push(sRunningID)
                    end
                  end

                  # porderが指定されている場合，porder順を保持しておく
                  if (!hPriInfo[:PORDER][sPrcID].empty?)
                    hPOrderTask[sPrcID] = []
                    if (!sRunningID.nil?)
                      hPOrderTask[sPrcID].push(sRunningID)
                    end
                    hPOrderTask[sPrcID].concat(hPriInfo[:PORDER][sPrcID])
                  end
                }
              end
            }

            # runningとreadyが同一優先度でporder指定がある場合，porderをドメイン毎の数値に置き換える
            hPOrderTask.each{|sPrcID, aPOrderTask|
              hNewPOrder = {"KERNEL" => 1, USER_DOM1_ID => 1}
              aPOrderTask.each{|sTaskID|
                sDomID = hDomainInfo[sTaskID]
                # porderが指定されているタスクだけ設定する
                if (hPostData.has_key?(sTaskID) && hPostData[sTaskID].has_key?("porder"))
                  hPostData[sTaskID]["porder"] = hNewPOrder[sDomID]
                end
                hNewPOrder[sDomID] += 1
              }
            }
          end
        }
      end
    }

    # runningからreadyに変わったタスクがdoで返り値を確認している場合，削除する
    hRunning2ReadyTask.each{|sPrcID, aRunning2ReadyTask|
      aRunning2ReadyTask.uniq!()
      aRunning2ReadyTask.each{|sTaskID|
        hOrgTestScenario.each{|sCondition, hData|
          if ((sCondition =~ /^do/) && !hData.nil?)
            hData = generalize_do_post(hData)

            hData.each{|snlTime, hDoData|
              if (!hDoData.nil? && hDoData.has_key?("syscall") && (sTaskID == hDoData["id"]))
                RETURN_TYPE.each{|sRetType|
                  if (hDoData.has_key?(sRetType))
                    hDoData.delete(sRetType)
                  end
                }
              end
            }
          end
        }
      }
    }
  end

  hExTesryInfo["#{sTestID}_#{sProfile}3"] = hOrgTestScenario
end

# H4 / HM4
# ユーザ1 -> ユーザ2
def expand_H4_HM4(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  hDomainInfo = {}
  hOrgTestScenario.each{|sCondition, hData|
    if (sCondition == "pre_condition")
      hData.each{|sObjID, sObjInfo|
        if (USER_DOM_OBJ.include?(sObjInfo["type"]))
          # テストに関係ないタイムイベントハンドラはカーネルドメインとする
          if ($aHandler.include?(sObjID) && ![$sCaller, $sArg1].include?(sObjID))
            sObjInfo["domain"] = "KERNEL"
          else
            # API発行先が処理単位の場合
            if (!NONE_DOM_OBJ.include?($hObjType[$sArg1]))
              # API発行元のみユーザドメイン1とする
              if (sObjID == $sCaller)
                sObjInfo["domain"] = USER_DOM1_ID
              # API発行先，その他はユーザドメイン2とする
              else
                sObjInfo["domain"] = USER_DOM2_ID
              end
            # API発行先が処理単位以外の場合
            else
              # API発行先のみはユーザドメイン1とする
              if (sObjID == $sArg1)
                sObjInfo["domain"] = USER_DOM2_ID
              # API発行元，その他はユーザドメイン1とする
              else
                sObjInfo["domain"] = USER_DOM1_ID
              end
            end
          end

          # 対象オブジェクトにユーザドメイン1からのアクセス権を付与する
          if (sObjID == $sArg1)
            sObjInfo.merge!(get_acp(sApiName, USER_DOM1_ID))
          end

          # タスクのドメイン情報を保持
          if (sObjInfo["type"] == "TASK")
            hDomainInfo[sObjID] = sObjInfo["domain"]
          end
        end
      }

      # エラー通知が設定されているタイムイベント通知の，元の通知対象オブジェクトはタイムイベント通知と同じドメインとする
      $hTenTargetWithError.each{|sTenID, sTargetID|
        hData[sTargetID]["domain"] = hData[sTenID]["domain"]
        hDomainInfo[sTargetID] = hData[sTenID]["domain"]
      }

      # ユーザドメイン定義
      hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
      hData.merge!(Marshal.load(Marshal.dump(USER_DOM2_DATA)))
    end
  }

  hExTesryInfo["#{sTestID}_#{sProfile}4"] = hOrgTestScenario
end

# H5 / HM5
# ユーザ(SVC) -> カーネル
def expand_H5_HM5(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  # 第1引数がない/オブジェクトではない場合
  if (!$hObjType.has_key?($sArg1))
    # 発行先がなく，アクセス許可が不要な場合はテスト実施不要(SVC経由とする意味がない)
    if (!SYS_ACP_API.include?(sApiName) && !DOM_ACP_API.include?(sApiName))
      return
    end

    hOrgTestScenario.each{|sCondition, hData|
      if (sCondition == "pre_condition")
        hData.each{|sObjID, sObjInfo|
          if (USER_DOM_OBJ.include?(sObjInfo["type"]))
            # テストに関係ないタイムイベントハンドラはカーネルドメインとする
            if ($aHandler.include?(sObjID))
              sObjInfo["domain"] = "KERNEL"
            # それ以外はすべてユーザドメインとする
            else
              sObjInfo["domain"] = USER_DOM1_ID
            end
          end
        }

        # ユーザドメイン定義
        hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
      end
    }

  # 第1引数がオブジェクトの場合
  else
    hDomainInfo = {}
    hRunning2ReadyTask = {}
    hOrgTestScenario.each{|sCondition, hData|
      if (sCondition == "pre_condition")
        sRunningPri = nil
        hData.each{|sObjID, sObjInfo|
          if (USER_DOM_OBJ.include?(sObjInfo["type"]))
            # テストに関係ないタイムイベントハンドラはカーネルドメインとする
            if ($aHandler.include?(sObjID) && ![$sCaller, $sArg1].include?(sObjID))
              sObjInfo["domain"] = "KERNEL"
            else
              # API発行先が処理単位の場合
              if (!NONE_DOM_OBJ.include?($hObjType[$sArg1]))
                # API発行元のみユーザドメインとする
                if (sObjID == $sCaller)
                  sObjInfo["domain"] = USER_DOM1_ID
                  sRunningPri = hTestScenario["pre_condition"][sObjID]["tskpri"]
                # API発行先，その他はカーネルドメインとする
                else
                  sObjInfo["domain"] = "KERNEL"
                end
              # API発行先が処理単位以外の場合
              else
                # API発行先のみはカーネルドメインとする
                if (sObjID == $sArg1)
                  sObjInfo["domain"] = "KERNEL"
                # API発行元，その他はユーザドメインとする
                else
                  sObjInfo["domain"] = USER_DOM1_ID
                end
              end
            end

            # タスクのドメイン情報を保持
            if (sObjInfo["type"] == "TASK")
              hDomainInfo[sObjID] = sObjInfo["domain"]
            end
          end
        }

        # エラー通知が設定されているタイムイベント通知の，元の通知対象オブジェクトはタイムイベント通知と同じドメインとする
        $hTenTargetWithError.each{|sTenID, sTargetID|
          hData[sTargetID]["domain"] = hData[sTenID]["domain"]
          hDomainInfo[sTargetID] = hData[sTenID]["domain"]
        }

        # ユーザドメイン定義
        hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))

        # runningのタスク(ユーザドメイン)と同一優先度のreadyのタスク(カーネルドメイン)が存在したらユーザドメインへ変更する【NGKI0588】
        hData.each{|sObjID, sObjInfo|
          if ((sObjInfo["type"] == "TASK") && (sObjInfo["domain"] == "KERNEL") && (sObjInfo["tskstat"] == "ready") && 
              (hTestScenario["pre_condition"][sObjID]["tskpri"] == sRunningPri))
            sObjInfo["domain"] = USER_DOM1_ID
            hDomainInfo[sObjID] = sObjInfo["domain"]
          end
        }
      end

      # pre_conditionを含む各condition
      if (sCondition.include?("condition") && !hData.nil?)
        hData = generalize_do_post(hData)

        hData.each{|snlTime, hPostData|
          if (!hPostData.nil?)
            # 対象のconditionで，同一優先度のrunningとreadyが混在するかチェック
            hPOrderTask = {}
            $aSamePriorityInfo.each{|hPriInfo|
              if ((hPriInfo[:CONDITION] == sCondition) && (hPriInfo[:TIME] == snlTime))
                hPriInfo[:RUNNING].each{|sPrcID, sRunningID|
                  hRunning2ReadyTask[sPrcID] = []

                  # runinngのタスクがユーザドメインの場合に，カーネルドメインのreadyが存在したら入れ替える【NGKI0588】
                  if (!sRunningID.nil? && (hDomainInfo[sRunningID] == USER_DOM1_ID))
                    sSwapTask = nil
                    if (!hPriInfo[:PORDER][sPrcID].empty?)
                      hPriInfo[:PORDER][sPrcID].each{|sTaskID|
                        if (hDomainInfo[sTaskID] == "KERNEL")
                          sSwapTask = sTaskID
                          break
                        end
                      }
                    else
                      hPriInfo[:READY][sPrcID].each{|sTaskID|
                        if (hDomainInfo[sTaskID] == "KERNEL")
                          sSwapTask = sTaskID
                          break
                        end
                      }
                    end

                    # 入れ替え対象のタスクが存在した場合，入れ替える
                    if (!sSwapTask.nil?)
                      # running -> ready
                      if (hPostData.has_key?(sRunningID))
                        hPostData[sRunningID]["tskstat"] = "ready"
                      else
                        hPostData[sRunningID] = {"tskstat" => "ready"}
                      end
                      # ready -> running
                      if (hPostData.has_key?(sSwapTask))
                        hPostData[sSwapTask]["tskstat"] = "running"
                      else
                        hPostData[sSwapTask] = {"tskstat" => "running"}
                      end

                      # runningでなくなったタスクIDを保持
                      hRunning2ReadyTask[sPrcID].push(sRunningID)
                    end
                  end

                  # porderが指定されている場合，porder順を保持しておく
                  if (!hPriInfo[:PORDER][sPrcID].empty?)
                    hPOrderTask[sPrcID] = []
                    if (!sRunningID.nil?)
                      hPOrderTask[sPrcID].push(sRunningID)
                    end
                    hPOrderTask[sPrcID].concat(hPriInfo[:PORDER][sPrcID])
                  end
                }
              end
            }

            # runningとreadyが同一優先度でporder指定がある場合，porderをドメイン毎の数値に置き換える
            hPOrderTask.each{|sPrcID, aPOrderTask|
              hNewPOrder = {"KERNEL" => 1, USER_DOM1_ID => 1}
              aPOrderTask.each{|sTaskID|
                sDomID = hDomainInfo[sTaskID]
                # porderが指定されているタスクだけ設定する
                if (hPostData.has_key?(sTaskID) && hPostData[sTaskID].has_key?("porder"))
                  hPostData[sTaskID]["porder"] = hNewPOrder[sDomID]
                end
                hNewPOrder[sDomID] += 1
              }
            }
          end
        }
      end
    }

    # runningからreadyに変わったタスクがdoで返り値を確認している場合，削除する
    hRunning2ReadyTask.each{|sPrcID, aRunning2ReadyTask|
      aRunning2ReadyTask.uniq!()
      aRunning2ReadyTask.each{|sTaskID|
        hOrgTestScenario.each{|sCondition, hData|
          if ((sCondition =~ /^do/) && !hData.nil?)
            hData = generalize_do_post(hData)

            hData.each{|snlTime, hDoData|
              if (!hDoData.nil? && hDoData.has_key?("syscall") && (sTaskID == hDoData["id"]))
                RETURN_TYPE.each{|sRetType|
                  if (hDoData.has_key?(sRetType))
                    hDoData.delete(sRetType)
                  end
                }
              end
            }
          end
        }
      }
    }
  end

  # 発行元からのテスト対象API呼出しをSVC経由に切り換える
  hOrgTestScenario.each{|sCondition, hData|
    if ((sCondition =~ /^do/) && !hData.nil?)
      hData = generalize_do_post(hData)

      hData.each{|snlTime, hDoData|
        if (!hDoData.nil? && hDoData.has_key?("syscall") &&
            (hDoData["syscall"] =~ /^#{sApiName}/) && (hDoData["id"] == $sCaller))
          hDoData["syscall"].gsub!(sApiName, "TTSP_#{sApiName.upcase()}")
        end
      }
    end
  }

  hExTesryInfo["#{sTestID}_#{sProfile}5"] = hOrgTestScenario
end

# H6 / HM6
# カーネル -> 無所属
def expand_H6_HM6(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  hOrgTestScenario.each{|sCondition, hData|
    if (sCondition == "pre_condition")
      hData.each{|sObjID, sObjInfo|
        if (USER_DOM_OBJ.include?(sObjInfo["type"]))
          # テストに関係ないタイムイベントハンドラはカーネルドメインとする
          if ($aHandler.include?(sObjID))
            sObjInfo["domain"] = "KERNEL"
          else
            # API発行先のみは無所属とする
            if (sObjID == $sArg1)
              sObjInfo["domain"] = "NONE"
            # API発行元，その他はカーネルドメインとする
            else
              sObjInfo["domain"] = "KERNEL"
            end
          end
        end
      }
    end
  }

  hExTesryInfo["#{sTestID}_#{sProfile}6"] = hOrgTestScenario
end

# H7 / HM7
# ユーザ -> 無所属
def expand_H7_HM7(sProfile, hExTesryInfo, hOrgTestScenario, sApiName, sTestID, hTestScenario)
  hOrgTestScenario.each{|sCondition, hData|
    if (sCondition == "pre_condition")
      hData.each{|sObjID, sObjInfo|
        if (USER_DOM_OBJ.include?(sObjInfo["type"]))
          # テストに関係ないタイムイベントハンドラはカーネルドメインとする
          if ($aHandler.include?(sObjID))
            sObjInfo["domain"] = "KERNEL"
          else
            # API発行先のみは無所属とする
            if (sObjID == $sArg1)
              sObjInfo["domain"] = "NONE"
            # API発行元，その他はユーザドメインとする
            else
              sObjInfo["domain"] = USER_DOM1_ID
            end
          end
        end
      }

      # ユーザドメイン定義
      hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
    end
  }

  hExTesryInfo["#{sTestID}_#{sProfile}7"] = hOrgTestScenario
end


aSpecialTesry = ["fch_hrt_a-1"]
def expand_special_tesry(sExFilePath, sFilePath, sBaseName, sProfile, sDir)
  hTesryInfo = YAML.load_file(sFilePath)
  hExTesryInfo = {"version" => hTesryInfo.delete("version")}

  case sBaseName
  when "fch_hrt_a-1"
    hTesryInfo.each{|sTestID, hCondition|
      hCondition.each{|sCondition, hData|
        if (sCondition == "pre_condition")
          hData.each{|sObjID, sObjInfo|
            if (USER_DOM_OBJ.include?(sObjInfo["type"]))
              # すべてユーザドメインとする
              sObjInfo["domain"] = USER_DOM1_ID
            end
          }

          # ユーザドメイン定義
          hData.merge!(Marshal.load(Marshal.dump(USER_DOM1_DATA)))
        end
      }

      hExTesryInfo["#{sTestID}_#{sProfile}3"] = hCondition
    }
  end

  # 拡張後のファイルを保存するフォルダがなければ作成する
  if (!Dir.exist?(sDir))
    FileUtils.mkdir_p(sDir)
  end

  # 拡張したTESRYデータをファイルに出力して整形
  sExTesryData = hExTesryInfo.to_yaml()
  File.open(sExFilePath, "wb"){|cIO|
    cIO.puts(sExTesryData)
  }
  format_tesry(sExFilePath)
end


aTargetFile.each{|sFilePath|
  # 拡張済みのyamlは対象外
  if (sFilePath.end_with?("_ex.yaml"))
    next
  end

  # 対象ファイルのパスとファイル名
  sDir = File.dirname(sFilePath)
  sBaseName = File.basename(sFilePath, ".yaml")

  # HRP or HRMP
  sProfile = nil
  if (sFilePath.include?("/ASP/"))
    sProfile = "H"
    sDir.gsub!("/ASP/", "/HRP/")
  elsif (sFilePath.include?("/FMP/"))
    sProfile = "HM"
    sDir.gsub!("/FMP/", "/HRMP/")
  else
    abort("invalid file: #{sFilePath}")
  end

  # 拡張後のファイルパス作成
  sExFilePath = "#{sDir}/#{sBaseName}_#{sProfile}_ex.yaml"

  # テストケース毎の特別対応
  if (aSpecialTesry.include?(sBaseName))
    expand_special_tesry(sExFilePath, sFilePath, sBaseName, sProfile, sDir)
    next
  end

  hTesryInfo = YAML.load_file(sFilePath)

  # 拡張するTESRYデータ初期化(versionを元データから取り除く)
  hExTesryInfo = {"version" => hTesryInfo.delete("version")}

  hTesryInfo.each{|sTestID, hTestScenario|
    #
    # 解析フェーズ
    #

    # 拡張フェーズのためにコピーしておく
    hOrgTestScenario = Marshal.load(Marshal.dump(hTestScenario))

    # テスト対象のAPI名
    sApiName = get_target_api_name(sTestID)

    # 拡張対象外のAPIはスキップ
    if (IGNORE_API.include?(sApiName))
      next
    end

    # エラー条件のテストケースは対象外
    if (!is_normal_testcase?(sTestID, hTestScenario))
      next
    end

    $hObjType = {}
    $sCaller = nil
    $sArg1 = nil
    $hTenTargetWithError = {}
    $aHandler = []
    $aSamePriorityInfo = []
    bTimeEventNotifyCase = false
    bIniTerRtn = false
    sReturnCode = nil
    sPreReturnCode = nil
    hPreTaskInfo = {}
    hTestScenario.each{|sCondition, hData|
      # テストに登場するオブジェクトを保持する
      if (sCondition == "pre_condition")
        hData.each{|sObjID, sObjInfo|
          $hObjType[sObjID] = sObjInfo["type"]

          # TNFY_HANDLERはカーネルドメインにしか所属できないため保持する
          if (sObjInfo.has_key?("nfytype") && (sObjInfo["nfytype"] == "TNFY_HANDLER"))
            $aHandler.push(sObjID)
          end

          # タスク状態/優先度を後続のconditionに補完する
          if (sObjInfo["type"] == "TASK")
            hPreTaskInfo[sObjID] = {"tskstat" => sObjInfo["tskstat"]}
            if (!sObjInfo.has_key?("tskpri"))
              sObjInfo["tskpri"] = "TSK_PRI_MID"
            end
            hPreTaskInfo[sObjID]["tskpri"] = sObjInfo["tskpri"]
            if (!sObjInfo.has_key?("prcid"))
              sObjInfo["prcid"] = "PRC_SELF"
            end
            hPreTaskInfo[sObjID]["prcid"] = sObjInfo["prcid"]
          # エラー通知が設定されているタイムイベント通知の，元の通知対象のオブジェクトを保持する
          elsif (["ALARM", "CYCLE"].include?(sObjInfo["type"]) && sObjInfo.has_key?("enfytype"))
            $hTenTargetWithError[sObjID] = sObjInfo["nfy_info1"]
          # 初期化，終了処理ルーチンを使用するテストケースは拡張対象外
          elsif (["INIRTN", "TERRTN"].include?(sObjInfo["type"]))
            bIniTerRtn = true
          end
        }

        # タイムイベント通知はダミーの非タスクコンテキスト確定
        if (sTestID.end_with?("_at", "_ae"))
          $sCaller = "DUMMY_ALM"
          if (sTestID.end_with?("_at"))
            $sArg1 = hData["DUMMY_ALM"]["nfy_info1"]
          else
            $sArg1 = hData["DUMMY_ALM"]["enfy_info1"]
          end
          bTimeEventNotifyCase = true
        elsif (sTestID.end_with?("_ct", "_ce"))
          $sCaller = "DUMMY_CYC"
          if (sTestID.end_with?("_ct"))
            $sArg1 = hData["DUMMY_CYC"]["nfy_info1"]
          else
            $sArg1 = hData["DUMMY_CYC"]["enfy_info1"]
          end
          bTimeEventNotifyCase = true
        end

      elsif ((sCondition =~ /^do/) && !hData.nil?)
        hData = generalize_do_post(hData)

        hData.each{|_, hDoData|
          if (!hDoData.nil? && hDoData.has_key?("syscall") && (hDoData["syscall"] =~ /^#{sApiName}/))
            # テスト対象APIを呼び出す処理単位を取得する
            if ($sCaller.nil?)
              $sCaller = hDoData["id"]
            else
              # 既にテスト対象APIを呼び出していた場合，前回の返り値を退避
              sPreReturnCode = sReturnCode
            end

            # E_OK以外の返り値を確認しているdoを優先する
            RETURN_TYPE.each{|sRetType|
              if (hDoData.has_key?(sRetType))
                if (sReturnCode.nil?)
                  sReturnCode = hDoData[sRetType]
                elsif ((sPreReturnCode == "E_OK") && (sReturnCode != "E_OK"))
                  $sCaller = hDoData["id"]
                end
              end
            }

            # 対象APIの引数解析
            if (hDoData["syscall"] == "#{sApiName}()")
              # 引数なし
            elsif (hDoData["syscall"] =~ /^#{sApiName}\([\w\-\+\&]+\)$/)
              $sArg1 = hDoData["syscall"].gsub(/^#{sApiName}\(([\w\-\+\&]+)\)$/, "\\1")
            else
              $sArg1 = hDoData["syscall"].gsub(/^#{sApiName}\(([\w\-\+\&]+),.+\w\)$/, "\\1")
            end
          end
        }
      end

      # pre_conditionを含む各condition
      if (sCondition.include?("condition") && !hData.nil?)
        hData = generalize_do_post(hData)

        # tskstat/tskpri/prcid/porderを補完する
        hData.each{|snlTime, hPostData|
          if (!hPostData.nil?)
            # 設定がなければ前のconditionのタスク状態/優先度で補完し，設定があれば保持している情報を更新する
            if (sCondition != "pre_condition")
              hPreTaskInfo.each{|sTaskID, hTaskInfo|
                if (!hPostData.has_key?(sTaskID))
                  hPostData[sTaskID] = hTaskInfo
                else
                  if (hPostData[sTaskID].has_key?("tskstat"))
                    hTaskInfo["tskstat"] = hPostData[sTaskID]["tskstat"]
                  else
                    hPostData[sTaskID]["tskstat"] = hTaskInfo["tskstat"]
                  end
                  if (hPostData[sTaskID].has_key?("tskpri"))
                    hTaskInfo["tskpri"] = hPostData[sTaskID]["tskpri"]
                  else
                    hPostData[sTaskID]["tskpri"] = hTaskInfo["tskpri"]
                  end
                  if (hPostData[sTaskID].has_key?("prcid"))
                    hTaskInfo["prcid"] = hPostData[sTaskID]["prcid"]
                  else
                    hPostData[sTaskID]["prcid"] = hTaskInfo["prcid"]
                  end
                  if (hPostData[sTaskID].has_key?("porder"))
                    hTaskInfo["porder"] = hPostData[sTaskID]["porder"]
                  end
                end
              }
            end

            # 同一優先度のrunningとreadyが混在する場合，各情報を保持する
            hSameRunningReady = {}
            hPreTaskInfo.each{|sTaskID, hTaskInfo|
              if (["running", "ready"].include?(hTaskInfo["tskstat"]))
                if (!hSameRunningReady.has_key?(hTaskInfo["prcid"]))
                  hSameRunningReady[hTaskInfo["prcid"]] = {}
                end
                if (!hSameRunningReady[hTaskInfo["prcid"]].has_key?(hTaskInfo["tskpri"]))
                  hSameRunningReady[hTaskInfo["prcid"]][hTaskInfo["tskpri"]] = []
                end
                hSameRunningReady[hTaskInfo["prcid"]][hTaskInfo["tskpri"]].push([sTaskID, hTaskInfo["tskstat"], hPostData[sTaskID]["porder"]])
              end
            }

            hRunningTask = {}
            hRunningPri = {}
            hSameReadyTask = {}
            hPOrderInfo = {}
            hPOrderReadyTask = {}
            hSameRunningReady.each{|sPrcID, _|
              hRunningTask[sPrcID] = nil
              hRunningPri[sPrcID] = nil
              hSameReadyTask[sPrcID] = []
              hPOrderInfo[sPrcID] = {}
              hPOrderReadyTask[sPrcID] = []
            }

            hSameRunningReady.each{|sPrcID, hPrcInfo|
              hPrcInfo.each{|sTaskPri, aTaskList|
                if (aTaskList.size() > 1)
                  aTaskList.each{|aTaskData|
                    if (aTaskData[1] == "running")
                      hRunningTask[sPrcID] = aTaskData[0]
                      hRunningPri[sPrcID] = sTaskPri
                    else
                      hSameReadyTask[sPrcID].push(aTaskData[0])
                      if (!aTaskData[2].nil?)
                        hPOrderInfo[sPrcID][aTaskData[2]] = aTaskData[0]
                      end
                    end
                  }

                  # porderが指定されているタスクはporder順にソートして別途保持する
                  if (!hPOrderInfo.empty?)
                    hPOrderInfo.each{|sPrcID2, hInfo|
                      hInfo.keys().sort().each{|nOldPOrder|
                        hPOrderReadyTask[sPrcID2].push(hInfo[nOldPOrder])
                      }
                    }
                  end

                  $aSamePriorityInfo.push({:CONDITION => sCondition, :TIME => snlTime, :RUNNING => hRunningTask,
                                           :READY => hSameReadyTask, :PORDER => hPOrderReadyTask})
                end
              }
            }
          end
        }
      end
    }

    # 初期化，終了処理ルーチンを使用するテストケースは拡張対象外
    if (bIniTerRtn == true)
      next
    end

    # pre_conditionの時点で【NGKI0588】によりパターンH3/HM3，H5/HM5が成立しないテストかチェック
    bSamePriInPreCondition = false
    $aSamePriorityInfo.each{|hPriInfo|
      if (hPriInfo[:CONDITION] == "pre_condition")
        hPriInfo[:RUNNING].each{|sPrcID, sRunningID|
          if ((sRunningID == $sCaller) && hPriInfo[:READY][sPrcID].include?($sArg1))
            bSamePriInPreCondition = true
            break
          end
        }
      end
    }


    #
    # 拡張フェーズ
    #

    # H1/HM1: 呼出し元，呼出し先ともにユーザドメインに所属できる場合，もしくは引数がTSK_SELFの場合
    if ((USER_DOM_OBJ.include?($hObjType[$sCaller]) && !$sArg1.nil? && USER_DOM_OBJ.include?($hObjType[$sArg1]) &&
        !$aHandler.include?($sCaller) && !$aHandler.include?($sArg1)) ||
        ($sArg1 == "TSK_SELF"))
      expand_H1_HM1(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end

    # H2/HM2: 呼出し先がユーザドメインに所属できる場合
    if (!$sArg1.nil? && USER_DOM_OBJ.include?($hObjType[$sArg1]) && !$aHandler.include?($sArg1))
      expand_H2_HM2(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end

    # H3/HM3: 呼出し元がユーザドメインに所属できる場合(引数がないAPIも含む)
    if ((bSamePriInPreCondition == false) && ($sArg1 != "TSK_SELF") && USER_DOM_OBJ.include?($hObjType[$sCaller]) && !$aHandler.include?($sCaller))
      expand_H3_HM3(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end

    # H4/HM4: 呼出し元，呼出し先ともにユーザドメインに所属できる場合
    if (USER_DOM_OBJ.include?($hObjType[$sCaller]) && !$sArg1.nil? && USER_DOM_OBJ.include?($hObjType[$sArg1]) &&
        !$aHandler.include?($sCaller) && !$aHandler.include?($sArg1))
      expand_H4_HM4(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end

    # H5/HM5: 呼出し元がユーザドメインに所属できる場合(引数がないAPIも含む)
    # ※タイムイベント通知によるAPI呼出しはSVC経由にできないため対象外
    if ((bSamePriInPreCondition == false) && (bTimeEventNotifyCase == false) &&
        ($sArg1 != "TSK_SELF") && USER_DOM_OBJ.include?($hObjType[$sCaller]) && !$aHandler.include?($sCaller))
      expand_H5_HM5(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end

    # H6/HM6: 呼出し先が無所属できる場合
    if (NONE_DOM_OBJ.include?($hObjType[$sArg1]))
      expand_H6_HM6(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end

    # H7/HM7: 呼出し元がユーザドメインに所属でき，呼出し先が無所属できる場合
    if (USER_DOM_OBJ.include?($hObjType[$sCaller]) && !$aHandler.include?($sCaller) && NONE_DOM_OBJ.include?($hObjType[$sArg1]))
      expand_H7_HM7(sProfile, hExTesryInfo, Marshal.load(Marshal.dump(hOrgTestScenario)), sApiName, sTestID, hTestScenario)
    end
  }

  # 拡張対象が存在しない場合スキップ
  if (hExTesryInfo.size() == 1)
    next
  end

  # 拡張後のファイルを保存するフォルダがなければ作成する
  if (!Dir.exist?(sDir))
    FileUtils.mkdir_p(sDir)
  end

  # 拡張したTESRYデータをファイルに出力して整形
  sExTesryData = hExTesryInfo.to_yaml()
#puts(sExTesryData)
#next
  File.open(sExFilePath, "wb"){|cIO|
    cIO.puts(sExTesryData)
  }
  format_tesry(sExFilePath)
}
