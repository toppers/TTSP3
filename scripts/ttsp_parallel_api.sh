#!/bin/bash
#
#  TTSP3 APIオートコードテスト 並列ドライバ
#
#  ttb.sh の逐次フロー（グループ毎に TTG→make→QEMU を直列実行）を
#  グループ単位で並列化する．各 auto_code_N はマニフェスト断片・生成物
#  とも独立しているため，TTG・make・QEMU を安全に並列実行できる．
#
#  フェーズ:
#    1) マニフェスト生成＋ディレクトリ作成（ttb.sh流用・逐次，数分）
#    2) グループ並列: TTG → make -j（xargs -P）
#    3) グループ並列: QEMU実行（xargs -P）
#
#  使い方:
#    ./scripts/ttsp_parallel_api.sh <OS_PATH> <PROFILE> <OBJ_DIR> [DIV_NUM]
#    例) ./scripts/ttsp_parallel_api.sh ../fmp3/ FMP obj_fmp_gcov 20
#
#  環境変数:
#    PAR_GROUPS   : 並列グループ数（既定: 10）
#    MAKE_J       : グループ内 make 並列度（既定: 4）
#    TTSP_MAKE_OPT: make追加オプション（例 ENABLE_GCOV=true）
#    SKIP_PREP    : 1でフェーズ1をスキップ（再ビルド時）
#    SKIP_RUN     : 1でフェーズ3をスキップ（ビルドのみ）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 1800）
#
set -u
cd "$(dirname "$0")/.."
TTSP_DIR=$(pwd)

ARG_OS_PATH="${1:?OS_PATH (e.g. ../fmp3/)}"
ARG_PROFILE="${2:?PROFILE (ASP/FMP)}"
ARG_OBJ="${3:?OBJ_DIR}"
ARG_DIV="${4:-20}"

# configure.sh とターゲット設定の読込み（ttb.sh と同じ手順）
# 注意: configure.sh は DIV_NUM= 等を空で定義するため，引数の反映は source の後で行う
source ./configure.sh
OS_PATH="$ARG_OS_PATH"; PROFILE_NAME="$ARG_PROFILE"; OBJECT_DIR="$ARG_OBJ"
source ./library/$PROFILE_NAME/target/$TARGET_NAME/ttsp_target.sh

DIV_NUM="$ARG_DIV"
# 並列度の既定はコア数から自動決定（例: 32コア→P=10×j4, 4コア→P=2×j2）
NPROC=$(nproc)
PAR_GROUPS="${PAR_GROUPS:-$(( NPROC >= 12 ? NPROC / 3 : (NPROC >= 4 ? 2 : 1) ))}"
MAKE_J="${MAKE_J:-$(( NPROC >= 16 ? 4 : 2 ))}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"

# プロファイル毎のオブジェクトリスト（ttb.sh より転記）
if [ "$PROFILE_NAME" = "ASP" ]; then
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
	KERNEL_NAME="asp"
	QEMU_SMP=""
elif [ "$PROFILE_NAME" = "FMP" ]; then
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/spin_lock.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
	KERNEL_NAME="fmp"
	QEMU_SMP="-smp $PROCESSOR_NUM"
else
	echo "ERROR: PROFILE=$PROFILE_NAME 未対応（ASP/FMPのみ）"; exit 1
fi

# TTGオプションの組み立て（scripts/api_test.sh より転記）
TTG_BIN_ABS=$(realpath "./$TTG_BIN")
if [ "$PROFILE_NAME" = "ASP" ]; then
	TTG_OPT="-a $TTG_OPT --out_file_name $APPLI_NAME --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION"
else
	TTG_OPT="-f $TTG_OPT --prc_num $PROCESSOR_NUM --out_file_name $APPLI_NAME --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION --irc_arch $IRC_ARCH"
fi
if [ -f "./library/$PROFILE_NAME/target/$TARGET_NAME/configure.yaml" ]; then
	TTG_OPT="-c $(realpath ./library/$PROFILE_NAME/target/$TARGET_NAME/configure.yaml) $TTG_OPT"
fi

API_DIR="$OBJECT_DIR/api_test"

# ---- フェーズ1: マニフェスト生成＋ディレクトリ作成（ttb.sh流用） ----
if [ "${SKIP_PREP:-0}" != "1" ]; then
	echo "===== phase 1: manifest + directories (sequential) ====="
	printf '1\n1\n3\n%s\n5\nr\nr\nr\nq\n' "$DIV_NUM" | \
		bash ttb.sh "$OS_PATH" "$PROFILE_NAME" "$OBJECT_DIR" > /tmp/ttsp_par_prep_$$.log 2>&1
	for i in $(seq 1 "$DIV_NUM"); do
		test -d "$API_DIR/auto_code_$i" || {
			echo "ERROR: $API_DIR/auto_code_$i が無い（フェーズ1失敗）"
			tail -20 /tmp/ttsp_par_prep_$$.log; exit 1; }
	done
fi

# ---- フェーズ2: グループ並列 TTG → make ----
build_group() { # $1=group番号
	local i="$1"
	local dir="$API_DIR/auto_code_$i"
	cd "$dir" || return 1
	# マニフェスト断片からテストケースリストを作成（コメント行除外）
	local list
	list=$(grep -v '^#' "MANIFEST_AUTO_CODE_$i" | tr '\n' ' ')
	ruby "$TTG_BIN_ABS" $TTG_OPT $list > result_ttg.log 2>&1 || {
		echo "TTG FAIL: auto_code_$i"; return 1; }
	make $TTSP_MAKE_OPT -j"$MAKE_J" \
		KERNEL_COBJS="$KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" \
		APPL_COBJS="$APPL_COBJS_COMMON $APPL_COBJS_TARGET" \
		> result_make.log 2>&1 || {
		echo "MAKE FAIL: auto_code_$i"; return 1; }
	echo "BUILD OK: auto_code_$i"
}
export -f build_group
export API_DIR TTG_BIN_ABS TTG_OPT MAKE_J KERNEL_COBJS_COMMON KERNEL_COBJS_TARGET \
       APPL_COBJS_COMMON APPL_COBJS_TARGET TTSP_MAKE_OPT

echo "===== phase 2: parallel TTG+make (P=$PAR_GROUPS, make -j$MAKE_J) ====="
t0=$(date +%s)
seq 1 "$DIV_NUM" | xargs -P "$PAR_GROUPS" -I{} bash -c 'build_group {}'
t1=$(date +%s)
echo "build wall time: $((t1 - t0))s"

build_ok=0
for i in $(seq 1 "$DIV_NUM"); do
	[ -f "$API_DIR/auto_code_$i/$KERNEL_NAME" ] && build_ok=$((build_ok + 1))
done
echo "binaries: $build_ok/$DIV_NUM"

# ---- フェーズ3: グループ並列 QEMU実行 ----
if [ "${SKIP_RUN:-0}" != "1" ]; then
	run_group() { # $1=group番号
		local i="$1"
		local dir="$API_DIR/auto_code_$i"
		[ -f "$dir/$KERNEL_NAME" ] || { echo "RUN SKIP: auto_code_$i (no binary)"; return 0; }
		( cd "$dir" && rm -f objs/*.gcda && \
			timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 -semihosting \
				-m 512M -serial null -serial mon:stdio -nographic $QEMU_SMP \
				-kernel "$KERNEL_NAME" < /dev/null > execute.log 2>&1 )
		local fin
		fin=$(tr -d '\r' < "$dir/execute.log" | grep -c 'All check points passed')
		echo "RUN auto_code_$i: finish=$fin"
	}
	export -f run_group
	export KERNEL_NAME QEMU_SMP QEMU_TIMEOUT

	echo "===== phase 3: parallel QEMU (P=$PAR_GROUPS) ====="
	t2=$(date +%s)
	seq 1 "$DIV_NUM" | xargs -P "$PAR_GROUPS" -I{} bash -c 'run_group {}'
	t3=$(date +%s)
	echo "run wall time: $((t3 - t2))s"
fi
