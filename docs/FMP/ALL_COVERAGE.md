# ALL_COVERAGE.md — FMP3 kernel/ 分岐カバレッジ（ALL = BBテスト + WBテスト）

> 計測日: 2026-06-10（`all` モード = BBテスト + WBテスト）
> 方式: gcov（`bash scripts/coverage_gcov_fmp.sh all` → `python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/`）
> 対象: FMP3 3.4.0 `kernel/`、APIオートコード 20グループ + check_library + WBテスト9本（計32ディレクトリ, union集計）
> ターゲット: zybo_z7_gcc (Cortex-A9 dual-core, QEMU, -smp 2)
>
> このファイルは **BBテスト + WBテストを統合した `all` モードの最終カバレッジ** を記録する。
> - BBテストのみのカバレッジ（ファイル別） → [`BB_COVERAGE.md`](BB_COVERAGE.md)
> - BB未到達分岐の分析・WBテスト対応・残存未到達 → [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md)（第1部=WBで到達 / 第2部=残存未到達）
>
> **計測条件（コンパイルオプション）:**
> - `ENABLE_GCOV=true` — gcov 計装（`-fprofile-arcs -ftest-coverage`）
> - `-DNDEBUG`（`COPTS` 経由） — `assert()` を無効化し分岐ノードを消滅させる（assert 失敗パスは仕様適合性の分岐ではないため計測対象外）
> - **`-O2` + インライン抑制**（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`） — `static inline` 展開による gcov 分岐水増し（wait.h 等）を除去するため `-O2` 維持で inline のみ抑制。論理分岐がそのまま反映され bb/all 分母も一致。`-O0` は実行時クラッシュ・タイミング変化のため不採用（詳細理由は [`BB_COVERAGE.md`](BB_COVERAGE.md) 計測条件）。

## 全体サマリ

**分岐カバレッジ（C1）: 1549/1597 = 97.0%**（`all` モード、union集計、-O2+インライン抑制・2026-06-10 再計測）
行カバレッジ（C0）: 3538/3621 = 97.7%

> **2026-06-10 再計測で現状化**（32 dirs union）。旧値 1520/1597=95.2% から **+29 分岐**。内訳：
> - サブ優先度BB/WB（chg_spr_F-e-1/3/4/6・chg_spr_W-a・subprio_head_W-a）：task.c 66→74・mutex.c 125→129・
>   task_manage.c 148→149（計 +13）。
> - **interrupt.c 割込み番号バリデーション(VALID_INTNO)異常系BB（`{ras,dis,ena,clr,prb}_int_F-e-1`・combination）：
>   interrupt.c 分岐 87→99（+12）**。`BB_UNREACHABLE.md §2` 参照。
> - **単一TM-processor変種WB（`tepp1_W-a`・`-DTOPPERS_TEPP_PRC=0x1`）：time_event.c §5-c 66→69（+3）・
>   startup.c §9-b 29→30（+1）**。`BB_UNREACHABLE.md §5-c` / `COVERAGE_RAISE_PLAN.md` Method B 参照。
> - 残未到達 48（うち約 17 が interrupt.c・構造的dead/check_intno_cfg複合/chg_ipm timing-affinity）。

- `bb` モード（WBテストなし）: 1533/1597 = 96.0%（2026-06-10 再計測。WB寄与は all−bb = **+16 分岐**）→ [`BB_COVERAGE.md`](BB_COVERAGE.md)
- WBテスト9本（`alarm_W-a` / `cyclic_W-a` / `xsns_dpn_W-a` / `xsns_dpn_W-b` / `time_event_W-a` / `W-b` / `chg_spr_W-a` / `subprio_head_W-a` / **`tepp1_W-a`**）が分岐を追加（`tepp1_W-a` は単一TM-processor構成で §5-c/§9-b）→ 詳細は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第1部・§4・§5-c
- ASP の WBテスト群を移植・拡張したもの。**bb/all とも分母 1597 で一致**（インライン抑制でビルド差が解消）
- `xsns_dpn_W-b`（custom idle 方式）で exception.c の `p_my_pcb->p_runtsk==NULL` 分岐を到達（8/10→9/10、all 1519→1520）。MAIN_TASK を PE1 のみに割り当て PE2 をアイドルにして CPU 例外を発生させる。検証: 8 dir（check_library/exception + xsns_dpn BB split6 + `W-a`）で 8/10、`W-b` 追加で 9/10。
- 旧 -O2（インライン展開あり）計測: all 1582/1677（wait.h 等の水増しを含む。bb 1576 と分母不一致）。インライン抑制で分母が 1677→1597 に正規化し C1 は 95.2% に。

## ファイル別 分岐カバレッジ（all モード）

| ファイル | 行 C0 | 分岐 C1 | 未到達 |
|---|---|---|---|
| alarm.c | 108/108 (100.0%) | 49/50 (98.0%) | 1 |
| check.h | 66/66 (100.0%) | 24/24 (100.0%) | — |
| cyclic.c | 111/111 (100.0%) | 47/48 (97.9%) | 1 |
| dataqueue.c | 317/333 (95.2%) | 132/132 (100.0%) | — |
| eventflag.c | 204/208 (98.1%) | 106/106 (100.0%) | — |
| exception.c | 12/12 (100.0%) | 9/10 (90.0%) | 1 |
| interrupt.c | 117/123 (95.1%) | 99/116 (85.3%) | 17 |
| mempfix.c | 182/186 (97.8%) | 72/74 (97.3%) | 2 |
| mutex.c | 252/256 (98.4%) | 129/132 (97.7%) | 3 |
| pridataq.c | 299/312 (95.8%) | 128/128 (100.0%) | — |
| semaphore.c | 153/157 (97.5%) | 64/64 (100.0%) | — |
| spin_lock.c | 91/91 (100.0%) | 37/38 (97.4%) | 1 |
| startup.c | 96/96 (100.0%) | 30/30 (100.0%) | — |
| sys_manage.c | 290/298 (97.3%) | 93/96 (96.9%) | 3 |
| task.c | 166/167 (99.4%) | 74/78 (94.9%) | 4 |
| task.h | 17/17 (100.0%) | 8/8 (100.0%) | — |
| task_manage.c | 267/271 (98.5%) | 149/152 (98.0%) | 3 |
| task_refer.c | 86/86 (100.0%) | 32/33 (97.0%) | 1 |
| task_sync.c | 224/228 (98.2%) | 98/98 (100.0%) | — |
| task_term.c | 129/137 (94.2%) | 59/60 (98.3%) | 1 |
| time_event.c | 180/185 (97.3%) | 69/76 (90.8%) | 7 |
| time_event.h | 2/2 (100.0%) | —（分岐なし） | — |
| time_manage.c | 67/68 (98.5%) | 20/22 (90.9%) | 2 |
| wait.c | 66/66 (100.0%) | 8/8 (100.0%) | — |
| wait.h | 36/37 (97.3%) | 13/14 (92.9%) | 1 |
| **TOTAL** | **3538/3621 (97.7%)** | **1549/1597 (97.0%)** | **48** |

> インライン抑制により分母が 1677→1597 に正規化（wait.h 64→14、task.c 92→78、dataqueue 136→132 等）。残存 **48** 分岐の分類・到達不能理由は [`BB_UNREACHABLE.md`](BB_UNREACHABLE.md) 第2部 / [`TIMING_TEST.md`](TIMING_TEST.md) を参照（2026-06-10 再計測：サブ優先度BB/WB ＋ interrupt負テストBB ＋ 単一TM-processor変種 tepp1_W-a を反映）。

## ASP との比較

> いずれも -O2+インライン抑制計測。

| 指標 | ASP (all) | FMP (all) |
|---|---|---|
| 総分岐数 | 1379 | 1597 |
| 到達分岐 | 1370 | 1549 |
| カバレッジ | 99.3% | 97.0% |
| 未到達分岐 | 11 | 48 |

FMP の残存 **48** 分岐の主要因はマルチコア遅延ディスパッチパス（timing 系・[`TIMING_TEST.md`](TIMING_TEST.md)）・interrupt.c の `VALID_INTNO` 構造的dead＋`check_intno_cfg` 複合＋chg_ipm（L383 timing/L392 affinity）。サブ優先度機能（`TA_SUBPRI`/`ENA_SPR`）・割込み番号バリデーション異常系・time_event.c §5-c 非TM-processor 転送は 2026-06-10 のBB/WB追加で到達済み（後者は単一TM-processor変種 `tepp1_W-a`・Method B）。FMP 固有のマルチコア協調処理・サブ優先度機能が ASP に対し分岐数を +218 増やしている。マルチコアレース分岐は案3（2コアストレスループ）で到達可能なことが実証済み。

## 更新手順

```bash
# WBテストを含む all モードで再計測
bash scripts/coverage_gcov_fmp.sh all

# ファイル別 all 数値を再生成（このファイルの表を更新）
python3 scripts/ttsp_gcov_report.py --filter /fmp3/kernel/ \
    obj_fmp_gcov/check_library/* obj_fmp_gcov/api_test/auto_code_* obj_fmp_gcov/api_test/wb_*
```
