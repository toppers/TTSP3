#
#  TTSP3
#      TOPPERS Test Suite Package 3
#
#  Copyright (C) 2009-2019 by FUJI SOFT INCORPORATED
#  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#
#  上記著作権者は，TTSP3のライセンス（利用条件(1)〜(4)）に従い，
#  本ソフトウェアの利用を無償で許諾する．本ソフトウェアは無保証である．
#
#  2026-06-07: FMP3 POSIXターゲット（linux_gcc）用に新規作成．
#
#  本ターゲットの特記事項:
#  - ネイティブ（Linuxプロセス）実行のため QEMU 不要．
#  - 時刻はCLOCK_MONOTONIC（実時間）駆動で停止不可のため FUNC_TIME="false"．
#    check_library の timer チェック（メニューc→4）は対象外
#    （c→2: 例外，c→3: 割込み を使用すること）．
#  - プロセッサ数は CONFIG_OPT の -O "-DTNUM_PRCID=2" で指定
#    （linux_gcc のデフォルトは4）．
#

#
# アプリケーション名
#
APPLI_NAME="out"

#
# アーキテクチャフォルダの定義（必要な場合のみ）
#
ARCH_PATH=

#
# プロセッサ数(FMPカーネルのみ使用)
# （CONFIG_OPT の -DTNUM_PRCID と一致させること）
#
PROCESSOR_NUM=2

#
# ターゲット依存APIの有無
# [true: 有り，false: 無し]
#
FUNC_TIME="false"		# システム時刻制御関数（実時間駆動のため停止不可）
FUNC_INTERRUPT="true"	# 割込み発生関数
FUNC_EXCEPTION="true"	# CPU例外発生関数

#
# IRCアーキテクチャ(FMPカーネルのみ使用)
# （割込み番号は0〜255のフラット空間＝グローバルIRC）
#
IRC_ARCH="global"

#
# TTGへの追加オプション
#
TTG_OPT=

#
# コンフィギュレータへの追加オプション
# （fmp3/target/linux_gcc/target_user.txt のテストプログラム向け指定に準拠．
#   test_svc.o はTTSPでは不要のため除外）
#
CONFIG_OPT="-w -S syslog.o -S banner.o -S serial.o -S serial_cfg.o -S posix_serial.o -S logtask.o -O -DTNUM_PRCID=2 -o -Wno-unused-but-set-variable"

#
# ターゲット依存部でKERNEL_COBJSへ追加するオブジェクトファイル
# （fmp3/target/linux_gcc/Makefile.target の KERNEL_COBJS と一致させる）
#
KERNEL_COBJS_TARGET="objs/target_kernel_impl.o objs/posix_kernel_impl.o objs/interrupt_sim.o objs/thread_ctrl.o objs/posix_ipi.o objs/posix_timer_itimer.o"
APPL_COBJS_TARGET="objs/ttsp_target_test.o"

#
# make depend / make の追加オプション(必要な場合のみ)
# （環境変数 TTSP_MAKE_OPT で上書き可能）
#
MAKE_OPT="${TTSP_MAKE_OPT:-}"

#
# 実行モジュールの実行をシェルスクリプトで実装済みか
#
EXC_MODULE="true"

#
# 実行モジュールの実行(ターゲット依存)
# （ネイティブ実行．ハング対策で timeout を併用）
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"

	timeout 300 ./fmp | tee $LOGFILE
}
