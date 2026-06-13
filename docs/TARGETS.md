# TARGETS.md — ターゲット能力マトリクス（AI向け）

> **目的**：各 profile×target の**実行系・能力・非対応/注意点**を1表に front-load し、
> 「ビルド/実行して初めて気づく」コスト（例：FMP linux_gcc は exception check が組めない、
> `FUNC_TIME=false` で timer 対象外）を無くす。**出典は各 `library/<PROF>/target/<tgt>/ttsp_target.sh`**
> （`USE_QEMU`/`FUNC_TIME`/`FUNC_INTERRUPT`/`FUNC_EXCEPTION`/`IRC_ARCH`/`PROCESSOR_NUM`）。最終確認 2026-06-13。

---

## 能力マトリクス

| Profile | Target | 実行系 | PE | FUNC_TIME | IRC | 例外機構 | check 対応（exc/int/timer） | 主要な非対応・注意 |
|---|---|---|---|---|---|---|---|---|
| FMP | **zybo_z7_gcc**（主） | QEMU `xilinx-zynq-a9` `-smp 2` | 2 | true | combination | 実CPU例外 | ✅/✅/✅ | **a9gtimer パッチ必須**（`docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch`）。未適用だと timer check が必ず失敗 |
| FMP | **linux_gcc**（副） | **native**（QEMU不要） | 2 | **false** | **global** | **シグナル**（SIGFPE） | ✅int／**✗exc**／**—timer** | **exc check 未対応**＝`TTSP_EXCNO_C` 未定義でビルド不可（注A）。`FUNC_TIME=false`＝時刻停止不可で timer対象外・adj_tim系は実時間依存。grobal IRC＝割込み番号異常系が一部不一致 |
| FMP | imx8mm_evk_arm64_gcc | `USE_QEMU=false`（実機/別） | 1 | true | combination | 実CPU例外 | ❓ | arm64。本セッション未検証 |
| ASP | **zybo_z7_gcc**（主） | QEMU `xilinx-zynq-a9` | 1 | true | local | 実CPU例外 | ✅/✅/✅ | 単一プロセッサ。a9gtimer パッチ（同上）。`scripts/ci_run.sh` |
| ASP | lpc55s69evk_gcc | 実機（M33） | 1 | true | local | 実CPU例外 | 実機 | **Cortex-M33**。asp3_core 後段 M33 ターゲットの雛形（`AGENTS.md` §6） |
| ASP | nucleo_f401re_gcc | 実機（M4） | 1 | true | local | 実CPU例外 | 実機 | Cortex-M4 |
| HRMP | zybo_z7_gcc | QEMU `xilinx-zynq-a9` `-smp 2` | 2 | true | combination | 実CPU例外 | ❓ | 保護＋マルチコア。a9gtimer。後回し方針 |
| HRP | zybo_z7_gcc | QEMU `xilinx-zynq-a9` | 1 | true | local | 実CPU例外 | ❓ | 保護・単一コア。syssvc が TECS化（`docs/HRP/COVERAGE_STATUS.md`）。API並列ドライバ未対応 |
| HRP | zynqmp_r5_gcc | QEMU（Cortex-R5） | 1 | true | local | 実CPU例外 | ❓ | 2026-06-12 追加（`fef2f9e`）。`ttsp_target.sh` が `parallel_simulation()` でQEMU実行 |

> 実行系の別：**QEMU**＝`USE_QEMU=true`（zybo系/zynqmp）／**native**＝linux_gcc（`./fmp` 直接実行、~30秒）／
> **実機/別**＝`USE_QEMU=false`（imx8mm）または実ボード（lpc55/nucleo）。
> PE：FMP/HRMP は SMP（`-smp PROCESSOR_NUM`）。ASP/HRP は単一プロセッサ（kernel が uniprocessor）。

---

## ターゲット選択・実行コマンド（非対話）

```bash
# 主：FMP zybo（QEMU・フルCI）— 合否は末尾 PASS=/FAIL=
bash scripts/ci_run_fmp.sh                       # check_library + API20 + cfg-error

# 副：FMP linux_gcc（native）— ターゲット切替は環境変数
TTSP_TARGET_NAME=linux_gcc bash scripts/ttsp_parallel_api.sh ../fmp3/ FMP obj_fmp_posix 20
#   check_library 個別: ttb.sh の c メニュー（exc=2 / int=3 / timer=4。linux_gcc は int のみ）

# ASP zybo
bash scripts/ci_run.sh

# カバレッジ（gcov）
bash scripts/coverage_gcov_fmp.sh bb     # bb=BBのみ / all=+WB / smoke=check_libraryのみ
```

> ターゲット切替は `configure.sh` の `TARGET_NAME="${TTSP_TARGET_NAME:-zybo_z7_gcc}"`。
> **対話 `ttb.sh` のメニュー駆動（`printf 'c\n3\n1\n…'`）は自動化に不向き**（ドリフトしやすい）。
> 上記スクリプト経由を推奨。合否の現状基準は **`docs/STATUS.md`**。

---

## 注

- **注A（FMP linux_gcc の exception check）**：共有テスト
  `library/FMP/check_library/exception/out.cfg` が `DEF_EXC(TTSP_EXCNO_C, …)` を含むが、
  linux_gcc の `ttsp_target_test.h` は `TTSP_EXCNO_A`/`B`/PE2系のみで `TTSP_EXCNO_C` 未定義
  → `cfg1_out.c` で `‘TTSP_EXCNO_C’ undeclared` でビルド失敗。**interrupt check は通る**。
  （zybo は `(0x10000|EXCNO_FATAL)` で定義あり）。

---

## ターゲット依存部の構成（追加時）

1 ターゲット＝`library/<PROF>/target/<tgt>/` の4ファイル（`AGENTS.md` §6）：
`ttsp_target_test.c`（7関数）/`ttsp_target_test.h`（スタック・不正アドレス・割込み/例外番号等）/
`ttsp_target.sh`（**本表の出典**：`USE_QEMU`/`FUNC_*`/`IRC_ARCH`/`KERNEL_COBJS_TARGET`）/`ttsp_target.cfg`。
M33 新規は `lpc55s69evk_gcc` を雛形にする。

---

## 更新手順

- `ttsp_target.sh` を変えたら本表の該当行を更新（フィールドは grep で機械抽出可）。
- 新ターゲット追加時は1行追加し、`docs/STATUS.md` にも合否行（初期は ❓）を足す。
