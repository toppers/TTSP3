#!/bin/bash
#
#  ci_run.sh — TTSP3 非対話CIランナー（全プロファイル統一）
#
#  使い方:
#    scripts/ci_run.sh [PROFILE] [target]
#      PROFILE : ASP（既定）| FMP | HRP | HRMP
#      target  : zybo_z7_gcc（既定。本ランナーは QEMU(Cortex-A9) 前提）
#
#  例:
#    scripts/ci_run.sh            # ASP zybo（後方互換：引数なし＝ASP）
#    scripts/ci_run.sh FMP        # FMP zybo（ci_run_fmp.sh と等価）
#    scripts/ci_run.sh HRMP       # HRMP zybo
#    scripts/ci_run.sh HRP        # HRP zybo
#
#  ステージ：1)check_library(exc/int/timer) 2)API auto-code 20分割
#            3)scratch(ASPのみ) 4)cfg-error（既知残を許容）→ 末尾に正規化 VERDICT。
#
#  前提：被テストカーネルが ../<asp3|fmp3|hrp3|hrmp3>/ にあり、QEMU は a9gtimer パッチ
#        適用済み（docs/patches/。未適用だと check_library/timer が必ず失敗）。
#
#  環境変数：CI_MODE(full|smoke) / API_DIV_NUM(20) / QEMU_TIMEOUT(1800) /
#            CFGERR_ALLOW_NG（既定はプロファイル別。空白区切りで上書き可）
#  終了コード：0=全パス（許容残を除く），非0=失敗あり
#
set -u
cd "$(dirname "$0")/.."

PROFILE="${1:-ASP}"
TARGET="${2:-zybo_z7_gcc}"

# プロファイル別パラメータ（OS_PATH / カーネル名 / SMP / cfg-error既定許容 / scratch有無）
case "$PROFILE" in
	ASP)  OS=../asp3/;  KN=asp;  SMP="";       DEF_ALLOW="";          DO_SCRATCH=1 ;;
	FMP)  OS=../fmp3/;  KN=fmp;  SMP="-smp 2"; DEF_ALLOW="DEF_INH_c"; DO_SCRATCH=0 ;;
	HRMP) OS=../hrmp3/; KN=hrmp; SMP="-smp 2"; DEF_ALLOW="DEF_INH_c"; DO_SCRATCH=0 ;;
	HRP)  OS=../hrp3/;  KN=hrp;  SMP="";       DEF_ALLOW="DEF_INH_c"; DO_SCRATCH=0 ;;
	*) echo "ERROR: PROFILE は ASP/FMP/HRP/HRMP（指定: $PROFILE）" >&2; exit 1 ;;
esac
OSDIR="${OS%/}"
OBJ="obj_${KN}"; [ "$PROFILE" = ASP ] && OBJ="obj"   # ASP は従来どおり obj

test -d "$OSDIR" || { echo "ERROR: $OSDIR (sibling kernel) not found" >&2; exit 1; }
test -f "library/$PROFILE/target/$TARGET/ttsp_target.sh" \
	|| { echo "ERROR: 未知の $PROFILE/$TARGET" >&2; exit 1; }
mkdir -p sil_test   # ttb.sh の存在チェック対策（SILテストはTTSP3未サポートで空）
grep -q '^USE_QEMU=true' "library/$PROFILE/target/$TARGET/ttsp_target.sh" \
	|| { echo "ERROR: 本ランナーは QEMU 前提（$TARGET は USE_QEMU!=true）。linux_gcc は ttsp_parallel_api.sh を直接使う" >&2; exit 1; }

MODE="${CI_MODE:-full}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-1800}"
CFGERR_ALLOW_NG="${CFGERR_ALLOW_NG:-$DEF_ALLOW}"
export TTSP_MAKE_OPT="${TTSP_MAKE_OPT:-}"
FAIL=0; PASS_CNT=0; FAIL_CNT=0

echo "##### TTSP3 CI: $PROFILE / $TARGET (mode=$MODE, obj=$OBJ) #####"

run_qemu() { # $1=dir
	( cd "$1" && timeout "$QEMU_TIMEOUT" qemu-system-arm -M xilinx-zynq-a9 \
		-semihosting -m 512M -serial null -serial mon:stdio -nographic \
		$SMP -kernel "$KN" < /dev/null > execute.log 2>&1 )
}
check_log() { # $1=dir $2=label
	if tr -d '\r' < "$1/execute.log" 2>/dev/null | grep -q 'All check points passed\.'; then
		echo "PASS: $2"; PASS_CNT=$((PASS_CNT + 1))
	else
		echo "FAIL: $2  (tail of execute.log)"; tail -15 "$1/execute.log" 2>/dev/null | sed 's/^/    /'
		FAIL=1; FAIL_CNT=$((FAIL_CNT + 1))
	fi
}
require_binary() { # $1=dir $2=label $3=buildlog
	if [ ! -f "$1/$KN" ]; then
		echo "BUILD FAIL: $2  (tail of $3)"; tail -25 "$3" 2>/dev/null | sed 's/^/    /'
		FAIL=1; FAIL_CNT=$((FAIL_CNT + 1)); return 1
	fi
	return 0
}

# ===== stage 1: ターゲット依存チェック（exception/interrupt/timer）=====
echo "===== stage 1: target-dependent check (exception/interrupt/timer) ====="
printf 'c\n1\n1\nr\nr\nq\n' | TTSP_TARGET_NAME="$TARGET" bash ttb.sh "$OS" "$PROFILE" "$OBJ" > ci_${KN}_chk.log 2>&1
for d in exception interrupt timer; do
	dir=$OBJ/check_library/$d
	require_binary "$dir" "check_library/$d" ci_${KN}_chk.log || continue
	run_qemu "$dir"; check_log "$dir" "check_library/$d"
done

if [ "$MODE" = "full" ]; then
	# ===== stage 2: API オートコード（並列ドライバ）=====
	echo "===== stage 2: API auto-code (${DIV_NUM}-way, parallel) ====="
	bash scripts/ttsp_parallel_api.sh "$OS" "$PROFILE" "$OBJ" "$DIV_NUM" > ci_${KN}_api.log 2>&1
	grep -E 'wall time|TTG FAIL|MAKE FAIL|binaries' ci_${KN}_api.log
	for i in $(seq 1 "$DIV_NUM"); do
		dir=$OBJ/api_test/auto_code_$i
		require_binary "$dir" "api/auto_code_$i" ci_${KN}_api.log || continue
		check_log "$dir" "api/auto_code_$i"
	done

	# ===== stage 3: API scratch code（ASP のみ）=====
	if [ "$DO_SCRATCH" -eq 1 ]; then
		echo "===== stage 3: API scratch code ====="
		printf '1\n2\n1\n2\nr\nr\nr\nq\n' | TTSP_TARGET_NAME="$TARGET" bash ttb.sh "$OS" "$PROFILE" "$OBJ" > ci_${KN}_scr.log 2>&1
		scr_found=0
		for dir in $OBJ/api_test/scratch_code/*/; do
			[ -d "$dir" ] || continue
			scr_found=1; name=$(basename "$dir")
			require_binary "$dir" "api/scratch/$name" ci_${KN}_scr.log || continue
			run_qemu "$dir"; check_log "$dir" "api/scratch/$name"
		done
		[ "$scr_found" -eq 0 ] && { echo "FAIL: scratch code tests not generated"; FAIL=1; FAIL_CNT=$((FAIL_CNT + 1)); }
	fi

	# ===== stage 4: API コンフィグエラー（既知残を許容）=====
	echo "===== stage 4: API configuration error (parallel) ====="
	bash scripts/ttsp_parallel_cfgerr.sh "$OS" "$PROFILE" "${OBJ}_cfgerr" > ci_${KN}_cfgerr.log 2>&1
	ok_n=$(grep -c ': Test OK' ci_${KN}_cfgerr.log)
	unexpected_ng=0
	while read -r name _; do
		[ -z "$name" ] && continue
		skip=0; for allow in $CFGERR_ALLOW_NG; do [ "$name" = "$allow" ] && skip=1; done
		if [ "$skip" -eq 0 ]; then echo "    unexpected NG: $name"; unexpected_ng=$((unexpected_ng + 1))
		else echo "    known residual (allowed): $name"; fi
	done < <(grep ': Test NG' ci_${KN}_cfgerr.log | sed 's/ : Test NG.*//')
	echo "configuration error tests: OK=$ok_n, unexpected NG=$unexpected_ng (allowed: ${CFGERR_ALLOW_NG:-none})"
	if [ "$ok_n" -eq 0 ] || [ "$unexpected_ng" -ne 0 ]; then
		echo "FAIL: configuration error tests"; FAIL=1; FAIL_CNT=$((FAIL_CNT + 1))
	else
		PASS_CNT=$((PASS_CNT + ok_n))
	fi
fi

echo "==================================================="
echo "$PROFILE CI result: PASS=$PASS_CNT  FAIL=$FAIL_CNT"
echo "==================================================="
# 正規化 VERDICT（API群を docs/STATUS.md のベースラインと比較）
[ "$MODE" = "full" ] && bash scripts/verdict.sh "$PROFILE" "$TARGET" "$OBJ" "$DIV_NUM" || true
[ "$FAIL" -eq 0 ] && echo "RESULT: SUCCESS" || echo "RESULT: FAILURE"
exit "$FAIL"
