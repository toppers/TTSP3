#!/usr/bin/env python3
"""
qlog_to_pcs.py — QEMU の `-d in_asm,exec,nochain` ログを、
実行された命令アドレス一覧（1行1アドレス）に変換する。

QEMU プラグイン (libexeclog.so) をビルドしなくても、標準の
qemu-system-* だけで命令カバレッジ用の PC 列を得るための変換器。

仕組み:
  - `IN:` ブロック（翻訳された各 TB の逆アセンブル）から
    「TB 先頭アドレス -> その TB に含まれる全命令アドレス」を作る
  - `Trace` 行（実行された TB）から実行された TB 先頭を拾い、
    その TB の全命令アドレスを展開して出力する
  ※ nochain を付けないと連鎖実行が Trace に出ず取りこぼすので必須

使い方:
  qemu-system-arm ... -d in_asm,exec,nochain -D qemu.log
  ./qlog_to_pcs.py qemu.log > pcs.txt
  ./asmcov.py --elf demo.elf --execlog pcs.txt ...
"""

import re
import sys

# IN: ブロック内の命令行 "0x00000008:  2003   movs r0, #3"
ADDR_RE = re.compile(r'^(?:0x)?([0-9a-fA-F]+):\s')
# Trace 行中の hex トークン（4桁以上）
HEX_RE = re.compile(r'[0-9a-fA-F]{4,}')


def parse_blocks(text):
    """IN: ブロックを解析し tb_start -> [instr addrs] を返す。"""
    tb = {}
    cur = None
    in_block = False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith('IN:'):
            in_block = True
            cur = None
            continue
        m = ADDR_RE.match(s)
        if in_block and m:
            a = int(m.group(1), 16)
            if cur is None:
                cur = a
                tb[cur] = []
            tb[cur].append(a)
        else:
            in_block = False
            cur = None
    return tb


def executed_pcs(text, tb):
    """Trace 行から実行 TB を特定し、その命令アドレスを展開して返す。

    SMP（`-smp N`）では複数 vCPU の Trace 行が交錯するが、命令網羅(C0)は
    「実行された PC の集合」なので、コア番号を無視して全 Trace を集めて
    union すれば正しい（交錯は無害）。コア順序に依存するのは C1 のみ。
    """
    starts = set(tb)
    out = []
    for line in text.splitlines():
        if not line.startswith('Trace'):
            continue
        for tok in HEX_RE.findall(line):
            try:
                v = int(tok, 16)
            except ValueError:
                continue
            if v in starts:        # ホストアドレス等は TB 先頭集合に無いので除外される
                out.extend(tb[v])
                break
    return out


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: qlog_to_pcs.py qemu.log > pcs.txt")
    text = open(sys.argv[1]).read()
    tb = parse_blocks(text)
    if not tb:
        sys.exit("IN: ブロックが見つかりません（-d in_asm を付けたか確認）")
    pcs = executed_pcs(text, tb)
    if not pcs:
        sys.exit("Trace 行から実行 TB を特定できません（-d exec,nochain を確認）")
    for a in pcs:
        print(hex(a))


if __name__ == '__main__':
    main()
