#!/bin/bash
#
#  TTSP3 非対話CIランナー
#
#  ttb.sh（対話メニュー）を標準入力で駆動してビルドし，QEMU実行と合否判定を
#  非対話で行う．ローカルでも `./scripts/ci_run.sh` で実行可能．
#
#  前提：
#    - ../asp3/ に被テストカーネル（UPSTREAM_KERNEL.md の版）
#    - configure.sh: OS_PATH="../asp3/" / PROFILE_NAME="ASP" / TARGET_NAME="zybo_z7_gcc"
#    - zybo_z7_gcc/ttsp_target.sh: USE_QEMU=true
#    - qemu-system-arm は a9gtimer パッチ適用済みであること
#      （docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch．
#        未適用だと check_library/timer が必ず失敗する）
#
#  環境変数：
#    CI_MODE      : full（既定）| smoke（ターゲット依存チェックのみ）
#    API_DIV_NUM  : APIオートコードの分割数（既定 20）
#    QEMU_TIMEOUT : QEMU 1実行あたりのタイムアウト秒（既定 1800）
#
#  終了コード： 0=全パス，非0=失敗あり
#
set -u
cd "$(dirname "$0")/.."

test -d ../asp3 || { echo "ERROR: ../asp3 (sibling kernel) not found"; exit 1; }
grep -q 'OS_PATH="../asp3/"' configure.sh || { echo "ERROR: OS_PATH != ../asp3/"; exit 1; }
grep -q '^USE_QEMU=true' library/ASP/target/zybo_z7_gcc/ttsp_target.sh \
	|| { echo "ERROR: USE_QEMU != true (zybo_z7_gcc)"; exit 1; }

MODE="${CI_MODE:-full}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"
FAIL=0
PASS_CNT=0
FAIL_CNT=0

run_qemu() { # $1=dir
	( cd "$1" && timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 \
		-semihosting -m 512M -serial null -serial mon:stdio -nographic \
		-kernel asp < /dev/null > execute.log 2>&1 )
}

check_log() { # $1=dir $2=label
	if tr -d '\r' < "$1/execute.log" | grep -q '^All check points passed\.'; then
		echo "PASS: $2"
		PASS_CNT=$((PASS_CNT + 1))
	else
		echo "FAIL: $2  (tail of execute.log)"
		tail -20 "$1/execute.log" | sed 's/^/    /'
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
	fi
}

require_binary() { # $1=dir $2=label $3=buildlog
	if [ ! -f "$1/asp" ]; then
		echo "BUILD FAIL: $2  (tail of $3)"
		tail -30 "$3" | sed 's/^/    /'
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
		return 1
	fi
	return 0
}

echo "===== stage 1: target-dependent check (exception/interrupt/timer) ====="
printf 'c\n1\n1\nr\nr\nq\n' | bash ttb.sh > ci_build_chk.log 2>&1
for d in exception interrupt timer; do
	dir=obj/check_library/$d
	require_binary "$dir" "check_library/$d" ci_build_chk.log || continue
	run_qemu "$dir"
	check_log "$dir" "check_library/$d"
done

if [ "$MODE" = "full" ]; then
	echo "===== stage 2: API auto-code (TESRY, ${DIV_NUM}-way) ====="
	printf '1\n1\n3\n%s\n4\nr\nr\nr\nq\n' "$DIV_NUM" | bash ttb.sh > ci_build_api.log 2>&1
	for i in $(seq 1 "$DIV_NUM"); do
		dir=obj/api_test/auto_code_$i
		require_binary "$dir" "api/auto_code_$i" ci_build_api.log || continue
		run_qemu "$dir"
		check_log "$dir" "api/auto_code_$i"
	done

	echo "===== stage 3: API scratch code ====="
	printf '1\n2\n1\n2\nr\nr\nr\nq\n' | bash ttb.sh > ci_build_scr.log 2>&1
	scr_found=0
	for dir in obj/api_test/scratch_code/*/; do
		[ -d "$dir" ] || continue
		scr_found=1
		name=$(basename "$dir")
		require_binary "$dir" "api/scratch/$name" ci_build_scr.log || continue
		run_qemu "$dir"
		check_log "$dir" "api/scratch/$name"
	done
	if [ "$scr_found" -eq 0 ]; then
		echo "FAIL: scratch code tests not generated"
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
	fi

	echo "===== stage 4: API configuration error ====="
	printf '1\n3\n1\n2\nr\nr\nr\nq\n' | bash ttb.sh > ci_cfgerr.log 2>&1
	ok_n=$(grep -c ': Test OK' ci_cfgerr.log)
	ng_n=$(grep -c ': Test NG' ci_cfgerr.log)
	echo "configuration error tests: OK=$ok_n NG=$ng_n"
	if [ "$ng_n" -ne 0 ] || [ "$ok_n" -eq 0 ]; then
		echo "FAIL: configuration error tests (OK=$ok_n NG=$ng_n)"
		grep ': Test NG' ci_cfgerr.log | sed 's/^/    /'
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
	else
		PASS_CNT=$((PASS_CNT + ok_n))
	fi
fi

echo "===== summary ====="
echo "PASS=$PASS_CNT FAIL=$FAIL_CNT (mode=$MODE)"
if [ "$FAIL" -ne 0 ]; then
	echo "RESULT: FAILURE"
else
	echo "RESULT: SUCCESS"
fi
exit $FAIL
