#!/usr/bin/env python3
"""
branchcov.py — QEMU の `-d in_asm,exec,nochain` ログから
C1（分岐網羅 / 判定網羅）を算出する。

原理:
  - objdump -d から条件分岐を列挙し、各分岐の
      taken 先 T（オペランドのターゲット）と
      fall-through 先 F（次命令アドレス）の 2 エッジを母数にする
  - 実行 TB 列（順序付き）から「前TBの末尾命令 -> 次TBの先頭命令」を
    観測エッジとして集める（QEMU は条件分岐で必ず TB を切るので、
    末尾＝分岐 / 次TB先頭＝T か F になり taken/not-taken を判別できる）
  - 各条件分岐で T・F の両方を観測できたかが C1

複数ログを渡すと観測エッジをマージする（複数入力で C1 を上げる）。

使い方:
  qemu-system-arm ... -d in_asm,exec,nochain -D qemu.log
  ./branchcov.py --elf demo.elf --log qemu.log [log2 ...] --include demo.s
"""

import argparse
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qlog_to_pcs import parse_blocks, executed_pcs  # IN: ブロック解析を再利用
import asmcov  # 行カバレッジ(C0)の算出を再利用（--lcov 出力時のみ）

HEX_RE = re.compile(r'[0-9a-fA-F]{4,}')
INSN_LINE_RE = re.compile(r'^\s*[0-9a-fA-F]+:\t')
# Trace 行の CPU 番号 "Trace 0: 0x..." / "Trace 1: 0x..."（SMP で各 vCPU が付与）
TRACE_CPU_RE = re.compile(r'^Trace\s+(\d+):')

# ARM/Thumb の条件コード（al=常時 は除く）
COND = {'eq', 'ne', 'cs', 'hs', 'cc', 'lo', 'mi', 'pl',
        'vs', 'vc', 'hi', 'ls', 'ge', 'lt', 'gt', 'le'}
IT_RE = re.compile(r'^it[te]{0,3}$')


# ---------------- objdump 側（静的情報） ----------------

def parse_insns(text):
    """objdump -d 出力を [{addr, mnem, operand}, ...]（アドレス順）に。"""
    insns = []
    for line in text.splitlines():
        if not INSN_LINE_RE.match(line):
            continue
        parts = line.split('\t')
        if len(parts) < 3:
            continue
        addr = int(parts[0].strip().rstrip(':'), 16)
        mnem = parts[2].strip()
        operand = parts[3].strip() if len(parts) >= 4 else ''
        if mnem:
            insns.append({'addr': addr, 'mnem': mnem, 'operand': operand})
    return insns


def is_cond_branch(mnem):
    m = mnem.lower()
    if m.endswith('.n') or m.endswith('.w'):
        m = m[:-2]
    if m in ('cbz', 'cbnz'):
        return True
    return m.startswith('b') and len(m) == 3 and m[1:3] in COND


def branch_target(operand):
    """分岐オペランドから絶対ターゲットアドレスを取り出す。"""
    op = re.sub(r'<[^>]*>', '', operand)           # <sym> を除去
    cands = re.findall(r'\b([0-9a-fA-F]+)\b', op)   # 純粋な hex（レジスタは除外される）
    return int(cands[-1], 16) if cands else None


def find_cond_branches(insns):
    out = []
    for i, ins in enumerate(insns):
        if is_cond_branch(ins['mnem']):
            t = branch_target(ins['operand'])
            f = insns[i + 1]['addr'] if i + 1 < len(insns) else None
            out.append({'addr': ins['addr'], 'mnem': ins['mnem'], 't': t, 'f': f})
    return out


def count_it_blocks(insns):
    return sum(1 for ins in insns if IT_RE.match(ins['mnem'].lower()))


# ---------------- ログ側（動的情報） ----------------

def ordered_tb_starts_by_cpu(text, starts):
    """実行 TB 先頭の列を **CPU ごとに分離**して返す（{cpu: [tb_start, ...]}）。

    SMP では QEMU が複数 vCPU の Trace 行を時間順に交錯して出力する。
    エッジ復元は「同一コア上の連続実行」が前提なので、コア番号でバケツ
    分けしてから隣接を取らないと、コアをまたいだ偽エッジが混入する。
    単一コア（`Trace 0:` のみ）なら {0: [...]} の 1 バケツになり従来と同じ。
    """
    seqs = {}
    for line in text.splitlines():
        m = TRACE_CPU_RE.match(line)
        if not m:
            continue
        cpu = int(m.group(1))
        for tok in HEX_RE.findall(line):
            v = int(tok, 16)
            if v in starts:
                seqs.setdefault(cpu, []).append(v)
                break
    return seqs


def ordered_tb_starts(text, starts):
    """全コアの実行 TB 先頭を時間順にフラットに返す（後方互換の薄いラッパ）。

    エッジ復元には使わないこと（交錯したコアの隣接が偽エッジになる）。
    CPU 分離が必要な箇所は ordered_tb_starts_by_cpu を使う。
    """
    seq = []
    for line in text.splitlines():
        if not line.startswith('Trace'):
            continue
        for tok in HEX_RE.findall(line):
            v = int(tok, 16)
            if v in starts:
                seq.append(v)
                break
    return seq


def edges_from_log(text):
    """1ログから観測エッジ集合 {(src_insn, dst_tb_start)} を返す。

    SMP ログでも正しく動くよう、CPU ごとに分離した TB 列の中だけで
    隣接エッジを取り、最後に全コア分を union する。コアをまたぐ
    遷移は制御フローではないのでエッジにしない。
    """
    tb = parse_blocks(text)
    starts = set(tb)
    seqs = ordered_tb_starts_by_cpu(text, starts)
    edges = set()
    for seq in seqs.values():
        for a, b in zip(seq, seq[1:]):
            if tb.get(a):
                edges.add((tb[a][-1], b))   # 前TB末尾命令 -> 次TB先頭（同一コア内）
    return edges


# ---------------- 集計 ----------------

def compute_c1(branches, edges):
    results = []
    covered = 0
    for br in branches:
        taken = (br['addr'], br['t']) in edges
        fall = (br['addr'], br['f']) in edges
        covered += int(taken) + int(fall)
        results.append({**br, 'taken': taken, 'fall': fall})
    total = 2 * len(branches)
    return results, covered, total


# ---------------- addr2line（表示・絞り込み用） ----------------

def addr2line_map(elf, addrs, prefix):
    if not addrs:
        return {}
    stdin = '\n'.join(hex(a) for a in addrs) + '\n'
    try:
        out = subprocess.run([f'{prefix}addr2line', '-e', elf],
                             input=stdin, capture_output=True,
                             text=True, check=True).stdout
    except (FileNotFoundError, subprocess.CalledProcessError):
        return {}
    mp = {}
    for a, line in zip(addrs, out.splitlines()):
        line = line.strip()
        if line and not line.startswith('??'):
            mp[a] = line
    return mp


# ---------------- lcov 出力（C0 行網羅 + C1 分岐網羅） ----------------

def write_lcov(path, line_total, line_hit, branch_results, line_of):
    """genhtml --branch-coverage 用に DA(行) + BRDA(分岐) を書き出す。

    line_total/line_hit は asmcov.aggregate と同じ (file,line)->{addr,...}。
    branch_results は compute_c1 の結果（include 絞り込み済み）。
    """
    from collections import defaultdict

    files = set(f for f, _ in line_total)
    da = defaultdict(dict)                 # file -> {line: hit_count}
    for (f, l), addrs in line_total.items():
        da[f][l] = len(line_hit.get((f, l), ()))

    # 分岐を file -> [(line, block, taken, fall)] に整理。block は分岐ごとに採番。
    brda = defaultdict(list)
    blk = defaultdict(int)
    for r in branch_results:
        loc = line_of.get(r['addr'])
        if not loc:
            continue
        f, l = loc
        files.add(f)
        brda[f].append((l, blk[f], r['taken'], r['fall']))
        blk[f] += 1

    def cell(reached, hit):
        # 分岐自体が一度も到達されなければ '-'、到達したが未通過なら 0
        return '1' if hit else ('-' if not reached else '0')

    with open(path, 'w') as fp:
        for f in sorted(files):
            fp.write('TN:\n')
            fp.write(f'SF:{f}\n')
            for l in sorted(da[f]):
                fp.write(f'DA:{l},{da[f][l]}\n')
            brf = brh = 0
            for l, block, taken, fall in sorted(brda[f]):
                reached = taken or fall
                fp.write(f'BRDA:{l},{block},0,{cell(reached, taken)}\n')  # taken 側
                fp.write(f'BRDA:{l},{block},1,{cell(reached, fall)}\n')   # fall 側
                brf += 2
                brh += int(taken) + int(fall)
            lf = len(da[f])
            lh = sum(1 for l in da[f] if da[f][l] > 0)
            fp.write(f'LF:{lf}\nLH:{lh}\n')
            fp.write(f'BRF:{brf}\nBRH:{brh}\n')
            fp.write('end_of_record\n')


def main():
    ap = argparse.ArgumentParser(description='QEMU ログから C1（分岐網羅）を算出')
    ap.add_argument('--elf', required=True)
    ap.add_argument('--log', nargs='+', required=True,
                    help='-d in_asm,exec,nochain のログ（複数指定で観測エッジをマージ）')
    ap.add_argument('--prefix', default='arm-none-eabi-')
    ap.add_argument('--include', default='',
                    help='このパス部分文字列を含む分岐だけ集計')
    ap.add_argument('--lcov',
                    help='C0(行網羅)+C1(分岐網羅)の lcov .info 出力先 '
                         '(genhtml --branch-coverage で HTML 化)')
    args = ap.parse_args()

    objdump = subprocess.run([f'{args.prefix}objdump', '-d', args.elf],
                             capture_output=True, text=True, check=True).stdout
    insns = parse_insns(objdump)
    branches = find_cond_branches(insns)
    it_count = count_it_blocks(insns)

    edges = set()
    for path in args.log:
        with open(path) as fp:
            edges |= edges_from_log(fp.read())

    # 表示・絞り込み用の行情報
    line_of = addr2line_map(args.elf, [b['addr'] for b in branches], args.prefix)
    if args.include:
        branches = [b for b in branches
                    if args.include in line_of.get(b['addr'], '')]

    results, covered, total = compute_c1(branches, edges)

    def mark(ok):
        return '○' if ok else '×'

    pct = f'{100.0 * covered / total:.1f}%' if total else 'n/a'
    print('=== C1（分岐網羅 / 判定網羅） ===')
    print(f'条件分岐数 : {len(branches)}')
    print(f'網羅エッジ : {covered}/{total} ({pct})')

    miss = [r for r in results if not (r['taken'] and r['fall'])]
    print('\n=== 未充足の分岐 ===')
    if not miss:
        print('  （全分岐 taken/not-taken 両方を網羅）')
    for r in miss:
        loc = line_of.get(r['addr'], hex(r['addr']))
        ttag = '' if r['t'] is None else f'->{hex(r["t"])}'
        print(f'  {loc}\t{r["mnem"]} {ttag}\t'
              f'taken={mark(r["taken"])} fall={mark(r["fall"])}')

    if it_count:
        print(f'\n注意: IT ブロックを {it_count} 個検出しました。'
              'IT による条件実行は分岐命令を伴わないため、'
              'この C1 集計には含まれていません（別途、述語命令の真/偽実行の'
              '判定が必要）。')

    # ---- lcov 出力（行網羅は asmcov の集計、分岐網羅は BRDA で付与）----
    if args.lcov:
        all_addrs = [ins['addr'] for ins in insns]
        line_tuple = asmcov.addr2line(args.elf, all_addrs, args.prefix)  # addr->(path,line)
        executed = set()
        for path in args.log:
            with open(path) as fp:
                text = fp.read()
            executed |= set(executed_pcs(text, parse_blocks(text)))
        agg = asmcov.aggregate(all_addrs, line_tuple, executed, args.include)
        write_lcov(args.lcov, agg['line_total'], agg['line_hit'], results, line_tuple)
        print(f'\nlcov を書き出しました: {args.lcov}')
        print(f'  genhtml --branch-coverage {args.lcov} -o cov_html  で HTML 化できます')


if __name__ == '__main__':
    main()
