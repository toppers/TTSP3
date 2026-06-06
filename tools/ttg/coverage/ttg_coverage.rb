#!ruby -Ku
#
# $Id: ttg_coverage.rb 28 2019-02-12 01:50:02Z fujisft-shigihara $
#
TOOL_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")
$LOAD_PATH.unshift(TOOL_ROOT)
require "test/unit"
require "bin/ttg.rb"

DIR_API_TEST = File.expand_path(TOOL_ROOT + "/../../api_test/")
DIR_TTC_TEST = File.expand_path(TOOL_ROOT + "/ttc/test/err_check")
DIR_JUST_IN  = File.expand_path(TOOL_ROOT + "/coverage/for_covers_all")

def exit(nErr = 0)
  if (nErr == 1)
    raise(StandardError)
  else
    super()
  end
end

#=====================================================================
# クラス名: CoverageTest
# 概　  要: カバレッジを取得するためのテストケース
#=====================================================================
class CoverageTest < Test::Unit::TestCase
  include CommonModule
  include TTCModule
  include TTG

  #===================================================================
  # 概　要: 各テストケース実行前の初期化処理
  #===================================================================
  def setup()
    cConf = Config.new()
    cConf.reset()
    @aArgs = []
  end

  #===================================================================
  # 概　要: TTGオプション（ヘルプ，バージョン）
  #===================================================================
  def test_ttg_option()
    print_test("TTG basic option")

    ["-h", "-v"].each{|sOpt|
      setup()
      @aArgs.push(sOpt)
      aPattern = [
        "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
      ]
      begin
        exec_test(aPattern)
      rescue
      end
    }
  end

  #===================================================================
  # 概　要: TTGオプション（プロファイル両方指定）
  #===================================================================
  def test_ttg_profile_option_error()
    print_test("TTG profile option error")

    @aArgs.push("-a", "-f")
    aPattern = [
      "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
    ]
    begin
      exec_test(aPattern)
    rescue
    end
  end

  #===================================================================
  # 概　要: TTGオプション（OptionParserError）
  #===================================================================
  def test_ttg_option_parser_error()
    print_test("TTG option parser error")

    @aArgs.push("--undefined")
    aPattern = [
      "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
    ]
    begin
      exec_test(aPattern)
    rescue
    end
  end

  #===================================================================
  # 概　要: configureオプション指定
  #===================================================================
  def test_ttg_configure_option()
    print_test("TTG all configure option")
    cConf = Config.new()
    cConf.load_config(DEFAULT_CONFIG_FILE)
    # 引数
    @aArgs.push("-a")
    aKeys = [
      CFG_PRC_NUM,
      CFG_MAIN_PRCID,
      CFG_DEFAULT_CLASS,
      CFG_TIMER_ARCH,
      CFG_TIME_MANAGE_PRCID,
      CFG_TIME_MANAGE_CLASS,
      CFG_TIMER_INT_PRI,
      CFG_SPINLOCK_NUM,
      CFG_IRC_ARCH,
      CFG_SUPPORT_GET_UTM,
      CFG_SUPPORT_ENA_INT,
      CFG_SUPPORT_DIS_INT,
      CFG_OWN_IPI_RAISE,
      CFG_ENA_EXC_LOCK,
      CFG_ENA_CHGIPM,
      CFG_FUNC_TIME,
      CFG_FUNC_INTERRUPT,
      CFG_FUNC_EXCEPTION,
      CFG_ALL_GAIN_TIME,
      CFG_STACK_SHARE,
      CFG_OUT_FILE,
      CFG_WAIT_SPIN_LOOP,
      CFG_EXCEPT_ARG_NAME,
      CFG_YAML_LIBRARY,
      CFG_ENABLE_GCOV,
      CFG_ENABLE_LOG
    ]
    aKeys.each{|sKey|
      @aArgs.push("--#{sKey}")
      @aArgs.push(cConf.get(sKey).to_s())
    }
    aPattern = [
      "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: TTCファイル処理（事前削除）
  #===================================================================
  def test_ttc_pre_file_check()
    print_test("TTC pre file check")

    # ファイル作成
    unless (File.exist?(TTC_EXCLUSION_FILE))
      `touch #{TTC_EXCLUSION_FILE}`
    end
    unless (File.exist?(TTC_DEBUG_FILE_BEFORE))
      `touch #{TTC_DEBUG_FILE_BEFORE}`
    end

    # ファイル削除
    @aArgs.push("-a", "-d")
    aPattern = [
      "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: TTC YAMLライブラリ依存
  #===================================================================
  def test_ttc_yaml_library()
    print_test("TTC yaml library error")

    # TESRY
    aFiles = [
      "#{DIR_JUST_IN}/invalid_yaml.yaml"
    ]
    [CFG_LIB_YAML, CFG_LIB_KWALIFY].each{|sLib|
      aFiles.each{|sFileName|
        setup()
        @aArgs.push("-f", "--#{CFG_YAML_LIBRARY}", sLib)
        begin
          exec_test([sFileName])
        rescue
        end
      }
    }
  end

  #===================================================================
  # 概　要: TTC特殊ケース
  #===================================================================
  def test_ttc_covers_all()
    print_test("TTC for covers_all")

    # TESRY
    aFiles = [
      "#{DIR_JUST_IN}/invalid_expression.yaml",
      "#{DIR_JUST_IN}/complement_pre_var.yaml",
      "#{DIR_JUST_IN}/complement_isr.yaml",
      "#{DIR_JUST_IN}/pre_activate_process_unit.yaml",
      "#{DIR_JUST_IN}/non_var_info_in_post_condition.yaml",
      "#{DIR_JUST_IN}/T1_*.yaml",
      "#{DIR_JUST_IN}/T2_*.yaml",
      "#{DIR_JUST_IN}/T3_*.yaml"
    ]
    aFiles.each{|sFileName|
      setup()
      @aArgs.push("-f")
      begin
        exec_test([sFileName])
      rescue
      end
    }
  end

  #===================================================================
  # 概　要: TTC特殊ケース（configure）
  #===================================================================
  def test_ttc_covers_all_configure()
    print_test("TTC for covers_all configure")

    aFiles = [
      "#{DIR_JUST_IN}/invalid_macro_configure.yaml",
      "#{DIR_JUST_IN}/undefined_configure.yaml",
      "#{DIR_JUST_IN}/T0_008.yaml"
    ]
    aFiles.each{|sFileName|
      setup()
      @aArgs.push("-a", "-c", sFileName)
      begin
        exec_test(["#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"])
      rescue
      end
    }
  end

  #===================================================================
  # 概　要: ASPテストケースの実行
  #===================================================================
  def test_asp()
    print_test("ASP valid")
    # 引数
    @aArgs.push("-a", "--#{CFG_ENABLE_GCOV}", "true")
    aPattern = [
      "#{DIR_API_TEST}/ASP/*/*/*.yaml",
      "#{TOOL_ROOT}/test/just_in_case/asp/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行
  #===================================================================
  def test_fmp()
    print_test("FMP valid")
    # 引数
    @aArgs.push("-f", "--#{CFG_ENABLE_GCOV}", "true")
    aPattern = [
      "#{DIR_API_TEST}/ASP/*/*/*.yaml",
      "#{DIR_API_TEST}/FMP/*/*/*.yaml",
      "#{TOOL_ROOT}/test/just_in_case/*/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（global + debug）
  #===================================================================
  def test_fmp_global()
    print_test("FMP global + debug")
    # 引数
    @aArgs.push("-f", "--#{CFG_TIMER_ARCH}", TSR_PRM_TIMER_GLOBAL, "-d")
    aPattern = [
      "#{DIR_API_TEST}/FMP/*/*/*.yaml",
      "#{TOOL_ROOT}/test/just_in_case/*/*.yaml",
      "#{DIR_JUST_IN}/inthdr_global_timer.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（global，プロセッサ番号入れ替え）
  #===================================================================
  def test_fmp_global_change()
    print_test("FMP global change main_prcid & time_manage_prcid")
    # 引数
    @aArgs.push("-f", "--#{CFG_TIMER_ARCH}", TSR_PRM_TIMER_GLOBAL, "--#{CFG_MAIN_PRCID}", "2",
                "--#{CFG_TIME_MANAGE_PRCID}", "3")
    aPattern = [
      "#{DIR_API_TEST}/FMP/*/*/*.yaml",
      "#{TOOL_ROOT}/test/just_in_case/*/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（all_gain_time）
  #===================================================================
  def test_fmp_all_gain()
    print_test("FMP all_gain_time")
    # 引数
    @aArgs.push("-f", "--#{CFG_ALL_GAIN_TIME}", "true")
    aPattern = [
      "#{DIR_API_TEST}/FMP/*/*/*.yaml",
      "#{TOOL_ROOT}/test/just_in_case/*/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（時間動作判定）
  #===================================================================
  def test_fmp_gain_time()
    print_test("FMP gain_time")
    # 引数
    @aArgs.push("-f", "--#{CFG_ALL_GAIN_TIME}", "true", "--#{CFG_FUNC_TIME}", "false")
    aPattern = [
      "#{TOOL_ROOT}/ttc/test/variation/target_dependence_func/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（dis_int非サポート，プロセッサ番号入
  #       : れ替え）
  #===================================================================
  def test_fmp_not_dis_int()
    print_test("FMP not_dis_int")
    # 引数
    @aArgs.push("-f", "--#{CFG_SUPPORT_DIS_INT}", "false", "--#{CFG_MAIN_PRCID}", "2")
    aPattern = [
      "#{DIR_API_TEST}/FMP/interrupt/*/*.yaml",
      "#{TOOL_ROOT}/test/just_in_case/*/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（起動中の非タスクあり）
  #===================================================================
  def test_fmp_global_exist_activate_non_task()
    print_test("FMP global_exist_activate_non_task")

    @aArgs.push("-f", "--#{CFG_TIMER_ARCH}", TSR_PRM_TIMER_GLOBAL, "--#{CFG_MAIN_PRCID}", "2",
                "--#{CFG_TIME_MANAGE_PRCID}", "2")
    aPattern = [
      "#{DIR_JUST_IN}/global_exist_activate_non_task.yaml"
    ]
    exec_test(aPattern)

    setup()
    @aArgs.push("-f", "--#{CFG_TIMER_ARCH}", TSR_PRM_TIMER_GLOBAL, "--#{CFG_MAIN_PRCID}", "2",
                "--#{CFG_TIME_MANAGE_PRCID}", "1")
    aPattern = [
      "#{DIR_JUST_IN}/global_exist_activate_non_task.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: ASPテストケースの実行（gcov 初期化/終了ルーチン除外）
  #===================================================================
  def test_asp_gcov()
    print_test("ASP gcov (exclude INIRTN + TERRTN)")
    # 引数
    @aArgs.push("-a", "--#{CFG_ENABLE_GCOV}", "true")
    aPattern = [
      "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: ASPテストケースの実行（html + progress bar）
  #===================================================================
  def test_asp_html()
    print_test("ASP (html + progress bar off)")
    # 引数
    @aArgs.push("-a", "-t", "-p")
    aPattern = [
      "#{DIR_API_TEST}/ASP/task_manage/act_tsk/*.yaml"
    ]
    exec_test(aPattern)
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（html + ttj）
  #===================================================================
  def test_fmp_html()
    print_test("FMP (html + ttj)")
    # 引数
    @aArgs.push("-f", "-t", "-j")
    aPattern = [
      "#{DIR_API_TEST}/FMP/task_manage/act_tsk/*.yaml"
    ]
    exec_test(aPattern)
  end


  #===================================================================
  # 概　要: T0エラーチェック
  #===================================================================
  def test_ttg_error_T0()
    print_test("TTG T0 error")
    # 引数
    Dir.glob("#{DIR_TTC_TEST}/T0/*/*.yaml"){|sFileName|
      setup()
      @aArgs.concat(["-f", "-c", sFileName])
      begin
        exec_test("#{DIR_API_TEST}/ASP/task_manage/act_tsk/act_tsk_a-1.yaml")
      rescue
      end
    }
  end

  #===================================================================
  # 概　要: ASPテストケースの実行（T1～T5）
  #===================================================================
  def test_asp_error()
    print_test("ASP T1-T5 error")
    common_error("-a")
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（T1～T5）
  #===================================================================
  def test_fmp_error()
    print_test("FMP T1-T5 error")
    common_error("-f")
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（T6）
  #===================================================================
  def test_fmp_error_T6()
    print_test("FMP T6")
    # 引数
    cTTG = TTGMain.new()
    Dir.glob("#{DIR_TTC_TEST}/T6/T6_*-configure.yaml"){|sConfName|
      sFileName = sConfName.sub("-configure", "")
      setup()
      @aArgs.concat(["-f", "-c", sConfName, sFileName])
      begin
        cTTG.main(@aArgs)
      rescue
      end
    }
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（T7，T7_F001以外）
  #===================================================================
  def test_fmp_error_T7()
    print_test("FMP T7")
    # 引数
    aPattern = []
    Dir.glob("#{DIR_TTC_TEST}/T7/*.yaml"){|sFileName|
      if(sFileName =~ /(T7_\d+\-\w+)[\w\-]+\.yaml$/)
        aPattern.push($1)
      end
    }

    aPattern.uniq().sort().each{|sPrefix|
      $stderr.puts sPrefix
      setup()
      @aArgs.push("-f")
      begin
        exec_test("#{DIR_TTC_TEST}/T7/#{sPrefix}*.yaml")
      rescue
      end
    }
  end

  #===================================================================
  # 概　要: FMPテストケースの実行（T7_F001）
  #===================================================================
  def test_fmp_error_T7_fmp()
    print_test("FMP T7_F001")

    @aArgs.push("-f", "-c", "#{DIR_TTC_TEST}/T7/T7_F001-spinlock_num-configure.yaml")
    begin
      exec_test("#{DIR_TTC_TEST}/T7/T7_F001-spinlock_num-multiple*.yaml")
    rescue
    end
  end

  #===================================================================
  # 概　要: エラーテストケースの実行共通部
  #===================================================================
  def common_error(sProfile)
    # 引数
    @aArgs.push(sProfile)
    aPattern = [
      "#{DIR_TTC_TEST}/T1/*.yaml",
      "#{DIR_TTC_TEST}/T2/*/*/*.yaml",
      "#{DIR_TTC_TEST}/T3/*.yaml",
      "#{DIR_TTC_TEST}/T4/*.yaml",
      "#{DIR_TTC_TEST}/T5/*.yaml"
    ]
    aPattern.each{|sPattern|
      Dir.glob(sPattern){|sFileName|
        setup()
        @aArgs.concat(["-f"])
        # configure
        sConfName = sFileName.sub(".yaml", "-configure.yaml")
        if (File.exist?(sConfName))
          @aArgs.concat(["-c", sConfName])
        end
        begin
          exec_test(sFileName)
        rescue
        end
      }
    }
  end
  private :common_error

  #===================================================================
  # 概　要: 指定された条件でTTG実行
  #===================================================================
  def exec_test(aPattern)
    aPattern.each{|sPattern|
      Dir.glob(sPattern){|sFileName|
        @aArgs.push(sFileName)
      }
    }
    # TTG実行
    cTTG = TTGMain.new()
    cTTG.main(@aArgs)
  end
  private :exec_test

  #===================================================================
  # 概　要: 実行内容表示
  #===================================================================
  def print_test(sMsg)
    $stderr.puts
    $stderr.puts("-" * 32)
    $stderr.puts(sMsg)
    $stderr.puts("-" * 32)
  end
end
