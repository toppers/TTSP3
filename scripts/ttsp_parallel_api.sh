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
elif [ "$PROFILE_NAME" = "HRMP" ]; then
	# [改変] 2026-06-09: HRMP対応（保護＋マルチコア）．KERNEL_COBJS/APPL_COBJS は ttb.sh より転記．
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o objs/spin_lock.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o objs/ttsp_mem_obj_kernel1.o objs/ttsp_mem_obj_kernel2.o objs/ttsp_mem_obj_user1.o objs/ttsp_mem_obj_user2.o objs/ttsp_mem_obj_kernel_dummy1.o objs/ttsp_mem_obj_kernel_dummy2.o objs/ttsp_mem_obj_user_dummy1.o objs/ttsp_mem_obj_user_dummy2.o"
	KERNEL_NAME="hrmp"
	QEMU_SMP="-smp $PROCESSOR_NUM"
elif [ "$PROFILE_NAME" = "HRP" ]; then
	# [改変] 2026-06-09: HRP対応（保護・単一コア・方式A）．HRP は syssvc が TECS化されており，
	# KERNEL_COBJS/APPL_COBJS を破壊的に上書きすると Makefile 既定の TECS celltype オブジェクトが
	# 落ちてリンク失敗する（docs/HRP/COVERAGE_STATUS.md）．テスト用追加オブジェクトは ttb.sh の
	# 配線で configure -U（TEST_LIB_FILE）により APPLOBJS へ渡され，フェーズ1生成の Makefile に
	# 含まれる．そこで HRP では make 時に COBJS を上書きしない（下の build_group / run_group で分岐）．
	KERNEL_COBJS_COMMON=""
	APPL_COBJS_COMMON=""
	KERNEL_NAME="hrp"
	QEMU_SMP=""
else
	echo "ERROR: PROFILE=$PROFILE_NAME 未対応（ASP/FMP/HRP/HRMP）"; exit 1
fi

# TTGオプションの組み立て（scripts/api_test.sh より転記）
TTG_BIN_ABS=$(realpath "./$TTG_BIN")
if [ "$PROFILE_NAME" = "ASP" ]; then
	TTG_OPT="-a $TTG_OPT --out_file_name $APPLI_NAME --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION"
elif [ "$PROFILE_NAME" = "HRP" ]; then
	# [改変] 2026-06-09: HRP は TTG フラグ -h（単一コア・保護，--prc_num/--irc_arch なし）
	TTG_OPT="-h $TTG_OPT --out_file_name $APPLI_NAME --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION"
elif [ "$PROFILE_NAME" = "HRMP" ]; then
	# [改変] 2026-06-09: HRMP は TTG フラグ -H（FMPは -f）
	TTG_OPT="-H $TTG_OPT --prc_num $PROCESSOR_NUM --out_file_name $APPLI_NAME --func_time $FUNC_TIME --func_interrupt $FUNC_INTERRUPT --func_exception $FUNC_EXCEPTION --irc_arch $IRC_ARCH"
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
	# [改変] 2026-06-09: HRMP の GCOV計装ビルドでは libgcov/librdimon を保護ドメインに
	# 配置する必要がある（未配置だと /DISCARD/ で .text が破棄されリンク失敗）．TTG生成の
	# out.cfg は libc.a までしか ATT_MOD しないため，ここで追記する（非GCOV時も無害）．
	if [ "$GCOV_ATTACH_LIBS" = "1" ]; then
		grep -q 'libgcov.a' out.cfg || \
			printf 'ATT_MOD("libgcov.a");\nATT_MOD("librdimon.a");\n' >> out.cfg
	fi
	# 実験用フック（既定オフ）: GCOV_GRANT_SYSSTAT2=1 のとき，TTG生成 out.cfg の SAC_SYS に
	# システム状態許可ベクタ2(sysstat2)=TACP_SHARED を付与する．HRP では sus_tsk/rsm_tsk/
	# ter_tsk 等が sysstat2_acvct を要求するが，TTG既定では sysstat2 がカーネルドメインのみで，
	# ユーザドメインのASP由来テストが E_OACV で早期終了する（docs/HRP/WB_UNREACHABLE.md §1）．
	# 単引数 SAC_SYS は sysstat2 を追記，SAC_SYS 無しなら KERNEL_DOMAIN へ全許可で挿入する．
	if [ "${GCOV_GRANT_SYSSTAT2:-0}" = "1" ]; then
		if grep -qE 'SAC_SYS\(\{[^}]*\}\);' out.cfg; then
			perl -pi -e 's/SAC_SYS\((\{[^}]*\})\);/SAC_SYS($1, {TACP_SHARED, TACP_SHARED, TACP_SHARED, TACP_SHARED});/' out.cfg
		elif grep -q 'KERNEL_DOMAIN {' out.cfg; then
			perl -0pi -e 's/(KERNEL_DOMAIN \{\n)/$1\tSAC_SYS({TACP_SHARED, TACP_SHARED, TACP_SHARED, TACP_SHARED}, {TACP_SHARED, TACP_SHARED, TACP_SHARED, TACP_SHARED});\n/ if !$done++;' out.cfg
		fi
	fi
	# [改変] 2026-06-09: HRP は方式A（COBJS 非上書き）．それ以外は従来どおり上書き．
	if [ "$PROFILE_NAME" = "HRP" ]; then
		make $TTSP_MAKE_OPT -j"$MAKE_J" \
			> result_make.log 2>&1 || {
			echo "MAKE FAIL: auto_code_$i"; return 1; }
	else
		make $TTSP_MAKE_OPT -j"$MAKE_J" \
			KERNEL_COBJS="$KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" \
			APPL_COBJS="$APPL_COBJS_COMMON $APPL_COBJS_TARGET" \
			> result_make.log 2>&1 || {
			echo "MAKE FAIL: auto_code_$i"; return 1; }
	fi
	echo "BUILD OK: auto_code_$i"
}
# 保護カーネル（HRP/HRMP）かつ GCOV計装時のみ out.cfg に libgcov/librdimon を追記する
GCOV_ATTACH_LIBS=0
if { [ "$PROFILE_NAME" = "HRMP" ] || [ "$PROFILE_NAME" = "HRP" ]; } && [[ "$TTSP_MAKE_OPT" == *ENABLE_GCOV=true* ]]; then
	GCOV_ATTACH_LIBS=1
fi
export -f build_group
export API_DIR TTG_BIN_ABS TTG_OPT MAKE_J KERNEL_COBJS_COMMON KERNEL_COBJS_TARGET \
       APPL_COBJS_COMMON APPL_COBJS_TARGET TTSP_MAKE_OPT GCOV_ATTACH_LIBS PROFILE_NAME \
       GCOV_GRANT_SYSSTAT2

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
		if [ "$RUN_NATIVE" = "1" ]; then
			# POSIXターゲット: ネイティブ実行
			( cd "$dir" && rm -f objs/*.gcda && \
				timeout "$QEMU_TIMEOUT" "./$KERNEL_NAME" < /dev/null > execute.log 2>&1 )
		elif declare -f parallel_simulation > /dev/null; then
			# [改変] 2026-06-12: ターゲット依存のQEMU起動
			# （ttsp_target.shがparallel_simulationを定義する場合．
			#   カレントディレクトリで実行し，execute.logに出力すること）
			( cd "$dir" && rm -f objs/*.gcda && \
				timeout "$QEMU_TIMEOUT" bash -c parallel_simulation \
					< /dev/null > execute.log 2>&1 )
		else
			( cd "$dir" && rm -f objs/*.gcda && \
				timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 -semihosting \
					-m 512M -serial null -serial mon:stdio -nographic $QEMU_SMP \
					-kernel "$KERNEL_NAME" < /dev/null > execute.log 2>&1 )
		fi
		local fin
		fin=$(tr -d '\r' < "$dir/execute.log" | grep -c 'All check points passed')
		echo "RUN auto_code_$i: finish=$fin"
	}
	export -f run_group
	declare -f parallel_simulation > /dev/null && export -f parallel_simulation
	export QEMU_UPSTREAM
	# POSIXターゲット（linux_gcc）はネイティブ実行
	RUN_NATIVE=0
	[ "$TARGET_NAME" = "linux_gcc" ] && RUN_NATIVE=1
	export KERNEL_NAME QEMU_SMP QEMU_TIMEOUT RUN_NATIVE

	echo "===== phase 3: parallel QEMU (P=$PAR_GROUPS) ====="
	t2=$(date +%s)
	seq 1 "$DIV_NUM" | xargs -P "$PAR_GROUPS" -I{} bash -c 'run_group {}'
	t3=$(date +%s)
	echo "run wall time: $((t3 - t2))s"
fi
