#!ruby -Ku
#
# $Id: error_checker.rb 28 2019-02-12 01:50:02Z fujisft-shigihara $
#

if ($0 == __FILE__)
  TOOL_ROOT = File.expand_path(File.dirname(__FILE__) + "/../../../")
  $LOAD_PATH.unshift(TOOL_ROOT)
end

require "ttc/test/err_check/test_data.rb"
require "ttc/bin/kwalify.rb"
require "optparse"

module ErrorCheckModule
  class ErrorCheck
    #=================================================================
    # 概  要: コンストラクタ
    #=================================================================
    def initialize(aArgs)
      check_class(Array, aArgs)  # 全オプション

      # エラーチェッカの位置
      @sTECPath      = File.dirname(__FILE__)
      @aMakeFileList = []  # エラーファイルおよびシェルファイルの生成時その情報を持つ変数

      # プロファイル設定
      @bASP     = false
      @bFMP     = false
      @bProfile = nil

      # T0: environmentエラーチェックのオプション
      @bEnvironment = false
      @bT0_001      = false
      @bT0_002      = false
      @bT0_003      = false
      @bT0_004      = false
      @bT0_005      = false
      @bT0_006      = false
      @bT0_007      = false
      @bT0_008      = false
      @bT0_009      = false
      @bT0_010      = false

      # T1: basicエラーチェックのオプション
      @bBasic = false

      # T2: attributeエラーチェックのオプション
      @bAttribute = false
      @bT2_001    = false
      @bT2_002    = false
      @bT2_003    = false

      # T3: objectエラーチェックのオプション
      @bObject = false

      # T4: conditionエラーチェックのオプション
      @bCondition = false

      # T5: scenarioエラーチェックのオプション
      @bScenario = false

      # T6: variationエラーチェックのオプション
      @bVariation = false

      # T7: multipleエラーチェックのオプション
      @bMultiple = false

      # 生成，実行，シェル，ディレクトリのオプション
      @bCreate  = false
      @bShell   = false
      @bRemove  = false

      # configureの情報取得
      @hConfigure = Kwalify::Yaml.load_file(ANY_CONFIGURE)
      @hConf      = @hConfigure.dup()         # configureのマクロ以外の部分
      @hMacro     = @hConf.delete(CFG_MACRO)  # configureのマクロ部分

      # 生成ファイル名と実行ファイル名を保持する変数と実行パス
      @sFileName = ""

      # ASPモードの場合，FMPファイルを除外するための変数
      @aFMPAttr = []

      # オプション設定
      parse_option(aArgs)
    end

    #=================================================================
    # 概  要: オプションによる前処理
    #=================================================================
    def parse_option(aArgs)
      check_class(Array, aArgs)  # 全オプション

      cOpt = OptionParser.new()
      cOpt.program_name = "TTC Error Checker"

      # 実施するテストの設定
      cOpt.on("-A", "--all", "All item") {
        @bEnvironment = true  # T0: environment
          @bT0_001    = true
          @bT0_002    = true
          @bT0_003    = true
          @bT0_004    = true
          @bT0_005    = true
          @bT0_006    = true
          @bT0_007    = true
          @bT0_008    = true
          @bT0_009    = true
          @bT0_010    = true
        @bBasic       = true  # T1: basic
        @bAttribute   = true  # T2: attribute
          @bT2_001    = true
          @bT2_002    = true
          @bT2_003    = true
        @bObject      = true  # T3: object
        @bCondition   = true  # T4: condition
        @bScenario    = true  # T5: scenario
        @bVariation   = true  # T6: variation
        @bMultiple    = true  # T7: multiple
      }

      cOpt.on("")

      cOpt.on("-t number", "--test number", "Test item number [0-7]") {|tVal|
        if (tVal == "0")
          @bEnvironment = true
        end
        if (tVal == "1")
          @bBasic = true
        end
        if (tVal == "2")
          @bAttribute = true
        end
        if (tVal == "3")
          @bObject = true
        end
        if (tVal == "4")
          @bCondition = true
        end
        if (tVal == "5")
          @bScenario = true
        end
        if (tVal == "6")
          @bVariation = true
        end
        if (tVal == "7")
          @bMultiple = true
        end
      }
      cOpt.on("-l number", "--label number", "Item label number [1-10]") {|lVal|
        if (lVal == "1")
          @bT0_001 = true
          @bT2_001 = true
        end
        if (lVal == "2")
          @bT0_002 = true
          @bT2_002 = true
        end
        if (lVal == "3")
          @bT0_003 = true
          @bT2_003 = true
        end
        if (lVal == "4")
          @bT0_004 = true
        end
        if (lVal == "5")
          @bT0_005 = true
        end
        if (lVal == "6")
          @bT0_006 = true
        end
        if (lVal == "7")
          @bT0_007 = true
        end
        if (lVal == "8")
          @bT0_008 = true
        end
        if (lVal == "9")
          @bT0_009 = true
        end
        if (lVal == "10")
          @bT0_010 = true
        end
      }

      cOpt.on("")

      # プロファイル設定
      cOpt.on("-a", "--asp", "asp mode") {  # asp
        @bASP     = true
        @bProfile = "-a"

        # ASPモードの場合，FMPファイルを除外するための変数を整える
        ATT_FMP_DEFINED_TO_OBJECT.each{|sObject, aFMPAttr|
          aFMPAttr.each{|sFMPAttr|
            @aFMPAttr.push(sFMPAttr)
          }
        }

        @aFMPAttr = @aFMPAttr.uniq()
      }
      cOpt.on("-f", "--fmp", "fmp mode") {  # fmp
        @bFMP     = true
        @bProfile = "-f"
      }

      cOpt.on("")

      # 生成，実行，削除設定
      cOpt.on("-c", "--create", "Create error-file") {     # エラーファイル生成
        @bCreate = true
      }
      cOpt.on("-s", "--shell", "Make shell") {             # シェルファイル生成
        @bShell = true
      }
      cOpt.on("-r", "--remove", "All remove") {  # 生成したファイルおよびディレクトリの削除
        @bRemove = true
      }

      cOpt.on("")

      # Help
      cOpt.on("-h", "--help", "Help") {
        puts cOpt.help()
        exit(1)
      }
      # オプション処理
      begin
        aConfPath = cOpt.parse(aArgs)
      rescue OptionParser::ParseError
        puts cOpt.help()
        exit(1)
      end

      # @bEnvironmentだけ定義された場合はT0の全ラベルをtrueにする
      if ((@bEnvironment == true) && (@bT0_001 == false) && (@bT0_002 == false) && (@bT0_003 == false) &&
          (@bT0_004 == false) && (@bT0_005 == false) && (@bT0_006 == false) &&
          (@bT0_007 == false) && (@bT0_008 == false) && (@bT0_009 == false) && (@bT0_010 == false))
        @bT0_001 = true
        @bT0_002 = true
        @bT0_003 = true
        @bT0_004 = true
        @bT0_005 = true
        @bT0_006 = true
        @bT0_007 = true
        @bT0_008 = true
        @bT0_009 = true
        @bT0_010 = true
      end

      # @bAttributeだけ定義された場合はT2の全ラベルをtrueにする
      if ((@bAttribute == true) && (@bT2_001 == false) && (@bT2_002 == false) && (@bT2_003 == false))
        @bT2_001 = true
        @bT2_002 = true
        @bT2_003 = true
      end

      # プロファイルオプションのチェック
      if ((((@bASP == true) && (@bFMP == true)) || ((@bASP == false) && (@bFMP == false))) && (@bRemove == false))
        puts cOpt.help()
        exit(1)
      end

      # T0，T1，T2，T3，T4，T5，T6，T7オプションのチェック
      if (((@bT0_001 == false) && (@bT0_002 == false) && (@bT0_003 == false) && (@bT0_004 == false) &&
           (@bT0_005 == false) && (@bT0_006 == false) && (@bT0_007 == false) && (@bT0_008 == false) &&
           (@bT0_009 == false) && (@bT0_010 == false) && (@bT2_001 == false) && (@bT2_002 == false) && (@bT2_003 == false) &&
           (@bBasic == false) && (@bObject == false) && (@bCondition == false) && (@bScenario == false) &&
           (@bVariation == false) && (@bMultiple == false)) && (@bRemove == false))
        puts cOpt.help()
        exit(1)
      end

      # ファイル生成オプションのチェック
      if ((@bCreate == false) && (@bShell == false) && (@bRemove == false))
        puts cOpt.help()
        exit(1)
      end
   end

    #=================================================================
    # 概  要: エラーファイル生成，シェルファイル生成
    #=================================================================
    def proceed_TTC_check()
      # Delete
      if (@bRemove == true)
        remove()
        return
      end

      # configureファイルの属性が一致しているかチェック
      check_configure()

      # T0: environment
      if (@bEnvironment == true)
        # Write
        if (@bCreate == true)
          if (@bT0_001 == true)
            create_file(FDR_T0_001)
          end
          if (@bT0_002 == true)
            create_file(FDR_T0_002)
          end
          if (@bT0_003 == true)
            create_file(FDR_T0_003)
          end
          if (@bT0_004 == true)
            create_file(FDR_T0_004)
          end
          if (@bT0_005 == true)
            create_file(FDR_T0_005)
          end
          if (@bT0_006 == true)
            create_file(FDR_T0_006)
          end
          if (@bT0_007 == true)
            create_file(FDR_T0_007)
          end
          if (@bT0_008 == true)
            create_file(FDR_T0_008)
          end
          if (@bT0_009 == true)
            create_file(FDR_T0_009)
          end
          if (@bT0_010 == true)
            create_file(FDR_T0_010)
          end
        end

        # Shell
        if (@bShell == true)
          if (@bT0_001 == true)
            create_shell(FDR_T0_001)
          end
          if (@bT0_002 == true)
            create_shell(FDR_T0_002)
          end
          if (@bT0_003 == true)
            create_shell(FDR_T0_003)
          end
          if (@bT0_004 == true)
            create_shell(FDR_T0_004)
          end
          if (@bT0_005 == true)
            create_shell(FDR_T0_005)
          end
          if (@bT0_006 == true)
            create_shell(FDR_T0_006)
          end
          if (@bT0_007 == true)
            create_shell(FDR_T0_007)
          end
          if (@bT0_008 == true)
            create_shell(FDR_T0_008)
          end
          if (@bT0_009 == true)
            create_shell(FDR_T0_009)
          end
          if (@bT0_010 == true)
            create_shell(FDR_T0_010)
          end
        end
      end

      # T1: basic check
      if (@bBasic == true)
        # Shell
        if (@bShell == true)
          create_shell(FDR_T1)
        end
      end

      # T2: attribute
      if (@bAttribute == true)
        # Write
        if (@bCreate == true)
          if (@bT2_001 == true)
            create_file(FDR_T2_001)
          end
          if (@bT2_002 == true)
            create_file(FDR_T2_002)
          end
        end

        # Shell
        if (@bShell == true)
          if (@bT2_001 == true)
            create_shell(FDR_T2_001)
          end
          if (@bT2_002 == true)
            create_shell(FDR_T2_002)
          end
          if (@bT2_003 == true)
            create_shell(FDR_T2_003)
          end
        end
      end

      # T3: object
      if (@bObject == true)
        # Shell
        if (@bShell == true)
          create_shell(FDR_T3)
        end
      end

      # T4: condition
      if (@bCondition == true)
        # Shell
        if (@bShell == true)
          create_shell(FDR_T4)
        end
      end

      # T5: scenario
      if (@bScenario == true)
        # Shell
        if (@bShell == true)
          create_shell(FDR_T5)
        end
      end

      # T6: variation
      if (@bVariation == true)
        # Shell
        if (@bShell == true)
          create_shell(FDR_T6)
        end
      end

      # T7: multiple
      if (@bMultiple == true)
        # Shell
        if (@bShell == true)
          create_shell(FDR_T7)
        end
      end

      # 生成したファイルのリストをファイルに書込む
      if ((@bCreate == true) || (@bShell == true))
        make_file_list()
      end
    end

    #=================================================================
    # 概  要: 生成したファイルのリストをファイルとして保持する
    #=================================================================
    def make_file_list()
      aBeforeFile = []

      sBeforeDir = File.expand_path("")  # 現在の位置を保持する
      Dir.chdir(@sTECPath)

      # 既存のファイルのリストから情報を取得
      if (File.file?(MAKE_FILE_LIST) == true)
        sFileInfo = File.open(MAKE_FILE_LIST, "r").read()

        sFileInfo.each_line{|sLineInfo|
          aBeforeFile.push(sLineInfo.gsub("\n", ""))
        }
      end

      # ファイルリストを作成および更新する
      File.open(MAKE_FILE_LIST, "w"){|cIO|
        @aMakeFileList.concat(aBeforeFile)
        @aMakeFileList = @aMakeFileList.uniq.sort()

        @aMakeFileList.each{|sMakeFileList|
          cIO.puts(sMakeFileList)
        }
      }

      Dir.chdir(sBeforeDir)  # 元の位置に戻る
    end

    #=================================================================
    # 概  要: configureとマクロの属性が一致しているかをチェック
    #=================================================================
    def check_configure()
      sNotList   = ""
      aConfList  = []
      bTitleFlag = true

      # configureファイルの属性リスト
      @hConf.each_key{|key|
        aConfList.push(key)
      }
      @hMacro.each_key{|key|
        aConfList.push(key)
      }

      if (@bEnvironment == true)
        # configureファイルの属性がツールのマクロに指定されているかをチェック
        aConfList.each{|key|
          if (CHK_CONFIGURE_TYPE.include?(key) == false)
            if (bTitleFlag == true)
              sNotList += "[File] #{File.expand_path(@sTECPath)}/test_data.rb\n"
              bTitleFlag = false
            end

            sNotList += "  [#{key}] Need to add attributes\n"
          end
        }

        bTitleFlag = true

        # 指定したツールのマクロがconfigureファイルにあるかをチェック
        CHK_CONFIGURE_TYPE.each_key{|key|
          if (aConfList.include?(key) == false)
            if (bTitleFlag == true)
              sNotList += "[File] #{File.expand_path(@sTECPath)}/test_data.rb\n"
              bTitleFlag = false
            end

            sNotList += "  [#{key}] Need to remove attributes\n"
          end
        }
      end

      # ツール内のconfigureのチェック
      aConfFile = []

      FDR_CONFIGURE_FILE.each{|sConForder|
        if (((@bScenario == true) && (sConForder == FDR_T5)) ||
            ((@bVariation == true) && (sConForder == FDR_T6)) ||
            ((@bMultiple == true) && (sConForder == FDR_T7)))
          sBeforeDir = File.expand_path("")  # 現在の位置を保持する

          Dir.chdir(@sTECPath)
          aFileList = catch_file_list(sConForder)
          Dir.chdir(sBeforeDir)  # 元の位置に戻る

          aFileList.each{|sFileList|
            if (sFileList.include?(CONFIGURE_FILE) == true)
              aConfFile.push(sFileList)
            end
          }

          aConfFile.each{|sConfList|
            hConfInfo = Kwalify::Yaml.load_file(sConfList)
            hConfList = hConfInfo.delete(CFG_MACRO)
            hConfList = hConfList.merge(hConfInfo)

            bTitleFlag = true

            aConfList.each{|key|
              if (hConfList.include?(key) == false)
                if (bTitleFlag == true)
                  sNotList += "[File] #{sConfList}\n"
                  bTitleFlag = false
                end

                sNotList += "  [#{key}] Need to add attributes\n"
              end
            }
          }

          aConfFile.each{|sConfList|
            hConfInfo = Kwalify::Yaml.load_file(sConfList)
            hConfList = hConfInfo.delete(CFG_MACRO)
            hConfList = hConfList.merge(hConfInfo)

            bTitleFlag = true

            hConfList.each_key{|key|
              if (aConfList.include?(key) == false)
                if (bTitleFlag == true)
                  sNotList += "[File] #{sConfList}\n"
                  bTitleFlag = false
                end

                sNotList += "  [#{key}] Need to remove attributes\n"
              end
            }
          }
      end
      }

      # ツールのマクロとconfigureファイルの内容が異なる場合，ファイルに出力する
      if (sNotList != "")
        if (File.file?(DO_NOT_ATTRIBUTE) == true)
          sNotInfo = File.open(DO_NOT_ATTRIBUTE, "r").read()

          if (sNotInfo.include?(sNotList) == true)
            sNotList = sNotInfo
          else
            sNotList = sNotInfo + sNotList
          end
        end

        File.open(DO_NOT_ATTRIBUTE, "w"){|cIO|
          sNotList.each_line{|sNotLine|
            cIO.puts(sNotLine)
          }
        }
      end
    end

    #=================================================================
    # 概  要: FMP関連のTESRYコードを取得する
    #=================================================================
    def search_FMP_file(aFileList)
      check_class(Array, aFileList)  # ファイルリスト

      aFMPFile = []

      aFileList.each{|sFileList|
        sFileInfo = File.open(sFileList, "r").read()

        catch(:FMPfile) {
          sFileInfo.each_line(){|sFileLine|
            next if (sFileLine.include?(TSR_LBL_VERSION) == true)

            @aFMPAttr.each{|sFMPAttr|
              if (sFileLine.include?(sFMPAttr) == true)
                aFMPFile.push(sFileList)
                throw(:FMPfile)
              end
            }
          }
        }
      }

      return aFMPFile  # [Array] FMP関連のTESRYコードの一覧
    end

    #=================================================================
    # 概  要: エラーファイルを生成する
    #         ※ YAMLライブラリからYAMLファイルを作成するとarrayの
    #            インデントがずれる現象が起こるため，直接にYAMLファイル
    #            を作成するメソッド
    #=================================================================
    def prepare_file(ahErrorInfo)
      check_class([Hash, Array], ahErrorInfo)  # エラーデータ情報を持っているハッシュ

      cIO = File.open(@sFileName, "w")
      cIO.puts("# #{@sFileName.split("/")[-1]}")

      if (ahErrorInfo.is_a?(Hash) == true)
        ahErrorInfo.each{|sSection, xSectionInfo|
          next if (sSection == TSR_LBL_VERSION)

          if (xSectionInfo.is_a?(Hash) == true)
            cIO.puts("#{sSection}:")
            process_file_creation(cIO, xSectionInfo)
          elsif (xSectionInfo.is_a?(Array) == true)
            cIO.puts("#{sSection}:")
            process_file_creation(cIO, xSectionInfo)
          else
            cIO.puts("#{sSection}: #{xSectionInfo}")
          end
        }
      elsif (ahErrorInfo.is_a?(Array) == true)
        ahErrorInfo.each{|xError|
          if (xError.is_a?(Hash) == true)
            bFlag = false

            xError.each{|sSection, xSectionInfo|
              if (bFlag == false)
                sArraySym = "- "
                bFlag = true
              else
                sArraySym = "  "
              end

              if (xSectionInfo.is_a?(Hash) == true)
                sIndent = "  "
                cIO.puts("#{sArraySym}#{sSection}:")
                process_file_creation(cIO, xSectionInfo, sIndent)
              elsif (xSectionInfo.is_a?(Array) == true)
                cIO.puts("#{sArraySym}#{sSection}:")
                process_file_creation(cIO, xSectionInfo)
              else
                cIO.puts("#{sArraySym}#{sSection}: #{xSectionInfo}")
              end
            }
          else
            cIO.puts("- #{xError}")
          end
        }
      end

      puts("  #{@sFileName}")
    end

    #=================================================================
    # 概  要: エラーファイルの情報をファイルに記入する．
    #         ※ YAMLライブラリからYAMLファイルを作成するとarrayの
    #            インデントがずれる現象が起こるため，直接にYAMLファイル
    #            を作成するメソッド
    #=================================================================
    def process_file_creation(cIO, ahYaml, sIndent = "", bArrayFlag = false)
      check_class(IO, cIO)           # ファイル入出力IO
      check_class(String, sIndent)   # YAMLインデント
      check_class(Bool, bArrayFlag)  # Arrayを区別するためのフラグ
      check_class([Hash, Array, String], ahYaml)  # エラーデータ情報を持っているハッシュ

      sIndent += "  "

      if (ahYaml.is_a?(Hash) == true)
        ahYaml.each{|sYamlId, ahYamlInfo|
          if (ahYamlInfo.is_a?(Hash) == true)
            if (bArrayFlag == true)
              cIO.puts("#{" " * (sIndent.size() - 2)}- #{sYamlId}:")
              bArrayFlag = false
            else
              cIO.puts("#{sIndent}#{sYamlId}:")
            end

            process_file_creation(cIO, ahYamlInfo, sIndent)
          elsif (ahYamlInfo.is_a?(Array) == true)
            if (bArrayFlag == true)
              cIO.puts("#{" " * (sIndent.size() - 2)}- #{sYamlId}:")
              bArrayFlag = false
            else
              cIO.puts("#{sIndent}#{sYamlId}:")
            end

            process_file_creation(cIO, ahYamlInfo, sIndent, true)
          else
            if (bArrayFlag == true)
              cIO.puts("#{" " * (sIndent.size() - 2)}- #{sYamlId}: #{ahYamlInfo}")
              bArrayFlag = false
            else
              cIO.puts("#{sIndent}#{sYamlId}: #{ahYamlInfo}")
            end
          end
        }
      elsif (ahYaml.is_a?(Array) == true)
        ahYaml.each{|ahYamlInfo|
          process_file_creation(cIO, ahYamlInfo, sIndent, true)
        }
      elsif (ahYaml.is_a?(String) == true)
        if (bArrayFlag == true)
          cIO.puts("#{" " * (sIndent.size() - 2)}- #{ahYaml}")
        end
      end
    end

    #=================================================================
    # 概  要: 項目ごとにエラーファイルを生成する
    #=================================================================
    def create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      puts("[#{sDirectory}] Error-file Creating..")
      sBeforeDir = File.expand_path("")  # 現在の位置を保持する
      Dir.chdir(@sTECPath)

      case sDirectory
      when FDR_T0_001
        prepare_directory(FDR_T0_001)
        T0_001_create_file(FDR_T0_001)

      when FDR_T0_002
        prepare_directory(FDR_T0_002)
        T0_002_create_file(FDR_T0_002)

      when FDR_T0_003
        prepare_directory(FDR_T0_003)
        T0_003_create_file(FDR_T0_003)

      when FDR_T0_004
        prepare_directory(FDR_T0_004)
        T0_004_create_file(FDR_T0_004)

      when FDR_T0_005
        prepare_directory(FDR_T0_005)
        T0_005_create_file(FDR_T0_005)

      when FDR_T0_006
        prepare_directory(FDR_T0_006)
        T0_006_create_file(FDR_T0_006)

      when FDR_T0_007
        prepare_directory(FDR_T0_007)
        T0_007_create_file(FDR_T0_007)

      when FDR_T0_008
        prepare_directory(FDR_T0_008)
        T0_008_create_file(FDR_T0_008)

      when FDR_T0_009
        prepare_directory(FDR_T0_009)
        T0_009_create_file(FDR_T0_009)

      when FDR_T0_010
        prepare_directory(FDR_T0_010)
        T0_010_create_file(FDR_T0_010)

      when FDR_T2_001
        T2_001_create_file(FDR_T2_001)

      when FDR_T2_002
        T2_002_create_file(FDR_T2_002)

      end

      Dir.chdir(sBeforeDir)  # 元の位置に戻る
    end

    #=================================================================
    # 概  要: シェルファイル生成の前に生成に必要な情報を整える
    #=================================================================
    def create_shell(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      return if (File.directory?(File.expand_path("#{@sTECPath}/#{sDirectory}")) == false)

      puts("[#{sDirectory}] Shell Creating..")

      aFileList  = []
      sBeforeDir = File.expand_path("")  # 現在の位置を保持する

      Dir.chdir(@sTECPath)
      aFileList = catch_file_list(sDirectory)
      Dir.chdir(sBeforeDir)  # 元の位置に戻る

      case sDirectory
      when FDR_T0_001, FDR_T0_002, FDR_T0_003, FDR_T0_004, FDR_T0_005, FDR_T0_006, FDR_T0_007, FDR_T0_008, FDR_T0_009, FDR_T0_010
        T0_create_shell(sDirectory, aFileList)

      when FDR_T1
        T1_create_shell(sDirectory, aFileList)

      when FDR_T2_001, FDR_T2_002, FDR_T2_003
        T2_create_shell(sDirectory, aFileList)

      when FDR_T3
        T3_create_shell(sDirectory, aFileList)

      when FDR_T4
        T4_create_shell(sDirectory, aFileList)

      when FDR_T5
        T5_create_shell(sDirectory, aFileList)

      when FDR_T6
        T6_create_shell(sDirectory, aFileList)

      when FDR_T7
        T7_create_shell(sDirectory, aFileList)

      end

      puts("  #{File.expand_path("")}/#{sDirectory.split("/")[-1]}.sh")
    end

    #=================================================================
    # 概  要: ファイルリストを作成する
    #=================================================================
    def catch_file_list(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      sBeforeDir = File.expand_path("")  # 現在の位置を保持する
      Dir.chdir(sDirectory)

      aDirList  = []
      aFileList = []

      # ファイルとディレクトリを取得する
      Dir.entries(File.expand_path("")).each{|sInfo|
        next if (sInfo == ".")
        next if (sInfo == "..")
        next if (sInfo == ".svn")

        if (File.ftype(sInfo) == "directory")
          aDirList.push(sInfo)
        elsif ((File.ftype(sInfo) == "file") && (sInfo.include?(".yaml") == true))
          aFileList.push("#{File.expand_path("")}/#{sInfo}")
        end
      }

      # 下位のディレクトリがある場合はその下位のディレクトリも取得する
      aDirList.each{|sDirList|
        aFileList.concat(catch_file_list(sDirList))
      }

      # ファイルをまとめる
      aFileList = aFileList.uniq.sort()
      Dir.chdir(sBeforeDir)  # 元の位置に戻る

      return aFileList  # [Array] ファイルのリスト
    end

    #=================================================================
    # 概  要: ディレクトリを生成する
    #=================================================================
    def prepare_directory(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      sDirTemp = ""

      sDirectory.split("/").each{|sDir|
        sDirTemp += "#{sDir}/"

        if (File.directory?(sDirTemp) == false)
          Dir.mkdir(sDirTemp)
        end
      }
    end

    #=================================================================
    # 概  要: 生成したディレクトリを削除する
    #=================================================================
    def remove_directory(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      if (File.directory?(File.expand_path(sDirectory)) == false)
        return
      end

      aDirList  = []

      # ディレクトリを取得する
      Dir.entries(File.expand_path(sDirectory)).each{|sInfo|
        next if (sInfo == ".")
        next if (sInfo == "..")
        next if (sInfo == ".svn")

        if (File.ftype("#{sDirectory}/#{sInfo}") == "directory")
          aDirList.push(sInfo)
        end
      }

      # 下位のディレクトリがある場合はその下位のディレクトリも取得する
      aDirList.each{|sDirList|
        Dir.chdir(sDirectory)
        remove_directory(sDirList)
        Dir.chdir("../")
      }

      # すべてのディレクトリを削除する
      begin
        Dir.rmdir(sDirectory)
      rescue Errno::ENOTEMPTY, Errno::EBUSY
        # ファイルが残っている場合はエラーしない
      end
    end

    #=================================================================
    # 概  要: エラーファイル，シェルファイル，ディレクトリを削除する
    #=================================================================
    def remove()
      puts("TTC Error-checker Removing..")

      sBeforeDir = File.expand_path("")  # 現在の位置を保持する
      Dir.chdir(@sTECPath)

      # 生成したファイルリストから情報を取得する
      if (File.file?(MAKE_FILE_LIST) == true)
        sFileInfo = File.open(MAKE_FILE_LIST, "r").read()

        # ファイル削除
        sFileInfo.each_line{|sLineInfo|
          sLineInfo = sLineInfo.gsub("\n", "")
          puts("  #{sLineInfo}")

          begin
            File.delete(sLineInfo)
          rescue Errno::ENOENT
            # ファイルがない場合エラーにしない
          end
        }
      end

      # ディレクトリ削除
      DEL_FOLDER_LIST.each{|sDirectory|
        remove_directory(sDirectory)
      }

      # make_file_listファイル削除
      begin
        File.delete(MAKE_FILE_LIST)
      rescue Errno::ENOENT
        # ファイル削除時，ファイルがない場合エラーにしない
      end

      # do_not_attributeファイル削除
      begin
        File.delete(DO_NOT_ATTRIBUTE)
      rescue Errno::ENOENT
        # ファイル削除時，ファイルがない場合エラーにしない
      end

      Dir.chdir(sBeforeDir)  # 元の位置に戻る
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T0_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array, aFileList)    # ファイルリスト

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory.split("/")[-1]}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          cIO.puts("echo [File] #{sFileList}")
          cIO.puts("#{TTG_PATH} #{@bProfile} #{ANY_T0_TESRY} -c #{sFileList}")
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory.split("/")[-1]}.sh")
    end

    #=================================================================
    # 概  要: T0のエラーファイルの内容を生成する
    #=================================================================
    def T0_convert_data(sDirectory, sKey, xType)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(String, sKey)        # 置換用マクロのキー
      check_class([Class, Integer, Float, String, Hash], xType)  # 置換用マクロの値

      hConfigureInfo = {}

      if (xType.is_a?(Hash) == true)
        xType.each{|typeKey, typeVal|
          hConfigureInfo.store(typeKey, typeVal)
        }

        CVT_DEPEND_NAME.each{|dependKey, dependVal|
          if (xType == dependVal)
            @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{sKey}-depend_#{dependKey}.yaml"
            @aMakeFileList.push(@sFileName)
          end
        }
      else
        hConfigureInfo = {sKey => CVT_CONFIGURE_VALUE[xType]}
        @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{sKey}-#{CVT_CONFIGURE_NAME[xType]}.yaml"
        @aMakeFileList.push(@sFileName)
      end

      return hConfigureInfo  # [Hash]正しいデータをエラーデータに置換したハッシュ
    end

=begin
    #=================================================================
    # 概  要: T0_001のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_001_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      ERROR_ATTRIBUTE.each{|key, val|
        hConfInfo = {key => val}
        @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{key}.yaml"
        @aMakeFileList.push(@sFileName)
        hErrorInfo = @hConfigure.merge(hConfInfo)
        prepare_file(hErrorInfo)
      }
    end
=end

    #=================================================================
    # 概  要: T0_001のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_001_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      hDeleteInfo = {}

      GRP_CFG_NECESSARY_KEYS.each{|val|
        @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{val}-delete.yaml"
        @aMakeFileList.push(@sFileName)

        hDeleteInfo = Marshal.load(Marshal.dump(@hConfigure))
        hDeleteInfo.delete(val)
        prepare_file(hDeleteInfo)
      }
    end

    #=================================================================
    # 概  要: T0_002のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_002_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      @hConf.each{|key, val|
        next if (CHK_CONFIGURE_TYPE[key].nil? == true)

        CHK_CONFIGURE_TYPE[key].each{|type|
          hConfInfo  = T0_convert_data(sDirectory, key, type)
          hErrorInfo = @hConfigure.merge(hConfInfo)
          prepare_file(hErrorInfo)
        }
      }
    end

    #=================================================================
    # 概  要: T0_003のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_003_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      @hConf.each{|key, val|
        next if (CHK_CONFIGURE_VALUE[key].nil? == true)

        CHK_CONFIGURE_VALUE[key].each{|type|
          hConfInfo  = T0_convert_data(sDirectory, key, type)
          hErrorInfo = @hConfigure.merge(hConfInfo)
          prepare_file(hErrorInfo)
        }
      }
    end

    #=================================================================
    # 概  要: T0_004のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_004_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      @hMacro.each{|key, val|
        next if (CHK_CONFIGURE_TYPE[key].nil? == true)

        CHK_CONFIGURE_TYPE[key].each{|type|
          hMacroInfo = T0_convert_data(sDirectory, key, type)
          hMacroInfo = {"macro" => @hMacro.merge(hMacroInfo)}
          hErrorInfo = @hConfigure.merge(hMacroInfo)
          prepare_file(hErrorInfo)
        }
      }
    end

    #=================================================================
    # 概  要: T0_005のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_005_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      @hMacro.each{|key, val|
        next if (CHK_CONFIGURE_VALUE[key].nil? == true)

        CHK_CONFIGURE_VALUE[key].each{|type|
          hMacroInfo = T0_convert_data(sDirectory, key, type)
          hMacroInfo = {"macro" => @hMacro.merge(hMacroInfo)}
          hErrorInfo = @hConfigure.merge(hMacroInfo)
          prepare_file(hErrorInfo)
        }
      }
    end

    #=================================================================
    # 概  要: T0_006のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_006_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      hErrorInfo = {}
      @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-"

      NON_FUNC_TIME_NON_GAIN_TIME.each{|key, val|
        hErrorInfo.store(key, val)
        @sFileName += "#{key}_#{val}_"
      }

      @sFileName = @sFileName.gsub(/_\z/, ".yaml")
      @aMakeFileList.push(@sFileName)
      hErrorInfo = @hConfigure.merge(hErrorInfo)
      prepare_file(hErrorInfo)
    end

    #=================================================================
    # 概  要: T0_007のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_007_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      hDeleteInfo = {}
      GRP_CFG_NECESSARY_MACRO.each{|val|
        @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{val}-delete.yaml"
        @aMakeFileList.push(@sFileName)

        hDeleteInfo = Marshal.load(Marshal.dump(@hMacro))
        hDeleteInfo.delete(val)
        hDeleteInfo = {"macro" => hDeleteInfo}
        hDeleteInfo = @hConfigure.merge(hDeleteInfo)
        prepare_file(hDeleteInfo)
      }
    end

    #=================================================================
    # 概  要: T0_008のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_008_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      aArrayInfo = []
      @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{CONFIGURE_FILE}.yaml"
      @aMakeFileList.push(@sFileName)

      aArrayInfo.push(@hConfigure)
      prepare_file(aArrayInfo)
    end

    #=================================================================
    # 概  要: T0_009のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_009_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      aArrayInfo = []
      @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{CONFIGURE_FILE}.yaml"
      @aMakeFileList.push(@sFileName)

      aArrayInfo.push(@hMacro)
      hArrayInfo = {"macro" => aArrayInfo}
      hArrayInfo = @hConfigure.merge(hArrayInfo)
      prepare_file(hArrayInfo)
    end

    #=================================================================
    # 概  要: T0_010のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T0_010_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      @sFileName = "#{File.expand_path(sDirectory)}/#{sDirectory.split("/")[-1]}-#{CONFIGURE_FILE}.yaml"
      @aMakeFileList.push(@sFileName)
      
      hConfInfo = @hConf.merge(ERROR_CONFIGURE_ENTRY)
      hErrorInfo = @hConfigure.merge(hConfInfo)
      prepare_file(hErrorInfo)
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T1_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array, aFileList)    # ファイルリスト

      aFMPFile = []

      if (@bFMP == true)
        if (@aFMPAttr.empty?() == true)
          # ASPモードの場合，FMPファイルを除外するための変数を整える
          ATT_FMP_DEFINED_TO_OBJECT.each{|sObject, aFMPAttr|
            aFMPAttr.each{|sFMPAttr|
              @aFMPAttr.push(sFMPAttr)
            }
          }

          @aFMPAttr = @aFMPAttr.uniq()
          aFMPFile = search_FMP_file(aFileList)
          @aFMPAttr = []
        else
          aFMPFile = search_FMP_file(aFileList)
        end
      end

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          next if ((@bFMP == true) && (aFMPFile.include?(sFileList) == true))
          cIO.puts("echo [File] #{sFileList}")
          cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList}")
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory.split("/")[-1]}.sh")
    end

    #=================================================================
    # 概  要: T2のエラーファイルの内容を生成するために必要な情報を
    #         整える
    #=================================================================
    def T2_prepare_convert_data(sDirectory, sObjectType, sAttribute, aAttrInfo)
      check_class(String, sDirectory)   # 対象ディレクトリ
      check_class(String, sObjectType)  # オブジェクトタイプ
      check_class(String, sAttribute)   # 属性
      check_class(Array,  aAttrInfo)    # エラー情報

      case sObjectType
      when TSR_OBJ_TASK
        hTesryTask = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_TASK : ANY_T2_FMP_TESRY_TASK)
        T2_convert_object_data(hTesryTask, sAttribute, aAttrInfo, TSR_OBJ_TASK, sDirectory)

      when TSR_OBJ_ALARM
        hTesryAlarm = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_ALARM : ANY_T2_FMP_TESRY_ALARM)
        T2_convert_object_data(hTesryAlarm, sAttribute, aAttrInfo, TSR_OBJ_ALARM, sDirectory)

      when TSR_OBJ_CYCLE
        hTesryCycle = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_CYCLE : ANY_T2_FMP_TESRY_CYCLE)
        T2_convert_object_data(hTesryCycle, sAttribute, aAttrInfo, TSR_OBJ_CYCLE, sDirectory)

      when TSR_OBJ_TASK_EXC
        hTesryTaskExc = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_TASK_EXC : ANY_T2_FMP_TESRY_TASK_EXC)
        T2_convert_object_data(hTesryTaskExc, sAttribute, aAttrInfo, TSR_OBJ_TASK_EXC, sDirectory)

      when TSR_OBJ_EXCEPTION
        hTesryException = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_EXCEPTION : ANY_T2_FMP_TESRY_EXCEPTION)
        T2_convert_object_data(hTesryException, sAttribute, aAttrInfo, TSR_OBJ_EXCEPTION, sDirectory)

      when TSR_OBJ_INTHDR
        hTesryInthdr = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_INTHDR : ANY_T2_FMP_TESRY_INTHDR)
        T2_convert_object_data(hTesryInthdr, sAttribute, aAttrInfo, TSR_OBJ_INTHDR, sDirectory)

      when TSR_OBJ_ISR
        hTesryIsr = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_ISR : ANY_T2_FMP_TESRY_ISR)
        T2_convert_object_data(hTesryIsr, sAttribute, aAttrInfo, TSR_OBJ_ISR, sDirectory)

      when TSR_OBJ_INIRTN
        hTesryInirtn = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_INIRTN : ANY_T2_FMP_TESRY_INIRTN)
        T2_convert_object_data(hTesryInirtn, sAttribute, aAttrInfo, TSR_OBJ_INIRTN, sDirectory)

      when TSR_OBJ_TERRTN
        hTesryTerrtn = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_TERRTN : ANY_T2_FMP_TESRY_TERRTN)
        T2_convert_object_data(hTesryTerrtn, sAttribute, aAttrInfo, TSR_OBJ_TERRTN, sDirectory)

      when TSR_OBJ_SEMAPHORE
        hTesrySemaphore = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_SEMAPHORE : ANY_T2_FMP_TESRY_SEMAPHORE)
        T2_convert_object_data(hTesrySemaphore, sAttribute, aAttrInfo, TSR_OBJ_SEMAPHORE, sDirectory)

      when TSR_OBJ_EVENTFLAG
        hTesryEventflag = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_EVENTFLAG : ANY_T2_FMP_TESRY_EVENTFLAG)
        T2_convert_object_data(hTesryEventflag, sAttribute, aAttrInfo, TSR_OBJ_EVENTFLAG, sDirectory)

      when TSR_OBJ_DATAQUEUE
        hTesryDataqueue = {}
        if (sAttribute == TSR_VAR_DATA)
          hTesryDataqueue = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_DATAQUEUE_1 : ANY_T2_FMP_TESRY_DATAQUEUE_1)
        elsif (sAttribute == TSR_VAR_VAR)
          hTesryDataqueue = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_DATAQUEUE_2 : ANY_T2_FMP_TESRY_DATAQUEUE_2)
        else
          hTesryDataqueue = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_DATAQUEUE : ANY_T2_FMP_TESRY_DATAQUEUE)
        end
        T2_convert_object_data(hTesryDataqueue, sAttribute, aAttrInfo, TSR_OBJ_DATAQUEUE, sDirectory)

      when TSR_OBJ_P_DATAQUEUE
        hTesryDataqueue = {}
        if ((sAttribute == TSR_VAR_DATA) || (sAttribute == TSR_VAR_DATAPRI))
          hTesryPridataq = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_P_DATAQUEUE_1 : ANY_T2_FMP_TESRY_P_DATAQUEUE_1)
        elsif ((sAttribute == TSR_VAR_VARDATA) || (sAttribute == TSR_VAR_VARPRI))
          hTesryPridataq = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_P_DATAQUEUE_2 : ANY_T2_FMP_TESRY_P_DATAQUEUE_2)
        else
          hTesryPridataq = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_P_DATAQUEUE : ANY_T2_FMP_TESRY_P_DATAQUEUE)
        end
        T2_convert_object_data(hTesryPridataq, sAttribute, aAttrInfo, TSR_OBJ_P_DATAQUEUE, sDirectory)

      when TSR_OBJ_MAILBOX
        hTesryMailbox = {}
        if ((sAttribute == TSR_VAR_MSG) || (sAttribute == TSR_VAR_MSGPRI))
          hTesryMailbox = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_MAILBOX_1 : ANY_T2_FMP_TESRY_MAILBOX_1)
        elsif (sAttribute == TSR_VAR_VAR)
          hTesryMailbox = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_MAILBOX_2 : ANY_T2_FMP_TESRY_MAILBOX_2)
        else
          hTesryMailbox = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_MAILBOX : ANY_T2_FMP_TESRY_MAILBOX)
        end
        T2_convert_object_data(hTesryMailbox, sAttribute, aAttrInfo, TSR_OBJ_MAILBOX, sDirectory)

      when TSR_OBJ_MEMORYPOOL
        hTesryMemorypool = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_MEMORYPOOL : ANY_T2_FMP_TESRY_MEMORYPOOL)
        T2_convert_object_data(hTesryMemorypool, sAttribute, aAttrInfo, TSR_OBJ_MEMORYPOOL, sDirectory)

      when TSR_OBJ_SPINLOCK
        hTesrySpinlock = Kwalify::Yaml.load_file(ANY_T2_FMP_TESRY_SPINLOCK)
        T2_convert_object_data(hTesrySpinlock, sAttribute, aAttrInfo, TSR_OBJ_SPINLOCK, sDirectory)

      when TSR_OBJ_CPU_STATE
        hTesryCpuState = Kwalify::Yaml.load_file(@bASP == true ? ANY_T2_ASP_TESRY_CPU_STATE : ANY_T2_FMP_TESRY_CPU_STATE)
        T2_convert_object_data(hTesryCpuState, sAttribute, aAttrInfo, TSR_OBJ_CPU_STATE, sDirectory)

      when TSR_LBL_DO
        hTesryDo = Kwalify::Yaml.load_file(ANY_T2_TESRY_DO)
        T2_convert_do_data(hTesryDo, sAttribute, aAttrInfo, sObjectType, sDirectory)

      end
    end

    #=================================================================
    # 概  要: T2のエラーファイルの内容を生成する
    #=================================================================
    def T2_convert_object_data(hTesryObject, sAttribute, aAttrInfo, sObjectType, sDirectory)
      check_class(Hash,   hTesryObject)  # TESRYコードの情報
      check_class(String, sAttribute)    # 属性
      check_class(Array,  aAttrInfo)     # エラー情報
      check_class(String, sObjectType)   # オブジェクトタイプ
      check_class(String, sDirectory)    # 対象ディレクトリ

      bTestFlag = true

      hTesryObject.each{|sSection, hSectionInfo|
        next if (sSection == TSR_LBL_VERSION)

        hSectionInfo.each{|sCondition, hConditionInfo|
          next if (sCondition.include?(TSR_LBL_DO))
          next if (sCondition == TSR_LBL_VARIATION)
          next if (sCondition == TSR_LBL_NOTE)
          next if (hConditionInfo.nil?() == true)

          hConditionInfo.each{|sObject, hObecjtInfo|
            if (hObecjtInfo[TSR_PRM_TYPE] == sObjectType && bTestFlag == true)
              next if ((@bASP == true) && (ATT_FMP_DEFINED_TO_OBJECT[sObjectType].include?(sAttribute) == true))  # ASPモードでFMP属性の場合は弾く
              bTestFlag = false

              aAttrInfo.each{|sConvert|
                hObjectTemp = Marshal.load(Marshal.dump(hTesryObject))

                case sAttribute
                when TSR_VAR_WAIPTN, TSR_VAR_WFMODE
                  next if (hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST].nil? == true)

                  sTask = hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST][0].keys[0]
                  hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST][0][sTask][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]

                when TSR_VAR_VARPRI, TSR_VAR_VARDATA
                  next if (hObjectTemp[sSection][sCondition][sObject][TSR_PRM_RTSKLIST].nil? == true)

                  sTask = hObjectTemp[sSection][sCondition][sObject][TSR_PRM_RTSKLIST][0].keys[0]
                  hObjectTemp[sSection][sCondition][sObject][TSR_PRM_RTSKLIST][0][sTask][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]

                when TSR_VAR_DATA, TSR_VAR_DATAPRI
                  next if (hObjectTemp[sSection][sCondition][sObject][TSR_PRM_DATALIST].nil? == true)

                  hObjectTemp[sSection][sCondition][sObject][TSR_PRM_DATALIST][0][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]

                when TSR_VAR_MSG, TSR_VAR_MSGPRI
                  next if (hObjectTemp[sSection][sCondition][sObject][TSR_PRM_MSGLIST].nil? == true)

                  hObjectTemp[sSection][sCondition][sObject][TSR_PRM_MSGLIST][0][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]

                when TSR_VAR_VAR
                  if ((sObjectType == TSR_OBJ_EVENTFLAG) || (sObjectType == TSR_OBJ_MAILBOX))
                    next if (hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST].nil? == true)

                    sTask = hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST][0].keys[0]
                    hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST][0][sTask][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]
                  elsif (sObjectType == TSR_OBJ_DATAQUEUE)
                    next if (hObjectTemp[sSection][sCondition][sObject][TSR_PRM_RTSKLIST].nil? == true)

                    sTask = hObjectTemp[sSection][sCondition][sObject][TSR_PRM_RTSKLIST][0].keys[0]
                    hObjectTemp[sSection][sCondition][sObject][TSR_PRM_RTSKLIST][0][sTask][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]
                  elsif (sObjectType == TSR_OBJ_MEMORYPOOL)
                    sTask = ""
                    sVar  = ""

                    hTesryObject[sSection][sCondition].each{|sObjectID, sObjectInfo|
                      if ((sObjectInfo[TSR_PRM_TYPE] == TSR_OBJ_TASK) && (sObjectInfo[TSR_PRM_VAR].nil? == false))
                        sTask = sObjectID
                        sVar  = sObjectInfo[TSR_PRM_VAR].keys[0]
                      end
                    }

                    hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST] = [{sTask => {TSR_PRM_VAR => sVar}}]
                    sTask = hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST][0].keys[0]
                    hObjectTemp[sSection][sCondition][sObject][TSR_PRM_WTSKLIST][0][sTask][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]
                  else
                    hObjectTemp[sSection][sCondition][sObject][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]
                  end

                else
                  hObjectTemp[sSection][sCondition][sObject][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]

                end

                @sFileName = "#{File.expand_path(sDirectory)}/#{sObjectType.downcase()}/#{sDirectory.split("/")[-1]}_#{sObjectType.downcase()}-#{sAttribute}-#{CVT_ATTRIBUTE_NAME[sConvert]}.yaml"
                @aMakeFileList.push(@sFileName)
                prepare_file(hObjectTemp)
              }
            end
          }
        }
      }
    end

    #=================================================================
    # 概  要: doに該当するT2のエラーファイルの内容を生成する
    #=================================================================
    def T2_convert_do_data(hTesryDo, sAttribute, aAttrInfo, sObjectType, sDirectory)
      check_class(Hash,   hTesryDo)     # doの情報
      check_class(String, sAttribute)   # 属性
      check_class(Array,  aAttrInfo)    # エラー情報
      check_class(String, sObjectType)  # オブジェクトタイプ
      check_class(String, sDirectory)   # 対象ディレクトリ

      hTesryDo.each{|sSection, hSectionInfo|
        next if (sSection == TSR_LBL_VERSION)

        hSectionInfo[TSR_LBL_DO].each{|doKey, doVal|
          aAttrInfo.each{|sConvert|
            hDoTemp = Marshal.load(Marshal.dump(hTesryDo))
            hDoTemp[sSection][TSR_LBL_DO][sAttribute] = CVT_ATTRIBUTE_VALUE[sConvert]

            @sFileName = "#{File.expand_path(sDirectory)}/#{sObjectType.downcase()}/#{sDirectory.split("/")[-1]}_#{TSR_LBL_DO}-#{sAttribute}-#{CVT_ATTRIBUTE_NAME[sConvert]}.yaml"
            @aMakeFileList.push(@sFileName)
            prepare_file(hDoTemp)
          }
        }
      }
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T2_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array, aFileList)    # ファイルリスト

      aFMPFile = search_FMP_file(aFileList)

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory.split("/")[-1]}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))
          cIO.puts("echo [File] #{sFileList}")
          cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList}")
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory.split("/")[-1]}.sh")
    end

    #=================================================================
    # 概  要: T2_001のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T2_001_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      CHK_ATTRIBUTE_TYPE.each{|sObjectType, hAttribute|
        prepare_directory("#{FDR_T2_001}/#{sObjectType.downcase()}")
        puts("[#{FDR_T2_001}/#{sObjectType.downcase()}] Error-file Creating..")

        hAttribute.each{|sAttribute, aAttrInfo|
          T2_prepare_convert_data(sDirectory, sObjectType, sAttribute, aAttrInfo)
        }
      }
    end

    #=================================================================
    # 概  要: T2_002のエラーファイルを生成するために必要な情報を整える
    #=================================================================
    def T2_002_create_file(sDirectory)
      check_class(String, sDirectory)  # 対象ディレクトリ

      CHK_ATTRIBUTE_VALUE.each{|sObjectType, hAttribute|
        prepare_directory("#{FDR_T2_002}/#{sObjectType.downcase()}")
        puts("[#{FDR_T2_002}/#{sObjectType.downcase()}] Error-file Creating..")

        hAttribute.each{|sAttribute, aAttrInfo|
          T2_prepare_convert_data(sDirectory, sObjectType, sAttribute, aAttrInfo)
        }
      }
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T3_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array, aFileList)    # ファイルリスト

      aFMPFile = search_FMP_file(aFileList)

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))
          cIO.puts("echo [File] #{sFileList}")
          cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList}")
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory.split("/")[-1]}.sh")
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T4_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array,  aFileList)   # ファイルリスト

      T3_create_shell(sDirectory, aFileList)
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T5_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array,  aFileList)   # ファイルリスト

      aConfList = []
      aTemp     = []

      aFMPFile = search_FMP_file(aFileList)

      # ASPモードの場合，FMPファイルを除外する
      aFileList.each{|sFileList|
        next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))

        aTemp.push(sFileList)
      }

      aFileList = aTemp

      # 多数ファイルを実行するための実行命令名の変更
      aFileList.each{|sFileList|
        if (sFileList.include?(CONFIGURE_FILE) == true)
          aConfList.push(sFileList.gsub("-#{CONFIGURE_FILE}", ""))
          aFileList.delete(sFileList)
        end
      }

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          if (aConfList.include?(sFileList) == true)
            next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))
            cIO.puts("echo [File] #{sFileList}")
            cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList} -c #{sFileList.gsub(".yaml", "-#{CONFIGURE_FILE}.yaml")}")
          else
            next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))
            cIO.puts("echo [File] #{sFileList}")
            cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList}")
          end
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory}.sh")
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T6_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array,  aFileList)   # ファイルリスト

      aConfList = []
      aFMPFile  = search_FMP_file(aFileList)

      aFileList.each{|sFileList|
        if (sFileList.include?(CONFIGURE_FILE) == true)
          aConfList.push(sFileList.gsub("-#{CONFIGURE_FILE}", ""))
          aFileList.delete(sFileList)
        end
      }

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))
          cIO.puts("echo [File] #{sFileList}")
          cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList} -c #{sFileList.gsub(".yaml", "-#{CONFIGURE_FILE}.yaml")}")
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory}.sh")
    end

    #=================================================================
    # 概  要: シェルファイルを生成する
    #=================================================================
    def T7_create_shell(sDirectory, aFileList)
      check_class(String, sDirectory)  # 対象ディレクトリ
      check_class(Array,  aFileList)   # ファイルリスト

      aConfList    = []
      aNonConfList = []
      aTemp        = []

      aFMPFile = search_FMP_file(aFileList)

      # ASPモードの場合，FMPファイルを除外する
      aFileList.each{|sFileList|
        next if ((@bASP == true) && (aFMPFile.include?(sFileList) == true))

        aTemp.push(sFileList)
      }

      aFileList = aTemp

      # 多数ファイルを実行するための実行命令名の変更
      aFileList.each{|sFileList|
        if (sFileList.include?(CONFIGURE_FILE) == true)
          aConfList.push(sFileList.gsub("-#{CONFIGURE_FILE}", ""))
        elsif (sFileList.include?("multiple") == true)
          aNonConfList.push(sFileList.gsub(/-multiple./, ""))
        end
      }

      aFileList = aNonConfList.uniq.sort()

      # シェルファイルを実行したディレクトリに生成する
      File.open("#{sDirectory}.sh", "w"){|cIO|
        aFileList.each{|sFileList|
          if (aConfList.include?(sFileList) == true)
            cIO.puts("echo [File] #{sFileList}")
            cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList.gsub(".yaml", "-multiple*.yaml")} -c #{sFileList.gsub(".yaml", "-configure.yaml")}")
          elsif (aNonConfList.include?(sFileList) == true)
            cIO.puts("echo [File] #{sFileList}")
            cIO.puts("#{TTG_PATH} #{@bProfile} #{sFileList.gsub(".yaml", "-multiple*.yaml")}")
          end
        }
      }

      @aMakeFileList.push("#{File.expand_path("")}/#{sDirectory}.sh")
    end

  end
end

#=====================================================================
# 概  要: Main
#=====================================================================
if ($0 == __FILE__)
  require 'pp'

  include ErrorCheckModule

  cErrorCheck = ErrorCheck.new(ARGV)
  cErrorCheck.proceed_TTC_check()
end
