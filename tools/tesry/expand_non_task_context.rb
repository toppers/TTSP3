#!ruby -w
#
# 引数に与えたTESRYファイルに対して，非タスクコンテキストから呼出し可能
# なAPIを含むテストケースである場合，タイムイベントハンドラから呼び出す
# TESRYデータを作成する．また，以下のAPIに対しては，タイムイベント通知
# によるAPI実行を行うTESRYデータも作成する．
# ・act_tsk
# ・wup_tsk
# ・sig_sem
# ・set_flg
# ・psnd_dtq
#

if (__FILE__ == $0)
  TOOL_ROOT = File.expand_path(File.dirname(__FILE__))
  $LOAD_PATH.unshift(TOOL_ROOT)
end
require "tesry_formatter.rb"
require "is_normal_testcase.rb"

# 非タスクコンテキストから呼出し可能なAPI
# (sns_xxx，xsns_dpn，fch_hrtは非タスクコンテキストから呼び出すテストケースを設計するため拡張不要)
NTC_CALLABLE_API = ["act_tsk", "mact_tsk", "wup_tsk", "rel_wai", "sig_sem", "set_flg", "psnd_dtq", "fsnd_dtq", "psnd_pdq",
                    "loc_spn", "try_spn", "unl_spn", "adj_tim", "sta_alm", "msta_alm", "stp_alm",
                    "rot_rdq", "mrot_rdq", "get_tid", "get_did", "get_pid", "loc_cpu", "unl_cpu",
                    "dis_int", "ena_int", "clr_int", "ras_int", "prb_int", "cal_svc"]

# XXX_SELFに関するタグ(拡張時は除去する)
SELF_TAG = ["【NGKI1121】",  # act_tsk
            "【NGKI1275】",  # wup_tsk
            "【NGKI2689】",  # rot_rdq
            "【NGKI1135】",  # mact_tsk
            "【NGKI2701】"]  # mrot_rdq

$hDummyAlarmData = {}
$hDummyCycleData = {}
$hDummyTaskData = {}
$hNotifyAlarmData = {}
$hErrorAlarmData = {}
$hNotifyCycleData = {}
$hErrorCycleData = {}

# タイムイベント情報設定
def set_notify_data(sNtyType, sNtyInfo1, sNtyInfo2)
  $bNotifyFlg = true
  $hNotifyAlarmData["nfytype"] = sNtyType
  $hNotifyAlarmData["nfy_info1"] = sNtyInfo1
  $hNotifyAlarmData["nfy_info2"] = sNtyInfo2
  $hErrorAlarmData["enfytype"] = sNtyType.gsub("TNFY_", "TENFY_")
  $hErrorAlarmData["enfy_info1"] = sNtyInfo1
  $hErrorAlarmData["enfy_info2"] = sNtyInfo2
  $hNotifyCycleData["nfytype"] = sNtyType
  $hNotifyCycleData["nfy_info1"] = sNtyInfo1
  $hNotifyCycleData["nfy_info2"] = sNtyInfo2
  $hErrorCycleData["enfytype"] = sNtyType.gsub("TNFY_", "TENFY_")
  $hErrorCycleData["enfy_info1"] = sNtyInfo1
  $hErrorCycleData["enfy_info2"] = sNtyInfo2
  if (!["TNFY_SETFLG", "TNFY_SNDDTQ"].include?(sNtyType))
    $hNotifyAlarmData.delete("nfy_info2")
    $hErrorAlarmData.delete("enfy_info2")
    $hNotifyCycleData.delete("nfy_info2")
    $hErrorCycleData.delete("enfy_info2")
  elsif (sNtyType == "TNFY_SNDDTQ")
    $hErrorAlarmData.delete("enfy_info2")
    $hErrorCycleData.delete("enfy_info2")
  end
end

# ファイル出力
def output_file(hTesryInfo, sFilePath)
  # 拡張したTESRYデータをファイルに出力して整形
  sTesryData = hTesryInfo.to_yaml()
#puts(sTesryData)
#return
  File.open(sFilePath, "wb"){|cIO|
    cIO.puts(sTesryData)
  }
  format_tesry(sFilePath)
end

# テストケース毎の特別対応
aSpecialTesry = ["adj_tim_d-1", "adj_tim_d-2", "adj_tim_e-1", "adj_tim_e-2",
                 "adj_tim_F-c-1", "adj_tim_F-c-2", "loc_spn_F-d", "unl_spn_F-c-2", "unl_cpu_F-d"]
def expand_special_tesry(sNtcFilePath, sFilePath, sBaseName)
  hTesryInfo = YAML.load_file(sFilePath)
  hNtcTesryInfo = {"version" => hTesryInfo.delete("version")}
  sCurTestID = nil
  hTesryInfo.each{|sTestID, hCondition|
    sCurTestID = sTestID
  }

  [["#{sCurTestID}_ai", $hDummyAlarmData, "DUMMY_ALM"],
   ["#{sCurTestID}_ci", $hDummyCycleData, "DUMMY_CYC"]].each{|aNonTaskInfo|
    hNtcTesryInfo[aNonTaskInfo[0]] = {}
    hBackUpInfo = {}
    hTemp = Marshal.load(Marshal.dump(hTesryInfo))

    case sBaseName
    when "adj_tim_d-1", "adj_tim_d-2"
      hTemp.each{|_, hCondition|
        hCondition.each{|sConditon, hInfo|
          case sConditon
          when "pre_condition"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = Marshal.load(Marshal.dump(aNonTaskInfo[1]))
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]]["hdlstat"] = "STP"
            if (aNonTaskInfo[2] == "DUMMY_ALM")
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]]["almstat"] = "TALM_STA"
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]]["lefttim"] = 0
            else
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]]["cycphs"] = 0
            end
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon].merge!(hInfo)
          when "post_condition_0"
            if (aNonTaskInfo[2] == "DUMMY_ALM")
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {1 => {aNonTaskInfo[2] => {"almstat" => "TALM_STP", "hdlstat" => "ACTIVATE"}}}
            else
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {1 => {aNonTaskInfo[2] => {"hdlstat" => "ACTIVATE"}}}
            end
          when "do_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {1 => {"id" => aNonTaskInfo[2]}}
            hInfo.each{|sKey, sVal|
              if (sKey != "id")
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon][1][sKey] = sVal
              end
            }
          when "post_condition_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {1 => hInfo}
          when "do_2"
            hBackUpInfo["do_3"] = {1 => hInfo}
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {1 => {"id" => aNonTaskInfo[2], "code" => "return"}}
          when "post_condition_2"
            hInfo["TASK1"]["var"]["systim2"]["value"] += "+1"
            hBackUpInfo["post_condition_3"] = {1 => hInfo}
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {1 => {aNonTaskInfo[2] => {"hdlstat" => "STP"}}}
          else
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          end
        }
        hNtcTesryInfo[aNonTaskInfo[0]].merge!(hBackUpInfo)

        if (sBaseName == "adj_tim_d-2")
          hNtcTesryInfo[aNonTaskInfo[0]]["do_4"] = {1 => {"id" => "TASK1", "syscall" => "adj_tim(-1 * ANY_ADJUST_MINUS_TIME)", "ercd" => "E_OK"}}
          hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_4"] = {1 => nil}
        end
      }

    when "adj_tim_e-1", "adj_tim_e-2", "adj_tim_F-c-1", "adj_tim_F-c-2"
      hTemp.each{|_, hCondition|
        hCondition.each{|sConditon, hInfo|
          case sConditon
          when "pre_condition"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = aNonTaskInfo[1].merge(hInfo)
          when "do_0"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"id" => aNonTaskInfo[2]}
            hInfo.each{|sKey, sVal|
              if (sKey != "id")
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey] = sVal
              end
            }
          when "post_condition_0"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"ALM1" => hInfo[0].delete("ALM1")}
            hInfo[0] = {aNonTaskInfo[2] => {"hdlstat" => "STP"}}
            hBackUpInfo["post_condition_1"] = hInfo
          when "do_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"id" => aNonTaskInfo[2], "code" => "return"}
            hBackUpInfo["do_2"] = hInfo
          when "post_condition_1"
            hBackUpInfo["post_condition_2"] = hInfo
          else
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          end
        }
        hNtcTesryInfo[aNonTaskInfo[0]].merge!(hBackUpInfo)
      }

    when "loc_spn_F-d"
      hTemp.each{|_, hCondition|
        hCondition.each{|sConditon, hInfo|
          case sConditon
          when "pre_condition"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = Marshal.load(Marshal.dump(aNonTaskInfo[1]))
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon].merge!(hInfo)
          when "do_0"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"id" => aNonTaskInfo[2]}
            hInfo.each{|sKey, sVal|
              if (sKey != "id")
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey] = sVal
              end
            }
          when "post_condition_0"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {aNonTaskInfo[2] => {"hdlstat" => "ACTIVATE-waitspin",
                                                                            "spinid" => hInfo["TASK1"]["spinid"]}}
          when "post_condition_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {aNonTaskInfo[2] => {"hdlstat" => "ACTIVATE"}}
            hInfo.delete("TASK1")
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon].merge!(hInfo)
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon]["SPN1"]["procid"] = aNonTaskInfo[2]
          else
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          end
        }
      }

    when "unl_spn_F-c-2"
      hTemp.each{|_, hCondition|
        hCondition.each{|sConditon, hInfo|
          case sConditon
          when "pre_condition"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = Marshal.load(Marshal.dump(aNonTaskInfo[1]))
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon].merge!(hInfo)
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon]["SPN1"]["procid"] = aNonTaskInfo[2]
          when "do_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"id" => aNonTaskInfo[2],
                                                        "syscall" => hInfo["syscall"],
                                                        "ercd" => "E_OK"}
          when "post_condition_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon]["TASK1"]["tskstat"] = "running"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon]["TASK2"]["tskstat"] = "ready"
          else
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          end
        }
      }

    when "unl_cpu_F-d"
      hTemp.each{|_, hCondition|
        hCondition.each{|sConditon, hInfo|
          case sConditon
          when "pre_condition"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = Marshal.load(Marshal.dump(aNonTaskInfo[1]))
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon].merge!(hInfo)
          when "do_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"id" => aNonTaskInfo[2],
                                                        "syscall" => hInfo["syscall"],
                                                        "ercd" => "E_OK"}
          when "post_condition_1"
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"CPU_STATE1" => hInfo.delete("CPU_STATE1")}
            hNtcTesryInfo[aNonTaskInfo[0]]["do_2"] = {"id" => aNonTaskInfo[2], "code" => "return"}
            hBackUpInfo["post_condition_2"] = {aNonTaskInfo[2] => {"hdlstat" => "STP"}}
            hBackUpInfo["post_condition_2"].merge!(hInfo)

          else
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          end
        }
        hNtcTesryInfo[aNonTaskInfo[0]].merge!(hBackUpInfo)
      }
    end
  }

  output_file(hNtcTesryInfo, sNtcFilePath)
end


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

aTargetFile.each{|sFilePath|
  # 拡張済みのyamlは対象外
  if (sFilePath.end_with?("_ntc.yaml") || sFilePath.end_with?("_ten.yaml") || sFilePath.end_with?("_ex.yaml"))
    next
  end

  # 拡張後のファイル名作成
  sDir = File.dirname(sFilePath)
  sBaseName = File.basename(sFilePath, ".yaml")
  sNtcFilePath = "#{sDir}/#{sBaseName}_ntc.yaml"
  sTenFilePath = "#{sDir}/#{sBaseName}_ten.yaml"

  # ダミーデータ初期化
  $hDummyAlarmData = {"DUMMY_ALM" => {"type"      => "ALARM",
                                      "nfytype"   => "TNFY_HANDLER",
                                      "nfy_info1" => "EXINF_A",
                                      "almstat"   => "TALM_STP",
                                      "hdlstat"   => "ACTIVATE"}}

  $hDummyCycleData = {"DUMMY_CYC" => {"type"      => "CYCLE",
                                      "nfytype"   => "TNFY_HANDLER",
                                      "nfy_info1" => "EXINF_A",
                                      "cycstat"   => "TCYC_STA",
                                      "cycphs"    => "RELATIVE_TIME_A",
                                      "cyctim"    => "RELATIVE_TIME_B*2",
                                      "hdlstat"   => "ACTIVATE"}}

  $hDummyTaskData = {"DUMMY_TASK" => {"type"    => "TASK",
                                      "tskstat" => "ready",
                                      "tskpri"  => "TSK_PRI_BOTTOM",
                                      "actcnt"  => 1}}

  # FMP向けの場合の追加設定
  bFmpFlg = false
  if (sFilePath.include?("_F-"))
    bFmpFlg = true
    $hDummyAlarmData["DUMMY_ALM"]["prcid"] = "PRC_SELF"
    $hDummyCycleData["DUMMY_CYC"]["prcid"] = "PRC_SELF"
    $hDummyTaskData["DUMMY_TASK"]["prcid"] = "PRC_SELF"
  end

  # テストケース毎の特別対応
  if (aSpecialTesry.include?(sBaseName))
    expand_special_tesry(sNtcFilePath, sFilePath, sBaseName)
    next
  end

  hTesryInfo = YAML.load_file(sFilePath)

  # 拡張するTESRYデータ初期化(versionを元データから取り除く)
  hNtcTesryInfo = {"version" => hTesryInfo.delete("version")}
  hTenTesryInfo = Marshal.load(Marshal.dump(hNtcTesryInfo))


  # 拡張対象のAPIかを判別する
  bTargetFlg = true
  hTesryInfo.each{|sTestID, hTestScenario|
    sApiName = get_target_api_name(sTestID)
    # 非タスクコンテキストから呼び出せないAPIは対象外
    if (!NTC_CALLABLE_API.include?(sApiName))
      bTargetFlg = false
      break
    end
    # エラー条件のテストケースは対象外
    if (!is_normal_testcase?(sTestID, hTestScenario))
      bTargetFlg = false
      break
    end
    # doで対象APIを呼び出す処理単位がタスクでない場合は対象外
    hTestScenario.each{|sCondition, hData|
      if ((sCondition =~ /^do/) && !hData.nil?)
        # 時刻指定対応
        bIsTimeSet = false
        hData.each{|snKey, shVal|
          if (snKey.is_a?(Integer) || (snKey =~ /^[A-Z0-9_\+\-\*]+$/))
            bIsTimeSet = true
            break
          end
        }
        if (bIsTimeSet == false)
          hData = {:DUMMY => hData}
        end

        hData.each{|_, hDoData|
          if (hDoData.has_key?("syscall") && hDoData["syscall"].include?(sApiName) &&
              hDoData.has_key?("id") && !hDoData["id"].start_with?("TASK"))
            bTargetFlg = false
            break
          end
        }
      end
    }
  }
  # 拡張対象外の場合スキップ
  if (bTargetFlg == false)
    next
  end

  # タイムイベント用データ初期化
  $bNotifyFlg = false
  $hNotifyAlarmData = {"type"      => "ALARM",
                       "nfytype"   => nil,
                       "nfy_info1" => nil,
                       "nfy_info2" => nil,
                       "almstat"   => "TALM_STP"}
  $hErrorAlarmData = {"type"       => "ALARM",
                      "nfytype"    => "TNFY_ACTTSK",
                      "nfy_info1"  => "DUMMY_TASK",
                      "enfytype"   => nil,
                      "enfy_info1" => nil,
                      "enfy_info2" => nil,
                      "almstat"    => "TALM_STP"}
  $hNotifyCycleData = {"type"      => "CYCLE",
                       "nfytype"   => nil,
                       "nfy_info1" => nil,
                       "nfy_info2" => nil,
                       "cycstat"   => "TCYC_STP",
                       "cycphs"    => 0,
                       "cyctim"    => "RELATIVE_TIME_A"}
  $hErrorCycleData = {"type"       => "CYCLE",
                      "nfytype"    => "TNFY_ACTTSK",
                      "nfy_info1"  => "DUMMY_TASK",
                      "enfytype"   => nil,
                      "enfy_info1" => nil,
                      "enfy_info2" => nil,
                      "cycstat"    => "TCYC_STP",
                      "cycphs"     => 0,
                      "cyctim"     => "RELATIVE_TIME_A"}

  if (bFmpFlg == true)
    $hNotifyAlarmData["prcid"] = "PRC_SELF"
    $hErrorAlarmData["prcid"] = "PRC_SELF"
    $hNotifyCycleData["prcid"] = "PRC_SELF"
    $hErrorCycleData["prcid"] = "PRC_SELF"
  end

  #
  # テスト構成チェック
  #
  sCurTestID = nil
  sRunningTask = nil
  sActiveContext = nil
  bIsActiveContext = false
  aOtherPrcTask = []
  sDoID = nil
  snStaAlmOkTime = nil
  hPreState = {}
  hStateChangedTask = {}
  hLeftTmoTask = {}
  aHavingVarTask = []
  aPOrderTask = []
  bNotOkFlg = false
  sSetFlgPattern = ""
  bCpuLock = false
  sMultiDoID = nil
  aMultiKeepDo = []
  aMultiAlarmStartPost = []
  aMultiAlarmStopPost = []
  hTesryInfo.each{|sTestID, hCondition|
    sCurTestID = sTestID
    hCondition["pre_condition"].each{|sObjID, hObjInfo|
      if (hObjInfo.has_key?("tskstat") && hObjInfo["tskstat"].include?("running"))
        # 他プロセッサで実行状態は対象外
        if (!hObjInfo.has_key?("prcid") || (hObjInfo["prcid"] == "PRC_SELF"))
          # pre_conditionでrunningのタスクID
          sRunningTask = sObjID
        end
      elsif (hObjInfo.has_key?("hdlstat") && hObjInfo["hdlstat"] == "ACTIVATE")
        # 他プロセッサで実行状態は対象外
        if (!hObjInfo.has_key?("prcid") || (hObjInfo["prcid"] == "PRC_SELF"))
          # pre_conditionでACTIVATEの処理単位のID
          sActiveContext = sObjID
        end
        # 全プロセッサにおいてACTIVATEの非タスクコンテキストが存在するか
        bIsActiveContext = true
      end

      # pre_conditionにおける各タスクの状態，タイムアウト値，プロセッサ情報を保持
      if (hObjInfo["type"] == "TASK")
        hPreState[sObjID] = hObjInfo["tskstat"]
        if (hObjInfo["tskstat"].include?("waiting") && hObjInfo.has_key?("lefttmo"))
          hLeftTmoTask[sObjID] = hObjInfo["lefttmo"]
        end
        if (hObjInfo.has_key?("prcid") && (hObjInfo["prcid"] != "PRC_SELF"))
          aOtherPrcTask.push(sObjID)
        end
      elsif ((hObjInfo["type"] == "CPU_STATE") && hObjInfo.has_key?("loc_cpu") && (hObjInfo["loc_cpu"] == true))
        bCpuLock = true
      end
    }

    hDoData = hCondition["do"]
    if (hDoData.nil?)
      hDoData = hCondition["do_0"]
    end
    if (!hDoData.nil?)
      if (hDoData.has_key?("id"))
        # doでAPIを発行する処理単位のID
        sDoID = hDoData["id"]
      end
      if (hDoData.has_key?("ercd") && (hDoData["ercd"] != "E_OK"))
        # E_OK以外が返り値になっているか
        bNotOkFlg = true
      end
      if (hDoData.has_key?("syscall") && hDoData["syscall"].include?("set_flg"))
        # set_flgの第2引数
        sSetFlgPattern = hDoData["syscall"].gsub(/set_flg\(\w+,\s([\w\|]+)\)/, "\\1")
      end
      if (hDoData.has_key?("syscall"))
        if ((hDoData["syscall"] =~ /^sta_alm/) && hDoData.has_key?("ercd") && (hDoData["ercd"] == "E_OK"))
          # 返り値E_OKのsta_almを呼び出す際の第2引数
          snStaAlmOkTime = hDoData["syscall"].gsub(/^sta_alm\(ALM1,\s(\w+)\)$/, "\\1")
          if (snStaAlmOkTime =~ /^[0-9]+$/)
            snStaAlmOkTime = snStaAlmOkTime.to_i()
          end
        elsif ((hDoData["syscall"] =~ /^msta_alm/) && hDoData.has_key?("ercd") && (hDoData["ercd"] == "E_OK"))
          # 返り値E_OKのmsta_almを呼び出す際の第2引数
          snStaAlmOkTime = hDoData["syscall"].gsub(/^msta_alm\(ALM1,\s(\w+),\s\w+\)$/, "\\1")
          if (snStaAlmOkTime =~ /^[0-9]+$/)
            snStaAlmOkTime = snStaAlmOkTime.to_i()
          end
        # タイムイベント通知対象API情報取得
        elsif (hDoData["syscall"] =~ /^act_tsk/)
          sTargetId = hDoData["syscall"].gsub(/act_tsk\((\w+)\)/, "\\1")
          if (sTargetId == "TSK_SELF")
            set_notify_data("TNFY_ACTTSK", "TASK1", nil)
          else
            set_notify_data("TNFY_ACTTSK", sTargetId, nil)
          end
        elsif (hDoData["syscall"] =~ /^wup_tsk/)
          sTargetId = hDoData["syscall"].gsub(/wup_tsk\((\w+)\)/, "\\1")
          if (sTargetId == "TSK_SELF")
            set_notify_data("TNFY_WUPTSK", "TASK1", nil)
          else
            set_notify_data("TNFY_WUPTSK", sTargetId, nil)
          end
        elsif (hDoData["syscall"] =~ /^sig_sem/)
          set_notify_data("TNFY_SIGSEM", "SEM1", nil)
        elsif (hDoData["syscall"] =~ /^set_flg/)
          set_notify_data("TNFY_SETFLG", "FLG1", sSetFlgPattern)
        elsif (hDoData["syscall"] =~ /^psnd_dtq/)
          set_notify_data("TNFY_SNDDTQ", "DTQ1", "DATA_A")
        end
      end
    end

    hPostData = hCondition["post_condition"]
    if (!hPostData.nil?)
      # タスクの状態遷移状況から，非タスクコンテキストへの変更時の然るべき状態を設定
      hPreState.each{|sTaskID, sState|
        if (hPostData.has_key?(sTaskID) && hPostData[sTaskID].has_key?("tskstat"))
          # 他プロセッサでの変化は対象外
          if ((hPostData[sTaskID].has_key?("prcid") && (hPostData[sTaskID]["prcid"] != "PRC_SELF")) ||
              (aOtherPrcTask.include?(sTaskID) && !hPostData[sTaskID].has_key?("prcid")))
            next
          end

          case sState
          when "running"
            # 非タスクコンテキストからの実行ではディスパッチしないためrunningのままとする
            if (hPostData[sTaskID]["tskstat"] == "ready")
              hStateChangedTask[sTaskID] = "running"
            end
            # 実行状態のタスクにporderが指定されているかを保持
            if (hPostData[sTaskID].has_key?("porder"))
              aPOrderTask.push(sTaskID)
            end
          when "dormant", "waiting"
            # 非タスクコンテキストからの実行ではディスパッチしないため，起動や待ちが解除されたreadyとする
            if (hPostData[sTaskID]["tskstat"] == "running")
              hStateChangedTask[sTaskID] = "ready"
              # 変数チェックが存在したかを保持
              if (hPostData[sTaskID].has_key?("var"))
                aHavingVarTask.push(sTaskID)
              end
            end
            # タスクの状態が変わった場合はタイムアウト値を破棄
            if (hLeftTmoTask.has_key?(sTaskID))
              hLeftTmoTask.delete(sTaskID)
            end
          when "ready"
            # 非タスクコンテキストからの実行ではディスパッチしないためreadyのままとする
            if (hPostData[sTaskID]["tskstat"] == "running")
              hStateChangedTask[sTaskID] = "ready"
            end
          end
        end
      }
    end

    # 複数のdo/post向け処理
    hCondition.each{|sConditon, hInfo|
      if (sConditon =~ /^do_[0-9]+/)
        if (sMultiDoID.nil?)
          # do_0のidを保持
          sMultiDoID = hInfo["id"]
        elsif (sMultiDoID != hInfo["id"])
          # do_0とidが異なるdo_*を保持
          aMultiKeepDo.push(sConditon)
        end
      elsif ((sConditon =~ /^post_condition_[0-9]+/) && !hInfo.nil?)
        hInfo.each{|sObjID, hObjInfo|
          if (hObjInfo.has_key?("hdlstat"))
            if (hObjInfo["hdlstat"] == "ACTIVATE")
              # post_conditionでACTIVATEの処理単位が登場したpost_condition_*を保持
              aMultiAlarmStopPost.push(sConditon)
            elsif (hObjInfo["hdlstat"] == "STP")
              # post_conditionでSTPの処理単位が登場したpost_condition_*を保持
              aMultiAlarmStartPost.push(sConditon)
            end
          end
        }
      end
    }
  }

  #
  # 実行中のタスクがdoでAPIを呼び出している場合，非タスクコンテキストへ置き換える
  #
  if (sActiveContext.nil? && !sRunningTask.nil? && (sRunningTask == sDoID))
    # アラームハンドラ，周期ハンドラからの呼出し(_ai，_ci)
    [["#{sCurTestID}_ai", Marshal.load(Marshal.dump($hDummyAlarmData)), "DUMMY_ALM"],
     ["#{sCurTestID}_ci", Marshal.load(Marshal.dump($hDummyCycleData)), "DUMMY_CYC"]].each{|aNonTaskInfo|
      hNtcTesryInfo[aNonTaskInfo[0]] = {}
      hTemp = Marshal.load(Marshal.dump(hTesryInfo))
      hTemp.each{|_, hCondition|
        hCondition.each{|sConditon, hInfo|
          if (sConditon == "note")
            SELF_TAG.each{|sTag|
              hInfo.gsub!(sTag, "")
            }
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          elsif (hInfo.nil? || sConditon == "variation")
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
          elsif (sConditon == "pre_condition")
            # ダミーの非タスクコンテキストを追加
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = aNonTaskInfo[1].merge(hInfo)
            # 実行中タスクにvarが指定されている場合，非タスクコンテキストへ移動(sta_almの場合TASK側のままとする)
            if (snStaAlmOkTime.nil? && hInfo[sRunningTask].has_key?("var"))
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]]["var"] = hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sRunningTask].delete("var")
            end
            # スピンロック取得中のTASK1をダミーの非タスクコンテキストへ変更
            hNtcTesryInfo[aNonTaskInfo[0]][sConditon].each{|sObjID, hObjInfo|
              if (hObjInfo.has_key?("procid") && (hObjInfo["procid"] == "TASK1"))
                hObjInfo["procid"] = aNonTaskInfo[2]
              end
            }
          else
            # sta_alm/msta_almを非タスクコンテキストから呼び出してリターンするためのdo/post追加
            if (!snStaAlmOkTime.nil?)
              case sConditon
              when "do", "do_0"
                hNtcTesryInfo[aNonTaskInfo[0]]["do_0"] = {"id" => aNonTaskInfo[2],
                                                         "syscall" => hInfo["syscall"],
                                                         "ercd" => hInfo["ercd"]}
              when "post_condition", "post_condition_0"
                hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_0"] = {"ALM1" => hInfo[0]["ALM1"].dup()}
                hNtcTesryInfo[aNonTaskInfo[0]]["do_1"] = {"id" => aNonTaskInfo[2],
                                                         "code" => "return"}
                hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_1"] = {0 => {aNonTaskInfo[2] => {"hdlstat" => "STP"}}}
                hInfo.each{|sKey, shVal|
                  if (sKey == 0)
                    hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_1"][sKey].merge!(shVal)
                  else
                    hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_1"][sKey] = shVal
                  end
                }
              when "do_1"
                hNtcTesryInfo[aNonTaskInfo[0]]["do_2"] = hInfo
              when "post_condition_1"
                hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_2"] = hInfo
              end

            # post_conditionで変数を確認していたタスクがrunningでなくなった場合，
            # もしくは，porderを指定したタスクが存在した場合，非タスクコンテキストリターン後のdo/postを追加
            elsif (!aHavingVarTask.empty? || !aPOrderTask.empty?)
              if (sConditon == "do")
                hNtcTesryInfo[aNonTaskInfo[0]]["do_0"] = {"id" => aNonTaskInfo[2],
                                                         "syscall" => hInfo["syscall"].gsub("TPRI_SELF", "TSK_PRI_MID")}
                if (hInfo.has_key?("ercd"))
                  hNtcTesryInfo[aNonTaskInfo[0]]["do_0"]["ercd"] = hInfo["ercd"]
                else
                  # API呼出しで返り値を確認していない場合，非タスクコンテキストから返り値を確認する
                  hNtcTesryInfo[aNonTaskInfo[0]]["do_0"]["ercd"] = "E_OK"
                end

              else
                hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_0"] = {}
                hInfo.each{|sKey, shVal|
                  # pre_conditionからpost_conditionでタスクの状態が変化している場合，然るべき状態へ変更
                  if (hStateChangedTask.has_key?(sKey))
                    hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_0"][sKey] = {}
                    shVal.each{|sParam, sValue|
                      if (sParam == "tskstat")
                        hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_0"][sKey][sParam] = hStateChangedTask[sKey]
                      elsif ((sParam == "var") && (hStateChangedTask[sKey] != "running"))
                        # post_conditionでrunningでなくなった場合，変数チェックは不可
                        next
                      else
                        hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_0"][sKey][sParam] = sValue
                      end
                    }
                  else
                    hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_0"][sKey] = shVal.dup()
                  end
                }

                hNtcTesryInfo[aNonTaskInfo[0]]["do_1"] = {"id" => aNonTaskInfo[2],
                                                         "code" => "return"}

                hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_1"] = {aNonTaskInfo[2] => {"hdlstat" => "STP"}}
                hInfo.each{|sKey, shVal|
                  if (sKey =~ /^TASK/)
                    shVal.delete("porder")
                    if (!shVal.empty?)
                      hNtcTesryInfo[aNonTaskInfo[0]]["post_condition_1"][sKey] = shVal.dup()
                    end
                  end
                }
              end

            elsif (sConditon =~ /^do/)
              # 複数do/postで変更しないdo
              if (aMultiKeepDo.include?(sConditon))
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = hInfo
                next
              end

              # doでAPIを呼び出す処理単位を非タスクコンテキストへ変更
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {"id" => aNonTaskInfo[2]}
              hInfo.each{|sKey, sVal|
                if (sKey == "syscall")
                  hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey] = sVal.gsub("TSK_SELF", "TASK1").gsub("TPRI_SELF", "TSK_PRI_MID")
                elsif (sKey != "id")
                  hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey] = sVal
                end
              }

              # API呼出しで返り値を確認していない場合，非タスクコンテキストから返り値を確認する
              # (複数のdo/postが存在する場合は返り値を追加しない)
              if (!hInfo.has_key?("ercd") && !hInfo.has_key?("bool") && !hInfo.has_key?("erbool") &&
                  sMultiDoID.nil?)
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon]["ercd"] = "E_OK"
              end

            elsif (sConditon =~ /^post_condition/)
              hNtcTesryInfo[aNonTaskInfo[0]][sConditon] = {}

              # 複数のdo/postが存在する場合の非タスクコンテキスト起動/停止
              if (aMultiAlarmStopPost.include?(sConditon))
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]] = {"hdlstat" => "STP"}
              elsif (aMultiAlarmStartPost.include?(sConditon))
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]] = {"hdlstat" => "ACTIVATE"}
              end

              hInfo.each{|sKey, shVal|
                # pre_conditionからpost_conditionでタスクの状態が変化している場合，然るべき状態へ変更
                if (hStateChangedTask.has_key?(sKey))
                  hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey] = {}
                  shVal.each{|sParam, sValue|
                    if (sParam == "tskstat")
                      hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey][sParam] = hStateChangedTask[sKey]
                    else
                      hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey][sParam] = sValue
                    end
                  }
                else
                  hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sKey] = shVal
                end

                # スピンロック取得中のTASK1をダミーの非タスクコンテキストへ変更
                if (shVal.has_key?("procid") && (shVal["procid"] == "TASK1"))
                  shVal["procid"] = aNonTaskInfo[2]
                end
              }

              # 実行中タスクにvarが指定されている場合，非タスクコンテキストへ移動
              if (hInfo.has_key?(sRunningTask) && hInfo[sRunningTask].has_key?("var"))
                if (!hNtcTesryInfo[aNonTaskInfo[0]][sConditon].has_key?(aNonTaskInfo[2]))
                  hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]] = {}
                end
                hNtcTesryInfo[aNonTaskInfo[0]][sConditon][aNonTaskInfo[2]]["var"] = hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sRunningTask].delete("var")
                # 移動した結果，実行中タスクに何もパラメータがなくなったら削除
                if (hNtcTesryInfo[aNonTaskInfo[0]][sConditon][sRunningTask].empty?)
                  hNtcTesryInfo[aNonTaskInfo[0]][sConditon].delete(sRunningTask)
                end
              end

            end
          end
        }
      }
    }
    output_file(hNtcTesryInfo, sNtcFilePath)

    # 対象外のAPI，E_OKが返らない，CPロック状態，非タスクコンテキスト実行中のテストはタイムイベントでは実施できない
    if (($bNotifyFlg == true) && (bNotOkFlg == false) && (bCpuLock == false) && (bIsActiveContext == false))
      # タイムイベント/エラー通知による呼出し(_at，_ae，_ct，_ce)
      [["#{sCurTestID}_at", $hNotifyAlarmData, "DUMMY_ALM"],
       ["#{sCurTestID}_ae", $hErrorAlarmData, "DUMMY_ALM"],
       ["#{sCurTestID}_ct", $hNotifyCycleData, "DUMMY_CYC"],
       ["#{sCurTestID}_ce", $hErrorCycleData, "DUMMY_CYC"]].each{|aNotifyInfo|
        hTenTesryInfo[aNotifyInfo[0]] = {}
        hTemp = Marshal.load(Marshal.dump(hTesryInfo))
        hTemp.each{|_, hCondition|
          hCondition.each{|sConditon, hInfo|
            if (sConditon == "note")
              SELF_TAG.each{|sTag|
                hInfo.gsub!(sTag, "")
              }
              hTenTesryInfo[aNotifyInfo[0]][sConditon] = hInfo
            elsif (hInfo.nil? || sConditon == "variation")
              hTenTesryInfo[aNotifyInfo[0]][sConditon] = hInfo
            elsif (sConditon == "pre_condition")
              if (aNotifyInfo[0].end_with?("t"))
                # タイムイベント通知を追加
                hTenTesryInfo[aNotifyInfo[0]][sConditon] = {aNotifyInfo[2] => aNotifyInfo[1]}.merge(hInfo)
              else
                # エラー通知，ダミータスクを追加
                hDummyTask = Marshal.load(Marshal.dump($hDummyTaskData))
                hTenTesryInfo[aNotifyInfo[0]][sConditon] = {aNotifyInfo[2] => aNotifyInfo[1]}.merge(hDummyTask)
                hTenTesryInfo[aNotifyInfo[0]][sConditon].merge!(hInfo)
              end

            elsif (sConditon =~ /^do/)
              # doで呼び出すAPIをsta_almへ変更
              hTenTesryInfo[aNotifyInfo[0]][sConditon] = hInfo
              if (aNotifyInfo[2] == "DUMMY_ALM")
                hTenTesryInfo[aNotifyInfo[0]][sConditon]["syscall"] = "TTSP_STA_ALM(DUMMY_ALM, 0)"
              else
                hTenTesryInfo[aNotifyInfo[0]][sConditon]["syscall"] = "TTSP_STA_CYC(DUMMY_CYC)"
              end

              # API呼出しで返り値を確認していない場合，確認する
              if (!hInfo.has_key?("ercd"))
                hTenTesryInfo[aNotifyInfo[0]][sConditon]["ercd"] = "E_OK"
              end

            elsif (sConditon =~ /^post_condition/)
              hTenTesryInfo[aNotifyInfo[0]][sConditon] = {0 => {}, 1 => {}}
              if (aNotifyInfo[2] == "DUMMY_ALM")
                hTenTesryInfo[aNotifyInfo[0]][sConditon][0]["DUMMY_ALM"] = {"almstat" => "TALM_STA"}
                hTenTesryInfo[aNotifyInfo[0]][sConditon][1]["DUMMY_ALM"] = {"almstat" => "TALM_STP"}
              else
                hTenTesryInfo[aNotifyInfo[0]][sConditon][0]["DUMMY_CYC"] = {"cycstat" => "TCYC_STA"}
              end

              hInfo.each{|sKey, shVal|
                hTenTesryInfo[aNotifyInfo[0]][sConditon][1][sKey] = shVal
              }

              # エラー通知で変数がある場合，エラーコードに変更する
              if (aNotifyInfo[0].end_with?("e"))
                hTenTesryInfo[aNotifyInfo[0]][sConditon][1].each{|sObjID, hObjInfo|
                  if (hObjInfo.has_key?("var"))
                    if (hObjInfo["var"].has_key?("data"))
                      hObjInfo["var"]["data"]["value"] = "E_QOVR"
                    elsif (hObjInfo["var"].has_key?("ttg_data"))
                      hObjInfo["var"]["ttg_data"]["value"] = "E_QOVR"
                    end
                  elsif (hObjInfo.has_key?("datalist"))
                    hObjInfo["datalist"][-1]["data"] = "E_QOVR"
                  end
                }
              end

              # pre_conditionでタイムアウト付き待ち状態となっているタスクはlefttmoを-1する
              hLeftTmoTask.each{|sTaskID, sLeftTmo|
                hNewHash = {"lefttmo" => "#{sLeftTmo}-1"}
                if (hTenTesryInfo[aNotifyInfo[0]][sConditon][1].has_key?(sTaskID))
                  hTenTesryInfo[aNotifyInfo[0]][sConditon][1][sTaskID].each{|sKey, shVal|
                    hNewHash[sKey] = shVal
                  }
                  hTenTesryInfo[aNotifyInfo[0]][sConditon][1][sTaskID] = hNewHash
                end
              }

            end
          }
        }
      }
      output_file(hTenTesryInfo, sTenFilePath)
    end
  end
}
