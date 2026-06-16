#!/bin/bash
#
#  TTSP3 手書きアセンブリ(.S) カバレッジ計測ランナー（zybo_z7 / QEMU）
#
#  gcov で計測できない手書きアセンブリ
#  （asp3/arch/arm_gcc/common/{start,core_support,gic_support}.S 等）の
#  命令網羅 / 行網羅を QEMU 実行から取得する．
#
#  C0（命令網羅 / 行網羅）に加え C1（分岐網羅）も取得する．
#  ASP/HRP（単一コア）に加え FMP/HRMP（SMP・-smp 2）にも対応する．
#  原理: ELF を QEMU で `-d in_asm,exec,nochain` 実行し，
#    - C0: 実行された命令アドレスを収集 → addr2line で .S の行へ逆マッピング
#    - C1: objdump で条件分岐を列挙し，実行 TB 遷移エッジから taken/not-taken を判定
#  して網羅率を算出（scripts/asmcov/branchcov.py が C0+C1 兼用 lcov を出力）．
#  ソースが C か asm かを問わず ELF に DWARF 行情報があれば成立する．
#
#  使い方:
#    ./scripts/coverage_asmcov_zybo.sh [smoke|bb]
#      smoke: check_library のみ（exception/interrupt/timer．既定・数分）
#      bb   : 上記に API オートコード(${DIV_NUM}分割)も加えて集計（数十分）
#
#  環境変数:
#    PROFILE      : ASP|HRP|FMP|HRMP（既定 ASP）．FMP/HRMP は SMP（-smp 2）で実行．
#    OS_PATH      : 兄弟カーネルへのパス（既定はプロファイル別 ../asp3/ 等）
#    SMP_NCPU     : QEMU の vCPU 数（既定 ASP/HRP=1, FMP/HRMP=2）．C1 はコア別に
#                   エッジ復元するので SMP でも偽エッジ混入なく集計できる．
#    OBJ_DIR      : ワークディレクトリ（既定 obj_${prof}_asmcov）
#    API_DIV_NUM  : bb 時の分割数（既定 20）
#    QEMU_TIMEOUT : QEMU 1実行のタイムアウト秒（既定 120．timer 等は全チェックポイント
#                   通過後もアイドルでスピンし自走終了しないため timeout で止める．
#                   実テストロジックの asm 経路は先頭数秒で網羅されるので 120s で十分）
#    TRACE_CAP_MB : トレースログのサイズ上限 MB（既定 256．長時間アイドルで
#                   スピンするテスト＝timer 等のログ無制限膨張を防ぐ．上限到達後は
#                   読み捨て＝先頭プレフィックスのみ集計するので C1 を過大報告しない）
#    OUT_DIR      : レポート出力先（既定 $OBJ_DIR/asmcov）
#    SRC_FILTER   : 集計対象の .S パス部分一致（既定 arch/arm_gcc/common）
#
#  ビルドオプション:
#    COPTS に -gdwarf-4 を付与する（DWARF5 では .debug_line_str がリンク時に
#    脱落し addr2line が .S のファイル名を解決できないため．詳細は
#    scripts/asmcov/README.md）．カーネル・リンカスクリプトは無改変．
#
set -u
cd "$(dirname "$0")/.."

MODE="${1:-smoke}"
case "$MODE" in
	smoke|bb) ;;
	*) echo "ERROR: unknown mode '$MODE' (smoke|bb)"; exit 1 ;;
esac

PROFILE="${PROFILE:-ASP}"
case "$PROFILE" in
	ASP)  prof=asp;  kbin=asp;  def_os=../asp3/;  def_ncpu=1 ;;
	HRP)  prof=hrp;  kbin=hrp;  def_os=../hrp3/;  def_ncpu=1 ;;
	FMP)  prof=fmp;  kbin=fmp;  def_os=../fmp3/;  def_ncpu=2 ;;
	HRMP) prof=hrmp; kbin=hrmp; def_os=../hrmp3/; def_ncpu=2 ;;
	*) echo "ERROR: PROFILE must be ASP|HRP|FMP|HRMP (got '$PROFILE')"; exit 1 ;;
esac
OS_PATH="${OS_PATH:-$def_os}"
# SMP コア数（FMP/HRMP は既定 2）．C0 はコア順序非依存で SMP 安全．C1 は
# branchcov が `Trace <cpu>:` のコア番号でエッジ復元をコア別に分離する（交錯対応）．
SMP_NCPU="${SMP_NCPU:-$def_ncpu}"
OBJ_DIR="${OBJ_DIR:-obj_${prof}_asmcov}"
DIV_NUM="${API_DIV_NUM:-20}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-120}"
TRACE_CAP_MB="${TRACE_CAP_MB:-256}"
TRACE_CAP_BYTES=$(( TRACE_CAP_MB * 1024 * 1024 ))
OUT_DIR="${OUT_DIR:-$OBJ_DIR/asmcov}"
SRC_FILTER="${SRC_FILTER:-arch/arm_gcc/common}"

ASMCOV_DIR="scripts/asmcov"
abs_asmcov="$(cd "$ASMCOV_DIR" && pwd)"
PREFIX="arm-none-eabi-"

test -d "$OS_PATH" || { echo "ERROR: $OS_PATH (sibling kernel) not found"; exit 1; }
for t in qemu-system-arm "${PREFIX}objdump" "${PREFIX}addr2line" lcov genhtml python3; do
	command -v "$t" >/dev/null 2>&1 || { echo "ERROR: required tool not found: $t"; exit 1; }
done

# DWARF4 を末尾に付与（Makefile の "COPTS := -g ... $(COPTS)" の後ろに展開され後勝ち）．
# 注意: env で渡すこと（make COPTS=... のコマンドライン代入は -mcpu 等を消す）．
export COPTS="${COPTS:+$COPTS }-gdwarf-4"

# フラグ変更で旧 .o が stale になるため削除して再コンパイルを強制する
echo "===== clean stale objects for -gdwarf-4 rebuild ====="
find "$OBJ_DIR" -name "*.o" -delete 2>/dev/null || true

mkdir -p "$OUT_DIR"
INFOS=""

# $1=ビルドディレクトリ, $2=ラベル
trace_and_cover() {
	local dir="$1" label="$2"
	[ -f "$dir/$kbin" ] || { echo "SKIP (no ELF): $label"; return 1; }
	local qlog="$dir/qemu.log" info="$dir/asmcov.info"
	# トレースは FIFO 経由で cap_stream.py（サイズ上限）に受けさせる．上限到達後は
	# 読み捨て＝QEMUのパイプを塞がず最後まで走らせ，先頭プレフィックスのみ集計する．
	# cap_stream を background 起動し PID を wait することで書き込み完了を同期する．
	(
		cd "$dir" || exit 1
		rm -f qemu.log trace.fifo
		mkfifo trace.fifo
		python3 "$abs_asmcov/cap_stream.py" qemu.log "$TRACE_CAP_BYTES" < trace.fifo &
		cappid=$!
		timeout "$QEMU_TIMEOUT" qemu-system-arm \
			-M xilinx-zynq-a9 -semihosting -m 512M -serial null -serial mon:stdio \
			-nographic -smp "$SMP_NCPU" -kernel "$kbin" \
			-d in_asm,exec,nochain -D trace.fifo \
			< /dev/null > execute.log 2>&1
		wait "$cappid"
		rm -f trace.fifo
	)
	local last; last=$(tr -d '\r' < "$dir/execute.log" | tail -1)
	echo "run $label: $last ($(du -h "$qlog" 2>/dev/null | cut -f1) trace)"
	[ -s "$qlog" ] || { echo "  WARN: empty qemu.log ($label)"; return 1; }
	# C0(行網羅)+C1(分岐網羅)を算出し兼用 lcov(.info: DA + BRDA) を出力．
	# テストごとに自身の ELF を母数にする（各テストは別リンク＝アドレス非互換のため）．
	python3 "$ASMCOV_DIR/branchcov.py" --elf "$dir/$kbin" --log "$qlog" \
		--prefix "$PREFIX" --include "$SRC_FILTER" --lcov "$info" 2>/dev/null \
		| grep -E '網羅|条件分岐' | sed 's/^/  /'
	# .info を「.S のみ」に絞り，SF: パスを realpath で正規化する．
	# 各テストは別ビルドdir のため SF: が ".../<test>/../../../../asp3//.../foo.S" と
	# テストごとに異なり，そのままだと lcov -a が同一 .S を別ファイル扱いして
	# マージできない．realpath で全テスト同一パスへ揃えて統合を成立させる．
	python3 - "$info" <<-'PY'
		import os, sys
		path = sys.argv[1]
		out, keep = [], False
		with open(path) as f:
		    for line in f:
		        if line.startswith('SF:'):
		            sf = line[3:].strip()
		            keep = sf.endswith('.S')
		            if keep:
		                out.append('TN:\n')
		                out.append('SF:' + os.path.realpath(sf) + '\n')
		            continue
		        if keep:
		            out.append(line)
		with open(path, 'w') as f:
		    f.writelines(out)
	PY
	# trace ログは大きいので集計後に削除（.info は残す）
	rm -f "$qlog"
	[ -s "$info" ] && INFOS="$INFOS -a $info"
}

echo "===== build: check_library ($PROFILE / -gdwarf-4) ====="
printf 'c\n1\n1\nr\nr\nq\n' | bash ttb.sh "$OS_PATH" "$PROFILE" "$OBJ_DIR" \
	> "/tmp/asmcov_build_chk_$$.log" 2>&1
ref_built=""
for d in exception interrupt timer; do
	dir="$OBJ_DIR/check_library/$d"
	if [ ! -f "$dir/$kbin" ]; then
		echo "BUILD WARN: check_library/$d (skip)"; continue
	fi
	[ -z "$ref_built" ] && ref_built="$dir"
	trace_and_cover "$dir" "check_library/$d"
done

# 依存部スクラッチ（層1・docs/DEP_COVERAGE_PLAN.md）．ソースが在る場合のみ．
# 既存 check_library のビルド済みディレクトリを複製し out.* を差し替えて
# -gdwarf-4 で再リンクする（COBJS はプロファイル別に明示指定）．
scratch_src="library/$PROFILE/check_library/dep_scratch"
if [ -f "$scratch_src/out.c" ] && [ -n "$ref_built" ]; then
	echo "===== build: dep_scratch ($PROFILE / -gdwarf-4) ====="
	# プロファイル別の共通カーネル/アプリ COBJS（ttb.sh と整合）
	K_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o"
	case "$PROFILE" in
		FMP)  K_COMMON="$K_COMMON objs/spin_lock.o" ;;
		HRP)  K_COMMON="$K_COMMON objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o" ;;
		HRMP) K_COMMON="$K_COMMON objs/messagebuf.o objs/svc_table.o objs/domain.o objs/mem_manage.o objs/memory.o objs/spin_lock.o" ;;
	esac
	A_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
	# ターゲット依存 COBJS は ttsp_target.sh から取得
	( unset KERNEL_COBJS_TARGET APPL_COBJS_TARGET
	  source "./library/$PROFILE/target/${TTSP_TARGET_NAME:-zybo_z7_gcc}/ttsp_target.sh" 2>/dev/null
	  echo "${KERNEL_COBJS_TARGET}|${APPL_COBJS_TARGET}" ) > /tmp/asmcov_cobjs_$$.txt
	K_TARGET="$(cut -d'|' -f1 /tmp/asmcov_cobjs_$$.txt)"
	A_TARGET="$(cut -d'|' -f2 /tmp/asmcov_cobjs_$$.txt)"
	rm -f /tmp/asmcov_cobjs_$$.txt
	sdir="$OBJ_DIR/check_library/dep_scratch"
	rm -rf "$sdir"; cp -rp "$ref_built" "$sdir"
	cp "$scratch_src"/out.c "$scratch_src"/out.cfg "$scratch_src"/out.h "$sdir"/
	( cd "$sdir" && rm -f "$kbin" qemu.log execute.log asmcov.info && make clean >/dev/null 2>&1; mkdir -p objs
	  COPTS=-gdwarf-4 make KERNEL_COBJS="$K_COMMON $K_TARGET" APPL_COBJS="$A_COMMON $A_TARGET" \
	    > /tmp/asmcov_build_scratch_$$.log 2>&1 )
	if [ -f "$sdir/$kbin" ]; then
		trace_and_cover "$sdir" "dep_scratch"
	else
		echo "BUILD WARN: dep_scratch (skip)"; tail -5 "/tmp/asmcov_build_scratch_$$.log"
	fi
fi

if [ "$MODE" = "bb" ]; then
	echo "===== build: API auto-code (${DIV_NUM}-way / -gdwarf-4) ====="
	bash scripts/ttsp_parallel_api.sh "$OS_PATH" "$PROFILE" "$OBJ_DIR" "$DIV_NUM"
	for i in $(seq 1 "$DIV_NUM"); do
		dir="$OBJ_DIR/api_test/auto_code_$i"
		[ -f "$dir/$kbin" ] && trace_and_cover "$dir" "api/auto_code_$i"
	done
fi

if [ -z "$INFOS" ]; then
	echo "ERROR: no coverage info produced"; exit 1
fi

MERGED="$OUT_DIR/asmcov_merged.info"
echo ""
echo "===== merge ($PROFILE, all tests) ====="
# lcov -a で (file,line[,branch]) 空間で全テストを統合（各テストは別リンク＝アドレス
# 非互換のため，命令アドレスの単純 union ではなく行/分岐単位で集計する）．
# BRDA は file:line:block:branch 単位でマージされる（同一ソース＋同一フラグなら
# 分岐の出現順=block が全テストで一致するため統合が成立する）．
lcov $INFOS -o "$MERGED" --rc lcov_branch_coverage=1 2>/dev/null | tail -3

echo ""
echo "===== HTML レポート（行網羅＋分岐網羅） ====="
genhtml "$MERGED" -o "$OUT_DIR/html" --branch-coverage \
	--rc genhtml_branch_coverage=1 >/dev/null 2>&1 \
	&& echo "  open $OUT_DIR/html/index.html"

echo ""
echo "===== 網羅サマリ（.S・全テスト統合 / C0 行網羅 + C1 分岐網羅） ====="
awk '
	/^SF:/ { n=split($0,a,"/"); f=a[n]; lf=lh=brf=brh=0 }
	/^LF:/ { sub("LF:",""); lf=$0 }
	/^LH:/ { sub("LH:",""); lh=$0 }
	/^BRF:/{ sub("BRF:",""); brf=$0 }
	/^BRH:/{ sub("BRH:",""); brh=$0 }
	/^end_of_record/ {
	         tlh+=lh; tlf+=lf; tbh+=brh; tbf+=brf;
	         printf "  %-20s 行 %4d/%-4d  分岐 %3d/%-3d\n", f, lh, lf, brh, brf }
	END    { if (tlf>0) printf "  %-20s 行 %4d/%-4d (%.1f%%)  分岐 %3d/%-3d (%s)\n", \
	           "合計", tlh, tlf, 100.0*tlh/tlf, tbh, tbf, \
	           (tbf>0 ? sprintf("%.1f%%", 100.0*tbh/tbf) : "n/a") }
' "$MERGED"
echo ""
echo "lcov: $MERGED"
