# scripts/asmcov — 手書きアセンブリ(.S)カバレッジ用ツール

QEMU 上で実行した TOPPERS カーネルの**手書きアセンブリ**（`arch/arm_gcc/common/{start,core_support,gic_support}.S` など、gcov で計測できない部分）の
**命令網羅 / 行網羅（C0）と分岐網羅（C1）**を取得するためのツール群。

## 由来

`qlog_to_pcs.py` / `asmcov.py` / `branchcov.py` は原理試作 `asm-coverage-demo`（同一
ワークスペースの `../../asm-coverage-demo`）から**無改変で取り込んだ**もの。TTSP3 を
自己完結（CI 実行可能）にするためにベンダリングしている。原理の詳細は同 demo の
`README.md` / `CLAUDE.md` を参照。

| ファイル | 役割 |
|---|---|
| `qlog_to_pcs.py` | QEMU `-d` ログ → 実行命令アドレス列（C0 用） |
| `asmcov.py` | C0: objdump(母数) + 実行PC + addr2line → 命令/行網羅 + lcov(DA) |
| `branchcov.py` | C1: objdump で条件分岐列挙 + TB 遷移エッジで taken/fall 判定 → **C0+C1 兼用 lcov(DA+BRDA)**。ランナーはこちらを使う |

※ demo 側には `covdb.py`/`runner.py`/`annotate.py`/`covdiff.py`（単一 ELF を多入力で
回す蓄積・CI・差分ツール）もあるが、TTSP3 は各テストが別リンク（アドレス非互換）の
ため、テスト横断の統合は **lcov レベルの `lcov -a` マージ**で行う（ランナーが実施）。

## 原理（要約）

```
ELF(-gdwarf-4) ──QEMU -d in_asm,exec,nochain──▶ qemu.log
   │                                               │
   │ objdump -d (母数: 全命令 / 条件分岐)     実行TB列(順序つき)
   │ addr2line (PC→.S:行)                          │
   └──────────────── branchcov.py ─────────────────┘
                          ▼
   C0(実行済み∩全命令=命令/行網羅) + C1(各分岐で taken/fall 両エッジ観測)
                          ▼
              C0+C1 兼用 lcov(.info: DA + BRDA)
```

- **C0**: 「実行された命令アドレスの集合 ∩ 全命令」を行単位に集計（DA）。
- **C1**: QEMU は条件分岐で必ず TB を切るので、実行 TB 列の「前 TB 末尾→次 TB 先頭」
  エッジが各分岐の taken/fall のどちらかに一致する。両方観測で C1 充足（BRDA）。
- `--include` でパス部分一致の絞り込み。ランナーは生成 lcov を `.S` のみに後段フィルタする。

## DWARF の注意（重要）

gcc 13.2 は `-g` 既定で **DWARF5**。`.S` のファイル名は `.debug_line_str` に入るが、TTSP3 の
リンカスクリプトが同セクションを保持せず最終 ELF から脱落 → addr2line がファイル名を解決できない
（行番号は復元可、`.c` は別経路で解決でき気付きにくい）。
**`-gdwarf-4` でビルドすれば回避**（ファイル名が保持される `.debug_str` に入る）。カーネル・
リンカスクリプトを触らず COPTS のみで解決できる。ランナー `scripts/coverage_asmcov_zybo.sh` は
この `-gdwarf-4` を自動付与する。

## 使い方

通常はランナー経由：

```bash
./scripts/coverage_asmcov_zybo.sh smoke   # check_library のみ（既定・数分）
./scripts/coverage_asmcov_zybo.sh bb      # API 20分割も含めて集計
```

出力（既定 `obj_asp_asmcov/asmcov/`）:
- `asmcov_merged.info` — 全テスト統合の lcov（DA=行網羅 + BRDA=分岐網羅）
- `html/index.html` — `genhtml --branch-coverage` による HTML（行＋分岐）
- 各テスト下の `asmcov.info` — テスト単位の C0+C1 lcov（マージ元）

## マルチプロセッサ（SMP・FMP/HRMP）対応

`-smp N` 実行では QEMU が複数 vCPU の `Trace` 行を時間順に**交錯**して出す（`Trace <cpu>: 0x...`）。

- **C0（命令/行網羅）はそのまま正しい**：実行 PC を集合 union するだけでコア順序・コア識別に
  非依存（交錯は無害）。`-smp N` を付けるだけで成立。
- **C1（分岐網羅）は CPU 分離が必須**：エッジ復元は「同一コア上の連続実行」が前提。交錯した
  まま隣接を取るとコアをまたいだ偽エッジ混入・真エッジ取りこぼしが起きる。`branchcov.py` は
  `ordered_tb_starts_by_cpu` で `Trace <cpu>:` のコア番号ごとに TB 列をバケツ分けし、各バケツ内
  だけで隣接エッジを取って union する。単一コア（`Trace 0:` のみ）は 1 バケツ＝従来と完全に同一（後方互換）。

ランナーは FMP/HRMP を既定 `-smp 2` で実行する（`SMP_NCPU` で上書き可）。

## 既知の制約（demo から継承）

- C1 のテスト横断マージは BRDA の `(file,line,block)` 一致が前提。同一カーネルソース＋
  同一フラグ（`-gdwarf-4`）なら分岐の出現順 `block` は全テストで一致するため成立する。
- Thumb の **IT ブロック**（述語実行）は分岐命令を伴わず C1 集計外（branchcov が警告）。
  zybo_z7 のカーネル `arch/arm_gcc/common/*.S` は ARM モードなので影響なし（IT 警告は
  Thumb でビルドされたライブラリ等に由来し、`.S` 集計には効かない）。
- `tbb/tbh`・switch の多分岐は各ターゲット観測の拡張が必要。

詳細は `docs/RUNBOOK.md` を参照。
