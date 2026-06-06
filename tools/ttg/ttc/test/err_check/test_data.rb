#!ruby -Ku
#
# $Id: test_data.rb 28 2019-02-12 01:50:02Z fujisft-shigihara $
#

# TTGおよびTTCのマクロが要るためCommonをインクルードする必要がある
require "common/bin/CommonModule.rb"

module ErrorCheckModule
  include CommonModule

  #=====================================================================
  # TTC Error-checkerの共通マクロ
  #=====================================================================
  TTSP_PATH = File.expand_path(File.dirname(__FILE__) + "/../../../../../")
  TTG_PATH  = TTSP_PATH + "/tools/ttg/bin/ttg.rb"

  # ファイル生成時の情報を持つファイル名
  MAKE_FILE_LIST   = "make_file_list.txt"
  DO_NOT_ATTRIBUTE = "do_not_attribute.txt"

  # configure名
  CONFIGURE_FILE = "configure"

  # フォルダ名
  FDR_T0 = "T0"
  FDR_T1 = "T1"
  FDR_T2 = "T2"
  FDR_T3 = "T3"
  FDR_T4 = "T4"
  FDR_T5 = "T5"
  FDR_T6 = "T6"
  FDR_T7 = "T7"

  FDR_T0_001 = "T0/T0_001"
  FDR_T0_002 = "T0/T0_002"
  FDR_T0_003 = "T0/T0_003"
  FDR_T0_004 = "T0/T0_004"
  FDR_T0_005 = "T0/T0_005"
  FDR_T0_006 = "T0/T0_006"
  FDR_T0_007 = "T0/T0_007"
  FDR_T0_008 = "T0/T0_008"
  FDR_T0_009 = "T0/T0_009"
  FDR_T0_010 = "T0/T0_010"

  FDR_T2_001 = "T2/T2_001"
  FDR_T2_002 = "T2/T2_002"
  FDR_T2_003 = "T2/T2_003"

  # 削除可能なフォルダ
  DEL_FOLDER_LIST = [
    FDR_T0,
    FDR_T2
  ]

  # configureファイルが保存されているフォルダ
  FDR_CONFIGURE_FILE = [
    FDR_T5,
    FDR_T6,
    FDR_T7
  ]

  #=====================================================================
  # T0: environmentのマクロ
  #=====================================================================
  # パス
  ANY_T0_TESRY  = TTSP_PATH + "/api_test/ASP/semaphore/ini_sem/ini_sem_a-1.yaml"
  ANY_CONFIGURE = TTSP_PATH + "/tools/ttg/bin/configure.yaml"

  # ANY VALUE
  ANY_ZERO                = 0
  ANY_PLUS                = 123
  ANY_MINUS               = -123
  ANY_STRING              = "string"
  ANY_TSK_PRI_LE_4_LOWER  = 0
  ANY_TSK_PRI_LE_4_UPPER  = 5
  ANY_TSK_PRI_GE_13_LOWER = 12
  ANY_TSK_PRI_GE_13_UPPER = 17

  # マクロの置換
  CVT_CONFIGURE_VALUE = {
    # configure
    String     => "string",
    Integer    => 0,
    Float      => 1.0,
    TrueClass  => true,
    FalseClass => false,

    # macro
    ANY_ZERO                => ANY_ZERO,
    ANY_PLUS                => ANY_PLUS,
    ANY_MINUS               => ANY_MINUS,
    ANY_STRING              => ANY_STRING,
    ANY_TSK_PRI_LE_4_LOWER  => ANY_TSK_PRI_LE_4_LOWER,
    ANY_TSK_PRI_LE_4_UPPER  => ANY_TSK_PRI_LE_4_UPPER,
    ANY_TSK_PRI_GE_13_LOWER => ANY_TSK_PRI_GE_13_LOWER,
    ANY_TSK_PRI_GE_13_UPPER => ANY_TSK_PRI_GE_13_UPPER
  }

  # ファイル変換名
  CVT_CONFIGURE_NAME = {
    # configure
    String     => "string",
    Integer    => "number",
    Float      => "float",
    TrueClass  => "true",
    FalseClass => "false",

    # macro
    ANY_ZERO                => "zero",
    ANY_PLUS                => "plus",
    ANY_MINUS               => "minus",
    ANY_STRING              => "string",
    ANY_TSK_PRI_LE_4_UPPER  => "upper",
    ANY_TSK_PRI_GE_13_LOWER => "lower",
    ANY_TSK_PRI_GE_13_UPPER => "upper"
  }

  # configureに規定されていない項目検査
  ERROR_CONFIGURE_ENTRY = {
    "core_num_error" => 1
  }

=begin
  # configureに指定されていない属性検査
  ERROR_ATTRIBUTE = {
    "error_attribute" => "T0_001"
  }
=end

  # 時間操作関数がないのに全テストケース時間停止指定である場合の検査
  NON_FUNC_TIME_NON_GAIN_TIME = {
    "all_gain_time" => false,
    "func_time"     => false
  }

  # タスク優先度の不具合
  TASTPRI_HIGH_MID = {
    "TSK_PRI_HIGH" => 10,
    "TSK_PRI_MID"  => 9,
    "TSK_PRI_LOW"  => 11
  }

  TASTPRI_MID_LOW = {
    "TSK_PRI_HIGH" => 9,
    "TSK_PRI_MID"  => 11,
    "TSK_PRI_LOW"  => 10
  }

  # データ優先度の不具合
  DATAPRI_HIGH_MID = {
    "DATA_PRI_HIGH" => 2,
    "DATA_PRI_MID"  => 1,
    "DATA_PRI_LOW"  => 3,
    "DATA_PRI_MAX"  => 4
  }

  DATAPRI_MID_LOW = {
    "DATA_PRI_HIGH" => 1,
    "DATA_PRI_MID"  => 3,
    "DATA_PRI_LOW"  => 2,
    "DATA_PRI_MAX"  => 4
  }

  DATAPRI_LOW_MAX = {
    "DATA_PRI_HIGH" => 1,
    "DATA_PRI_MID"  => 2,
    "DATA_PRI_LOW"  => 4,
    "DATA_PRI_MAX"  => 3
  }

  # メッセージ優先度の不具合
  MSGPRI_HIGH_MID = {
    "MSG_PRI_HIGH" => 2,
    "MSG_PRI_MID"  => 1,
    "MSG_PRI_LOW"  => 3,
    "MSG_PRI_MAX"  => 4
  }

  MSGPRI_MID_LOW = {
    "MSG_PRI_HIGH" => 1,
    "MSG_PRI_MID"  => 3,
    "MSG_PRI_LOW"  => 2,
    "MSG_PRI_MAX"  => 4
  }

  MSGPRI_LOW_MAX = {
    "MSG_PRI_HIGH" => 1,
    "MSG_PRI_MID"  => 2,
    "MSG_PRI_LOW"  => 4,
    "MSG_PRI_MAX"  => 3
  }

  # 割込み優先度の不具合
  ISRPRI_HIGH_MID = {
    "ISR_PRI_HIGH" => 10,
    "ISR_PRI_MID"  => 9,
    "ISR_PRI_LOW"  => 11
  }

  ISRPRI_MID_LOW = {
    "ISR_PRI_HIGH" => 9,
    "ISR_PRI_MID"  => 11,
    "ISR_PRI_LOW"  => 10
  }

  # セマフォ資源の不具合
  SEMCNT_NOW_MAX = {
    "ANY_NOW_SEMCNT" => 2,
    "ANY_MAX_SEMCNT" => 2
  }

  SEMCNT_MAX_NOW = {
    "ANY_NOW_SEMCNT" => 2,
    "ANY_MAX_SEMCNT" => 1
  }

  SEMCNT_MAX_INI = {
    "ANY_INI_SEMCNT" => 2,
    "ANY_MAX_SEMCNT" => 1
  }

  # 固定長メモリプール資源の不具合
  BLKCNT_INI_NOW = {
    "ANY_INI_BLKCNT" => 1,
    "ANY_NOW_BLKCNT" => 2
  }

  # bitmap_search関数カバレッジ網羅用
  BITMAP_LE = {  # TSK_PRI_LE_LE_4は，TSK_PRI_LE_4より小さい整数
    "TSK_PRI_LE_4"    => 2,
    "TSK_PRI_LE_LE_4" => 4
  }

  BITMAP_GE = {  # TSK_PRI_LE_GE_13は，TSK_PRI_GE_13より小さい整数
    "TSK_PRI_GE_13"    => 5,
    "TSK_PRI_LE_GE_13" => 16
  }

  # bit patternのuniq検査
  BIT_PATTERN_A_B = {
    "BIT_PATTERN_A" => 0x00000010,
    "BIT_PATTERN_B" => 0x00000010
  }

  BIT_PATTERN_A_C = {
    "BIT_PATTERN_A" => 0x00000100,
    "BIT_PATTERN_C" => 0x00000100
  }

  BIT_PATTERN_A_D = {
    "BIT_PATTERN_A" => 0x00001000,
    "BIT_PATTERN_D" => 0x00001000
  }

  BIT_PATTERN_A_E = {
    "BIT_PATTERN_A" => 0x00010000,
    "BIT_PATTERN_E" => 0x00010000
  }

  BIT_PATTERN_A_0B = {
    "BIT_PATTERN_A"  => 0x00100000,
    "BIT_PATTERN_0B" => 0x00100000
  }

  BIT_PATTERN_A_0C = {
    "BIT_PATTERN_A"  => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  BIT_PATTERN_B_C = {
    "BIT_PATTERN_B" => 0x00000100,
    "BIT_PATTERN_C" => 0x00000100
  }

  BIT_PATTERN_B_D = {
    "BIT_PATTERN_B" => 0x00001000,
    "BIT_PATTERN_D" => 0x00001000
  }

  BIT_PATTERN_B_E = {
    "BIT_PATTERN_B" => 0x00010000,
    "BIT_PATTERN_E" => 0x00010000
  }

  BIT_PATTERN_B_0B = {
    "BIT_PATTERN_B"  => 0x00100000,
    "BIT_PATTERN_0B" => 0x00100000
  }

  BIT_PATTERN_B_0C = {
    "BIT_PATTERN_B"  => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  BIT_PATTERN_C_D = {
    "BIT_PATTERN_C" => 0x00001000,
    "BIT_PATTERN_D" => 0x00001000
  }

  BIT_PATTERN_C_E = {
    "BIT_PATTERN_C" => 0x00010000,
    "BIT_PATTERN_E" => 0x00010000
  }

  BIT_PATTERN_C_0B = {
    "BIT_PATTERN_C"  => 0x00100000,
    "BIT_PATTERN_0B" => 0x00100000
  }

  BIT_PATTERN_C_0C = {
    "BIT_PATTERN_C"  => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  BIT_PATTERN_D_E = {
    "BIT_PATTERN_D" => 0x00010000,
    "BIT_PATTERN_E" => 0x00010000
  }

  BIT_PATTERN_D_0B = {
    "BIT_PATTERN_D"  => 0x00100000,
    "BIT_PATTERN_0B" => 0x00100000
  }

  BIT_PATTERN_D_0C = {
    "BIT_PATTERN_D"  => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  BIT_PATTERN_E_0B = {
    "BIT_PATTERN_E"  => 0x00100000,
    "BIT_PATTERN_0B" => 0x00100000
  }

  BIT_PATTERN_E_0C = {
    "BIT_PATTERN_E"  => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  BIT_PATTERN_0A_0B = {
    "BIT_PATTERN_0A" => 0x00100000,
    "BIT_PATTERN_0B" => 0x00100000
  }

  BIT_PATTERN_0A_0C = {
    "BIT_PATTERN_0A" => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  BIT_PATTERN_0B_0C = {
    "BIT_PATTERN_0B" => 0x01000000,
    "BIT_PATTERN_0C" => 0x01000000
  }

  # タスク例外のuniq検査
  TEXPTN_A_B = {
    "TEXPTN_A" => 0x00000010,
    "TEXPTN_B" => 0x00000010
  }

  TEXPTN_A_C = {
    "TEXPTN_A" => 0x00000100,
    "TEXPTN_C" => 0x00000100
  }

  TEXPTN_B_C = {
    "TEXPTN_B" => 0x00000100,
    "TEXPTN_C" => 0x00000100
  }

  # 依存性のマクロのファイル名
  CVT_DEPEND_NAME = {
    "tastpri_high_mid"  => TASTPRI_HIGH_MID,
    "tastpri_mid_low"   => TASTPRI_MID_LOW,
    "datapri_high_mid"  => DATAPRI_HIGH_MID,
    "datapri_mid_low"   => DATAPRI_MID_LOW,
    "datapri_low_max"   => DATAPRI_LOW_MAX,
    "msgpri_high_mid"   => MSGPRI_HIGH_MID,
    "msgpri_mid_low"    => MSGPRI_MID_LOW,
    "msgpri_low_max"    => MSGPRI_LOW_MAX,
    "isrpri_high_mid"   => ISRPRI_HIGH_MID,
    "isrpri_mid_low"    => ISRPRI_MID_LOW,
    "semcnt_now_max"    => SEMCNT_NOW_MAX,
    "semcnt_max_now"    => SEMCNT_MAX_NOW,
    "semcnt_max_ini"    => SEMCNT_MAX_INI,
    "blkcnt_ini_now"    => BLKCNT_INI_NOW,
    "bitmap_le"         => BITMAP_LE,
    "bitmap_ge"         => BITMAP_GE,
    "bit_pattern_a_b"   => BIT_PATTERN_A_B,
    "bit_pattern_a_c"   => BIT_PATTERN_A_C,
    "bit_pattern_a_d"   => BIT_PATTERN_A_D,
    "bit_pattern_a_e"   => BIT_PATTERN_A_E,
    "bit_pattern_a_0b"  => BIT_PATTERN_A_0B,
    "bit_pattern_a_0c"  => BIT_PATTERN_A_0C,
    "bit_pattern_b_c"   => BIT_PATTERN_B_C,
    "bit_pattern_b_d"   => BIT_PATTERN_B_D,
    "bit_pattern_b_e"   => BIT_PATTERN_B_E,
    "bit_pattern_b_0b"  => BIT_PATTERN_B_0B,
    "bit_pattern_b_0c"  => BIT_PATTERN_B_0C,
    "bit_pattern_c_d"   => BIT_PATTERN_C_D,
    "bit_pattern_c_e"   => BIT_PATTERN_C_E,
    "bit_pattern_c_0b"  => BIT_PATTERN_C_0B,
    "bit_pattern_c_0c"  => BIT_PATTERN_C_0C,
    "bit_pattern_d_e"   => BIT_PATTERN_D_E,
    "bit_pattern_d_0b"  => BIT_PATTERN_D_0B,
    "bit_pattern_d_0c"  => BIT_PATTERN_D_0C,
    "bit_pattern_e_0b"  => BIT_PATTERN_E_0B,
    "bit_pattern_e_0c"  => BIT_PATTERN_E_0C,
    "bit_pattern_0a_0b" => BIT_PATTERN_0A_0B,
    "bit_pattern_0a_0c" => BIT_PATTERN_0A_0C,
    "bit_pattern_0b_0c" => BIT_PATTERN_0B_0C,
    "texptn_a_b"        => TEXPTN_A_B,
    "texptn_a_c"        => TEXPTN_A_C,
    "texptn_b_c"        => TEXPTN_B_C
  }

  # type検査
  # 文字列と整数 : 真偽値
  # 整数         : 真偽値，文字列
  # 文字列       : 真偽値，整数
  # 真偽値       : 文字列，整数
  CHK_CONFIGURE_TYPE = {
    # configure
    "out_file_name"              => [        Integer, Float, TrueClass, FalseClass],
    "wait_spin_loop"             => [String,          Float, TrueClass, FalseClass],
    "stack_share"                => [String, Integer, Float                       ],
    "all_gain_time"              => [String, Integer, Float                       ],
    "func_time"                  => [String, Integer, Float                       ],
    "func_interrupt"             => [String, Integer, Float                       ],
    "func_exception"             => [String, Integer, Float                       ],
    "exception_arg_name"         => [        Integer, Float, TrueClass, FalseClass],
    "yaml_lib"                   => [        Integer, Float, TrueClass, FalseClass],
    "enable_gcov"                => [String, Integer, Float                       ],
    "enable_log"                 => [String, Integer, Float                       ],
    "prc_num"                    => [String,          Float, TrueClass, FalseClass],
    "main_prcid"                 => [String,          Float, TrueClass, FalseClass],
    "main_class"                 => [        Integer, Float, TrueClass, FalseClass],
    "timer_arch"                 => [        Integer, Float, TrueClass, FalseClass],
    "time_manage_prcid"          => [String,          Float, TrueClass, FalseClass],
    "time_manage_class"          => [        Integer, Float, TrueClass, FalseClass],
    "timer_int_pri"              => [                 Float, TrueClass, FalseClass],
    "spinlock_num"               => [String,          Float, TrueClass, FalseClass],
    "irc_arch"                   => [        Integer, Float, TrueClass, FalseClass],
    "own_ipi_raise"              => [String, Integer, Float                       ],
    "enable_exc_in_cpulock"      => [String, Integer, Float                       ],
    "enable_chg_ipm_in_non_task" => [String, Integer, Float                       ],
    "api_support_get_utm"        => [String, Integer, Float                       ],
    "api_support_ena_int"        => [String, Integer, Float                       ],
    "api_support_dis_int"        => [String, Integer, Float                       ],

    # macro
    "MAIN_PRCID"  => [Float, String, TrueClass, FalseClass],
    "PRC_SELF"    => [Float, String, TrueClass, FalseClass],
    "PRC_OTHER"   => [Float, String, TrueClass, FalseClass],
    "PRC_OTHER_1" => [Float, String, TrueClass, FalseClass],
    "PRC_OTHER_2" => [Float, String, TrueClass, FalseClass],

    "CLS_SELF_ALL"             => [Integer, Float, TrueClass, FalseClass],
    "CLS_OTHER_ALL"            => [Integer, Float, TrueClass, FalseClass],
    "CLS_OTHER_1_ALL"          => [Integer, Float, TrueClass, FalseClass],
    "CLS_OTHER_2_ALL"          => [Integer, Float, TrueClass, FalseClass],
    "CLS_SELF_ONLY_SELF"       => [Integer, Float, TrueClass, FalseClass],
    "CLS_OTHER_ONLY_OTHER"     => [Integer, Float, TrueClass, FalseClass],
    "CLS_OTHER_1_ONLY_OTHER_1" => [Integer, Float, TrueClass, FalseClass],
    "CLS_OTHER_2_ONLY_OTHER_2" => [Integer, Float, TrueClass, FalseClass],

    "INTNO_SELF_INH_A"       => [Float, TrueClass, FalseClass],
    "INTNO_SELF_INH_B"       => [Float, TrueClass, FalseClass],
    "INTNO_SELF_INH_C"       => [Float, TrueClass, FalseClass],
    "INTNO_SELF_ISR_A"       => [Float, TrueClass, FalseClass],
    "INTNO_SELF_ISR_B"       => [Float, TrueClass, FalseClass],
    "INTNO_SELF_ISR_C"       => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_INH_A"      => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_INH_B"      => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_INH_C"      => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_ISR_A"      => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_ISR_B"      => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_ISR_C"      => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_1_INH_A"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_1_INH_B"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_1_INH_C"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_1_ISR_A"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_1_ISR_B"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_1_ISR_C"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_2_INH_A"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_2_INH_B"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_2_INH_C"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_2_ISR_A"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_2_ISR_B"    => [Float, TrueClass, FalseClass],
    "INTNO_OTHER_2_ISR_C"    => [Float, TrueClass, FalseClass],
    "INTNO_GLOBAL_IRC_INH_A" => [Float, TrueClass, FalseClass],
    "INTNO_GLOBAL_IRC_INH_B" => [Float, TrueClass, FalseClass],
    "INTNO_GLOBAL_IRC_INH_C" => [Float, TrueClass, FalseClass],
    "INTNO_GLOBAL_IRC_ISR_A" => [Float, TrueClass, FalseClass],
    "INTNO_GLOBAL_IRC_ISR_B" => [Float, TrueClass, FalseClass],
    "INTNO_GLOBAL_IRC_ISR_C" => [Float, TrueClass, FalseClass],

    "INHNO_SELF_A"            => [Float, TrueClass, FalseClass],
    "INHNO_SELF_B"            => [Float, TrueClass, FalseClass],
    "INHNO_SELF_C"            => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_A"           => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_B"           => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_C"           => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_1_A"         => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_1_B"         => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_1_C"         => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_2_A"         => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_2_B"         => [Float, TrueClass, FalseClass],
    "INHNO_OTHER_2_C"         => [Float, TrueClass, FalseClass],
    "INHNO_GLOBAL_IRC_SELF_A" => [Float, TrueClass, FalseClass],
    "INHNO_GLOBAL_IRC_SELF_B" => [Float, TrueClass, FalseClass],
    "INHNO_GLOBAL_IRC_SELF_C" => [Float, TrueClass, FalseClass],

    "INTNO_INVALID_SELF"    => [Float, TrueClass, FalseClass],
    "INTNO_INVALID_OTHER"   => [Float, TrueClass, FalseClass],
    "INTNO_INVALID_OTHER_1" => [Float, TrueClass, FalseClass],
    "INTNO_INVALID_OTHER_2" => [Float, TrueClass, FalseClass],
    "INTNO_NOT_SET_SELF"    => [Float, TrueClass, FalseClass],
    "INTNO_NOT_SET_OTHER"   => [Float, TrueClass, FalseClass],
    "INTNO_NOT_SET_OTHER_1" => [Float, TrueClass, FalseClass],
    "INTNO_NOT_SET_OTHER_2" => [Float, TrueClass, FalseClass],

    "EXCNO_SELF_A"    => [Float, TrueClass, FalseClass],
    "EXCNO_OTHER_A"   => [Float, TrueClass, FalseClass],
    "EXCNO_OTHER_1_A" => [Float, TrueClass, FalseClass],
    "EXCNO_OTHER_2_A" => [Float, TrueClass, FalseClass],

    "PRC_TIMER_SELF"    => [Float, String, TrueClass, FalseClass],
    "PRC_TIMER_OTHER"   => [Float, String, TrueClass, FalseClass],
    "PRC_TIMER_OTHER_1" => [Float, String, TrueClass, FalseClass],
    "PRC_TIMER_OTHER_2" => [Float, String, TrueClass, FalseClass],

    "CLS_TIMER_SELF_ALL"                   => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_OTHER_ALL"                  => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_OTHER_1_ALL"                => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_OTHER_2_ALL"                => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_ONLY_TIMER"                 => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_OTHER_ONLY_TIMER_OTHER"     => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_OTHER_1_ONLY_TIMER_OTHER_1" => [Integer, Float, TrueClass, FalseClass],
    "CLS_TIMER_OTHER_2_ONLY_TIMER_OTHER_2" => [Integer, Float, TrueClass, FalseClass],

    "INTNO_TIMER_SELF_INH_A"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_SELF_INH_B"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_SELF_INH_C"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_SELF_ISR_A"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_SELF_ISR_B"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_SELF_ISR_C"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_INH_A"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_INH_B"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_INH_C"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_ISR_A"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_ISR_B"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_ISR_C"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_1_INH_A" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_1_INH_B" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_1_INH_C" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_1_ISR_A" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_1_ISR_B" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_1_ISR_C" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_2_INH_A" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_2_INH_B" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_2_INH_C" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_2_ISR_A" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_2_ISR_B" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_OTHER_2_ISR_C" => [Float, TrueClass, FalseClass],

    "INHNO_TIMER_SELF_A"    => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_SELF_B"    => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_SELF_C"    => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_A"   => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_B"   => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_C"   => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_1_A" => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_1_B" => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_1_C" => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_2_A" => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_2_B" => [Float, TrueClass, FalseClass],
    "INHNO_TIMER_OTHER_2_C" => [Float, TrueClass, FalseClass],

    "INTNO_TIMER_INVALID_SELF"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_INVALID_OTHER"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_INVALID_OTHER_1" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_INVALID_OTHER_2" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_NOT_SET_SELF"    => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_NOT_SET_OTHER"   => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_NOT_SET_OTHER_1" => [Float, TrueClass, FalseClass],
    "INTNO_TIMER_NOT_SET_OTHER_2" => [Float, TrueClass, FalseClass],

    "EXCNO_TIMER_SELF_A"    => [Float, TrueClass, FalseClass],
    "EXCNO_TIMER_OTHER_A"   => [Float, TrueClass, FalseClass],
    "EXCNO_TIMER_OTHER_1_A" => [Float, TrueClass, FalseClass],
    "EXCNO_TIMER_OTHER_2_A" => [Float, TrueClass, FalseClass],

    "TSK_PRI_HIGH" => [Float, String, TrueClass, FalseClass],
    "TSK_PRI_MID"  => [Float, String, TrueClass, FalseClass],
    "TSK_PRI_LOW"  => [Float, String, TrueClass, FalseClass],

    "TSK_PRI_LE_4"     => [Float, String, TrueClass, FalseClass],
    "TSK_PRI_LE_LE_4"  => [Float, String, TrueClass, FalseClass],
    "TSK_PRI_GE_13"    => [Float, String, TrueClass, FalseClass],
    "TSK_PRI_LE_GE_13" => [Float, String, TrueClass, FalseClass],

    "DATA_PRI_HIGH" => [Float, String, TrueClass, FalseClass],
    "DATA_PRI_MID"  => [Float, String, TrueClass, FalseClass],
    "DATA_PRI_LOW"  => [Float, String, TrueClass, FalseClass],
    "DATA_PRI_MAX"  => [Float, String, TrueClass, FalseClass],

    "MSG_PRI_HIGH" => [Float, String, TrueClass, FalseClass],
    "MSG_PRI_MID"  => [Float, String, TrueClass, FalseClass],
    "MSG_PRI_LOW"  => [Float, String, TrueClass, FalseClass],
    "MSG_PRI_MAX"  => [Float, String, TrueClass, FalseClass],
    
    "BIT_PATTERN_A" => [Float, String, TrueClass, FalseClass],
    "BIT_PATTERN_B" => [Float, String, TrueClass, FalseClass],
    "BIT_PATTERN_C" => [Float, String, TrueClass, FalseClass],
    "BIT_PATTERN_D" => [Float, String, TrueClass, FalseClass],
    "BIT_PATTERN_E" => [Float, String, TrueClass, FalseClass],

    "BIT_PATTERN_0A" => [Float, String, TrueClass, FalseClass],
    "BIT_PATTERN_0B" => [Float, String, TrueClass, FalseClass],
    "BIT_PATTERN_0C" => [Float, String, TrueClass, FalseClass],

    "WAIT_FLG_MODE_A" => [],
    "WAIT_FLG_MODE_B" => [],
    "WAIT_FLG_MODE_C" => [],
    "WAIT_FLG_MODE_D" => [],
    "WAIT_FLG_MODE_E" => [],

    "DATA_A" => [Float, TrueClass, FalseClass],
    "DATA_B" => [Float, TrueClass, FalseClass],
    "DATA_C" => [Float, TrueClass, FalseClass],
    "DATA_D" => [Float, TrueClass, FalseClass],
    "DATA_E" => [Float, TrueClass, FalseClass],
    "DATA_F" => [Float, TrueClass, FalseClass],

    "EXINF_A" => [Float, TrueClass, FalseClass],
    "EXINF_B" => [Float, TrueClass, FalseClass],
    "EXINF_C" => [Float, TrueClass, FalseClass],
    "EXINF_D" => [Float, TrueClass, FalseClass],
    "EXINF_E" => [Float, TrueClass, FalseClass],

    "FOREVER_TIME"     => [Float, String, TrueClass, FalseClass],
    "ANY_ELAPSED_TIME" => [Float, String, TrueClass, FalseClass],

    "RELATIVE_TIME_A" => [Float, String, TrueClass, FalseClass],
    "RELATIVE_TIME_B" => [Float, String, TrueClass, FalseClass],
    "RELATIVE_TIME_C" => [Float, String, TrueClass, FalseClass],

    "ACTIVATE_ALARM_TIME" => [Float, String, TrueClass, FalseClass],
    "WAIT_ALARM_TIME"     => [Float, String, TrueClass, FalseClass],

    "ANY_MAX_SEMCNT" => [Float, String, TrueClass, FalseClass],
    "ANY_NOW_SEMCNT" => [Float, String, TrueClass, FalseClass],
    "ANY_INI_SEMCNT" => [Float, String, TrueClass, FalseClass],

    "ANY_INI_BLKCNT" => [Float, String, TrueClass, FalseClass],
    "ANY_NOW_BLKCNT" => [Float, String, TrueClass, FalseClass],
    "ANY_BLKSZ"      => [Float, String, TrueClass, FalseClass],

    "TEXPTN_A"  => [Float, String, TrueClass, FalseClass],
    "TEXPTN_B"  => [Float, String, TrueClass, FalseClass],
    "TEXPTN_C"  => [Float, String, TrueClass, FalseClass],
    "TEXPTN_0A" => [Float, String, TrueClass, FalseClass],

    "INT_PRI_TIMER" => [Float, TrueClass, FalseClass],
    "INT_PRI_HIGH"  => [Float, TrueClass, FalseClass],
    "INT_PRI_MID"   => [Float, TrueClass, FalseClass],
    "INT_PRI_LOW"   => [Float, TrueClass, FalseClass],

    "ISR_PRI_HIGH" => [Float, String, TrueClass, FalseClass],
    "ISR_PRI_MID"  => [Float, String, TrueClass, FalseClass],
    "ISR_PRI_LOW"  => [Float, String, TrueClass, FalseClass],

    "ANY_IPM"           => [Float, TrueClass, FalseClass],
    "ANY_IPM_FOR_TIMER" => [Float, TrueClass, FalseClass],

    "ANY_ATT_CYC" => [Float, TrueClass, FalseClass],
    "ANY_ATT_INH" => [Float, TrueClass, FalseClass],
    "ANY_ATT_ISR" => [Float, TrueClass, FalseClass],
    "ANY_ATT_SEM" => [Float, TrueClass, FalseClass],
    "ANY_ATT_FLG" => [Float, TrueClass, FalseClass],
    "ANY_ATT_DTQ" => [Float, TrueClass, FalseClass],
    "ANY_ATT_PDQ" => [Float, TrueClass, FalseClass],
    "ANY_ATT_MBX" => [Float, TrueClass, FalseClass],
    "ANY_ATT_MPF" => [Float, TrueClass, FalseClass],

    "ANY_OBJECT_ID"     => [Float, TrueClass, FalseClass],
    "ANY_TASK_STAT"     => [Float, TrueClass, FalseClass],
    "ANY_TASK_WAIT"     => [Float, TrueClass, FalseClass],
    "ANY_TEX_STAT"      => [Float, TrueClass, FalseClass],
    "ANY_ALARM_STAT"    => [Float, TrueClass, FalseClass],
    "ANY_CYCLIC_STAT"   => [Float, TrueClass, FalseClass],
    "ANY_DATA_CNT"      => [Float, TrueClass, FalseClass],
    "ANY_ADDRESS"       => [Float, TrueClass, FalseClass],
    "ANY_QUEUING_CNT"   => [Float, TrueClass, FalseClass],
    "ANY_SPINLOCK_STAT" => [Float, TrueClass, FalseClass]
  }

  # value検査
  # 0以上の整数     : マイナス，実数
  # 0より大きい整数 : マイナス，実数，0
  # 文字列          : 
  # 特定な文字列    : 任意の文字列
  # 真偽値          : 
  # 0より小さい整数 : プラス，実数，0
  CHK_CONFIGURE_VALUE = {
    # configure
    "out_file_name"              => [],
    "wait_spin_loop"             => [ANY_MINUS],
    "stack_share"                => [],
    "all_gain_time"              => [],
    "func_time"                  => [],
    "func_interrupt"             => [],
    "func_exception"             => [],
    "exception_arg_name"         => [],
    "yaml_lib"                   => [ANY_STRING],
    "enable_gcov"                => [],
    "enable_log"                 => [],
    "prc_num"                    => [ANY_MINUS, ANY_ZERO],
    "main_prcid"                 => [ANY_MINUS, ANY_ZERO],
    "main_class"                 => [],
    "timer_arch"                 => [ANY_STRING],
    "time_manage_prcid"          => [ANY_MINUS, ANY_ZERO],
    "time_manage_class"          => [],
    "timer_int_pri"              => [ANY_PLUS, ANY_ZERO],
    "spinlock_num"               => [ANY_MINUS],
    "irc_arch"                   => [ANY_STRING],
    "own_ipi_raise"              => [],
    "enable_exc_in_cpulock"      => [],
    "enable_chg_ipm_in_non_task" => [],
    "api_support_get_utm"        => [],
    "api_support_ena_int"        => [],
    "api_support_dis_int"        => [],

    # macro
    "MAIN_PRCID"  => [ANY_MINUS, ANY_ZERO],
    "PRC_SELF"    => [ANY_MINUS, ANY_ZERO],
    "PRC_OTHER"   => [ANY_MINUS, ANY_ZERO],
    "PRC_OTHER_1" => [ANY_MINUS, ANY_ZERO],
    "PRC_OTHER_2" => [ANY_MINUS, ANY_ZERO],

    "CLS_SELF_ALL"             => [],
    "CLS_OTHER_ALL"            => [],
    "CLS_OTHER_1_ALL"          => [],
    "CLS_OTHER_2_ALL"          => [],
    "CLS_SELF_ONLY_SELF"       => [],
    "CLS_OTHER_ONLY_OTHER"     => [],
    "CLS_OTHER_1_ONLY_OTHER_1" => [],
    "CLS_OTHER_2_ONLY_OTHER_2" => [],

    "INTNO_SELF_INH_A"       => [ANY_MINUS],
    "INTNO_SELF_INH_B"       => [ANY_MINUS],
    "INTNO_SELF_INH_C"       => [ANY_MINUS],
    "INTNO_SELF_ISR_A"       => [ANY_MINUS],
    "INTNO_SELF_ISR_B"       => [ANY_MINUS],
    "INTNO_SELF_ISR_C"       => [ANY_MINUS],
    "INTNO_OTHER_INH_A"      => [ANY_MINUS],
    "INTNO_OTHER_INH_B"      => [ANY_MINUS],
    "INTNO_OTHER_INH_C"      => [ANY_MINUS],
    "INTNO_OTHER_ISR_A"      => [ANY_MINUS],
    "INTNO_OTHER_ISR_B"      => [ANY_MINUS],
    "INTNO_OTHER_ISR_C"      => [ANY_MINUS],
    "INTNO_OTHER_1_INH_A"    => [ANY_MINUS],
    "INTNO_OTHER_1_INH_B"    => [ANY_MINUS],
    "INTNO_OTHER_1_INH_C"    => [ANY_MINUS],
    "INTNO_OTHER_1_ISR_A"    => [ANY_MINUS],
    "INTNO_OTHER_1_ISR_B"    => [ANY_MINUS],
    "INTNO_OTHER_1_ISR_C"    => [ANY_MINUS],
    "INTNO_OTHER_2_INH_A"    => [ANY_MINUS],
    "INTNO_OTHER_2_INH_B"    => [ANY_MINUS],
    "INTNO_OTHER_2_INH_C"    => [ANY_MINUS],
    "INTNO_OTHER_2_ISR_A"    => [ANY_MINUS],
    "INTNO_OTHER_2_ISR_B"    => [ANY_MINUS],
    "INTNO_OTHER_2_ISR_C"    => [ANY_MINUS],
    "INTNO_GLOBAL_IRC_INH_A" => [ANY_MINUS],
    "INTNO_GLOBAL_IRC_INH_B" => [ANY_MINUS],
    "INTNO_GLOBAL_IRC_INH_C" => [ANY_MINUS],
    "INTNO_GLOBAL_IRC_ISR_A" => [ANY_MINUS],
    "INTNO_GLOBAL_IRC_ISR_B" => [ANY_MINUS],
    "INTNO_GLOBAL_IRC_ISR_C" => [ANY_MINUS],

    "INHNO_SELF_A"            => [ANY_MINUS],
    "INHNO_SELF_B"            => [ANY_MINUS],
    "INHNO_SELF_C"            => [ANY_MINUS],
    "INHNO_OTHER_A"           => [ANY_MINUS],
    "INHNO_OTHER_B"           => [ANY_MINUS],
    "INHNO_OTHER_C"           => [ANY_MINUS],
    "INHNO_OTHER_1_A"         => [ANY_MINUS],
    "INHNO_OTHER_1_B"         => [ANY_MINUS],
    "INHNO_OTHER_1_C"         => [ANY_MINUS],
    "INHNO_OTHER_2_A"         => [ANY_MINUS],
    "INHNO_OTHER_2_B"         => [ANY_MINUS],
    "INHNO_OTHER_2_C"         => [ANY_MINUS],
    "INHNO_GLOBAL_IRC_SELF_A" => [ANY_MINUS],
    "INHNO_GLOBAL_IRC_SELF_B" => [ANY_MINUS],
    "INHNO_GLOBAL_IRC_SELF_C" => [ANY_MINUS],

    "INTNO_INVALID_SELF"    => [ANY_MINUS],
    "INTNO_INVALID_OTHER"   => [ANY_MINUS],
    "INTNO_INVALID_OTHER_1" => [ANY_MINUS],
    "INTNO_INVALID_OTHER_2" => [ANY_MINUS],
    "INTNO_NOT_SET_SELF"    => [ANY_MINUS],
    "INTNO_NOT_SET_OTHER"   => [ANY_MINUS],
    "INTNO_NOT_SET_OTHER_1" => [ANY_MINUS],
    "INTNO_NOT_SET_OTHER_2" => [ANY_MINUS],

    "EXCNO_SELF_A"    => [ANY_MINUS],
    "EXCNO_OTHER_A"   => [ANY_MINUS],
    "EXCNO_OTHER_1_A" => [ANY_MINUS],
    "EXCNO_OTHER_2_A" => [ANY_MINUS],

    "PRC_TIMER_SELF"    => [ANY_MINUS, ANY_ZERO],
    "PRC_TIMER_OTHER"   => [ANY_MINUS, ANY_ZERO],
    "PRC_TIMER_OTHER_1" => [ANY_MINUS, ANY_ZERO],
    "PRC_TIMER_OTHER_2" => [ANY_MINUS, ANY_ZERO],

    "CLS_TIMER_SELF_ALL"                   => [],
    "CLS_TIMER_OTHER_ALL"                  => [],
    "CLS_TIMER_OTHER_1_ALL"                => [],
    "CLS_TIMER_OTHER_2_ALL"                => [],
    "CLS_TIMER_ONLY_TIMER"                 => [],
    "CLS_TIMER_OTHER_ONLY_TIMER_OTHER"     => [],
    "CLS_TIMER_OTHER_1_ONLY_TIMER_OTHER_1" => [],
    "CLS_TIMER_OTHER_2_ONLY_TIMER_OTHER_2" => [],

    "INTNO_TIMER_SELF_INH_A"    => [ANY_MINUS],
    "INTNO_TIMER_SELF_INH_B"    => [ANY_MINUS],
    "INTNO_TIMER_SELF_INH_C"    => [ANY_MINUS],
    "INTNO_TIMER_SELF_ISR_A"    => [ANY_MINUS],
    "INTNO_TIMER_SELF_ISR_B"    => [ANY_MINUS],
    "INTNO_TIMER_SELF_ISR_C"    => [ANY_MINUS],
    "INTNO_TIMER_OTHER_INH_A"   => [ANY_MINUS],
    "INTNO_TIMER_OTHER_INH_B"   => [ANY_MINUS],
    "INTNO_TIMER_OTHER_INH_C"   => [ANY_MINUS],
    "INTNO_TIMER_OTHER_ISR_A"   => [ANY_MINUS],
    "INTNO_TIMER_OTHER_ISR_B"   => [ANY_MINUS],
    "INTNO_TIMER_OTHER_ISR_C"   => [ANY_MINUS],
    "INTNO_TIMER_OTHER_1_INH_A" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_1_INH_B" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_1_INH_C" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_1_ISR_A" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_1_ISR_B" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_1_ISR_C" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_2_INH_A" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_2_INH_B" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_2_INH_C" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_2_ISR_A" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_2_ISR_B" => [ANY_MINUS],
    "INTNO_TIMER_OTHER_2_ISR_C" => [ANY_MINUS],

    "INHNO_TIMER_SELF_A"    => [ANY_MINUS],
    "INHNO_TIMER_SELF_B"    => [ANY_MINUS],
    "INHNO_TIMER_SELF_C"    => [ANY_MINUS],
    "INHNO_TIMER_OTHER_A"   => [ANY_MINUS],
    "INHNO_TIMER_OTHER_B"   => [ANY_MINUS],
    "INHNO_TIMER_OTHER_C"   => [ANY_MINUS],
    "INHNO_TIMER_OTHER_1_A" => [ANY_MINUS],
    "INHNO_TIMER_OTHER_1_B" => [ANY_MINUS],
    "INHNO_TIMER_OTHER_1_C" => [ANY_MINUS],
    "INHNO_TIMER_OTHER_2_A" => [ANY_MINUS],
    "INHNO_TIMER_OTHER_2_B" => [ANY_MINUS],
    "INHNO_TIMER_OTHER_2_C" => [ANY_MINUS],

    "INTNO_TIMER_INVALID_SELF"    => [ANY_MINUS],
    "INTNO_TIMER_INVALID_OTHER"   => [ANY_MINUS],
    "INTNO_TIMER_INVALID_OTHER_1" => [ANY_MINUS],
    "INTNO_TIMER_INVALID_OTHER_2" => [ANY_MINUS],
    "INTNO_TIMER_NOT_SET_SELF"    => [ANY_MINUS],
    "INTNO_TIMER_NOT_SET_OTHER"   => [ANY_MINUS],
    "INTNO_TIMER_NOT_SET_OTHER_1" => [ANY_MINUS],
    "INTNO_TIMER_NOT_SET_OTHER_2" => [ANY_MINUS],

    "EXCNO_TIMER_SELF_A"    => [ANY_MINUS],
    "EXCNO_TIMER_OTHER_A"   => [ANY_MINUS],
    "EXCNO_TIMER_OTHER_1_A" => [ANY_MINUS],
    "EXCNO_TIMER_OTHER_2_A" => [ANY_MINUS],

    "TSK_PRI_HIGH" => [ANY_MINUS, ANY_ZERO, TASTPRI_HIGH_MID],
    "TSK_PRI_MID"  => [ANY_MINUS, ANY_ZERO, TASTPRI_MID_LOW],
    "TSK_PRI_LOW"  => [ANY_MINUS, ANY_ZERO],

    "TSK_PRI_LE_4"     => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_LE_4_LOWER, ANY_TSK_PRI_LE_4_UPPER],
    "TSK_PRI_LE_LE_4"  => [ANY_MINUS, ANY_ZERO, BITMAP_LE],
    "TSK_PRI_GE_13"    => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_GE_13_LOWER, ANY_TSK_PRI_GE_13_UPPER],
    "TSK_PRI_LE_GE_13" => [ANY_MINUS, ANY_ZERO, BITMAP_GE],

    "DATA_PRI_HIGH" => [ANY_MINUS, ANY_ZERO, DATAPRI_HIGH_MID],
    "DATA_PRI_MID"  => [ANY_MINUS, ANY_ZERO, DATAPRI_MID_LOW],
    "DATA_PRI_LOW"  => [ANY_MINUS, ANY_ZERO, DATAPRI_LOW_MAX],
    "DATA_PRI_MAX"  => [ANY_MINUS, ANY_ZERO],

    "MSG_PRI_HIGH" => [ANY_MINUS, ANY_ZERO, MSGPRI_HIGH_MID],
    "MSG_PRI_MID"  => [ANY_MINUS, ANY_ZERO, MSGPRI_MID_LOW],
    "MSG_PRI_LOW"  => [ANY_MINUS, ANY_ZERO, MSGPRI_LOW_MAX],
    "MSG_PRI_MAX"  => [ANY_MINUS, ANY_ZERO],

    "BIT_PATTERN_A" => [ANY_MINUS, ANY_ZERO, BIT_PATTERN_A_B,  BIT_PATTERN_A_C,  BIT_PATTERN_A_D,  BIT_PATTERN_A_E,  BIT_PATTERN_A_0B, BIT_PATTERN_A_0C],
    "BIT_PATTERN_B" => [ANY_MINUS, ANY_ZERO, BIT_PATTERN_B_C,  BIT_PATTERN_B_D,  BIT_PATTERN_B_E,  BIT_PATTERN_B_0B, BIT_PATTERN_B_0C],
    "BIT_PATTERN_C" => [ANY_MINUS, ANY_ZERO, BIT_PATTERN_C_D,  BIT_PATTERN_C_E,  BIT_PATTERN_C_0B, BIT_PATTERN_C_0C],
    "BIT_PATTERN_D" => [ANY_MINUS, ANY_ZERO, BIT_PATTERN_D_E,  BIT_PATTERN_D_0B, BIT_PATTERN_D_0C],
    "BIT_PATTERN_E" => [ANY_MINUS, ANY_ZERO, BIT_PATTERN_E_0B, BIT_PATTERN_E_0C],

    "BIT_PATTERN_0A" => [ANY_MINUS, BIT_PATTERN_0A_0B, BIT_PATTERN_0A_0C],
    "BIT_PATTERN_0B" => [ANY_MINUS, BIT_PATTERN_0B_0C],
    "BIT_PATTERN_0C" => [ANY_MINUS],

    "WAIT_FLG_MODE_A" => [ANY_STRING],
    "WAIT_FLG_MODE_B" => [ANY_STRING],
    "WAIT_FLG_MODE_C" => [ANY_STRING],
    "WAIT_FLG_MODE_D" => [ANY_STRING],
    "WAIT_FLG_MODE_E" => [ANY_STRING],

    "DATA_A" => [],
    "DATA_B" => [],
    "DATA_C" => [],
    "DATA_D" => [],
    "DATA_E" => [],
    "DATA_F" => [],

    "EXINF_A" => [],
    "EXINF_B" => [],
    "EXINF_C" => [],
    "EXINF_D" => [],
    "EXINF_E" => [],

    "FOREVER_TIME"     => [ANY_MINUS, ANY_ZERO],
    "ANY_ELAPSED_TIME" => [ANY_MINUS, ANY_ZERO],

    "RELATIVE_TIME_A" => [ANY_MINUS],
    "RELATIVE_TIME_B" => [ANY_MINUS],
    "RELATIVE_TIME_C" => [ANY_MINUS],

    "ACTIVATE_ALARM_TIME" => [ANY_MINUS, ANY_ZERO],
    "WAIT_ALARM_TIME"     => [ANY_MINUS, ANY_ZERO],

    "ANY_MAX_SEMCNT" => [ANY_MINUS, ANY_ZERO, SEMCNT_NOW_MAX],
    "ANY_NOW_SEMCNT" => [ANY_MINUS, ANY_ZERO, SEMCNT_MAX_NOW],
    "ANY_INI_SEMCNT" => [ANY_MINUS, SEMCNT_MAX_INI],

    "ANY_INI_BLKCNT" => [ANY_MINUS, ANY_ZERO, BLKCNT_INI_NOW],
    "ANY_NOW_BLKCNT" => [ANY_MINUS, ANY_ZERO],
    "ANY_BLKSZ"      => [ANY_MINUS, ANY_ZERO],

    "TEXPTN_A"  => [ANY_MINUS, ANY_ZERO, TEXPTN_A_B,  TEXPTN_A_C],
    "TEXPTN_B"  => [ANY_MINUS, ANY_ZERO, TEXPTN_B_C],
    "TEXPTN_C"  => [ANY_MINUS, ANY_ZERO],
    "TEXPTN_0A" => [ANY_MINUS],

    "INT_PRI_TIMER" => [ANY_PLUS, ANY_ZERO],
    "INT_PRI_HIGH"  => [ANY_PLUS, ANY_ZERO],
    "INT_PRI_MID"   => [ANY_PLUS, ANY_ZERO],
    "INT_PRI_LOW"   => [ANY_PLUS, ANY_ZERO],

    "ISR_PRI_HIGH" => [ANY_MINUS, ANY_ZERO, ISRPRI_HIGH_MID],
    "ISR_PRI_MID"  => [ANY_MINUS, ANY_ZERO, ISRPRI_MID_LOW],
    "ISR_PRI_LOW"  => [ANY_MINUS, ANY_ZERO],

    "ANY_IPM"           => [ANY_PLUS, ANY_ZERO],
    "ANY_IPM_FOR_IPI"   => [ANY_PLUS, ANY_ZERO],

    "ANY_ATT_CYC" => [ANY_MINUS],
    "ANY_ATT_INH" => [ANY_MINUS],
    "ANY_ATT_ISR" => [ANY_MINUS],
    "ANY_ATT_SEM" => [ANY_MINUS],
    "ANY_ATT_FLG" => [ANY_MINUS],
    "ANY_ATT_DTQ" => [ANY_MINUS],
    "ANY_ATT_PDQ" => [ANY_MINUS],
    "ANY_ATT_MBX" => [ANY_MINUS],
    "ANY_ATT_MPF" => [ANY_MINUS],

    "ANY_OBJECT_ID"     => [ANY_MINUS],
    "ANY_TASK_STAT"     => [ANY_MINUS],
    "ANY_TASK_WAIT"     => [ANY_MINUS],
    "ANY_TEX_STAT"      => [ANY_MINUS],
    "ANY_ALARM_STAT"    => [ANY_MINUS],
    "ANY_CYCLIC_STAT"   => [ANY_MINUS],
    "ANY_DATA_CNT"      => [ANY_MINUS],
    "ANY_ADDRESS"       => [ANY_MINUS],
    "ANY_QUEUING_CNT"   => [ANY_MINUS],
    "ANY_SPINLOCK_STAT" => [ANY_MINUS]
  }

  #=====================================================================
  # T2: attributeのマクロ
  #=====================================================================
  # doに必要なファイルのパス
  ANY_T2_TESRY_DO = TTSP_PATH + "/api_test/ASP/mailbox/ini_mbx/ini_mbx_b-1.yaml"

  # ASPファイルのパス
  ANY_T2_ASP_TESRY_TASK          = TTSP_PATH + "/api_test/ASP/task_manage/act_tsk/act_tsk_c-2.yaml"
  ANY_T2_ASP_TESRY_ALARM         = TTSP_PATH + "/api_test/ASP/alarm/sta_alm/sta_alm_c-1.yaml"
  ANY_T2_ASP_TESRY_CYCLE         = TTSP_PATH + "/api_test/ASP/cyclic/stp_cyc/stp_cyc_c.yaml"
  ANY_T2_ASP_TESRY_TASK_EXC      = TTSP_PATH + "/api_test/ASP/task_except/ras_tex/ras_tex_c.yaml"
  ANY_T2_ASP_TESRY_EXCEPTION     = TTSP_PATH + "/api_test/ASP/exception/xsns_dpn/xsns_dpn_a.yaml"
  ANY_T2_ASP_TESRY_INTHDR        = TTSP_PATH + "/api_test/ASP/interrupt/dis_int/dis_int_d-1.yaml"
  ANY_T2_ASP_TESRY_ISR           = TTSP_PATH + "/tools/ttg/test/just_in_case/asp/isr_1.yaml"
  ANY_T2_ASP_TESRY_INIRTN        = TTSP_PATH + "/api_test/ASP/sys_manage/sns_ker/sns_ker_a.yaml"
  ANY_T2_ASP_TESRY_TERRTN        = TTSP_PATH + "/api_test/ASP/sys_manage/sns_ker/sns_ker_b.yaml"
  ANY_T2_ASP_TESRY_SEMAPHORE     = TTSP_PATH + "/api_test/ASP/semaphore/ini_sem/ini_sem_b-2.yaml"
  ANY_T2_ASP_TESRY_EVENTFLAG     = TTSP_PATH + "/api_test/ASP/eventflag/set_flg/set_flg_e-1-1.yaml"
  ANY_T2_ASP_TESRY_DATAQUEUE     = TTSP_PATH + "/api_test/ASP/dataqueue/ini_dtq/ini_dtq_b-1.yaml"
  ANY_T2_ASP_TESRY_DATAQUEUE_1   = TTSP_PATH + "/api_test/ASP/dataqueue/ini_dtq/ini_dtq_c-2-1.yaml"
  ANY_T2_ASP_TESRY_DATAQUEUE_2   = TTSP_PATH + "/api_test/ASP/dataqueue/fsnd_dtq/fsnd_dtq_d-1-1-1.yaml"
  ANY_T2_ASP_TESRY_P_DATAQUEUE   = TTSP_PATH + "/api_test/ASP/pridataq/ini_pdq/ini_pdq_b-1.yaml"
  ANY_T2_ASP_TESRY_P_DATAQUEUE_1 = TTSP_PATH + "/api_test/ASP/pridataq/prcv_pdq/prcv_pdq_d-2-2-1-1.yaml"
  ANY_T2_ASP_TESRY_P_DATAQUEUE_2 = TTSP_PATH + "/api_test/ASP/pridataq/ipsnd_pdq/ipsnd_pdq_e-1-1-2.yaml"
  ANY_T2_ASP_TESRY_MAILBOX       = TTSP_PATH + "/api_test/ASP/mailbox/ini_mbx/ini_mbx_b-1.yaml"
  ANY_T2_ASP_TESRY_MAILBOX_1     = TTSP_PATH + "/api_test/ASP/mailbox/snd_mbx/snd_mbx_e-2-2.yaml"
  ANY_T2_ASP_TESRY_MAILBOX_2     = TTSP_PATH + "/api_test/ASP/mailbox/ref_mbx/ref_mbx_c-1.yaml"
  ANY_T2_ASP_TESRY_MEMORYPOOL    = TTSP_PATH + "/api_test/ASP/mempfix/get_mpf/get_mpf_g-1-1.yaml"
  ANY_T2_ASP_TESRY_CPU_STATE     = TTSP_PATH + "/api_test/ASP/alarm/stp_alm/stp_alm_a-2.yaml"

  # FMPファイルのパス
  ANY_T2_FMP_TESRY_TASK          = TTSP_PATH + "/api_test/FMP/task_manage/act_tsk/act_tsk_F-b-3.yaml"
  ANY_T2_FMP_TESRY_ALARM         = TTSP_PATH + "/api_test/FMP/alarm/sta_alm/sta_alm_F-b-1.yaml"
  ANY_T2_FMP_TESRY_CYCLE         = TTSP_PATH + "/api_test/FMP/cyclic/stp_cyc/stp_cyc_F-b.yaml"
  ANY_T2_FMP_TESRY_TASK_EXC      = TTSP_PATH + "/api_test/FMP/task_except/ras_tex/ras_tex_F-b.yaml"
  ANY_T2_FMP_TESRY_EXCEPTION     = TTSP_PATH + "/api_test/FMP/exception/xsns_dpn/xsns_dpn_F-a.yaml"
  ANY_T2_FMP_TESRY_INTHDR        = TTSP_PATH + "/api_test/FMP/interrupt/dis_int/dis_int_F-b-1.yaml"
  ANY_T2_FMP_TESRY_ISR           = ANY_T2_ASP_TESRY_ISR
  ANY_T2_FMP_TESRY_INIRTN        = TTSP_PATH + "/api_test/FMP/sys_manage/sns_ker/sns_ker_F-a.yaml"
  ANY_T2_FMP_TESRY_TERRTN        = TTSP_PATH + "/api_test/FMP/sys_manage/sns_ker/sns_ker_F-b.yaml"
  ANY_T2_FMP_TESRY_SEMAPHORE     = TTSP_PATH + "/api_test/FMP/semaphore/ini_sem/ini_sem_F-b-1-1-1.yaml"
  ANY_T2_FMP_TESRY_EVENTFLAG     = TTSP_PATH + "/api_test/FMP/eventflag/set_flg/set_flg_F-c-1-1.yaml"
  ANY_T2_FMP_TESRY_DATAQUEUE     = TTSP_PATH + "/api_test/FMP/dataqueue/ini_dtq/ini_dtq_F-b-1-1-1.yaml"
  ANY_T2_FMP_TESRY_DATAQUEUE_1   = TTSP_PATH + "/api_test/FMP/dataqueue/ini_dtq/ini_dtq_F-b-2-1.yaml"
  ANY_T2_FMP_TESRY_DATAQUEUE_2   = TTSP_PATH + "/api_test/FMP/dataqueue/fsnd_dtq/fsnd_dtq_F-b-1-1-1.yaml"
  ANY_T2_FMP_TESRY_P_DATAQUEUE   = TTSP_PATH + "/api_test/FMP/pridataq/ini_pdq/ini_pdq_F-b-1-1-1.yaml"
  ANY_T2_FMP_TESRY_P_DATAQUEUE_1 = TTSP_PATH + "/api_test/FMP/pridataq/prcv_pdq/prcv_pdq_F-b-2-1-1.yaml"
  ANY_T2_FMP_TESRY_P_DATAQUEUE_2 = TTSP_PATH + "/api_test/FMP/pridataq/ipsnd_pdq/ipsnd_pdq_F-b-1-1-2.yaml"
  ANY_T2_FMP_TESRY_MAILBOX       = TTSP_PATH + "/api_test/FMP/mailbox/ini_mbx/ini_mbx_F-b-1-1-1.yaml"
  ANY_T2_FMP_TESRY_MAILBOX_1     = ANY_T2_ASP_TESRY_MAILBOX_1
  ANY_T2_FMP_TESRY_MAILBOX_2     = ANY_T2_ASP_TESRY_MAILBOX_2
  ANY_T2_FMP_TESRY_MEMORYPOOL    = TTSP_PATH + "/api_test/FMP/mempfix/get_mpf/get_mpf_F-e-1-1.yaml"
  ANY_T2_FMP_TESRY_SPINLOCK      = TTSP_PATH + "/api_test/FMP/spin_lock/loc_spn/loc_spn_F-b-2.yaml"
  ANY_T2_FMP_TESRY_CPU_STATE     = TTSP_PATH + "/api_test/FMP/alarm/stp_alm/stp_alm_F-a-1-2.yaml"

  # オブジェクトごとのFMPのみ指定可能な属性
  ATT_FMP_DEFINED_TO_OBJECT = {
    TSR_OBJ_TASK        => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_SPINID, TSR_PRM_ACTPRC],
    TSR_OBJ_ALARM       => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_SPINID],
    TSR_OBJ_CYCLE       => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_SPINID],
    TSR_OBJ_TASK_EXC    => [TSR_PRM_SPINID],
    TSR_OBJ_EXCEPTION   => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_SPINID],
    TSR_OBJ_INTHDR      => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_SPINID],
    TSR_OBJ_ISR         => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_SPINID],
    TSR_OBJ_INIRTN      => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_GLOBAL],
    TSR_OBJ_TERRTN      => [TSR_PRM_CLASS, TSR_PRM_PRCID, TSR_PRM_GLOBAL],
    TSR_OBJ_SEMAPHORE   => [TSR_PRM_CLASS],
    TSR_OBJ_EVENTFLAG   => [TSR_PRM_CLASS],
    TSR_OBJ_DATAQUEUE   => [TSR_PRM_CLASS],
    TSR_OBJ_P_DATAQUEUE => [TSR_PRM_CLASS],
    TSR_OBJ_MAILBOX     => [TSR_PRM_CLASS],
    TSR_OBJ_MEMORYPOOL  => [TSR_PRM_CLASS],
    TSR_OBJ_SPINLOCK    => [TSR_PRM_SPNSTAT, TSR_PRM_CLASS, TSR_PRM_PROCID],
    TSR_OBJ_CPU_STATE   => [TSR_PRM_PRCID]
  }

  # ANY VALUE
  ANY_EMPTY         = ""
  ANY_QUEUING_LOWER = -1
  ANY_QUEUING_UPPER = TTC_MAX_QUEUING + 1
  ANY_TSK_PRI_UPPER = TTC_MIN_PRI + 1

  # マクロの置換
  CVT_ATTRIBUTE_VALUE = {
    Array      => ["array"],
    Hash       => {"key" => "val"},
    String     => "string",
    Float      => 1.0,
    Integer    => 0,
    TrueClass  => true,
    FalseClass => false,
    NilClass   => "",

    ANY_ZERO          => ANY_ZERO,
    ANY_PLUS          => ANY_PLUS,
    ANY_MINUS         => ANY_MINUS,
    ANY_STRING        => ANY_STRING,
    ANY_QUEUING_LOWER => ANY_QUEUING_LOWER,
    ANY_QUEUING_UPPER => ANY_QUEUING_UPPER,
    ANY_TSK_PRI_UPPER => ANY_TSK_PRI_UPPER
  }

  # ファイル変換名
  CVT_ATTRIBUTE_NAME = {
    Array      => "array",
    Hash       => "hash",
    String     => "string",
    Integer    => "number",
    Float      => "float",
    TrueClass  => "true",
    FalseClass => "false",
    NilClass   => "null",

    ANY_ZERO          => "zero",
    ANY_PLUS          => "plus",
    ANY_MINUS         => "minus",
    ANY_STRING        => "string",
    ANY_QUEUING_LOWER => "lower",
    ANY_QUEUING_UPPER => "upper",
    ANY_TSK_PRI_UPPER => "upper"
  }

  # type検査
  # 配列         : [      ハッシュ，文字列，整数，真偽値, null]
  # ハッシュ     : [配列，          文字列，整数，真偽値, null]
  # 文字列       : [配列，ハッシュ，        整数，真偽値, null]
  # 整数         : [配列，ハッシュ，文字列，      真偽値, null]
  # 真偽値       : [配列，ハッシュ，文字列，整数,         null]
  # 文字列と整数 : [配列，ハッシュ，              真偽値, null]
  CHK_ATTRIBUTE_TYPE = {
    TSR_OBJ_TASK => {
      TSR_PRM_TSKSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_TSKPRI   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_ITSKPRI  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_EXINF    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_ACTCNT   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_WUPCNT   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_WOBJID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_PORDER   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_LEFTTMO  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_ACTPRC   => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_ALARM => {
      TSR_PRM_ALMSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_HDLSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_EXINF    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_LEFTTIM  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_CYCLE => {
      TSR_PRM_CYCSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CYCATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_HDLSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CYCTIM   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CYCPHS   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_EXINF    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_LEFTTIM  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_TASK_EXC => {
      TSR_PRM_TASK     => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_TEXSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_HDLSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_TEXPTN   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PNDPTN   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_EXCEPTION => {
      TSR_PRM_EXCNO    => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_HDLSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_INTHDR => {
      TSR_PRM_INTNO    => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INHNO    => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INTPRI   => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INTSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_HDLSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INTATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_ISR => {
      TSR_PRM_INTNO    => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INTPRI   => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INTSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_HDLSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_INTATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_ISRPRI   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_EXINF    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOTCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_VAR      => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SPINID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_INIRTN => {
      TSR_PRM_DO       => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_GLOBAL   => [Array, Hash, String, Integer, Float,                        NilClass],
      TSR_PRM_EXINF    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_TERRTN => {
      TSR_PRM_DO       => [Array,       String, Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_GLOBAL   => [Array, Hash, String, Integer, Float,                        NilClass],
      TSR_PRM_EXINF    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_SEMAPHORE => {
      TSR_PRM_SEMATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_MAXSEM   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_ISEMCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SEMCNT   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_WTSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass,         ]
    },

    TSR_OBJ_EVENTFLAG => {
      TSR_PRM_FLGATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_IFLGPTN  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_FLGPTN   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_WTSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_VAR_WAIPTN   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_WFMODE   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_VAR      => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_DATAQUEUE => {
      TSR_PRM_DTQATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_DTQCNT   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_STSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_RTSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_DATALIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_VAR_DATA     => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_VAR      => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_P_DATAQUEUE => {
      TSR_PRM_PDQATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_MAXDPRI  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PDQCNT   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_STSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_RTSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_DATALIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_VAR_DATA     => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_DATAPRI  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_VARDATA  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_VARPRI   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_MAILBOX => {
      TSR_PRM_MBXATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_MAXMPRI  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_WTSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_MSGLIST  => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_VAR_VAR      => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_MSG      => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_MSGPRI   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_MEMORYPOOL => {
      TSR_PRM_MPFATR   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BLKCNT   => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_FBLKCNT  => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BLKSZ    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_WTSKLIST => [       Hash, String, Integer, Float, TrueClass, FalseClass          ],
      TSR_PRM_MPF      => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_VAR_VAR      => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_SPINLOCK => {
      TSR_PRM_SPNSTAT  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_CLASS    => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_PROCID   => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    },

    TSR_OBJ_CPU_STATE => {
      TSR_PRM_CHGIPM   => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_LOCCPU   => [Array, Hash, String, Integer, Float,                        NilClass],
      TSR_PRM_DISDSP   => [Array, Hash, String, Integer, Float,                        NilClass],
      TSR_PRM_PRCID    => [Array, Hash, String,          Float, TrueClass, FalseClass, NilClass]
    },

    TSR_LBL_DO => {
      TSR_PRM_ID       => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_SYSCALL  => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_GCOV     => [Array, Hash, String, Integer, Float,                        NilClass],
      TSR_PRM_ERCD     => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_ERUINT   => [Array, Hash,                  Float, TrueClass, FalseClass, NilClass],
      TSR_PRM_BOOL     => [Array, Hash, String, Integer, Float,                        NilClass],
      TSR_PRM_CODE     => [Array, Hash,         Integer, Float, TrueClass, FalseClass, NilClass]
    }
  }

  # value検査
  # 0以上の整数     : マイナス，実数
  # 0より大きい整数 : マイナス，実数，0
  # 文字列          : 
  # 特定な文字列    : 任意の文字列
  # 真偽値          : 
  # 0より小さい整数 : プラス，実数，0
  # varの場合はT3_VARxxxで検査している
  CHK_ATTRIBUTE_VALUE = {
    TSR_OBJ_TASK => {
      TSR_PRM_TSKSTAT  => [ANY_STRING],
      TSR_PRM_TSKPRI   => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER],
      TSR_PRM_ITSKPRI  => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER],
      TSR_PRM_EXINF    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_ACTCNT   => [ANY_QUEUING_LOWER, ANY_QUEUING_UPPER],
      TSR_PRM_WUPCNT   => [ANY_QUEUING_LOWER, ANY_QUEUING_UPPER],
      TSR_PRM_WOBJID   => [],
      TSR_PRM_PORDER   => [ANY_MINUS],
      TSR_PRM_LEFTTMO  => [ANY_MINUS],
      TSR_PRM_ACTPRC   => [ANY_MINUS],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_ALARM => {
      TSR_PRM_ALMSTAT  => [ANY_STRING],
      TSR_PRM_HDLSTAT  => [ANY_STRING],
      TSR_PRM_EXINF    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_LEFTTIM  => [ANY_MINUS],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_CYCLE => {
      TSR_PRM_CYCSTAT  => [ANY_STRING],
      TSR_PRM_CYCATR   => [ANY_STRING],
      TSR_PRM_HDLSTAT  => [ANY_STRING],
      TSR_PRM_CYCTIM   => [ANY_MINUS],
      TSR_PRM_CYCPHS   => [ANY_MINUS],
      TSR_PRM_EXINF    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_LEFTTIM  => [ANY_MINUS],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_TASK_EXC => {
      TSR_PRM_TASK     => [],
      TSR_PRM_TEXSTAT  => [ANY_STRING],
      TSR_PRM_HDLSTAT  => [ANY_STRING],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_TEXPTN   => [ANY_MINUS],
      TSR_PRM_PNDPTN   => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_EXCEPTION => {
      TSR_PRM_EXCNO    => [ANY_MINUS],
      TSR_PRM_HDLSTAT  => [ANY_STRING],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_INTHDR => {
      TSR_PRM_INTNO    => [ANY_MINUS],
      TSR_PRM_INHNO    => [ANY_MINUS],
      TSR_PRM_INTPRI   => [ANY_PLUS, ANY_ZERO],
      TSR_PRM_INTSTAT  => [ANY_STRING],
      TSR_PRM_HDLSTAT  => [ANY_STRING],
      TSR_PRM_INTATR   => [ANY_STRING],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_ISR => {
      TSR_PRM_INTNO    => [ANY_MINUS],
      TSR_PRM_INTPRI   => [ANY_PLUS, ANY_ZERO],
      TSR_PRM_INTSTAT  => [ANY_STRING],
      TSR_PRM_HDLSTAT  => [ANY_STRING],
      TSR_PRM_INTATR   => [ANY_STRING],
      TSR_PRM_ISRPRI   => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER],
      TSR_PRM_EXINF    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO],
      TSR_PRM_BOOTCNT  => [ANY_MINUS],
      TSR_PRM_VAR      => [],
      TSR_PRM_SPINID   => []
    },

    TSR_OBJ_INIRTN => {
      TSR_PRM_DO       => [],
      TSR_PRM_GLOBAL   => [],
      TSR_PRM_EXINF    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO]
    },

    TSR_OBJ_TERRTN => {
      TSR_PRM_DO       => [],
      TSR_PRM_GLOBAL   => [],
      TSR_PRM_EXINF    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO]
    },

    TSR_OBJ_SEMAPHORE => {
      TSR_PRM_SEMATR   => [ANY_STRING],
      TSR_PRM_MAXSEM   => [ANY_MINUS],
      TSR_PRM_ISEMCNT  => [ANY_MINUS],
      TSR_PRM_SEMCNT   => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_WTSKLIST => []
    },

    TSR_OBJ_EVENTFLAG => {
      TSR_PRM_FLGATR   => [ANY_STRING],
      TSR_PRM_IFLGPTN  => [ANY_MINUS],
      TSR_PRM_FLGPTN   => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_WTSKLIST => [],
      TSR_VAR_WAIPTN   => [ANY_MINUS],
      TSR_VAR_WFMODE   => [ANY_STRING],
      TSR_VAR_VAR      => []
    },

    TSR_OBJ_DATAQUEUE => {
      TSR_PRM_DTQATR   => [ANY_STRING],
      TSR_PRM_DTQCNT   => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_STSKLIST => [],
      TSR_PRM_RTSKLIST => [],
      TSR_PRM_DATALIST => [],
      TSR_VAR_DATA     => [],
      TSR_VAR_VAR      => []
    },

    TSR_OBJ_P_DATAQUEUE => {
      TSR_PRM_PDQATR   => [ANY_STRING],
      TSR_PRM_MAXDPRI  => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER],
      TSR_PRM_PDQCNT   => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_STSKLIST => [],
      TSR_PRM_RTSKLIST => [],
      TSR_PRM_DATALIST => [],
      TSR_VAR_DATA     => [],
      TSR_VAR_DATAPRI  => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER],
      TSR_VAR_VARDATA  => [],
      TSR_VAR_VARPRI   => []
    },

    TSR_OBJ_MAILBOX => {
      TSR_PRM_MBXATR   => [ANY_STRING],
      TSR_PRM_MAXMPRI  => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER],
      TSR_PRM_CLASS    => [],
      TSR_PRM_WTSKLIST => [],
      TSR_PRM_MSGLIST  => [],
      TSR_VAR_VAR      => [],
      TSR_VAR_MSG      => [],
      TSR_VAR_MSGPRI   => [ANY_MINUS, ANY_ZERO, ANY_TSK_PRI_UPPER]
    },

    TSR_OBJ_MEMORYPOOL => {
      TSR_PRM_MPFATR   => [ANY_STRING],
      TSR_PRM_BLKCNT   => [ANY_MINUS],
      TSR_PRM_FBLKCNT  => [ANY_MINUS],
      TSR_PRM_BLKSZ    => [ANY_MINUS],
      TSR_PRM_CLASS    => [],
      TSR_PRM_WTSKLIST => [],
      TSR_PRM_MPF      => [],
      TSR_VAR_VAR      => []
    },

    TSR_OBJ_SPINLOCK => {
      TSR_PRM_SPNSTAT  => [ANY_STRING],
      TSR_PRM_CLASS    => [],
      TSR_PRM_PROCID   => []
    },

    TSR_OBJ_CPU_STATE => {
      TSR_PRM_CHGIPM   => [ANY_PLUS],
      TSR_PRM_LOCCPU   => [],
      TSR_PRM_DISDSP   => [],
      TSR_PRM_PRCID    => [ANY_MINUS, ANY_ZERO]
    },

    TSR_LBL_DO => {
      TSR_PRM_ID       => [],
      TSR_PRM_SYSCALL  => [],
      TSR_PRM_GCOV     => [],
      TSR_PRM_ERCD     => [],
      TSR_PRM_ERUINT   => [],
      TSR_PRM_BOOL     => [],
      TSR_PRM_CODE     => []
    }
  }
end
