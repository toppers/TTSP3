#!/usr/bin/env python3
#
#  TTSP3 カーネル行カバレッジレポータ
#
#  QEMUのTCGプラグイン drcov が出力した実行基本ブロック表と，
#  arm-none-eabi-objdump -dl の行番号情報を突き合わせて，
#  被テストカーネル（既定: asp3/kernel/ 配下＝ターゲット非依存部）の
#  行カバレッジを計算する．ターゲット側の計装（gcov等）は不要で，
#  テストを緑にした既存バイナリのまま計測できる．
#
#  使い方:
#    ttsp_coverage.py [--filter SUBSTR] [--uncovered] DIR...
#      DIR : 'asp'（ELF）と 'coverage.drcov' を含むテストディレクトリ
#    複数DIRを与えると (ファイル,行) 単位で和集合をとって統合する．
#
#  注意:
#    - 行カバレッジ（C0相当）であり分岐カバレッジではない
#    - 分母は「objdumpの行情報に現れた行」＝コード生成された行
#
import argparse
import bisect
import os
import re
import struct
import subprocess
import sys

OBJDUMP = os.environ.get("OBJDUMP", "arm-none-eabi-objdump")


def parse_drcov(path):
    """drcovファイルから実行された [start, end) アドレス区間リストを返す"""
    with open(path, "rb") as f:
        data = f.read()
    m = re.search(rb"BB Table: (\d+) bbs\n", data)
    if m is None:
        raise ValueError(f"{path}: BB Table not found")
    n = int(m.group(1))
    off = m.end()
    ivs = []
    for i in range(n):
        start, size, _mod = struct.unpack_from("<IHH", data, off + i * 8)
        ivs.append((start, start + size))
    return ivs


def objdump_lines(elf):
    """ELFから insn addr -> (srcfile, line) のマップを作る（要 -g ビルド）"""
    out = subprocess.run([OBJDUMP, "-dl", elf], capture_output=True,
                         text=True, check=True).stdout
    addr2loc = {}
    cur = None
    for ln in out.splitlines():
        m = re.match(r"(/[^:]+):(\d+)(?:\s.*)?$", ln)
        if m:
            cur = (os.path.normpath(m.group(1)), int(m.group(2)))
            continue
        m = re.match(r"\s+([0-9a-f]+):\t", ln)
        if m and cur:
            addr2loc[int(m.group(1), 16)] = cur
    return addr2loc


def make_hit_fn(ivs):
    ivs = sorted(ivs)
    starts = [s for s, _ in ivs]
    ends = [e for _, e in ivs]

    def hit(a):
        i = bisect.bisect_right(starts, a) - 1
        return i >= 0 and a < ends[i]
    return hit


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--filter", default="/asp3/kernel/",
                    help="集計対象ソースのパス部分文字列（既定: /asp3/kernel/）")
    ap.add_argument("--drcov-name", default="coverage.drcov",
                    help="各DIR内のdrcovファイル名（既定: coverage.drcov）")
    ap.add_argument("--uncovered", action="store_true",
                    help="未カバー行の一覧も出力する")
    ap.add_argument("dirs", nargs="+")
    args = ap.parse_args()

    total = {}   # file -> set(line)
    cov = {}     # file -> set(line)
    used = 0
    for d in args.dirs:
        elf = os.path.join(d, "asp")
        drc = os.path.join(d, args.drcov_name)
        if not (os.path.isfile(elf) and os.path.isfile(drc)):
            print(f"skip: {d} (asp/{args.drcov_name} なし)", file=sys.stderr)
            continue
        used += 1
        hit = make_hit_fn(parse_drcov(drc))
        for addr, (f, line) in objdump_lines(elf).items():
            if args.filter not in f:
                continue
            total.setdefault(f, set()).add(line)
            if hit(addr):
                cov.setdefault(f, set()).add(line)

    if used == 0:
        print("ERROR: 有効な入力ディレクトリがない", file=sys.stderr)
        return 1

    print(f"=== kernel line coverage (filter: {args.filter}, dirs: {used}) ===")
    tl = cl = 0
    for f in sorted(total):
        t = len(total[f])
        c = len(cov.get(f, set()))
        tl += t
        cl += c
        print(f"{os.path.basename(f):24s} {c:5d}/{t:5d}  {100 * c / t:5.1f}%")
    print(f"{'TOTAL':24s} {cl:5d}/{tl:5d}  {100 * cl / tl:5.1f}%")

    if args.uncovered:
        print("\n=== uncovered lines ===")
        for f in sorted(total):
            miss = sorted(total[f] - cov.get(f, set()))
            if miss:
                print(f"{f}: {','.join(map(str, miss))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
