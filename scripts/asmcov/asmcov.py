#!/usr/bin/env python3
"""
asmcov.py — QEMU TCG プラグイン (execlog) の実行ログから、
arm-none-eabi で組んだアセンブリの「命令網羅 / 行網羅」を算出する。

前提:
  1) デバッグ行情報付きでビルドした ELF
       arm-none-eabi-as -g -o foo.o foo.s
       arm-none-eabi-ld ... -o firmware.elf
  2) QEMU の execlog プラグインで取得した実行ログ
       qemu-system-arm -M <machine> -cpu <cpu> -nographic -kernel firmware.elf \
         -plugin /path/to/contrib/plugins/libexeclog.so -d plugin -D exec.log

出力:
  - コンソールに命令網羅率 / 行網羅率のサマリ
  - lcov 形式の .info（genhtml で HTML 化可能）
  - 任意でソース行ごとの未実行リスト

使用例:
  ./asmcov.py --elf firmware.elf --execlog exec.log \
      --include /path/to/src --lcov coverage.info --annotate
"""

import argparse
import re
import subprocess
import sys
from collections import defaultdict

# 行内に現れる最初の 0x... を PC とみなす（execlog の先頭フィールドが vaddr のため）
HEX_RE = re.compile(r'0x[0-9a-fA-F]+')
# objdump -d の命令行:  "   80001f4:\t4805      \tldr\tr0, [pc, #20]"
# （関数ヘッダ "080001f4 <main>:" はコロン直後がタブでないので除外される）
OBJDUMP_INSN_RE = re.compile(r'^\s*([0-9a-fA-F]+):\t')


def run(cmd, input_text=None):
    try:
        return subprocess.run(
            cmd, input=input_text, capture_output=True, text=True, check=True,
        ).stdout
    except FileNotFoundError:
        sys.exit(f"コマンドが見つかりません: {cmd[0]}（--prefix を確認）")
    except subprocess.CalledProcessError as e:
        sys.exit(f"{cmd[0]} が失敗しました:\n{e.stderr}")


def parse_objdump(text):
    """objdump -d 出力から命令アドレス一覧を返す。"""
    addrs = []
    for line in text.splitlines():
        m = OBJDUMP_INSN_RE.match(line)
        if m:
            addrs.append(int(m.group(1), 16))
    return addrs


def parse_execlog(text, pc_regex):
    """execlog から実行された PC の集合を返す。"""
    rx = re.compile(pc_regex) if pc_regex else HEX_RE
    executed = set()
    for line in text.splitlines():
        m = rx.search(line)
        if m:
            try:
                executed.add(int(m.group(0), 16))
            except ValueError:
                pass
    return executed


def parse_addr2line(output, addrs):
    """addr2line 出力（1アドレス1行: file:line）を addrs と zip して dict 化。"""
    mapping = {}
    for addr, line in zip(addrs, output.splitlines()):
        line = line.strip()
        if line.startswith('??') or ':' not in line:
            continue
        path, _, lno = line.rpartition(':')
        lno = lno.split()[0] if lno else ''   # "123 (discriminator 1)" に対応
        if path in ('', '??') or not lno.isdigit() or int(lno) == 0:
            continue
        mapping[addr] = (path, int(lno))
    return mapping


def addr2line(elf, addrs, prefix):
    if not addrs:
        return {}
    stdin = '\n'.join(hex(a) for a in addrs) + '\n'
    out = run([f'{prefix}addr2line', '-e', elf], input_text=stdin)
    return parse_addr2line(out, addrs)


def aggregate(insn_addrs, line_of, executed, include):
    insn_set = set(insn_addrs)
    exec_in_scope = executed & insn_set

    line_total = defaultdict(set)   # (file,line) -> {addr,...}
    line_hit = defaultdict(set)
    for a in insn_set:
        loc = line_of.get(a)
        if loc is None:
            continue
        if include and include not in loc[0]:
            continue
        line_total[loc].add(a)
        if a in exec_in_scope:
            line_hit[loc].add(a)

    # include 指定時は命令網羅も対象ソースに絞る
    if include:
        scoped = {a for a in insn_set
                  if line_of.get(a) and include in line_of[a][0]}
        total_insn = len(scoped)
        hit_insn = len(scoped & exec_in_scope)
    else:
        total_insn = len(insn_set)
        hit_insn = len(exec_in_scope)

    return {
        'total_insn': total_insn, 'hit_insn': hit_insn,
        'line_total': line_total, 'line_hit': line_hit,
    }


def write_lcov(path, line_total, line_hit):
    per_file = defaultdict(dict)  # file -> {line: count}
    for key in line_total:
        f, l = key
        per_file[f][l] = len(line_hit.get(key, ()))
    with open(path, 'w') as fp:
        for f in sorted(per_file):
            fp.write('TN:\n')
            fp.write(f'SF:{f}\n')
            found = hit = 0
            for l in sorted(per_file[f]):
                c = per_file[f][l]
                fp.write(f'DA:{l},{c}\n')
                found += 1
                hit += 1 if c > 0 else 0
            fp.write(f'LF:{found}\n')
            fp.write(f'LH:{hit}\n')
            fp.write('end_of_record\n')


def main():
    ap = argparse.ArgumentParser(
        description='QEMU execlog からアセンブリの命令/行カバレッジを算出')
    ap.add_argument('--elf', required=True, help='デバッグ情報付き ELF')
    ap.add_argument('--execlog', required=True, help='execlog プラグインの出力')
    ap.add_argument('--prefix', default='arm-none-eabi-', help='ツールチェーン接頭辞')
    ap.add_argument('--include', default='',
                    help='このパス部分文字列を含むソースだけ集計（startup等を除外）')
    ap.add_argument('--lcov', help='lcov .info の出力先')
    ap.add_argument('--pc-regex', default='',
                    help='execlog から PC を抜く正規表現（既定: 行内最初の 0x...）')
    ap.add_argument('--annotate', action='store_true', help='未実行の行を一覧表示')
    args = ap.parse_args()

    insn_addrs = parse_objdump(run([f'{args.prefix}objdump', '-d', args.elf]))
    if not insn_addrs:
        sys.exit('命令アドレスを抽出できませんでした（objdump 出力を確認）')

    with open(args.execlog) as fp:
        executed = parse_execlog(fp.read(), args.pc_regex)
    if not executed:
        print('警告: execlog から PC を1つも抽出できませんでした。'
              '--pc-regex の調整が必要かもしれません。', file=sys.stderr)

    line_of = addr2line(args.elf, insn_addrs, args.prefix)
    agg = aggregate(insn_addrs, line_of, executed, args.include)

    lt, lh = agg['line_total'], agg['line_hit']
    total_lines = len(lt)
    hit_lines = sum(1 for k in lt if lh.get(k))

    def pct(n, d):
        return f'{100.0 * n / d:.1f}%' if d else 'n/a'

    print('=== カバレッジ ===')
    print(f'命令網羅 : {agg["hit_insn"]}/{agg["total_insn"]} '
          f'({pct(agg["hit_insn"], agg["total_insn"])})')
    print(f'行網羅   : {hit_lines}/{total_lines} '
          f'({pct(hit_lines, total_lines)})')

    if args.annotate:
        print('\n=== 未実行の行 ===')
        miss = [k for k in sorted(lt) if not lh.get(k)]
        if not miss:
            print('  （すべて実行済み）')
        for f, l in miss:
            print(f'  {f}:{l}')

    if args.lcov:
        write_lcov(args.lcov, lt, lh)
        print(f'\nlcov を書き出しました: {args.lcov}')
        print(f'  genhtml {args.lcov} -o cov_html  で HTML レポート化できます')


if __name__ == '__main__':
    main()
