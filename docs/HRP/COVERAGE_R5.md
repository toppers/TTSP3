# HRP3 カバレッジ計測ステータス（zcu102_r5_gcc／Cortex-R5・MPU）— line 89.5% / branch 81.2%

> **合否（PASS/FAIL）の現状は `docs/STATUS.md` が正本**（本ファイルはカバレッジ%が主）。
> 本ファイルは **zybo_z7_gcc（A9/MMU）版 [COVERAGE_STATUS.md](COVERAGE_STATUS.md) の R5（PMSAv7 MPU）版**。
> 2026-06-14 実測：HRP `zcu102_r5_gcc` + upstream QEMU（`xlnx-zcu102`/aarch64）で
> **line 89.5% (2984/3334) / branch 81.2% (2056/2533)**。zybo HRP（89.4%/81.7%）と**同等**。

> 計測範囲：check_library（exception/interrupt/timer）3/3 ＋ API オートコード 20分割中 **18/20**
> （除外2群は下記「計測対象外」）。filter `/hrp3/kernel/`、21 ディレクトリ集計。

---

## 計測条件

| 項目 | 値 |
|---|---|
| ターゲット | `zcu102_r5_gcc`（HRP3・Cortex-R5F／PMSAv7 MPU・シングルコア） |
| カーネル | hrp3（SVN・ttsp3 git 外）。R5 ターゲット依存部に gcov 対応を追加（下記） |
| 計装 | `ENABLE_GCOV=true`：`--coverage -fprofile-info-section` ＋ `-DTOPPERS_ENABLE_GCOV` ＋ `-specs=rdimon.specs` |
| 最適化 | `-O2`（インライン抑制）＋ `-DNDEBUG`（assert をカバレッジ対象から除外） |
| 実行 | upstream `qemu-system-aarch64`（11以降）`-M xlnx-zcu102 -semihosting`。`target_exit` のセミホスティング終了で `.gcda` をホストへ直接書き出し |
| ランナー | `scripts/coverage_gcov_hrp_r5.sh [smoke\|bb\|all]` |
| 再現 | `bash scripts/coverage_gcov_hrp_r5.sh bb`（要 upstream QEMU 11 aarch64。システムの qemu 8.2.2 では不可） |

### R5 ターゲット依存部の gcov 対応（zybo 版との差分）

zybo（`COVERAGE_STATUS.md`）と同方式だが、**R5/MPU 固有の2点**を追加で要した：

| 箇所 | 内容 |
|---|---|
| `arch/arm_gcc/zynqmp_r5/chip_ldscript.trb` | **R5固有①**：R5 は MPU 用の独自 chip_ldscript.trb を使い `arch/gcc/ldscript.trb` を経由しないため、`GenerateProvide` フックが発火せず `__gcov_info_start/end`・`end/_end` 未定義でリンク失敗。MEMORY ブロック直後に `if defined? GenerateProvide(); GenerateProvide($ldscript); end` を追加 |
| `target/zcu102_r5_gcc/target_mem.cfg` | **R5固有②**：gcov 計装で大きい API テストが 16MB DDR を溢れる（`memory region 'DDR' overflow`）。`#ifdef TOPPERS_ENABLE_GCOV` のときのみ DDR を 16MB→64MB（0x7c000000–0x80000000、QEMU `-m 2G` の RAM 内）に拡大。非gcov 配置は不変 |
| `target/zcu102_r5_gcc/Makefile.target` | `ENABLE_GCOV` ブロック（計装フラグ・rdimon.specs） |
| `target/zcu102_r5_gcc/target_kernel_impl.c` | ベアメタル gcov ランタイム（`__gcov_info_to_gcda`＋セミホスティング書出し、静的 `gcov_heap_pool` `_sbrk`、`software_init/term_hook`、`target_exit` の QEMU 終了） |
| `target/zcu102_r5_gcc/target_ldscript.trb`（新規） | `GenerateProvide`（`__gcov_info_start/end`→`__start/__end_rodata_kernel_A1001` エイリアス）／`GcovLdscriptAppendGroup`。`target_{kernel,opt,mem}.trb` から IncludeTrb |
| `target/zcu102_r5_gcc/target_mem.cfg` | `KERNEL_DOMAIN { ATT_SEC(".gcov_info", { TA_NOWRITE\|TA_KEEP, "DDR" }); }` |

---

## ファイル別カバレッジ（2026-06-14 実測）

filter `/hrp3/kernel/`、check_library 3 ＋ auto_code 18 = 21 ディレクトリ集計。

| file | line | branch |
|---|---|---|
| alarm.c | 75/75 100.0% | 47/50 94.0% |
| cyclic.c | 80/80 100.0% | 48/54 88.9% |
| dataqueue.c | 266/266 100.0% | 210/216 97.2% |
| domain.c | 36/186 19.4% | 8/96 8.3% |
| eventflag.c | 176/176 100.0% | 167/174 96.0% |
| exception.c | 8/8 100.0% | 5/8 62.5% |
| interrupt.c | 118/118 100.0% | 85/92 92.4% |
| mem_manage.c | 33/65 50.8% | 21/62 33.9% |
| memory.c | 26/47 55.3% | 8/20 40.0% |
| mempfix.c | 160/160 100.0% | 129/138 93.5% |
| messagebuf.c | 273/288 94.8% | 117/222 52.7% |
| mutex.c | 219/219 100.0% | 165/168 98.2% |
| pridataq.c | 258/259 99.6% | 212/226 93.8% |
| semaphore.c | 128/128 100.0% | 103/108 95.4% |
| startup.c | 32/32 100.0% | 6/6 100.0% |
| svc_table.c | 0/2 0.0% | — |
| sys_manage.c | 175/267 65.5% | 109/206 52.9% |
| task.c | 126/127 99.2% | 70/72 97.2% |
| task.h | 11/11 100.0% | 8/8 100.0% |
| task_manage.c | 127/127 100.0% | 123/130 94.6% |
| task_refer.c | 81/89 91.0% | 43/47 91.5% |
| task_sync.c | 176/176 100.0% | 136/140 97.1% |
| task_term.c | 97/97 100.0% | 74/80 92.5% |
| time_event.c | 138/165 83.6% | 56/80 70.0% |
| time_event.h | 2/2 100.0% | 2/2 100.0% |
| time_manage.c | 59/60 98.3% | 35/40 87.5% |
| wait.c | 68/68 100.0% | 12/12 100.0% |
| wait.h | 36/36 100.0% | 57/76 75.0% |
| **TOTAL** | **2984/3334 89.5%** | **2056/2533 81.2%** |

主要な標準API（task/semaphore/eventflag/dataqueue/pridataq/mutex/mempfix/alarm/cyclic/
wait/interrupt）は line 90〜100%。残ギャップは保護ドメイン機能（domain.c/mem_manage.c）＝
zybo HRP と同傾向（保護ドメイン固有テスト未整備）。

### zybo（A9/MMU）との比較

| | line | branch | API群 |
|---|---|---|---|
| HRP zybo_z7_gcc | 89.4% (2982/3334) | 81.7% (2070/2533) | 20分割集計 |
| HRP zcu102_r5_gcc | **89.5% (2984/3334)** | **81.2% (2056/2533)** | 18/20（下記2群除外） |

ほぼ一致。branch がわずかに低いのは除外2群（group17/19）分。

---

## 計測対象外の2群（API オートコード 18/20）

| 群 | 理由 | 種別 |
|---|---|---|
| **auto_code_17** | `out.cfg: E_NOSPT: ATT_PMA is not supported on this target`。R5（MPU）の能力差で **非gcov でも build 不可**（`target/zcu102_r5_gcc/target_user.txt` に「ATT_PMA非サポート」明記） | R5 能力差（gcov 無関係） |
| **auto_code_19** | `target_mem.cfg: E_SYS: memory objects overlap`。gcov 計装で各保護ドメインのコード/データが約2倍に膨張し保護ドメイン境界が重なる。**zybo HRP/HRMP でも同じ gcov 計装時に group14/17/19 が overlap で脱落する既知事象**＝R5/MPU 固有ではなく gcov×保護ドメインの共通制約（R5 では PMSAv7 の2のべき乗アラインで更に増幅）。DDR 拡大では解消せず | gcov×保護ドメイン共通 |

> 注：非gcov の API 実行は **19/20**（ATT_PMA の group のみ脱落）＝`docs/STATUS.md` §1 注7。
> gcov 計装時は更に group19 が overlap で脱落して 18/20。

---

## 関連

- 合否・ベースラインの正本：[../STATUS.md](../STATUS.md)（§1 注7＝API 19/20、§2 注8＝本カバレッジ）
- zybo（A9）版カバレッジ：[COVERAGE_STATUS.md](COVERAGE_STATUS.md)
- ターゲット能力・実行コマンド：[../TARGETS.md](../TARGETS.md)
- 改変台帳：[../../DIVERGENCE_MAP.md](../../DIVERGENCE_MAP.md)
