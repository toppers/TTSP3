#
#  TTSP3
#      TOPPERS Test Suite Package 3
#
#  Copyright (C) 2009-2019 by FUJI SOFT INCORPORATED
#  Copyright (C) 2026 by Embedded and Real-Time Systems Laboratory
#              Graduate School of Information Science, Nagoya Univ., JAPAN
#
#  本ファイルはTTSP3ライセンスに従って利用できる．詳細は配布物に含まれ
#  る利用条件を参照のこと．
#
#  [改変] 2026-06-12: zybo_z7_gcc版をベースに，HRP3のZynqMP Cortex-R5
#  （zynqmp_r5_gcc）ターゲット向けに新規作成．QEMU起動コマンドを
#  アップストリームQEMU（xlnx-zcu102，R5Fシングルコア）に変更し，
#  KERNEL_COBJS_TARGETをzynqmp_r5構成に変更した．
#
#		ターゲット依存設定（ZynqMP Cortex-R5用）
#

# QEMUを使用する（アップストリームQEMU 11以降のqemu-system-aarch64．
# 環境変数QEMU_UPSTREAMでパスを指定できる）
USE_QEMU=true
QEMU_UPSTREAM="${QEMU_UPSTREAM:-$HOME/qemu/qemu-11.0.0/build/qemu-system-aarch64}"

#
# アプリケーションプログラム名
#
APPLI_NAME="out"

#
# アーキテクチャ上の使用フォルダ
#
ARCH_PATH=

#
# プロセッサ数（シングルコア）
#
PROCESSOR_NUM=1

#
# ターゲット依存関数の実装状況
#
FUNC_TIME="true"		# システム時刻制御関数
FUNC_INTERRUPT="true"	# 割込み発生関数
FUNC_EXCEPTION="true"	# CPU例外発生関数

#
# IRCアーキテクチャ
#
IRC_ARCH="local"

#
# TTGに与えるオプション
#
TTG_OPT=

#
# コンフィギュレータ（configure.rb）に与えるオプション
#
CONFIG_OPT="-o -Wno-unused-but-set-variable -o -DOMIT_CHECK_USTACK_OVERLAP"

#
# カーネルライブラリ使用時に追加するターゲット依存のオブジェクト
#
KERNEL_COBJS_TARGET="objs/chip_kernel_impl.o objs/core_kernel_impl.o objs/gic_kernel_impl.o objs/target_kernel_impl.o objs/ttc_hrt.o"

#
# アプリケーションに追加するターゲット依存のオブジェクト
#
APPL_COBJS_TARGET="objs/ttsp_target_test.o"

#
# makeに与えるオプション
#
MAKE_OPT="${TTSP_MAKE_OPT:-}"

#
# CPU例外モジュールの有無
#
EXC_MODULE="true"

#
# 実行モジュールの実行（QEMU）
#
simulation()
{
	LOGFILE=`pwd`"/execute.log"
	$QEMU_UPSTREAM -M xlnx-zcu102 -smp 6 -m 2G -nographic \
		-global xlnx-zynqmp.boot-cpu=rpu-cpu[0] \
		-global cortex-r5f-arm-cpu.mp-affinity=0 \
		-device loader,file=hrp,cpu-num=4 \
		-serial null -serial mon:stdio | tee $LOGFILE
}

#
# 並列実行用のQEMU起動（ttsp_parallel_api.sh用．execute.logに出力）
#
# R5ターゲットはセミホスティング終了がなくQEMUが自動終了しないため，
# 完了マーカー（All check points passed等）または出力の停滞（120秒）を
# 検出してQEMUを終了させる．
#
parallel_simulation()
{
	${QEMU_UPSTREAM:-$HOME/qemu/qemu-11.0.0/build/qemu-system-aarch64} \
		-M xlnx-zcu102 -smp 6 -m 2G -nographic \
		-global xlnx-zynqmp.boot-cpu=rpu-cpu[0] \
		-global cortex-r5f-arm-cpu.mp-affinity=0 \
		-device loader,file=hrp,cpu-num=4 \
		-serial null -serial mon:stdio &
	local qpid=$!
	local stall=0
	local prev_size=0
	local cur_size
	while kill -0 $qpid 2>/dev/null; do
		sleep 2
		if grep -q 'All check points passed\.' execute.log 2>/dev/null; then
			sleep 1
			break
		fi
		cur_size=$(stat -c %s execute.log 2>/dev/null || echo 0)
		if [ "$cur_size" = "$prev_size" ]; then
			stall=$((stall + 2))
			if [ $stall -ge 120 ]; then
				break
			fi
		else
			stall=0
			prev_size=$cur_size
		fi
	done
	kill $qpid 2>/dev/null
	wait $qpid 2>/dev/null
}
