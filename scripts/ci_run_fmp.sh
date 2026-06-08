#!/bin/bash
#
#  TTSP3 非対話CIランナー（FMP3 / zybo_z7_gcc / QEMU）
#
#  ASP用 ci_run.sh の FMP版。並列ドライバ（ttsp_parallel_api.sh /
#  ttsp_parallel_cfgerr.sh）でビルド・実行し，合否を本スクリプトで判定する。
#  ローカルでも `./scripts/ci_run_fmp.sh` で実行可能。
#
#  前提：
#    - ../fmp3/ に被テストカーネル（UPSTREAM_KERNEL.md の版＝exshonda/fmp3）
#    - library/FMP/target/zybo_z7_gcc/ttsp_target.sh: USE_QEMU=true / PROCESSOR_NUM=2
#    - qemu-system-arm は a9gtimer パッチ適用済み（docs/patches/）．
#      未適用だと check_library/timer が必ず失敗する。
#
#  環境変数：
#    CI_MODE         : full（既定）| smoke（ターゲット依存チェックのみ）
#    API_DIV_NUM     : APIオートコードの分割数（既定 20）
#    QEMU_TIMEOUT    : QEMU 1実行あたりのタイムアウト秒（既定 1800）
#    CFGERR_ALLOW_NG : cfg-errorで既知残として許容するテスト名（空白区切り）
#                      既定 "DEF_INH_c"（ASPテスト×FMPプロファイル相互作用＝
#                      DIVERGENCE_MAP E節C参照。CFG_INTのPE1専用割込みを全PE
#                      クラスに置くためE_RSATRが先に発火し意図のE_PARを遮蔽）
#
#  終了コード： 0=全パス（許容NGを除く），非0=失敗あり
#
set -u
cd "$(dirname "$0")/.."

test -d ../fmp3 || { echo "ERROR: ../fmp3 (sibling kernel) not found"; exit 1; }
mkdir -p sil_test   # ttb.shの存在チェック対策（SILテストはTTSP3未サポートで空）
grep -q '^USE_QEMU=true' library/FMP/target/zybo_z7_gcc/ttsp_target.sh \
	|| { echo "ERROR: USE_QEMU != true (FMP zybo_z7_gcc)"; exit 1; }

MODE="${CI_MODE:-full}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"
CFGERR_ALLOW_NG="${CFGERR_ALLOW_NG:-DEF_INH_c}"
FAIL=0
PASS_CNT=0
FAIL_CNT=0

run_qemu_fmp() { # $1=dir
	( cd "$1" && timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 \
		-semihosting -m 512M -serial null -serial mon:stdio -nographic \
		-smp 2 -kernel fmp < /dev/null > execute.log 2>&1 )
}

check_log() { # $1=dir $2=label
	# FMPはマルチプロセッサのため合格行は "PE N : All check points passed." の形式
	# （行頭アンカーは使わない。ttsp_parallel_api.sh の finish 判定と同じ基準）
	if tr -d '\r' < "$1/execute.log" 2>/dev/null | grep -q 'All check points passed\.'; then
		echo "PASS: $2"
		PASS_CNT=$((PASS_CNT + 1))
	else
		echo "FAIL: $2  (tail of execute.log)"
		tail -20 "$1/execute.log" 2>/dev/null | sed 's/^/    /'
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
	fi
}

require_binary() { # $1=dir $2=label $3=buildlog
	if [ ! -f "$1/fmp" ]; then
		echo "BUILD FAIL: $2  (tail of $3)"
		tail -30 "$3" 2>/dev/null | sed 's/^/    /'
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
		return 1
	fi
	return 0
}

# ===== stage 1: ターゲット依存チェック（exception/interrupt/timer）=====
echo "===== stage 1: target-dependent check (FMP: exception/interrupt/timer) ====="
printf 'c\n1\n1\nr\nr\nq\n' | bash ttb.sh ../fmp3/ FMP obj_fmp > ci_fmp_build_chk.log 2>&1
for d in exception interrupt timer; do
	dir=obj_fmp/check_library/$d
	require_binary "$dir" "check_library/$d" ci_fmp_build_chk.log || continue
	run_qemu_fmp "$dir"
	check_log "$dir" "check_library/$d"
done

if [ "$MODE" = "full" ]; then
	# ===== stage 2: API オートコード（並列ドライバ）=====
	echo "===== stage 2: API auto-code (FMP, ${DIV_NUM}-way, parallel) ====="
	bash scripts/ttsp_parallel_api.sh ../fmp3/ FMP obj_fmp "$DIV_NUM" > ci_fmp_build_api.log 2>&1
	grep -E 'wall time|TTG FAIL|MAKE FAIL|binaries' ci_fmp_build_api.log
	for i in $(seq 1 "$DIV_NUM"); do
		dir=obj_fmp/api_test/auto_code_$i
		require_binary "$dir" "api/auto_code_$i" ci_fmp_build_api.log || continue
		check_log "$dir" "api/auto_code_$i"
	done

	# ===== stage 3: API コンフィグエラー（並列ドライバ・既知残を許容）=====
	echo "===== stage 3: API configuration error (FMP, parallel) ====="
	bash scripts/ttsp_parallel_cfgerr.sh ../fmp3/ FMP obj_fmp_cfgerr > ci_fmp_cfgerr.log 2>&1
	ok_n=$(grep -c ': Test OK' ci_fmp_cfgerr.log)
	# 許容リストに無いNGだけを「真のNG」として数える
	unexpected_ng=0
	while read -r name _; do
		skip=0
		for allow in $CFGERR_ALLOW_NG; do [ "$name" = "$allow" ] && skip=1; done
		if [ "$skip" -eq 0 ]; then
			echo "    unexpected NG: $name"
			unexpected_ng=$((unexpected_ng + 1))
		else
			echo "    known residual (allowed): $name"
		fi
	done < <(grep ': Test NG' ci_fmp_cfgerr.log | sed 's/ : Test NG.*//')
	echo "configuration error tests: OK=$ok_n, unexpected NG=$unexpected_ng (allowed: $CFGERR_ALLOW_NG)"
	if [ "$ok_n" -eq 0 ] || [ "$unexpected_ng" -ne 0 ]; then
		echo "FAIL: configuration error tests"
		FAIL=1
		FAIL_CNT=$((FAIL_CNT + 1))
	else
		PASS_CNT=$((PASS_CNT + ok_n))
	fi
fi

echo "==================================================="
echo "FMP CI result: PASS=$PASS_CNT  FAIL=$FAIL_CNT"
echo "==================================================="
exit "$FAIL"
