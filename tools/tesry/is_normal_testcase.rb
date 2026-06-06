#!ruby -w
#
# 引数に与えたTESRYファイルに含まれるテストケースが，正常条件かエラー条
# 件かを判定する．
#

require "pp"
require "yaml"

TWO_WORD_DIR = ["sys", "spin", "task", "time"]
RETURN_TYPE  = ["ercd", "eruint", "erbool", "bool"]
NORMAL_LIST  = ["E_OK", "E_TMOUT", "E_RLWAI", "E_DLT", true, false]

def get_target_api_name(sTestID)
  aTemp = sTestID.split("_")
  if (TWO_WORD_DIR.include?(aTemp[1]))
    sApiName = "#{aTemp[3]}_#{aTemp[4]}"
  else
    sApiName = "#{aTemp[2]}_#{aTemp[3]}"
  end
  return sApiName
end

def is_normal_testcase?(sTestID, hTestScenario)
  sApiName = get_target_api_name(sTestID)

  bIsCallApi = false
  sReturnCode = nil
  sPreReturnCode = nil
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
        if (hDoData.has_key?("syscall") && hDoData["syscall"].include?(sApiName))
          # テスト対象APIを呼び出していたかを保持
          if (bIsCallApi == false)
            bIsCallApi = true
          else
            # 既にテスト対象APIを呼び出していた場合，前回の返り値を退避
            sPreReturnCode = sReturnCode
          end

          # テスト対象APIの返り値があれば保持
          RETURN_TYPE.each{|sRetType|
            if (hDoData.has_key?(sRetType))
              sReturnCode = hDoData[sRetType]
              # 既にテスト対象APIを呼び出していて，前回と返り値が異なる場合，どちらで判定するかを決める
              if (!sPreReturnCode.nil? && (sPreReturnCode != sReturnCode))
                if (sPreReturnCode == "E_OK")
                  # E_OKはテストシナリオ上必要な呼出しと見なし，E_OK以外を対象とするので何もしない(今回のsReturnCodeのまま)
                elsif (sReturnCode == "E_OK")
                  # E_OKはテストシナリオ上必要な呼出しと見なし，E_OK以外を対象とするので対象返り値をE_OK以外へ置き換える
                  sReturnCode = sPreReturnCode
                else
                  # 前回も今回もE_OKでなく，異なるエラーコードの場合，判定不可のためエラーとする(該当するテストは存在しない想定)
                  abort("duplicate target API !! #{sTestID}(#{sPreReturnCode} / #{sReturnCode})")
                end
              end
            end
          }
        end
      }
    end
  }

  # 対象APIを呼び出していない場合(_ten.yamlなど)は正常条件とする
  if (bIsCallApi == false)
    return true
  # 正常条件確定の返り値(返り値が指定されていない場合も正常条件)
  elsif (sReturnCode.nil? || NORMAL_LIST.include?(sReturnCode) || sReturnCode.is_a?(Integer))
    return true
  # E_RASTERは正常/エラーどちらもあるのでpost_conditionをチェック
  elsif (sReturnCode == "E_RASTER")
    # post_conditionが空＝システム状態に変化がない場合エラー条件とする
    if (hTestScenario.has_key?("post_condition") && hTestScenario["post_condition"].nil?)
      return false
    else
      return true
    end
  # 上記以外はエラー条件とする
  else
    return false
  end
end

if (__FILE__ == $0)
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
    hTesryInfo = YAML.load_file(sFilePath)
    hTesryInfo.each{|sTestID, hTestScenario|
      if (sTestID != "version")
        puts("#{sTestID}: #{is_normal_testcase?(sTestID, hTestScenario)}")
      end
    }
  }
end
