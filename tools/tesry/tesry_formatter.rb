#!ruby -w
#
# 引数に与えたTESRYファイルのインデントや改行を整形する．
#

require "pp"
require "yaml"

DO_KEY_LIST = ["id", "syscall", "gcov", "ercd", "eruint", "erbool", "bool", "code"]

# "@@@x@@@"をハッシュデータに付与
def set_delimiter(ahData)
  nMaxSize = 0

  # ハッシュの場合，「@@@最大文字数@@@」を付与したキーへ差し替える
  if (ahData.is_a?(Hash))
    ahData.each{|sHashKey, snahVal|
      if (nMaxSize < sHashKey.length())
        nMaxSize = sHashKey.length()
      end
    }
    hNewHash = {}
    ahData.each{|sHashKey, snahVal|
      if (snahVal.is_a?(String))
        hNewHash["@@@#{nMaxSize}@@@#{sHashKey}"] = snahVal.gsub(" ", "###")
      else
        hNewHash["@@@#{nMaxSize}@@@#{sHashKey}"] = snahVal
      end
    }
    ahData.clear()
    hNewHash.each{|sHashKey, snahVal|
      ahData[sHashKey] = snahVal
    }
    # 差替え後，値がハッシュもしくは配列の場合は再帰的に差替えを行う
    ahData.each{|sHashKey, snahVal|
      if (snahVal.is_a?(Hash) || snahVal.is_a?(Array))
        set_delimiter(snahVal)
      end
    }
  # 配列の場合，要素がハッシュの場合のみ，同様に処理する
  elsif (ahData.is_a?(Array))
    ahData.each{|shArrayKey|
      if (shArrayKey.is_a?(Hash))
        shArrayKey.each{|sHashKey, snahVal|
          if (nMaxSize < sHashKey.length())
            nMaxSize = sHashKey.length()
          end
        }
      end
    }
    # 要素がハッシュでない場合，何もしない
    if (nMaxSize != 0)
      aNewArray = []
      ahData.each{|shArrayKey|
        if (shArrayKey.is_a?(Hash))
          hNewHash = {}
          shArrayKey.each{|sHashKey, snahVal|
            if (snahVal.is_a?(String))
              hNewHash["@@@#{nMaxSize}@@@#{sHashKey}"] = snahVal.gsub(" ", "###")
            else
              hNewHash["@@@#{nMaxSize}@@@#{sHashKey}"] = snahVal
            end
          }
          aNewArray.push(hNewHash)
        else
          aNewArray.push(shArrayKey)
        end
      }
      ahData.clear()
      aNewArray.each{|shArrayKey|
        ahData.push(shArrayKey)
      }
      # ハッシュに対しては再帰的に差替えを行う
      ahData.each{|shArrayKey|
        if (shArrayKey.is_a?(Hash))
          shArrayKey.each_value{|snahVal|
            set_delimiter(snahVal)
          }
        end
      }
    end
  end
end

def format_tesry(sFilePath)
  # ハッシュとしてyamlファイルを読み込む
  hTesryInfo = YAML.load_file(sFilePath)

  # キーの整形対象のハッシュに@@@を付与する
  aPreObjList = nil
  hTesryInfo.each{|sTestID, hCondition|
    if (hCondition.is_a?(Hash))
      hCondition.each{|sCondition, hInfo|
        case sCondition
        when "pre_condition"
          if (hInfo.is_a?(Hash))
            # pre_condition直下のオブジェクト名を保持
            aPreObjList = hInfo.keys()
            # pre_condition直下は常に整形対象
            hInfo.each{|sInfo, hParam|
              set_delimiter(hParam)
            }
          else
            abort("not found \"#{sCondition}\"'s Key: #{sFilePath}")
          end
        when /^do.*$/
          if (hInfo.is_a?(Hash))
            # 時刻指定がない場合
            if ((hInfo.keys() - DO_KEY_LIST).empty?)
              set_delimiter(hInfo)
            # 時刻指定がある場合
            else
              hInfo.each{|sInfo, hParam|
                if (hParam.is_a?(Hash))
                  set_delimiter(hParam)
                end
              }
            end
          end
        when /^post_condition.*$/
          if (hInfo.is_a?(Hash))
            hInfo.each{|sInfo, hParam|
              if (hParam.is_a?(Hash))
                # 時刻指定がない場合
                if (aPreObjList.include?(sInfo))
                  set_delimiter(hParam)
                # 時刻指定がある場合
                else 
                  hParam.each{|sParam, hData|
                    if (hData.is_a?(Hash))
                      set_delimiter(hData)
                    end
                  }
                end
              end
            }
          end
        end
      }
    end
  }

  # @@@が付与されたハッシュデータを文字列へ変換し，1行ずつの配列へ変換
  aData = hTesryInfo.to_yaml().split("\n")

  # 頭の"---"を削除
  aData.shift()

  nPreSpaceNum = 0 # 前回の行の行頭空白数
  nPreHyphenSpaceNum = 0 # 前回の"-"での行頭空白数
  bIndentFlg = false # 行頭に空白を挿入するかを判定
  aNewArray = [] # 新しい配列
  lCond = nil # Conditionを判定
  aPreCondKey = []
  bDoTimeNotSetFlg = false # doの時刻設定の有無
  bPostTimeNotSetFlg = false  # post_conditionの時刻設定の有無

  # 1行ずつ処理する
  aData.each{|sLine|
    # nilが空白へ変換されるため，行末の空白を削除
    if (sLine =~ /\s$/)
      sLine.sub!(/\s$/, "")
    end
    # noteを含む行のダブルコーテーションを削除
    if(sLine =~ /^\s\snote/)
      sLine.gsub!("\"", "")
    end
    # "###"を半角スペースへ置換
    sLine.gsub!("###", " ")
    # シングルコーテーションをダブルコーテーションへ置換
    sLine.gsub!("'", "\"")

    # 行頭のスペースの数をカウント
    nTopSpaceNum = sLine.sub(/^(\s*).+$/, "\\1").size()

    # @@@x@@@の数字だけ":"の前に空白を挿入していく

    # "-"が含まれない場合
    if (sLine =~ /^\s+\"@@@[0-9]+@@@\w+\":/)
      nNum = sLine.sub(/^\s+\"@@@([0-9]+)@@@\w+\":.*$/, "\\1")
      sKey = sLine.sub(/^\s+\"@@@[0-9]+@@@(\w+)\":.*$/, "\\1")
      nPadding = nNum.to_i() - sKey.size()

      # 必要な数だけスペースを挿入
      sLine.gsub!(/^(\s+)(\"@@@[0-9]+@@@\w+\")(:.*)$/, "\\1#{sKey}#{' ' * nPadding}\\3")

      # 行頭に空白を挿入するか判定
      if (nPreHyphenSpaceNum < nTopSpaceNum)
        if (bIndentFlg == true)
          sLine = "  " + sLine # 行頭に空白を挿入
        end
      else
        bIndentFlg = false
      end

    # "-"が含まれる場合(hash)
    elsif (sLine =~ /^\s+\-\s\"@@@[0-9]+@@@\w+\":/)
      nNum = sLine.sub(/^\s+\-\s\"@@@([0-9]+)@@@\w+\":.*$/, "\\1")
      sKey = sLine.sub(/^\s+\-\s\"@@@[0-9]+@@@(\w+)\":.*$/, "\\1")
      nPadding = nNum.to_i() - sKey.size()

      # 必要な数だけスペースを挿入
      sLine.gsub!(/^(\s+)(\-\s\"@@@[0-9]+@@@\w+\")(:.*)$/, "\\1\-\s#{sKey}#{' ' * nPadding}\\3")

      # "-"が含まれる場合は，行頭にスペース2つ挿入
      sLine = "  " + sLine

      # "-"が含まれた行が登場した状態を保持
      bIndentFlg = true
      nPreHyphenSpaceNum = nTopSpaceNum

    # "-"が含まれる場合(array)
    elsif (sLine =~ /^\s+\-\s\w+/)
      # "-"が含まれるハッシュでない行の場合は，行頭にスペース2つ挿入
      sLine = "  " + sLine
    end

    # pre_condition/do/post_conditionの改行判定(インデントが前回と同じで，改行を挿入する場合)
    if (nTopSpaceNum == nPreSpaceNum)
      if ((sLine.include?("pre_condition")) || (sLine =~ /^\s+do\:$/) || (sLine =~ /^\s+do_[0-9]+\:$/) || (sLine.include?("post_condition")))
        # 改行を挿入
        aNewArray.push("")
      end
    end

    # 時刻指定判定のためpre_condition/do/post_conditionのどれかを保持
    if (sLine.include?("pre_condition"))
      lCond = :PRE
      aPreCondKey = []
    elsif ((sLine =~ /^\s+do\:$/) || (sLine =~ /^\s+do_[0-9]+\:$/))
      lCond = :DO
      bDoTimeNotSetFlg = false
    elsif (sLine.include?("post_condition"))
      lCond = :POST
      bPostTimeNotSetFlg = false
    end

    # 時刻指定があるかを判定
    if (lCond == :PRE)
      if (nTopSpaceNum == 4)
        aPreCondKey.push(sLine)
      end
    elsif (lCond == :DO)
      if (nTopSpaceNum == 4)
        DO_KEY_LIST.each{|sTargetData|
          if (sLine.include?(sTargetData))
            bDoTimeNotSetFlg = true
            break
          end
        }
      end
    elsif (lCond == :POST)
      if (nTopSpaceNum == 4)
        if (aPreCondKey.include?(sLine))
          bPostTimeNotSetFlg = true
        end
      end
    end

    # 改行を挿入
    if (nTopSpaceNum < nPreSpaceNum)
      if (lCond == :PRE)
        if (nTopSpaceNum <= 4)
          aNewArray.push("")
        end
      elsif (lCond == :DO)
        if (bDoTimeNotSetFlg == true)
          if (nTopSpaceNum <= 2)
            aNewArray.push("")
          end
        else
          if (nTopSpaceNum <= 4)
            aNewArray.push("")
          end
        end
      elsif (lCond == :POST)
        if (bPostTimeNotSetFlg == true)
          if (nTopSpaceNum <= 4)
            aNewArray.push("")
          end
        else
          if (nTopSpaceNum <= 6)
            aNewArray.push("")
          end
        end
      end
    end
    nPreSpaceNum = nTopSpaceNum
    aNewArray.push(sLine)
  }

  # 整形後の文字列を作成
  sAfter = aNewArray.join("\n")

  # 修正前のファイルと比較
  sBefore = File.read(sFilePath)
  if (sBefore != (sAfter + "\n"))
    # ハッシュデータとして差異が無いか確認(検証)
    if (__FILE__ == $0)
      sBeforeData = YAML.load(sBefore).to_yaml()
      sAfterData = YAML.load(sAfter).to_yaml()
      if (sBeforeData != sAfterData)
        puts(sBefore)
        puts("-" * 30)
        puts(sAfter)
        abort("Format failed: #{sFilePath}")
      end
    end

    # 差分があればファイルを上書き
    File.open(sFilePath, "wb"){|cIO|
      cIO.puts(sAfter)
    }
    puts("#{sFilePath} formatted.")
  end
end

if (__FILE__ == $0)
  if (ARGV.size() == 0)
    abort("Argument error !")
  end
  # 引数に応じて処理する
  ARGV.each{|sPath|
    if (FileTest.file?(sPath))
      if (sPath.include?(".yaml"))
        format_tesry(sPath)
      else
        abort("not yaml file: #{sPath}")
      end
    elsif (FileTest.directory?(sPath))
      Dir.glob("#{sPath}/**/*.yaml").each{|sFilePath|
        format_tesry(sFilePath)
      }
    else
      abort("not found: #{sPath}")
    end
  }
end
