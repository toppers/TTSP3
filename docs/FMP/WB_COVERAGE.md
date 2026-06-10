# WB_COVERAGE.md — FMP3 kernel/ WBテスト（ホワイトボックステスト）カバレッジ

> 更新: 2026-06-10 (WBテスト5本追加)
> 対象: FMP3 3.4.0 `kernel/`
> 方式: gcov（`bash scripts/coverage_gcov_fmp.sh all`）
> ターゲット: zybo_z7_gcc (Cortex-A9 dual-core, QEMU, -smp 2)

このファイルは **手書き WBテスト（方式2）の寄与のみ** をまとめる。
- 残存未到達分岐の分析 → [`WB_UNREACHABLE.md`](WB_UNREACHABLE.md)

**WBテストの位置づけ**: 自動生成 BBテスト（`bb` モード、1576/1677 = 94.0%）では到達できない分岐を、ソースを直接読んで設計した手書きテストで補う。WBテストを加えた `all` モードは 1582/1677 = 94.3%。ASP の WBテスト群（`alarm_W-a` / `cyclic_W-a` / `time_event_W-a` / `W-b` / `xsns_dpn_W-a`）を FMP に移植したもの。

---

## WBテストによるカバレッジ寄与サマリ

WBテスト（方式2）は以下の 6 分岐を新規に到達させ、`bb` → `all` で **+6 分岐** を追加する。

| ファイル | `bb` 分岐 | `all` 分岐 | 増分 | WBテスト |
|---|---|---|---|---|
| alarm.c | 48/50 | 49/50 | +1 | `alarm_W-a` |
| cyclic.c | 46/48 | 47/48 | +1 | `cyclic_W-a` |
| exception.c | 5/8 | 6/8 | +1 | `xsns_dpn_W-a` |
| time_event.c | 65/78 | 68/78 | +3 | `time_event_W-a`（×2）/ `time_event_W-b`（×1） |
| **合計** | **1576/1677 (94.0%)** | **1582/1677 (94.3%)** | **+6** | — |

> ASP との差異: ASP の `xsns_dpn_W-a` は `kerflg==false` 短絡評価パスを対象としたが、FMP の `xsns_dpn` は `check_tskctx()` ガードを持つため `kerflg_table=false` 分岐は構造的到達不能。FMP 版は代わりに `check_tskctx()==false`（タスクコンテキスト呼び出し、NGKI3152）の else 分岐を対象とする。詳細は §3。

---

## WBテストカタログ（方式2: 手書き）

内部カーネル機能（APIではない）を対象とするため、すべて `wb_test/FMP/` に分類する。

| WBテスト | 対象分岐 | 内容 | 配置 |
|---|---|---|---|
| `alarm_W-a` | alarm.c `if(sense_lock())` 真 | 通知ハンドラが `iloc_cpu()` を保持して戻る → `call_alarm` が `force_unlock_spin()` を実行 | [out.c](../../wb_test/FMP/alarm/alarm_W-a/out.c) |
| `cyclic_W-a` | cyclic.c `if(sense_lock())` 真 | 周期ハンドラが `iloc_cpu()` を保持して戻る → `call_cyclic` が `force_unlock_spin()` を実行 | [out.c](../../wb_test/FMP/cyclic/cyclic_W-a/out.c) |
| `xsns_dpn_W-a` | exception.c L105 `check_tskctx()` 偽 | タスクコンテキストから `xsns_dpn(NULL)` を直接呼出し → else 分岐 `state=true`（NGKI3152） | [out.c](../../wb_test/FMP/exception/xsns_dpn_W-a/out.c) |
| `time_event_W-a` | time_event.c L234 / L244 | `tmevt_down`: 右子ノードなし + 早期 break（heap sift-down） | [out.c](../../wb_test/FMP/time_event/time_event_W-a/out.c) |
| `time_event_W-b` | time_event.c L315 | `tmevtb_delete`: go-up パス（last < parent） | [out.c](../../wb_test/FMP/time_event/time_event_W-b/out.c) |

---

# WBテスト到達分岐の詳細分析

---

## 1. alarm.c / cyclic.c — `call_alarm` / `call_cyclic` の `force_unlock_spin` パス

**ソース** (`fmp3/kernel/alarm.c` L315–321, cyclic.c も同型):
```c
(*(p_almcb->p_alminib->nfyhdr))(p_almcb->p_alminib->exinf);  /* ハンドラ呼出し */
if (sense_lock()) {                                          /* L316 */
    force_unlock_spin(p_my_pcb);                             /* L317 */
}
else {
    lock_cpu();                                              /* L320 */
}
acquire_glock();
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| `if (sense_lock())` 真 → L317 | ハンドラが CPU ロック（`iloc_cpu()`）を保持したまま戻る → `force_unlock_spin()` で保持スピンロックをクリーンアップ | `call_alarm` はハンドラを `release_glock()`/`unlock_cpu()` 後に呼び出し、戻り後に `sense_lock()` で CPU ロック状態を確認する。BB テストのハンドラは CPU ロックを操作せず、戻り時は常にロック解除状態（`sense_lock()==false` → `lock_cpu()` 側）。`iloc_cpu()` を保持して戻るシナリオは自動生成テストでは生成されない。 |

> ASP の対応分岐は `if(!sense_lock()) lock_cpu();` の真分岐スキップ（[ASP WB_COVERAGE.md](../ASP/WB_COVERAGE.md) §1/§2）。FMP では並行制御のため当該コードが `force_unlock_spin()` 呼出しに置き換わっている。`iloc_cpu()` をハンドラ内で呼ぶことは NGKI 上許容された動作であり、誤使用ではない。

**WBテスト** [`alarm_W-a`](../../wb_test/FMP/alarm/alarm_W-a/out.c) / [`cyclic_W-a`](../../wb_test/FMP/cyclic/cyclic_W-a/out.c): 通知ハンドラ内で `iwup_tsk(MAIN_TASK)` の後に `iloc_cpu()` を呼び、CPU ロックを保持したまま戻ることで `force_unlock_spin()` パスを到達させる。gcov 実測で L317 `force_unlock_spin(p_my_pcb)` の実行と `if(sense_lock())` 真分岐 taken を確認済み。

---

## 2. time_event.c — `tmevt_down` / `tmevtb_delete`（`time_event_W-a` / `W-b`）

FMP のヒープ操作（`tmevt_down` L224, `tmevtb_delete` L292）は ASP と算法が同一（マクロが per-PE `p_tmevt_heap` 引数を取る点のみ異なる）。MAIN_TASK は PE1 上で動作し、登録アラームは PE1 の `p_tmevt_heap` に入るため、単一ヒープに対する ASP の配置・推論がそのまま成立する。

| WBテスト | 対象分岐 | 内容 |
|---|---|---|
| `time_event_W-a` | L234（右子なし）+ L244（早期 break） | 5アラームで右子の無いヒープ形状を構築し、index-2 を削除。`tmevt_down` で右子なし・早期break を同時カバー（+2 分岐） |
| `time_event_W-b` | L315（go-up） | 6アラームで、中間ノード削除時に最後尾ノードが削除位置の親より早い配置を構築（+1 分岐） |

詳細なヒープ配置・分岐到達ロジックは各 out.c のヘッダコメント、および [ASP WB_COVERAGE.md](../ASP/WB_COVERAGE.md) §4/§5（同一算法）を参照。

---

## 3. exception.c — `xsns_dpn` L105 `check_tskctx()` 偽分岐（`xsns_dpn_W-a`）

**ソース** (`fmp3/kernel/exception.c` L104–119):
```c
if (check_tskctx()) {                       /* L105: sense_context()=excpt_nest_count>0 */
    p_my_pcb = get_my_pcb();
    state = (kerflg_table[INDEX_PRC(p_my_pcb->prcid)]
                && exc_sense_intmask(p_excinf)
                && p_my_pcb->enadsp
                && p_my_pcb->p_runtsk != NULL) ? false : true;
}
else {
    state = true;                           /* L117: NGKI3152 タスクコンテキスト */
}
```

`check_tskctx()` は `sense_context()`（`excpt_nest_count > 0`、すなわち非タスク=例外コンテキストで真）を返す。

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L105 `check_tskctx()` 偽 → L117 | タスクコンテキスト（`excpt_nest_count==0`）から `xsns_dpn` を呼出し → `state=true`（NGKI3152） | BB テストの `check_library/exception` は CPU 例外ハンドラ内（`excpt_nest_count>0` → `check_tskctx()==true`）から `xsns_dpn` を呼ぶため、タスクコンテキスト呼出しの else 分岐は到達しない。 |

> **FMP 固有の制約**: FMP の `kerflg_table=false` 分岐は ASP と異なり構造的到達不能。`kerflg_table[prcid]` は `start_dispatch`（startup.c L237）の直前 L235 で true 化され、`check_tskctx()==true`（例外コンテキスト）が成立する時点では常に true。よって ASP `xsns_dpn_W-a` の初期化ルーチン手法は FMP では `check_tskctx()==false`（else）に落ち、`kerflg_table` 分岐を評価しない。詳細は [`WB_UNREACHABLE.md`](WB_UNREACHABLE.md) §6。

**WBテスト** [`xsns_dpn_W-a`](../../wb_test/FMP/exception/xsns_dpn_W-a/out.c): MAIN_TASK（タスクコンテキスト）から `xsns_dpn(NULL)` を直接呼び出し、戻り値が `true` であることを確認。gcov 実測で L105 偽分岐 taken・if-body（kerflg 評価）未実行を確認済み。

---

## 計測結果（all モード = BBテスト + WBテスト, 全分岐）

**総合: 1582 / 1677 = 94.3%**（gcov, ttsp_gcov_report.py, union集計, 28ディレクトリ）

| ファイル | 行カバレッジ | 分岐カバレッジ |
|---|---|---|
| alarm.c | 108/108 (100.0%) | 49/50 (98.0%) |
| check.h | 66/66 (100.0%) | 24/24 (100.0%) |
| cyclic.c | 111/111 (100.0%) | 47/48 (97.9%) |
| dataqueue.c | 317/333 (95.2%) | 136/136 (100.0%) |
| eventflag.c | 204/208 (98.1%) | 108/108 (100.0%) |
| exception.c | 12/12 (100.0%) | 6/8 (75.0%) |
| interrupt.c | 114/123 (92.7%) | 85/112 (75.9%) |
| mempfix.c | 182/186 (97.8%) | 74/76 (97.4%) |
| mutex.c | 250/256 (97.7%) | 127/134 (94.8%) |
| pridataq.c | 298/312 (95.5%) | 132/132 (100.0%) |
| semaphore.c | 153/157 (97.5%) | 66/66 (100.0%) |
| spin_lock.c | 91/91 (100.0%) | 37/38 (97.4%) |
| startup.c | 96/96 (100.0%) | 29/30 (96.7%) |
| sys_manage.c | 290/298 (97.3%) | 93/96 (96.9%) |
| task.c | 154/166 (92.8%) | 76/92 (82.6%) |
| task.h | 17/17 (100.0%) | 8/8 (100.0%) |
| task_manage.c | 265/271 (97.8%) | 148/152 (97.4%) |
| task_refer.c | 86/86 (100.0%) | 32/33 (97.0%) |
| task_sync.c | 224/228 (98.2%) | 98/98 (100.0%) |
| task_term.c | 129/137 (94.2%) | 59/60 (98.3%) |
| time_event.c | 177/185 (95.7%) | 68/78 (87.2%) |
| time_event.h | 2/2 (100.0%) | 2/2 (100.0%) |
| time_manage.c | 67/68 (98.5%) | 20/22 (90.9%) |
| wait.c | 66/66 (100.0%) | 10/10 (100.0%) |
| wait.h | 36/37 (97.3%) | 48/64 (75.0%) |
| **TOTAL** | **3515/3620 (97.1%)** | **1582/1677 (94.3%)** |

---

## ASP との比較

| 指標 | ASP (all) | FMP (all) |
|---|---|---|
| 総分岐数 | 1471 | 1677 |
| 到達分岐 | 1435 | 1582 |
| カバレッジ | 97.6% | 94.3% |
| 未到達分岐 | 36 | 95 |

FMP の残存 95 分岐の主要因はマルチコア遅延ディスパッチパス・サブ優先度機能（`TA_SUBPRI`/`ENA_SPR`）・interrupt.c chg_ipm 複合パスであり、詳細・追加 WBテスト候補は [`WB_UNREACHABLE.md`](WB_UNREACHABLE.md) を参照。

---

## 更新手順

```bash
# WBテストを含む all モードで再計測
bash scripts/coverage_gcov_fmp.sh all

# bb モード（WBテストなし）と比較して WB の寄与（差分）を確認
bash scripts/coverage_gcov_fmp.sh bb
```

WBテストは `wb_test/FMP/<group>/<name>_W-*/` に配置し、`coverage_gcov_fmp.sh` が `find` で自動検出する（`api_test/FMP` + `wb_test/FMP` 両対応）。
