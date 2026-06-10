# ALL_COVERAGE.md — FMP3 kernel/ 分岐カバレッジ（ALL = BBテスト + WBテスト）

> 計測日: 2026-06-10（`all` モード = BBテスト + WBテスト）
> 方式: gcov（`bash scripts/coverage_gcov_fmp.sh all` → `python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/`）
> 対象: FMP3 3.4.0 `kernel/`、APIオートコード 20グループ + check_library + WBテスト5本（計28ディレクトリ, union集計）
> ターゲット: zybo_z7_gcc (Cortex-A9 dual-core, QEMU, -smp 2)
>
> このファイルは **BBテスト + WBテストを統合した `all` モードの最終カバレッジ** を記録する。
> - BBテストのみのカバレッジ（ファイル別） → [`BB_COVERAGE.md`](BB_COVERAGE.md)
> - BB未到達分岐の分析・WBテスト対応・残存未到達 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)（第1部=WBで到達 / 第2部=残存未到達）
>
> **計測条件（コンパイルオプション）:**
> - `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）
> - `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる
> - `-O2`（zybo_z7_gcc デフォルト） — インライン展開により wait.h 等の追跡分岐数が増加（計測アーティファクト）

## 全体サマリ

**分岐カバレッジ（C1）: 1582/1677 = 94.3%**（`all` モード、union集計）
行カバレッジ（C0）: 3515/3620 = 97.1%

- `bb` モード（WBテストなし）: 1576/1677 = 94.0% → [`BB_COVERAGE.md`](BB_COVERAGE.md)
- WBテスト5本（`alarm_W-a` / `cyclic_W-a` / `xsns_dpn_W-a` / `time_event_W-a` / `W-b`）が **+6 分岐**（alarm +1 / cyclic +1 / exception +1 / time_event +3）を追加 → 詳細は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部
- ASP の WBテスト群を移植したもの。FMP は分母 1677 が bb/all で不変（ASP のような -O2 分母増加アーティファクトなし）

## ファイル別 分岐カバレッジ（all モード）

| ファイル | 行 C0 | 分岐 C1 | 未到達 |
|---|---|---|---|
| alarm.c | 108/108 (100.0%) | 49/50 (98.0%) | 1 |
| check.h | 66/66 (100.0%) | 24/24 (100.0%) | — |
| cyclic.c | 111/111 (100.0%) | 47/48 (97.9%) | 1 |
| dataqueue.c | 317/333 (95.2%) | 136/136 (100.0%) | — |
| eventflag.c | 204/208 (98.1%) | 108/108 (100.0%) | — |
| exception.c | 12/12 (100.0%) | 6/8 (75.0%) | 2 |
| interrupt.c | 114/123 (92.7%) | 85/112 (75.9%) | 27 |
| mempfix.c | 182/186 (97.8%) | 74/76 (97.4%) | 2 |
| mutex.c | 250/256 (97.7%) | 127/134 (94.8%) | 7 |
| pridataq.c | 298/312 (95.5%) | 132/132 (100.0%) | — |
| semaphore.c | 153/157 (97.5%) | 66/66 (100.0%) | — |
| spin_lock.c | 91/91 (100.0%) | 37/38 (97.4%) | 1 |
| startup.c | 96/96 (100.0%) | 29/30 (96.7%) | 1 |
| sys_manage.c | 290/298 (97.3%) | 93/96 (96.9%) | 3 |
| task.c | 154/166 (92.8%) | 76/92 (82.6%) | 16 |
| task.h | 17/17 (100.0%) | 8/8 (100.0%) | — |
| task_manage.c | 265/271 (97.8%) | 148/152 (97.4%) | 4 |
| task_refer.c | 86/86 (100.0%) | 32/33 (97.0%) | 1 |
| task_sync.c | 224/228 (98.2%) | 98/98 (100.0%) | — |
| task_term.c | 129/137 (94.2%) | 59/60 (98.3%) | 1 |
| time_event.c | 177/185 (95.7%) | 68/78 (87.2%) | 10 |
| time_event.h | 2/2 (100.0%) | 2/2 (100.0%) | — |
| time_manage.c | 67/68 (98.5%) | 20/22 (90.9%) | 2 |
| wait.c | 66/66 (100.0%) | 10/10 (100.0%) | — |
| wait.h | 36/37 (97.3%) | 48/64 (75.0%) | 16 |
| **TOTAL** | **3515/3620 (97.1%)** | **1582/1677 (94.3%)** | **95** |

> 残存 95 分岐の分類・到達不能理由・追加 WBテスト候補（サブ優先度機能が最有力）は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部を参照。

## ASP との比較

| 指標 | ASP (all) | FMP (all) |
|---|---|---|
| 総分岐数 | 1471 | 1677 |
| 到達分岐 | 1435 | 1582 |
| カバレッジ | 97.6% | 94.3% |
| 未到達分岐 | 36 | 95 |

FMP の残存 95 分岐の主要因はマルチコア遅延ディスパッチパス・サブ優先度機能（`TA_SUBPRI`/`ENA_SPR`）・interrupt.c chg_ipm 複合パス。FMP 固有のマルチコア協調処理・サブ優先度機能が ASP に対し分岐数を +206 増やしている。

## 更新手順

```bash
# WBテストを含む all モードで再計測
bash scripts/coverage_gcov_fmp.sh all

# ファイル別 all 数値を再生成（このファイルの表を更新）
python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/ \
    obj_fmp_gcov/check_library/* obj_fmp_gcov/api_test/auto_code_* obj_fmp_gcov/api_test/wb_*
```
