#!/usr/bin/env python3
#
#  TTSP3 gcov集計レポータ（FMP GCOV方式用）
#
#  各テストディレクトリの objs/*.gcda を `arm-none-eabi-gcov --json-format`
#  で解析し，(ソースファイル,行) 単位の和集合でカーネル行カバレッジを
#  集計する．lcov 不要．分岐カバレッジ(C1)のサマリも出す．
#
#  使い方:
#    ttsp_gcov_report.py [--filter SUBSTR] [--uncovered] [--by-function] DIR...
#      DIR : objs/*.gcda(.gcno) を含むテストディレクトリ
#      --by-function : ファイル別に加え，関数（API）別の分岐カバレッジも出力する
#                      （gcov JSON の functions[].start_line/end_line で行単位データを
#                        関数の行範囲にバケツ分けして集計．per-API 表の自動生成に使う）
#
import argparse
import glob
import gzip
import json
import os
import subprocess
import sys
import tempfile

GCOV = os.environ.get("GCOV", "arm-none-eabi-gcov")


def collect_dir(d, acc, func_acc=None):
    """1ディレクトリのgcdaを解析しaccへ統合する．
    func_acc を渡すと func_acc[path][関数名] = (start_line, end_line) も収集する．"""
    objs = os.path.join(d, "objs")
    gcdas = glob.glob(os.path.join(objs, "*.gcda"))
    if not gcdas:
        return 0
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([GCOV, "--json-format", "--branch-probabilities"]
                       + [os.path.abspath(g) for g in gcdas],
                       cwd=tmp, capture_output=True, text=True)
        for jz in glob.glob(os.path.join(tmp, "*.gcov.json.gz")):
            with gzip.open(jz, "rt") as f:
                data = json.load(f)
            base = data.get("current_working_directory", "")
            for filerec in data.get("files", []):
                path = filerec["file"]
                if not os.path.isabs(path):
                    path = os.path.join(base, path)
                path = os.path.normpath(path)
                rec = acc.setdefault(path, {})
                for line in filerec.get("lines", []):
                    ln = line["line_number"]
                    cnt, br_tot, br_cov_set = rec.get(ln, (0, 0, set()))
                    branches = line.get("branches", [])
                    covered = {i for i, b in enumerate(branches)
                               if b.get("count", 0) > 0}
                    rec[ln] = (
                        cnt + line.get("count", 0),
                        max(br_tot, len(branches)),
                        br_cov_set | covered,
                    )
                if func_acc is not None:
                    frec = func_acc.setdefault(path, {})
                    for fn in filerec.get("functions", []):
                        name = fn.get("demangled_name") or fn.get("name")
                        s = fn.get("start_line")
                        e = fn.get("end_line", s)
                        if name is None or s is None:
                            continue
                        os_, oe = frec.get(name, (s, e))
                        frec[name] = (min(os_, s), max(oe, e))
    return len(gcdas)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--filter", default="/fmp3/kernel/",
                    help="集計対象ソースのパス部分文字列（既定: /fmp3/kernel/）")
    ap.add_argument("--uncovered", action="store_true")
    ap.add_argument("--by-function", action="store_true",
                    help="関数（API）別の分岐カバレッジも出力する")
    ap.add_argument("dirs", nargs="+")
    args = ap.parse_args()

    acc = {}   # path -> {line: (count, br_total, br_covered)}
    func_acc = {} if args.by_function else None  # path -> {name: (start,end)}
    used = 0
    for d in args.dirs:
        n = collect_dir(d, acc, func_acc)
        if n:
            used += 1
        else:
            print(f"skip: {d} (gcdaなし)", file=sys.stderr)
    if used == 0:
        print("ERROR: 有効な入力ディレクトリがない", file=sys.stderr)
        return 1

    print(f"=== kernel coverage by gcov (filter: {args.filter}, dirs: {used}) ===")
    print(f"{'file':24s} {'line cov':>14s} {'branch cov':>14s}")
    tl = cl = tb = cb = 0
    targets = {p: rec for p, rec in acc.items() if args.filter in p}
    for path in sorted(targets):
        rec = targets[path]
        lt = len(rec)
        lc = sum(1 for c, _, _ in rec.values() if c > 0)
        bt = sum(b for _, b, _ in rec.values())
        bc = sum(len(s) for _, _, s in rec.values())
        tl += lt; cl += lc; tb += bt; cb += bc
        line_part = f"{os.path.basename(path):24s} {lc:5d}/{lt:<5d} {100*lc/lt:5.1f}%"
        if bt:
            print(f"{line_part}  {bc:5d}/{bt:<5d} {100*bc/bt:5.1f}%")
        else:
            print(f"{line_part}        -")
    if tl:
        total_part = f"{'TOTAL':24s} {cl:5d}/{tl:<5d} {100*cl/tl:5.1f}%"
        if tb:
            total_part += f"  {cb:5d}/{tb:<5d} {100*cb/tb:5.1f}%"
        print(total_part)

    if args.uncovered:
        print("\n=== uncovered lines ===")
        for path in sorted(targets):
            miss = sorted(ln for ln, (c, _, _) in targets[path].items() if c == 0)
            if miss:
                print(f"{path}: {','.join(map(str, miss))}")

    if args.by_function:
        print("\n=== per-function branch coverage ===")
        print(f"{'function (file)':44s} {'line cov':>12s} {'branch cov':>14s}")
        for path in sorted(targets):
            rec = targets[path]
            funcs = func_acc.get(path, {})
            if not funcs:
                continue
            base = os.path.basename(path)
            # 関数を開始行順に
            for name, (s, e) in sorted(funcs.items(), key=lambda kv: kv[1][0]):
                lt = lc = bt = bc = 0
                for ln, (c, b, cov) in rec.items():
                    if s <= ln <= e:
                        lt += 1
                        if c > 0:
                            lc += 1
                        bt += b
                        bc += len(cov)
                if lt == 0:
                    continue
                label = f"{name} ({base})"
                line_part = f"{label:44s} {lc:4d}/{lt:<4d} {100*lc/lt:5.1f}%"
                if bt:
                    mark = "" if bc == bt else "  ◀"
                    print(f"{line_part}  {bc:4d}/{bt:<4d} {100*bc/bt:5.1f}%{mark}")
                else:
                    print(f"{line_part}        -")
    return 0


if __name__ == "__main__":
    sys.exit(main())
