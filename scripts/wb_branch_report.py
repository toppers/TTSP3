#!/usr/bin/env python3
"""
wb_branch_report.py — WBテスト設計支援：ASP3カーネル未到達分岐レポート

gcov計測済みの obj_asp_gcov/ から全auto_codeグループを集計し，
指定カーネルソースの未到達分岐（C1カバレッジのギャップ）を表示する．
カバレッジ計測は事前に coverage_gcov_asp.sh full で実施すること．

使い方:
  python3 scripts/wb_branch_report.py task_sync
      未到達分岐のみ一覧表示（WBテスト設計の出発点）

  python3 scripts/wb_branch_report.py task_sync --lines 203-248
      指定行範囲の全分岐をカウント付きで表示（関数単位の分析用）

  python3 scripts/wb_branch_report.py task_sync --all
      ソース全体の全分岐をカウント付きで表示

  python3 scripts/wb_branch_report.py --list
      計測可能なカーネルソース一覧

  python3 scripts/wb_branch_report.py task_sync --obj-dir obj_fmp_gcov
      FMP3等，別プロファイルのカバレッジデータを参照

出力例（未到達分岐モード）:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    task_sync.c  ブランチカバレッジ  (23グループ集計)
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    全分岐: 118  到達: 117  未到達: 1  C1: 99.2%
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  未到達分岐  (1 箇所)

  行      分岐       ソース行（先頭60文字）
  ──────────────────────────────────────────────────────────────
  L210    br[0]      CHECK_UNL();
"""

import argparse
import collections
import glob
import os
import re
import subprocess
import sys

GCOV = "arm-none-eabi-gcov"


# ── gcno パスから ../../../../asp3/kernel/<base>.c を取り出すヘルパー ──────────

def _gcno_src_path(gcno_path):
    """gcno に埋め込まれたソースパスを返す（asp3/kernel/ ファイルのみ）"""
    try:
        out = subprocess.run(["strings", gcno_path],
                             capture_output=True, text=True).stdout
        for line in out.splitlines():
            if "asp3" in line and line.endswith(".c") and "/kernel/" in line:
                return line.strip()
    except Exception:
        pass
    return None


def find_kernel_sources(obj_dir):
    """obj_dir 内の auto_code_1/objs/*.gcno から kernel/*.c に対応するベース名を列挙"""
    sample_dir = os.path.join(obj_dir, "api_test", "auto_code_1", "objs")
    if not os.path.isdir(sample_dir):
        return []
    result = []
    for gcno in sorted(glob.glob(os.path.join(sample_dir, "*.gcno"))):
        src = _gcno_src_path(gcno)
        if src:
            result.append(os.path.splitext(os.path.basename(gcno))[0])
    return result


# ── gcov 実行 & パース ──────────────────────────────────────────────────────────

def run_gcov(auto_dir, src_rel):
    """auto_dir をカレントとして gcov を実行し，成功したら True を返す"""
    r = subprocess.run(
        [GCOV, "-b", "--branch-counts", "-o", "objs", src_rel],
        capture_output=True, text=True, cwd=auto_dir,
    )
    return r.returncode == 0


def parse_gcov_file(gcov_path):
    """
    .gcov ファイルを解析し，(branch_data, source_map) を返す．
      branch_data : {lineno: {br_idx: count}}
      source_map  : {lineno: source_text}
    """
    branch_data = collections.defaultdict(dict)
    source_map = {}
    cur_line = None
    br_idx = 0

    with open(gcov_path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            # branch行: "    branch  N  taken  M  ..."
            if re.match(r"\s*branch\s+\d+\s+taken\s+\d+", line):
                parts = line.split()
                try:
                    count = int(parts[3])
                    branch_data[cur_line][br_idx] = count
                    br_idx += 1
                except (IndexError, ValueError):
                    pass
                continue
            # call / unconditional 行はスキップ
            if re.match(r"\s*(call|unconditional)\s+", line):
                continue
            # ソース行: "   exec_count:  lineno:  source"
            m = re.match(r"[^:]+:\s*(\d+):(.*)", line)
            if m:
                lineno = int(m.group(1))
                if lineno > 0:
                    cur_line = lineno
                    br_idx = 0
                    source_map[lineno] = m.group(2)

    return branch_data, source_map


# ── 全グループ集計 ──────────────────────────────────────────────────────────────

def aggregate(obj_dir, basename):
    """
    obj_dir 内の全 auto_code_N グループにわたって分岐カウントを集計する．
    (branch_data, source_map, n_groups) を返す．
      branch_data : {lineno: {br_idx: total_count}}
      source_map  : {lineno: source_text}
      n_groups    : 処理したグループ数
    """
    pattern = os.path.join(obj_dir, "api_test", "auto_code_*",
                           "objs", f"{basename}.gcno")
    auto_dirs = sorted(
        os.path.dirname(os.path.dirname(g)) for g in glob.glob(pattern)
    )

    total_br = collections.defaultdict(lambda: collections.defaultdict(int))
    source_map = {}
    n_ok = 0

    for auto_dir in auto_dirs:
        src_rel = f"../../../../asp3/kernel/{basename}.c"
        if run_gcov(auto_dir, src_rel):
            gcov_path = os.path.join(auto_dir, f"{basename}.c.gcov")
            if os.path.exists(gcov_path):
                br, src = parse_gcov_file(gcov_path)
                for lineno, brs in br.items():
                    for idx, count in brs.items():
                        total_br[lineno][idx] += count
                if not source_map:
                    source_map = src
                n_ok += 1

    return total_br, source_map, n_ok


# ── レポート表示 ────────────────────────────────────────────────────────────────

_W = 68


def _header(title):
    bar = "━" * _W
    print(f"\n{bar}")
    print(f"  {title}")
    print(bar)


def print_summary(basename, n_groups, total, covered):
    _header(f"{basename}.c  ブランチカバレッジ  ({n_groups}グループ集計)")
    pct = 100.0 * covered / total if total else 0.0
    print(f"  全分岐: {total}  到達: {covered}  "
          f"未到達: {total - covered}  C1: {pct:.1f}%")
    print("━" * _W)


def print_uncovered(branch_data, source_map):
    """未到達分岐のみ表示（既定モード）"""
    uncov_lines = sorted(
        l for l, brs in branch_data.items() if any(c == 0 for c in brs.values())
    )
    n_uncov = sum(
        1 for brs in branch_data.values() for c in brs.values() if c == 0
    )
    if not uncov_lines:
        print("\n  ✓ 未到達分岐なし（C1カバレッジ 100%）")
        return

    print(f"\n未到達分岐  ({n_uncov} 箇所)\n")
    print(f"{'行':<8} {'分岐':<12} {'ソース行（先頭60文字）'}")
    print("─" * _W)
    for lineno in uncov_lines:
        brs = branch_data[lineno]
        uncov = [i for i, c in sorted(brs.items()) if c == 0]
        br_str = ", ".join(f"br[{i}]" for i in uncov)
        src = (source_map.get(lineno) or "").strip()[:60]
        print(f"L{lineno:<6}  {br_str:<12}  {src}")


def print_range(branch_data, source_map, lo, hi):
    """指定行範囲の全分岐をカウント付きで表示（関数単位の分析用）"""
    lines_in_range = sorted(l for l in branch_data if lo <= l <= hi)
    if not lines_in_range:
        print(f"\n  L{lo}–L{hi} の範囲に分岐データがありません。")
        return

    print(f"\nL{lo}–L{hi} 全分岐\n")
    print(f"{'行':<8} {'分岐カウント':<45} {'ソース行'}")
    print("─" * _W)
    for lineno in lines_in_range:
        brs = branch_data[lineno]
        src = (source_map.get(lineno) or "").strip()
        br_parts = []
        for idx in sorted(brs):
            c = brs[idx]
            tag = "【0】" if c == 0 else str(c)
            br_parts.append(f"br[{idx}]={tag}")
        br_str = "  ".join(br_parts)
        uncov = any(c == 0 for c in brs.values())
        flag = "  ◀" if uncov else ""
        print(f"L{lineno:<6}  {src}")
        print(f"          {br_str}{flag}")


def print_all(branch_data, source_map):
    """全ソース行の全分岐をカウント付きで表示"""
    print(f"\n全分岐\n")
    for lineno in sorted(branch_data):
        brs = branch_data[lineno]
        src = (source_map.get(lineno) or "").strip()
        br_parts = []
        for idx in sorted(brs):
            c = brs[idx]
            tag = "【0】" if c == 0 else str(c)
            br_parts.append(f"br[{idx}]={tag}")
        br_str = "  ".join(br_parts)
        uncov = any(c == 0 for c in brs.values())
        flag = "  ◀" if uncov else ""
        print(f"L{lineno:<6}  {src}")
        print(f"          {br_str}{flag}")


# ── main ────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="WBテスト設計支援：ASP3カーネル未到達分岐レポート",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("basename", nargs="?",
                    help="ソースファイルのベース名（例: task_sync）")
    ap.add_argument("--lines", metavar="N-M",
                    help="指定行範囲の全分岐を表示（例: --lines 203-248）")
    ap.add_argument("--all", action="store_true",
                    help="ソース全体の全分岐をカウント付きで表示")
    ap.add_argument("--obj-dir", default="obj_asp_gcov",
                    metavar="DIR",
                    help="gcovオブジェクトディレクトリ（既定: obj_asp_gcov）")
    ap.add_argument("--list", action="store_true",
                    help="計測可能なカーネルソース一覧を表示して終了")
    args = ap.parse_args()

    if args.list or not args.basename:
        available = find_kernel_sources(args.obj_dir)
        if not available:
            print(f"ERROR: {args.obj_dir}/ が見つからないか gcno が存在しません。")
            print("  coverage_gcov_asp.sh full を先に実行してください。")
            sys.exit(1)
        print(f"計測可能なカーネルソース ({args.obj_dir}/):")
        for name in available:
            print(f"  {name}.c")
        return

    basename = args.basename.removesuffix(".c")
    available = find_kernel_sources(args.obj_dir)
    if basename not in available:
        print(f"ERROR: '{basename}.c' のデータが {args.obj_dir}/ に見つかりません。")
        print("  --list で一覧を確認するか, coverage_gcov_asp.sh full を実行してください。")
        sys.exit(1)

    print(f"[集計中: {args.obj_dir}/api_test/auto_code_*/]", file=sys.stderr)
    branch_data, source_map, n_groups = aggregate(args.obj_dir, basename)

    if not branch_data:
        print("分岐データが取得できませんでした。gcovビルドを確認してください。")
        sys.exit(1)

    all_br = [(l, i, c) for l, brs in branch_data.items()
              for i, c in brs.items()]
    total = len(all_br)
    covered = sum(1 for _, _, c in all_br if c > 0)

    print_summary(basename, n_groups, total, covered)

    if args.lines:
        m = re.match(r"(\d+)-(\d+)$", args.lines)
        if not m:
            print("ERROR: --lines は 'N-M' の形式で指定してください（例: --lines 203-248）")
            sys.exit(1)
        lo, hi = int(m.group(1)), int(m.group(2))
        print_range(branch_data, source_map, lo, hi)
    elif args.all:
        print_all(branch_data, source_map)
    else:
        print_uncovered(branch_data, source_map)


if __name__ == "__main__":
    main()
