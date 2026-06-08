#!/bin/bash
#
#  TTSP3 コンフィギュレーションエラーテスト 並列ドライバ
#
#  各テストディレクトリは独立（make実行→期待エラーコードをgrep）のため，
#  scripts/api_test.sh の compare_error_code 相当を並列実行する．
#  マニフェスト生成・ディレクトリ作成（rename済み）は ttb.sh を流用．
#
#  使い方:
#    ./scripts/ttsp_parallel_cfgerr.sh <OS_PATH> <PROFILE> <OBJ_DIR>
#    例) ./scripts/ttsp_parallel_cfgerr.sh ../asp3/ ASP obj
#
#  環境変数:
#    PAR_JOBS     : 並列数（既定: nprocから自動）
#    TTSP_MAKE_OPT: make追加オプション
#    SKIP_PREP    : 1でマニフェスト生成＋mkdirをスキップ
#
#  終了コード: 0=全Test OK, 非0=NGあり
#
set -u
cd "$(dirname "$0")/.."
TTSP_DIR=$(pwd)

ARG_OS_PATH="${1:?OS_PATH}"
ARG_PROFILE="${2:?PROFILE (ASP/FMP)}"
ARG_OBJ="${3:?OBJ_DIR}"

source ./configure.sh
OS_PATH="$ARG_OS_PATH"; PROFILE_NAME="$ARG_PROFILE"; OBJECT_DIR="$ARG_OBJ"
source ./library/$PROFILE_NAME/target/$TARGET_NAME/ttsp_target.sh

NPROC=$(nproc)
PAR_JOBS="${PAR_JOBS:-$(( NPROC >= 12 ? NPROC / 2 : NPROC ))}"

# プロファイル毎のオブジェクトリスト（ttb.sh より転記）
if [ "$PROFILE_NAME" = "ASP" ]; then
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
elif [ "$PROFILE_NAME" = "FMP" ]; then
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/spin_lock.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
elif [ "$PROFILE_NAME" = "HRP" ]; then
	# ttb.sh より転記（HRP：保護機能・TECS）
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o"
	# [改変] 2026-06-08: HRP cfg-error の TECS アダプタ obj 名を tecsgen 1.8.0 の実生成名に修正．
	#   旧名 tHRPSVCPlugin_sXxxSVCCaller_Yyy_eZzz_tecsgen.{c,o} は当該 tecsgen が生成せず
	#   "No rule to make target ..._tecsgen.c" で停止していた（3.4→3.7 の tecsgen 名称差分）．
	#   cfg-error の最小 out.cdl に対する tecsgen 実出力（gen/Makefile.tecsgen の
	#   TECS_*_COBJS）に合わせ tHRPSVCBody_* / tHRPSVCCaller_* 系へ置換．
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o objs/ttsp_mem_obj_kernel1.o objs/ttsp_mem_obj_kernel2.o objs/ttsp_mem_obj_user1.o objs/ttsp_mem_obj_user2.o objs/tSerialAdapter_tecsgen.o objs/tSysLogAdapter_tecsgen.o objs/tHRPSVCBody_sSysLog_rKernelDomain_tecsgen.o objs/tHRPSVCBody_sSerialPort_rKernelDomain_tecsgen.o objs/tHRPSVCBody_sSysLog.o objs/tHRPSVCBody_sSerialPort.o objs/tHRPSVCCaller_sSysLog_tecsgen.o objs/tHRPSVCCaller_sSerialPort_tecsgen.o objs/tHRPSVCCaller_sSysLog.o objs/tHRPSVCCaller_sSerialPort.o objs/tSerialAdapter.o objs/tSysLogAdapter.o"
elif [ "$PROFILE_NAME" = "HRMP" ]; then
	# ttb.sh より転記（HRMP：保護機能＋マルチプロセッサ・TECS）
	KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o objs/spin_lock.o"
	APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o objs/ttsp_mem_obj_kernel1.o objs/ttsp_mem_obj_kernel2.o objs/ttsp_mem_obj_user1.o objs/ttsp_mem_obj_user2.o objs/ttsp_mem_obj_kernel_dummy1.o objs/ttsp_mem_obj_kernel_dummy2.o objs/ttsp_mem_obj_user_dummy1.o objs/ttsp_mem_obj_user_dummy2.o"
else
	echo "ERROR: PROFILE=$PROFILE_NAME 未対応（ASP/FMP/HRP/HRMP）"; exit 1
fi

ERR_DIR="$OBJECT_DIR/api_test/config_error"

# ---- フェーズ1: マニフェスト生成＋ディレクトリ作成（ttb.sh流用・逐次） ----
if [ "${SKIP_PREP:-0}" != "1" ]; then
	echo "===== cfg-error phase 1: manifest + directories ====="
	printf '1\n3\n1\n3\nr\nr\nr\nq\n' | \
		bash ttb.sh "$OS_PATH" "$PROFILE_NAME" "$OBJECT_DIR" > /tmp/ttsp_cfgerr_prep_$$.log 2>&1
	test -d "$ERR_DIR" || { echo "ERROR: $ERR_DIR が無い"; tail -20 /tmp/ttsp_cfgerr_prep_$$.log; exit 1; }
fi

# ---- フェーズ2: 並列チェック（compare_error_code 相当） ----
check_one() { # $1=テストディレクトリ
	local dir="$1"
	local name
	name=$(basename "$dir")
	cd "$dir" || { echo "$name : Test NG (no dir)"; return 1; }
	local err_code
	err_code=$(sed -e 's/\*/\\*/g' err_code.txt)
	make realclean $TTSP_MAKE_OPT \
		KERNEL_COBJS="$KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" \
		APPL_COBJS="$APPL_COBJS_COMMON $APPL_COBJS_TARGET" > /dev/null 2>&1
	make $TTSP_MAKE_OPT \
		KERNEL_COBJS="$KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" \
		APPL_COBJS="$APPL_COBJS_COMMON $APPL_COBJS_TARGET" > /dev/null 2> result_make.log
	if grep -q "$err_code" result_make.log; then
		echo "$name : Test OK"
	else
		echo "$name : Test NG (expect: $(cat err_code.txt))"
		return 1
	fi
}
export -f check_one
export TTSP_MAKE_OPT="${TTSP_MAKE_OPT:-}" \
       KERNEL_COBJS_COMMON KERNEL_COBJS_TARGET APPL_COBJS_COMMON APPL_COBJS_TARGET

echo "===== cfg-error phase 2: parallel check (P=$PAR_JOBS) ====="
t0=$(date +%s)
find "$ERR_DIR" -mindepth 1 -maxdepth 1 -type d ! -name 'temp_dir*' | sort | \
	xargs -P "$PAR_JOBS" -I{} bash -c 'check_one {}' > /tmp/ttsp_cfgerr_result_$$.log
t1=$(date +%s)
cat /tmp/ttsp_cfgerr_result_$$.log
ok_n=$(grep -c ': Test OK' /tmp/ttsp_cfgerr_result_$$.log)
ng_n=$(grep -c ': Test NG' /tmp/ttsp_cfgerr_result_$$.log)
rm -f /tmp/ttsp_cfgerr_result_$$.log
echo "cfg-error: OK=$ok_n NG=$ng_n (wall ${t1}s-${t0}s=$((t1 - t0))s)"
[ "$ng_n" -eq 0 ] && [ "$ok_n" -gt 0 ]
