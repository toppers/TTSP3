# HRP カバレッジ計測記録（BBテスト）

> HRP用のWBテスト（方式2）は未作成のため，`all` モード＝`bb` モードと等価。
> 本ファイルはBBテスト（API auto-code 20分割 + check_library）のみでの計測結果を記録する。
> → 未到達分岐の分析は [BB_UNREACHABLE.md](BB_UNREACHABLE.md) を参照。

---

## 計測条件

| 項目 | 値 |
|---|---|
| カーネル | HRP3 (`../hrp3/`) |
| ターゲット | zybo_z7_gcc (Cortex-A9 single-core, QEMU `-smp 1`) |
| スクリプト | `scripts/coverage_gcov_hrp.sh bb` |
| モード | bb = check_library + API auto-code 20分割（WBテスト無し） |
| ビルドフラグ | `ENABLE_GCOV=true`, `-DNDEBUG` (COPTS), `-O2` (Makefile既定) |
| ビルド方式 | 方式A（HRP は TECSコンポーネント化 syssvc のため APPL_COBJS/KERNEL_COBJS を非上書き） |
| フィルタ | `/hrp3/kernel/` のみ集計 |
| 計測日 | 2026-06-09 |
| 集計対象 | check_library 3 + API auto-code 19（計22バイナリの gcda） |
| 移行適用 | HRP3 3.3→3.4 アクセス許可仕様移行済（TTG CPUState.rb sysstat2 追加 + ter_tsk 44ファイル access2↔access3 入替） |

### コンパイルオプション補足

| フラグ | 効果 |
|---|---|
| `ENABLE_GCOV=true` | `--coverage -fprofile-info-section` を追加，gcov 計装有効（ベアメタル `__gcov_info_to_gcda` 方式） |
| `-DNDEBUG` | `assert()` マクロを無効化。`t_stddef.h` の `#ifndef NDEBUG` で制御される assert 分岐がコードから除去され，計測対象から外れる |
| `-O2` | コンパイラ最適化有効。`static inline` 関数が呼び出し元に展開され，同一ソース行が複数箇所で計測される（`wait.h` の分岐などはこのアーティファクト） |

---

## 計測結果（BBテスト＝全テスト）

**総合: line 2982 / 3334 = 89.4% ／ branch 2070 / 2533 = 81.7%**
（HRP3 3.3→3.4 アクセス許可仕様移行後。ベースライン比: line +9.8pp / branch +11.9pp）

| ファイル | 行カバレッジ | 分岐カバレッジ |
|---|---|---|
| alarm.c | 75/75 (100.0%) | 48/50 (96.0%) |
| cyclic.c | 80/80 (100.0%) | 49/54 (90.7%) |
| dataqueue.c | 266/266 (100.0%) | 212/216 (98.1%) |
| domain.c | 36/186 (19.4%) | 8/96 (8.3%) |
| eventflag.c | 176/176 (100.0%) | 169/174 (97.1%) |
| exception.c | 8/8 (100.0%) | 5/8 (62.5%) |
| interrupt.c | 116/118 (98.3%) | 84/92 (91.3%) |
| mem_manage.c | 33/65 (50.8%) | 21/62 (33.9%) |
| memory.c | 26/47 (55.3%) | 7/20 (35.0%) |
| mempfix.c | 160/160 (100.0%) | 131/138 (94.9%) |
| messagebuf.c | 273/288 (94.8%) | 117/222 (52.7%) |
| mutex.c | 219/219 (100.0%) | 166/168 (98.8%) |
| pridataq.c | 258/259 (99.6%) | 214/226 (94.7%) |
| semaphore.c | 128/128 (100.0%) | 104/108 (96.3%) |
| startup.c | 32/32 (100.0%) | 6/6 (100.0%) |
| svc_table.c | 0/2 (0.0%) | - |
| sys_manage.c | 175/267 (65.5%) | 110/206 (53.4%) |
| task.c | 126/127 (99.2%) | 70/72 (97.2%) |
| task.h | 11/11 (100.0%) | 8/8 (100.0%) |
| task_manage.c | 127/127 (100.0%) | 124/130 (95.4%) |
| task_refer.c | 81/89 (91.0%) | 43/47 (91.5%) |
| task_sync.c | 176/176 (100.0%) | 137/140 (97.9%) |
| task_term.c | 97/97 (100.0%) | 75/80 (93.8%) |
| time_event.c | 138/165 (83.6%) | 56/80 (70.0%) |
| time_event.h | 2/2 (100.0%) | 2/2 (100.0%) |
| time_manage.c | 59/60 (98.3%) | 35/40 (87.5%) |
| wait.c | 68/68 (100.0%) | 12/12 (100.0%) |
| wait.h | 36/36 (100.0%) | 57/76 (75.0%) |
| **TOTAL** | **2982/3334 (89.4%)** | **2070/2533 (81.7%)** |

### ベースライン比較（移行前）

**ベースライン（移行前 2026-06-09）: line 2653/3334 = 79.6% ／ branch 1769/2533 = 69.8%**

主な向上：
- `task_term.c`: 94.8%→100.0% line / 68.8%→93.8% branch（ter_tsk E_OACV早期終了の解消）
- `task_sync.c`: 98.9%→100.0% line / 89.3%→97.9% branch（sus_tsk 等の解消）
- `messagebuf.c`: 4.9%→94.8% line / 0.9%→52.7% branch（E_OACV による全滅から大幅回復）
- `time_manage.c`: 23.3%→98.3% line / 10.0%→87.5% branch
- `sys_manage.c`: 61.8%→65.5% line / 46.1%→53.4% branch

---

## 所見

- 標準APIの主要オブジェクト（task / task_manage / task_sync / semaphore / eventflag /
  dataqueue / pridataq / mutex / mempfix / alarm / cyclic / wait / interrupt）は
  **行 90〜100%** と高い。ASP/FMP と同等の水準。
- **HRP3 3.3→3.4 アクセス許可仕様移行後、E_OACV 早期終了が完全に解消**し、
  19/19 グループが `All check points passed.` で完走。
- 残低カバレッジは **HRP固有/保護カーネル機能**に集中（次節）。これは BBテスト（ASP/FMP/HRP
  共通の API auto-code）が保護ドメイン機能を十分に駆動しないことによる test-design 起因で，
  HRMP3 計測（`docs/HRMP/`）と同じ傾向。未到達の詳細は [BB_UNREACHABLE.md](BB_UNREACHABLE.md)。

### 計測上の既知事項

- **API auto-code は 19/20 グループを集計**。`auto_code_17` は gcov 計装時のみ，計装で増えた
  カウンタ領域＋`.gcov_info` メモリオブジェクトの追加により当該グループの密なメモリ配置で
  `target_mem.cfg:36: E_SYS: memory objects overlap`（保護パス4）となりビルド不成立。
  非計装では同グループは正常ビルド可（gcov 固有）。残19グループ＋check_library で集計した。
  全テストケースは複数グループに分散するため，欠落グループによる主要APIへの影響は軽微。

---

## 参考
- ASP3：`docs/ASP/`（98.3%）／FMP3：`docs/FMP/`（93.9%）／HRMP3：`docs/HRMP/`（75.4%）
- gcov 計装の有効化手順（保護カーネル）：`docs/HRP3_GCOV.md`
- 計測に至るまでの bring-up・真因記録：`docs/HRP/COVERAGE_STATUS.md`
- 計画・後段方針：`docs/WHITEBOX_PLAN.md`
