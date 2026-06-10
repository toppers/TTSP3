# BB_UNREACHABLE.md — FMP3 kernel/ BBテスト未到達分岐の分析とWBテスト対応

> 更新: 2026-06-10
> 対象: FMP3 3.4.0 `kernel/`（zybo_z7_gcc, QEMU -smp 2）
> 方式: gcov（`bash scripts/coverage_gcov_fmp.sh all` / `bb`）

このファイルは **BBテスト（自動生成）で到達できない分岐** の顛末を記録する。
- **第1部**: BBの穴を手書き WBテスト（方式2）で到達させたもの — テスト内容と到達手法（`bb`→`all` で +7 分岐）
- **第2部**: WBテストを加えてもなお到達しない分岐 — 到達不能理由・分類と追加 WBテスト候補（残存 77 分岐, `all` 1520/1597 = 95.2%、-O2+インライン抑制）

> **計測方式（2026-06-10 変更）**: `-O2` + インライン抑制（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`）。`static inline` 展開による gcov 分岐水増し（wait.h 等）を除去し、論理分岐をそのまま計測、bb/all 分母も一致（1597）。理由詳細は [`BB_COVERAGE.md`](BB_COVERAGE.md) 計測条件。旧 -O2 計測（分母 1677, wait.h 64分岐）からの移行。

関連:
- BBテストのみのカバレッジ（ファイル別） → [`BB_COVERAGE.md`](BB_COVERAGE.md)
- BBテスト + WBテスト統合の最終カバレッジ・ASP比較 → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

---

# 第1部 — BBの穴を WBテストで到達（方式2: 手書き）

> 自動生成 BBテスト（`bb` モード、1513/1597 = 94.7%）では到達できない分岐を、ソースを直接読んで設計した手書き WBテストで補う。WBテストを加えた `all` モードは 1520/1597 = 95.2%。ASP の WBテスト群（`alarm_W-a` / `cyclic_W-a` / `time_event_W-a` / `W-b` / `xsns_dpn_W-a` / `W-b`）を FMP に移植・拡張したもの。

## WBテストによるカバレッジ寄与サマリ

WBテスト（方式2）は以下の 7 分岐を新規に到達させ、`bb` → `all` で **+7 分岐** を追加する（未到達は 84 → 77）。

| ファイル | `bb` 分岐 | `all` 分岐 | 増分 | WBテスト |
|---|---|---|---|---|
| alarm.c | 48/50 | 49/50 | +1 | `alarm_W-a` |
| cyclic.c | 46/48 | 47/48 | +1 | `cyclic_W-a` |
| exception.c | 7/10 | 9/10 | +2 | `xsns_dpn_W-a`（check_tskctx 偽）/ `xsns_dpn_W-b`（p_runtsk=NULL）|
| time_event.c | 63/76 | 66/76 | +3 | `time_event_W-a`（×2）/ `time_event_W-b`（×1） |
| **合計** | **1513/1597 (94.7%)** | **1520/1597 (95.2%)** | **+7** | — |

> ※ -O2+インライン抑制計測。分岐番号は旧 -O2 と異なる（exception.c 8→10 分岐等）。各節の行番号・branch 番号は論理分岐の意味を示す。

> ASP との差異: ASP の `xsns_dpn_W-a` は `kerflg==false` 短絡評価パスを対象としたが、FMP の `xsns_dpn` は `check_tskctx()` ガードを持つため `kerflg_table=false` 分岐は構造的到達不能。FMP 版は代わりに `check_tskctx()==false`（タスクコンテキスト呼び出し、NGKI3152）の else 分岐を対象とする。詳細は §1-3。

## WBテストカタログ（方式2: 手書き）

内部カーネル機能（APIではない）を対象とするため、すべて `wb_test/FMP/` に分類する。

| WBテスト | 対象分岐 | 内容 | 配置 |
|---|---|---|---|
| `alarm_W-a` | alarm.c `if(sense_lock())` 真 | 通知ハンドラが `iloc_cpu()` を保持して戻る → `call_alarm` が `force_unlock_spin()` を実行 | [out.c](../../wb_test/FMP/alarm/alarm_W-a/out.c) |
| `cyclic_W-a` | cyclic.c `if(sense_lock())` 真 | 周期ハンドラが `iloc_cpu()` を保持して戻る → `call_cyclic` が `force_unlock_spin()` を実行 | [out.c](../../wb_test/FMP/cyclic/cyclic_W-a/out.c) |
| `xsns_dpn_W-a` | exception.c L105 `check_tskctx()` 偽 | タスクコンテキストから `xsns_dpn(NULL)` を直接呼出し → else 分岐 `state=true`（NGKI3152） | [out.c](../../wb_test/FMP/exception/xsns_dpn_W-a/out.c) |
| `xsns_dpn_W-b` | exception.c L114 `p_my_pcb->p_runtsk != NULL` 偽 | MAIN_TASK を PE1 のみに割当て、PE2 をアイドル（`p_runtsk==NULL`）にして custom idle フックから CPU 例外を発生 → CPU 例外ハンドラ（PE2）から `xsns_dpn(p_excinf)` → `p_runtsk==NULL` で短絡評価 → `state=true`（custom idle 方式・カーネル無改変）| [out.c](../../wb_test/FMP/exception/xsns_dpn_W-b/out.c) |
| `time_event_W-a` | time_event.c L234 / L244 | `tmevt_down`: 右子ノードなし + 早期 break（heap sift-down） | [out.c](../../wb_test/FMP/time_event/time_event_W-a/out.c) |
| `time_event_W-b` | time_event.c L315 | `tmevtb_delete`: go-up パス（last < parent） | [out.c](../../wb_test/FMP/time_event/time_event_W-b/out.c) |

---

## 1-1. alarm.c / cyclic.c — `call_alarm` / `call_cyclic` の `force_unlock_spin` パス

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

> ASP の対応分岐は `if(!sense_lock()) lock_cpu();` の真分岐スキップ（[ASP BB_UNREACHABLE.md](../ASP/BB_UNREACHABLE.md) 第1部 §1-1/§1-2）。FMP では並行制御のため当該コードが `force_unlock_spin()` 呼出しに置き換わっている。`iloc_cpu()` をハンドラ内で呼ぶことは NGKI 上許容された動作であり、誤使用ではない。

**WBテスト** [`alarm_W-a`](../../wb_test/FMP/alarm/alarm_W-a/out.c) / [`cyclic_W-a`](../../wb_test/FMP/cyclic/cyclic_W-a/out.c): 通知ハンドラ内で `iwup_tsk(MAIN_TASK)` の後に `iloc_cpu()` を呼び、CPU ロックを保持したまま戻ることで `force_unlock_spin()` パスを到達させる。gcov 実測で L317 `force_unlock_spin(p_my_pcb)` の実行と `if(sense_lock())` 真分岐 taken を確認済み。

---

## 1-2. time_event.c — `tmevt_down` / `tmevtb_delete`（`time_event_W-a` / `W-b`）

FMP のヒープ操作（`tmevt_down` L224, `tmevtb_delete` L292）は ASP と算法が同一（マクロが per-PE `p_tmevt_heap` 引数を取る点のみ異なる）。MAIN_TASK は PE1 上で動作し、登録アラームは PE1 の `p_tmevt_heap` に入るため、単一ヒープに対する ASP の配置・推論がそのまま成立する。

| WBテスト | 対象分岐 | 内容 |
|---|---|---|
| `time_event_W-a` | L234（右子なし）+ L244（早期 break） | 5アラームで右子の無いヒープ形状を構築し、index-2 を削除。`tmevt_down` で右子なし・早期break を同時カバー（+2 分岐） |
| `time_event_W-b` | L315（go-up） | 6アラームで、中間ノード削除時に最後尾ノードが削除位置の親より早い配置を構築（+1 分岐） |

詳細なヒープ配置・分岐到達ロジックは各 out.c のヘッダコメント、および [ASP BB_UNREACHABLE.md](../ASP/BB_UNREACHABLE.md) 第1部 §1-4/§1-6（同一算法）を参照。

---

## 1-3. exception.c — `xsns_dpn` L105 `check_tskctx()` 偽分岐 / L114 `p_runtsk==NULL` 分岐（`xsns_dpn_W-a` / `xsns_dpn_W-b`）

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

> **FMP 固有の制約**: FMP の `kerflg_table=false` 分岐は ASP と異なり構造的到達不能。`kerflg_table[prcid]` は `start_dispatch`（startup.c L237）の直前 L235 で true 化され、`check_tskctx()==true`（例外コンテキスト）が成立する時点では常に true。よって ASP `xsns_dpn_W-a` の初期化ルーチン手法は FMP では `check_tskctx()==false`（else）に落ち、`kerflg_table` 分岐を評価しない。残存分岐は本ファイル第2部 §6。

**WBテスト** [`xsns_dpn_W-a`](../../wb_test/FMP/exception/xsns_dpn_W-a/out.c): MAIN_TASK（タスクコンテキスト）から `xsns_dpn(NULL)` を直接呼び出し、戻り値が `true` であることを確認。gcov 実測で L105 偽分岐 taken・if-body（kerflg 評価）未実行を確認済み。

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L114 `p_my_pcb->p_runtsk != NULL` 偽 → state=true | `check_tskctx()==true`（例外コンテキスト）かつ自 PE がアイドル（`p_runtsk==NULL`）で CPU 例外が発生 | BB テストの CPU 例外はすべて実行中タスクのある PE で発生するため `p_runtsk != NULL`。アイドル PE で CPU 例外を起こすシナリオは自動生成テストでは生成されない。 |

**WBテスト** [`xsns_dpn_W-b`](../../wb_test/FMP/exception/xsns_dpn_W-b/out.c): `MAIN_TASK` を PE1 のみに割り当て、PE2 を実行可能タスクの無いアイドル状態（`p_runtsk==NULL`）にする。`core_support.S` のアイドルループ `dispatcher_2` は `TOPPERS_CUSTOM_IDLE` 定義時に `toppers_asm_custom_idle` を実行する。これを **COPTS の `-include <wb_dir>/ttsp_custom_idle.inc`**（カーネル無改変・禁則②非抵触）で注入し、フックから C 関数 `xsns_dpn_W_b_idle()` を呼ぶ。同関数は `sil_get_pid` で PE2 のみを判定し CPU 例外を発生させ、CPU 例外ハンドラ `xsns_dpn_W_b_exc()`（PE2）が `check_tskctx()==true` かつ `p_my_pcb->p_runtsk==NULL` のまま `xsns_dpn(p_excinf)` を呼んで `state=true`（L114 短絡）を確認する。注入は `scripts/coverage_gcov_fmp.sh` の WB ビルドが `ttsp_custom_idle.inc` の有無で当該テストにのみ適用（他テスト・カーネル本体には波及しない）。**実証**: 8 dir（check_library/exception + xsns_dpn BB split6 + `W-a`）では exception.c 8/10、`W-b` 追加で 9/10（merge 計測で確認）。残る 1 分岐（`kerflg_table==false`）は構造的到達不能（第2部 §6）。ASP `xsns_dpn_W-b` と同型だが SMP のため PE2 をアイドルにする点が差異。

---

# 第2部 — WBテストでも到達しない残存分岐

> `all` モード（BBテスト + WBテスト）での残存 77 分岐の分析。到達不能理由・分類と追加 WBテスト候補を示す。第1部の WBテストで到達済みの分岐（§5-a/§5-b, §6, §8）は本部の各節で「到達済み」と注記している。

## ビルド条件

| フラグ | 効果 |
|---|---|
| `ENABLE_GCOV=true` | gcov計装（`-fprofile-arcs -ftest-coverage`）を有効化 |
| `-DNDEBUG` | `assert()` 無効化。`t_stddef.h` の `#ifndef NDEBUG` で制御される assert 分岐がコードから除去される |
| **`-O2` + インライン抑制** | `-fno-inline` 系で `static inline` 展開を抑制し、wait.h 等の「64分岐」水増しアーティファクトを除去。各 inline 関数を1実体計測し論理分岐をそのまま反映、bb/all 分母も一致（1597）。`-O0` は実行時クラッシュ・タイミング変化のため不採用（理由詳細は [`BB_COVERAGE.md`](BB_COVERAGE.md)） |

---

## サマリー

> -O2+インライン抑制で再計測（合計 **77 / 1597**、`xsns_dpn_W-b` で exception を +1 到達後）。旧 -O2 計測の §3 wait.h アーティファクト（16）はインライン抑制で解消（現 wait.h 13/14 = 1分岐のみ未到達）。category 別の内訳は概数（インライン抑制で分岐数が再正規化されたため、interrupt.c は実分岐顕在化で増、task.c は 16→12 に減 等）。ファイル別 `all` 残存の正は [`ALL_COVERAGE.md`](ALL_COVERAGE.md)。

| # | カテゴリ | 未到達分岐数（概数）| 主なファイル |
|---|---|---|---|
| §1 | マルチコア遅延ディスパッチパス | 約30 | alarm.c, cyclic.c, mempfix.c, mutex.c(一部), sys_manage.c, task_manage.c, task_term.c |
| §2 | interrupt.c chg_ipm 複合パス | 約29 | interrupt.c（inline抑制で実分岐顕在化） |
| §3 | wait.h | 1 | wait.h（旧アーティファクト16はinline抑制で解消） |
| §4 | task.c サブ優先度機能 | 約12 | task.c |
| §5 | time_event.c ヒープ操作・マルチコアパス | 約10 | time_event.c（§5-a/b は WBで到達済） |
| §6 | exception.c xsns_dpn | 1 | exception.c（else・`p_runtsk==NULL` は WBで到達済（`xsns_dpn_W-a`/`W-b`）。残1: `kerflg_table` は構造的到達不能）|
| §7 | mutex.c サブ優先度パス | 約7 | mutex.c |
| §8 | alarm/cyclic force_unlock_spin | 0（WBで到達済）| alarm.c, cyclic.c |
| §9 | startup.c / task_refer.c / task_term.c / spin_lock.c | 約4 | 各1分岐 |
| §10 | time_manage.c adj_tim 64bit 折返し | 2 | time_manage.c（zybo 実用的到達不能 / simt 到達可能・ASP §3 同分類。マルチコア起因ではない）|
| **合計** | | **77 / 1597** | |

---

## §1. マルチコア遅延ディスパッチパス（FMP固有）

### 背景

FMP（Flexible Multiprocessor）では，カーネルAPIの多くに以下のパターンが追加されている：

```c
lock_cpu();
acquire_glock();
...
if (p_selftsk != p_my_pcb->p_schedtsk) {
    release_glock();
    dispatch();
    ercd = E_OK;
    goto unlock_and_exit;    /* ← 未到達 */
}
```
次のようなシナリオで発生する
- PE2 : TASK2 : sus_tsk(TASK1)
  - acquire_glock()でスピンロックを取得
- PE1 : TASK1 : dis_dsp()
  - lock_cpu()で割り込みを禁止
  -  PE1 の p_my_pcb->p_schedtsk は TASK1
  - acquire_glock()でスピンロックを取得を試みるがPE2が取得しているので取得できない
- PE2 : TASK2 : sus_tsk(TASK1)
  - make_non_runnable() で PE1の p_my_pcb->p_schedtsk をTASK1以外にする
  - release_glock() : ロックの開放
- PE1 : TASK1 : dis_dsp()
  - acquire_glock() でロックを取得
  - if (p_selftsk != p_my_pcb->p_schedtsk) が Trueとなりif文の中を実行する

**テスト環境での到達不能理由**: TTSP3のAPIテストは1タスク（または少数タスク）が順次APIを呼び出す構成．QEMUで2コア起動していても，PE2は `idle_loop` のみ実行し，PE1のスケジューリングを変更しない。そのため `p_selftsk == p_my_pcb->p_schedtsk` が常に成立する。

**対応方法検討** → 詳細は [`TIMING_TEST.md`](TIMING_TEST.md)
- 案1: QEMU + GDB スクリプト（gdbstub + scheduler-locking）で決定的に interleaving を強制
- 案2: QEMU にパッチを当ててコア間タイミングを制御（**フォーク保守コスト過大・不採用推奨**）
- 案3（推奨）: 純粋な2コア・ストレスループ WBテスト（外部ツール不要）— MTTCG の実並行を利用
- 案4: ハイブリッド（案3 主軸 + 残り分岐を案1 GDB で決定的補完）

### 影響ファイル

| ファイル | 未到達分岐 | 未到達行（例） |
|---|---|---|
| alarm.c | 2 (alarm.cのdispatchパス) | `alm_cal` ハンドラ後処理 |
| cyclic.c | 2 | `cyc_cal` ハンドラ後処理 |
| mempfix.c | 2 | `rel_mpf` / `ini_mpf` |
| mutex.c | 2 | `unl_mtx`(L567-568), `ini_mtx`(L618-619) |
| sys_manage.c | 3 | `rot_rdq`(L277-278), `dis_dsp`(L604-606) |
| task_manage.c | 4 | `act_tsk`(L161-162), `mact_tsk`(L232-233) |
| task_term.c | 1 | `ter_tsk`(L374-375) |

> **注記（2026-06-10 レビュー）**:
> - alarm.c / cyclic.c の「2」は `bb` モードの未到達数。うち各 1 分岐（`force_unlock_spin` 系）は `alarm_W-a` / `cyclic_W-a`（§8）で到達済みのため、`all` モードの残存は各 **1**（マルチコア起因の `force_unlock_spin` リトライ系）。ファイル別 `all` 残存は [`ALL_COVERAGE.md`](ALL_COVERAGE.md) を正とする。
> - **time_manage.c は本カテゴリ（マルチコア遅延ディスパッチ）に該当しない**。`all` 残存 **2 分岐**はいずれも `adj_tim` の 64bit `EVTTIM` 折返しパス（`fmp3/kernel/time_manage.c` L174–178 の `if (current_evttim < monotonic_evttim) { systim_offset += 1LLU << 32; }`）で、マルチコアの `set_hrt_event` ループ（L183–188）は到達済み。これは ASP の `adj_tim` 64bit 折返し分岐と同一で、**zybo 実 GIC タイマでは実用的到達不能・ASP3 公式 simt スイートでのみ C1 到達可能**（ASP `BB_UNREACHABLE.md` 第2部 §3 と同分類）。FMP では simt 計測を未実施。→ 下記 §10 参照。

**分類**: 到達困難（マルチコアタイミング依存）。WBテストで到達するには，PE2上のタスクがPE1のAPIコール中に優先度の高いタスクを起動するタイミング制御が必要。

---

## §2. interrupt.c chg_ipm 複合パス

`chg_ipm`（割込み優先度マスク変更）はFMP版で大幅に複雑化しており，複数の未到達パスを含む。

### §2-a. マルチコア dispatch retry パス

```c
/* interrupt.c L380-387 */
  retry:
    acquire_glock();
    p_my_pcb = get_my_pcb();
    if (p_selftsk != p_my_pcb->p_schedtsk) {   /* L383 - 常にfalse */
        release_glock();
        dispatch();                              /* L385 - 未到達 */
        goto retry;                              /* L386 - 未到達 */
    }
```

§1 と同じマルチコアパターン。

### §2-b. intpri == TIPM_ENAALL かつ enadsp == true パス

```c
/* interrupt.c L388 */
if (intpri == TIPM_ENAALL && p_my_pcb->enadsp) {
    set_dspflg(p_my_pcb);
    if (p_selftsk->raster && p_selftsk->enater) {   /* L391 */
        if (task_terminate(...)) {                   /* L392 */
            exit_and_migrate(...);                   /* L393 - 未到達 */
        } else {
            release_glock();
            exit_and_dispatch();                     /* L397 - 未到達 */
        }
        ercd = E_SYS;                               /* L399 - 未到達 */
    } else {
        if (p_selftsk != p_my_pcb->p_schedtsk) {    /* L403 */
            dispatch();                              /* L405-407 - 未到達 */
        }
    }
}
```

`TIPM_ENAALL` に戻す際，dispatch有効 + タスク終了要求 + 終了許可という複合条件が重なった場合に実行される。テストでは`chg_ipm(TIPM_ENAALL)` の呼び出しが単純なAPI適合性テストのためこの組み合わせが生じない。

**分類**: 
- `raster && enater` の組み合わせ: 到達困難（内部状態依存）
- `exit_and_migrate` / `exit_and_dispatch`: `task_terminate()` の返り値分岐（true = マイグレート, false = そのまま終了）→ 実用的到達不能（CPUアフィニティ依存）
- その他のマルチコアdispatchパス: §1 と同じ

**総計**: interrupt.c 27分岐（マクロ展開による分岐を含む）

---

## §3. wait.h — 過渡状態分岐（1 branch, 13/14）

> **2026-06-10 更新**: 旧 -O2 計測ではインライン展開により wait.h が「64分岐」に水増しされ 16分岐が未到達と計上されていたが、**インライン抑制（`-fno-inline` 系）で解消**。現在 wait.h は 14分岐（論理分岐どおり）で **13/14 = 92.9%**、残 1 分岐のみ。

```c
/* fmp3/kernel/wait.h make_wait */
Inline void
make_wait(PCB *p_my_pcb, TS tstat, TCB *p_selftsk)
{
    if (!TSTAT_SUSPENDED(p_selftsk->tstat)) { ... }
    else {
        p_selftsk->tstat |= tstat;             /* 過渡状態分岐 - 未到達 */
    }
    ...
}
```

- **過渡状態分岐**: 待ち状態（TS_WAITING）と強制待ち状態（TS_SUSPENDED）が同時成立する過渡状態。マルチコア遷移中に理論上発生しうるが、テストでは生じない。

**分類**: 到達困難（内部状態依存：過渡状態）。WBテスト不要（旧版のインライン展開アーティファクト ×16 はインライン抑制で消滅し、残るのは論理分岐 1 のみ）。

---

## §4. task.c サブ優先度機能

FMPはサブ優先度（`TA_SUBPRI`）機能をサポートする。この機能を使用するタスクは `subprio_primap` に対応ビットが立ち，サブ優先度順キューへの挿入が行われる。

### §4-a. queue_insert_subprio_head（L230-242）

```c
/* fmp3/kernel/task.c L229-242 */
Inline void
queue_insert_subprio_head(QUEUE *p_queue, TCB *p_tcb)
{
    QUEUE   *p_entry;
    uint_t  subpri = current_subpri(p_tcb);          /* L233 - 未到達 */

    for (p_entry = p_queue->p_next; p_entry != p_queue;
                                    p_entry = p_entry->p_next) {  /* L235-236 */
        if (subpri <= current_subpri((TCB *) p_entry)) {           /* L237 */
            break;
        }
    }
    queue_insert_prev(p_entry, &(p_tcb->task_queue));  /* L241 - 未到達 */
}
```

`change_priority` (L363) 内の `if ((subprio_primap & PRIMAP_BIT(newpri)) != 0U)` が常に偽（サブ優先度未使用）のため，インライン展開後のコード（L383-387周辺）も含め実行されない。

### §4-b. change_priority サブ優先度分岐（L382-387）

```c
/* fmp3/kernel/task.c L382-388 */
if ((subprio_primap & PRIMAP_BIT(newpri)) != 0U) {  /* L382 - 常にfalse */
    if (mtxmode) {
        queue_insert_subprio_head(...);  /* L384 */
    }
    else {
        queue_insert_subprio_tail(...);  /* L387 */
    }
}
```

**分類**: 実用的到達不能（`TA_SUBPRI` 未使用のテスト設定）。

`task_manage.c` の `chg_spr` (L600-607) も同様のサブ優先度パス（`change_subprio` 呼び出し後のdispatch分岐含む）が未到達。

---

## §5. time_event.c ヒープ操作・マルチコアパス

### §5-a. tmevt_down 右子なし + 早期 break（✅ 2026-06-10 WBテストで到達済み）

```c
/* fmp3/kernel/time_event.c L228-258 (tmevt_down) */
while ((child = LCHILD(index)) <= LAST_INDEX(p_tmevt_heap)) {
    if (child + 1 <= LAST_INDEX(p_tmevt_heap)         /* L234: 右子の有無 */
            && EVTTIM_LT(...)) { child = child + 1; }
    if (EVTTIM_LE(evttim, HEAP_NODE(child)->evttim)) { break; }  /* L244 */
    ...
}
```

**→ WBテスト [`time_event_W-a`](../../wb_test/FMP/time_event/time_event_W-a/out.c) で到達済み（+2 分岐）**。5アラームで右子の無いヒープ形状を構築し、index-2 削除で「右子なし（L234）」+「早期break（L244）」を同時カバー。ヒープ算法は ASP と同一。詳細 → 本ファイル第1部 §1-2。

### §5-b. tmevtb_delete go-up パス（✅ 2026-06-10 WBテストで到達済み）

```c
/* fmp3/kernel/time_event.c L315-334 (tmevtb_delete) */
if (index > ROOT_INDEX
        && EVTTIM_LT(event_evttim, HEAP_NODE(parent, ...)->evttim)) {  /* L315 */
    HEAP_NODE(index) = HEAP_NODE(parent);
    HEAP_NODE(index)->index = index;
    index = tmevt_up(parent, ...);
}
else {
    index = tmevt_down(index, ...);
}
```

**→ WBテスト [`time_event_W-b`](../../wb_test/FMP/time_event/time_event_W-b/out.c) で到達済み（+1 分岐）**。6アラームで中間ノード削除時に最後尾ノードが削除位置の親より早い配置を構築し、go-up（L315 真）をカバー。

### §5-c. 非TM processor 転送パス（L168, L522, L546, L583, L627）

FMPでは，タイムイベント処理プロセッサ（TM processor）が`p_tevtcb != NULL`を持ち，他のPEは`p_tevtcb == NULL`となる。その場合P_TM_PCBへ転送するパスが各関数に存在する：

```c
/* 例: time_event.c L521-523 (tmevtb_register) */
if (p_pcb->p_tevtcb == NULL) {
    p_pcb = P_TM_PCB;  /* L522 - 未到達 */
}
```

`initialize_event_time` の `else { p_my_pcb->p_tevtcb = NULL; }` (L168) も同様。

zybo_z7_gcc (dual Cortex-A9) 構成ではPE1・PE2ともに自プロセッサのタイムイベントを管理するため，`p_tevtcb == NULL` になるPEが存在しない。

### §5-d. HRTCNT_BOUND パス（L474）

```c
/* time_event.c L469-478 (set_hrt_event, #else !USE_64BIT_HRTCNT) */
if (hrtcnt > HRTCNT_BOUND) {
    target_hrt_set_event(p_pcb->prcid, HRTCNT_BOUND);  /* L474 - 未到達 */
}
```

次のタイムイベントが現在時刻から `HRTCNT_BOUND` を超える未来に設定された場合。テストではそのような長期タイムアウトが存在しない。

### §5-e. signal_time syslog パス（L757）

```c
/* time_event.c L756-759 */
if (nocall == 0) {
    syslog_1(LOG_NOTICE, "no time event processed...");  /* L757 - 未到達 */
}
```

HRT割込み発生時にタイムイベントが処理されなかった場合。テストでは常にいずれかのタイムイベントが処理される。

**分類**: §5-a, §5-b = **WBテストで到達済み**（`time_event_W-a`/`W-b`、計+3分岐）。§5-c = 実用的到達不能（テスト設定のTM processor構成）。§5-d = 到達困難（制約あり：テストシナリオの制限）。§5-e = 実用的到達不能。残存 10 分岐は §5-c/§5-d/§5-e（実用的到達不能・ターゲット設定依存）。

---

## §6. exception.c xsns_dpn 複合条件

```c
/* fmp3/kernel/exception.c L105-121 (xsns_dpn) */
if (check_tskctx()) {
    p_my_pcb = get_my_pcb();
    state = (kerflg_table[INDEX_PRC(p_my_pcb->prcid)]
                    && exc_sense_intmask(p_excinf)
                            && p_my_pcb->enadsp
                            && p_my_pcb->p_runtsk != NULL) ? false : true;
}
else {
    state = true;    /* タスクコンテキストの場合: ディスパッチ保留 */
}
```

`check_tskctx()` は `sense_context()`（`excpt_nest_count > 0`、例外コンテキストで真）を返す。10分岐中、BBテストで7、WBテストで+2 = 9/10 をカバー済み。

**✅ 2026-06-10 WBテストで到達済み（+2分岐）**:
- L105 `check_tskctx()` 偽分岐（タスクコンテキスト → else `state=true`、NGKI3152）を WBテスト [`xsns_dpn_W-a`](../../wb_test/FMP/exception/xsns_dpn_W-a/out.c) でカバー。MAIN_TASK から `xsns_dpn(NULL)` を直接呼び出す。詳細 → 本ファイル第1部 §1-3。
- L114 `p_my_pcb->p_runtsk == NULL` 分岐を WBテスト [`xsns_dpn_W-b`](../../wb_test/FMP/exception/xsns_dpn_W-b/out.c) でカバー（custom idle 方式）。MAIN_TASK を PE1 のみに割当て、PE2 をアイドル（`p_runtsk==NULL`）にして CPU 例外を発生 → CPU 例外ハンドラから `xsns_dpn(p_excinf)==true` を確認。詳細 → 本ファイル第1部 §1-3。

**残存 1 分岐（構造的到達不能）**:
- `kerflg_table[prcid]==false`: `kerflg_table` は `start_dispatch`（startup.c L237）直前の L235 で true 化され、`check_tskctx()==true`（例外コンテキスト）成立時は常に true。例外コンテキストで kerflg_table=false となる窓が存在しない。**構造的到達不能**（ASP は `xsns_dpn` に `check_tskctx()` ガードが無いため初期化ルーチンで到達できたが、FMP では不可）。custom idle 方式でも到達不能（窓が無い）。

> **【到達経路の記録】custom idle 方式（`p_runtsk==NULL` を到達）**
>
> ASP と共通の `arch/arm_gcc/common/core_support.S` アイドルループ `dispatcher_2` は、`TOPPERS_CUSTOM_IDLE` 定義時に `toppers_asm_custom_idle`（ターゲット依存マクロ）を実行する。このループは自 PE の `p_runtsk == NULL`（実行タスクなし）の状態で回る。カスタムアイドルフック内で CPU 例外を発火させると、CPU 例外コンテキスト（`excpt_nest_count > 0` → `check_tskctx()==true`）で `xsns_dpn(p_excinf)` が呼ばれ、`if (check_tskctx())` 本体に入って `p_my_pcb->p_runtsk == NULL` 分岐に到達する。
>
> **カーネル無改変で注入**: `fmp3` を編集せず（禁則②）、`COPTS` に `-include <wb_dir>/ttsp_custom_idle.inc` を渡して `toppers_asm_custom_idle` をテストスイート側で定義する。SMP では MAIN_TASK を PE1 のみに割り当てて PE2 をアイドルにし、`sil_get_pid` で PE2 を判定して発火する点が ASP との差異。`xsns_dpn_W-b` として実装済み（`all` 計測に反映: exception.c 9/10、kernel/ 1520/1597）。

**分類**: 残存 1 分岐（`kerflg_table==false`）は構造的到達不能。`p_runtsk==NULL` は `xsns_dpn_W-b` で到達済み。

---

## §7. mutex.c サブ優先度パス

```c
/* fmp3/kernel/mutex.c L248-258 (mutex_raise_priority) */
if (newpri <= p_tcb->priority) {
    if (newpri < p_tcb->priority
            || ((subprio_primap & PRIMAP_BIT(p_tcb->priority)) != 0U
                                            && !(p_tcb->boosted))) {  /* L251 */
        p_tcb->boosted = true;
        change_priority(...);
    }
```

```c
/* fmp3/kernel/mutex.c L276-283 (mutex_drop_priority) */
if (newpri != p_tcb->priority
        || ((subprio_primap & PRIMAP_BIT(p_tcb->priority)) != 0U
                                        && !(p_tcb->boosted))) {  /* L280 */
    change_priority(...);
```

`subprio_primap` が常に0（サブ優先度未使用）のため，`&&` の右辺 `!(p_tcb->boosted)` が評価されない。

**分類**: 実用的到達不能（サブ優先度未使用のテスト設定，§4と同一要因）。

---

## §8. alarm.c / cyclic.c force_unlock_spin パス（✅ 2026-06-10 WBテストで到達済み）

```c
/* fmp3/kernel/alarm.c L316-321 (call_alarm) */
if (sense_lock()) {
    force_unlock_spin(p_my_pcb);  /* L317 */
}
else {
    lock_cpu();
}
```

**→ WBテスト [`alarm_W-a`](../../wb_test/FMP/alarm/alarm_W-a/out.c) / [`cyclic_W-a`](../../wb_test/FMP/cyclic/cyclic_W-a/out.c) で到達済み（各+1分岐）**。

> **当初分類の訂正**: 旧版は「ハンドラ内 CPU ロック保持＝API誤使用につき到達不要」としていたが、これは誤り。ハンドラ内での `iloc_cpu()` 呼出しは NGKI 上許容された動作であり、ASP の `alarm_W-a`/`cyclic_W-a`（`if(!sense_lock()) lock_cpu()` の対応分岐）で実証済みのパスである。通知ハンドラが `iwup_tsk` 後に `iloc_cpu()` を呼んで CPU ロック状態で戻ることで、`call_alarm` は `force_unlock_spin()` を実行する。gcov 実測で L317 到達・`if(sense_lock())` 真分岐 taken を確認済み。詳細 → 本ファイル第1部 §1-1。

---

## §9. その他（各1分岐）

### §9-a. spin_lock.c loc_spn 待機ループ（1分岐）

```c
/* fmp3/kernel/spin_lock.c L209 (loc_spn, エミュレーション方式) */
while (LOCKFLAG(p_spninib)) {
    /* スピン待ち（他PEがロック保持中）*/
    release_glock();
    unlock_cpu();
    while (LOCKFLAG(p_spninib)) { ... }
    lock_cpu();
    acquire_glock();
}
```

スピンロックが既に他PEにより取得済みの場合のスピン待ちループ。テストでは `loc_spn` 呼び出し時に常にロックが空いている（単一シナリオ実行）ため，待機ループに入らない。

**分類**: 到達困難（マルチコア同時ロック競合依存）。

### §9-b. startup.c 非TM processor sta_ker パス（1分岐）

```c
/* fmp3/kernel/startup.c L221 (sta_ker) */
if (p_my_pcb->p_tevtcb != NULL) {
    while (try_glock());
    set_hrt_event(p_my_pcb);
    release_glock();
}
/* else: p_tevtcb == NULL のプロセッサはhrt_eventを設定しない */
```

zybo_z7_gcc構成（dual A9）では，PE1・PE2ともに`p_tevtcb != NULL`（各プロセッサが独立してタイムイベントを管理）。`p_tevtcb == NULL`（TM専用外プロセッサ）のケースが存在しないため，false分岐が未到達。

**分類**: 実用的到達不能（ターゲット設定に依存）。

### §9-c. task_refer.c マルチコア参照パス（1分岐）

```c
/* fmp3/kernel/task_refer.c L117 (ref_tsk) */
else if (p_tcb == p_pcb->p_runtsk) {
    pk_rtsk->tskstat = TTS_RUN;  /* 他PE上で実行中 */
}
```

`ref_tsk` で参照対象タスクが別プロセッサ上で実行中（TTS_RUN）かどうかのチェック。テストでは参照対象タスクが常に同一PE上に存在するか，RUNNABLE/WAITING状態で参照されるため，別PEで実行中の状態が参照されない。

**分類**: 到達困難（マルチコア状態参照タイミング依存）。

### §9-d. task_term.c ras_ter 自己終了パス（1分岐）

```c
/* fmp3/kernel/task_term.c L290-298 (ras_ter) */
if (p_selftsk->raster && p_my_pcb->dspflg) {
    if (task_terminate(p_my_pcb, p_selftsk)) {
        exit_and_migrate(p_my_pcb, p_selftsk);  /* L292 - 未到達 */
    } else {
        release_glock();
        exit_and_dispatch();                     /* L296 - 未到達 */
    }
    ercd = E_SYS;                               /* L298 - 構造的到達不能 */
}
```

`ras_ter` 自己呼び出し（自タスクに終了要求）で，その時点でディスパッチ可能状態の場合の即時終了パス。テストでは`ras_ter`呼び出し時のdspflg状態が該当しない。また，`exit_and_migrate` / `exit_and_dispatch` は non-returning 関数のため，L298は構造的到達不能。

**分類**: 到達困難（内部状態依存）+ 構造的到達不能（L298）。

---

## §10. time_manage.c — `adj_tim` 64bit `EVTTIM` 折返し（2 branches, 20/22）

```c
/* fmp3/kernel/time_manage.c L171-181 (adj_tim) */
current_evttim += adjtim;                              /* L171 */
boundary_evttim = current_evttim - BOUNDARY_MARGIN;    /* L172 */
if (adjtim > 0
        && monotonic_evttim - previous_evttim < (EVTTIM) adjtim) {   /* L174-175 */
#ifdef UINT64_MAX
    if (current_evttim < monotonic_evttim) {           /* L177 */
        systim_offset += 1LLU << 32;                   /* L178 ← 未到達 */
    }
#endif
    monotonic_evttim = current_evttim;                 /* L181 */
}
```

`all` モードで残る 2 分岐は、いずれも `adj_tim` の **正方向大調整時の 64bit `EVTTIM` 折返し**経路（L174–175 の複合条件成立 + L177 の `current_evttim < monotonic_evttim`）。`adjtim > 0` かつ単調時刻が大きく進む条件を要し、特に L177 の折返しは 64bit `EVTTIM` が `monotonic_evttim` を下回る巨大調整でのみ成立する。BBテストの `adj_tim` 系は通常範囲の調整のみで、この折返しを起こさない。

> **マルチコア起因ではない**: §1 の「マルチコア遅延ディスパッチ」とは無関係。本関数のマルチコア部（`set_hrt_event` ループ L183–188）は到達済み。

**分類**: **zybo 実 GIC タイマでは実用的到達不能 / ASP3 公式 simt スイートでのみ C1 到達可能**。ASP の `adj_tim` 64bit 折返し分岐（ASP [`BB_UNREACHABLE.md`](../ASP/BB_UNREACHABLE.md) 第2部 §3）と同一構造で、ASP では simt スイート（HRT_CONFIG3/64bit）で `adj_tim` 14/14=100% に到達済み。**FMP では simt 計測を未実施**のため未到達のまま計上。FMP のタイマー共有部（`time_event.c`/`time_manage.c`）は CPU 非依存で ASP と同実装のため、FMP でも simt 同型ビルドで到達可能と見込まれる（未実証）。

---

## 未到達分岐 総括

| カテゴリ | 分岐数（概数）| 備考 |
|---|---|---|
| マルチコア遅延ディスパッチパス（§1,§2の一部） | 約30 | FMP固有。並行実行シナリオ不在。→ [`TIMING_TEST.md`](TIMING_TEST.md) 案3で到達実証済み |
| interrupt.c chg_ipm 複合パス（§2） | 約29 | dispatch + 終了フロー複合（inline抑制で実分岐顕在化）|
| wait.h（§3） | 1 | 過渡状態分岐（旧アーティファクト16はinline抑制で解消）|
| サブ優先度機能（§4, §7） | 約19 | TA_SUBPRI/ENA_SPR 未使用設定 |
| time_event.c ヒープ・マルチコアパス（§5） | 約10 | TM設定依存（§5-a/b は WBで到達済み） |
| exception.c xsns_dpn（§6） | 1 | else・`p_runtsk==NULL` は WBで到達済み（`xsns_dpn_W-a`/`W-b`）。`kerflg_table` は構造的到達不能 |
| alarm/cyclic force_unlock_spin（§8） | 0 | WBテストで到達済み（`all` で各 1 残存はマルチコア起因の §1 側）|
| その他（§9） | 約4 | 各ファイル1分岐 |
| **time_manage.c adj_tim 64bit 折返し（§10）** | 2 | zybo 実用的到達不能 / simt 到達可能（ASP §3 と同分類）。マルチコア起因ではない |
| **合計** | **77 / 1597** | 95.2% branch coverage（all モード、-O2+インライン抑制）|

---

## WBテスト設計の考察

### ✅ 2026-06-10 実装済み（ASP 前例の移植、計 +6分岐）

| WBテスト | 対象 | 寄与 |
|---|---|---|
| `alarm_W-a` / `cyclic_W-a` | §8 force_unlock_spin | +2 |
| `xsns_dpn_W-a` | §6 check_tskctx 偽（NGKI3152） | +1 |
| `time_event_W-a` / `W-b` | §5-a/§5-b ヒープ操作 | +3 |

### 残存分岐に対する WBテスト追加の実現性

| カテゴリ | WBテスト化 | 理由 |
|---|---|---|
| マルチコア遅延ディスパッチ（§1,§2） | **実証済み（案3）** | [`TIMING_TEST.md`](TIMING_TEST.md) の2コアストレスループで dis_dsp/ena_dsp/chg_ipm のレース分岐到達を実証。横展開で広くカバー可 |
| interrupt.c 終了フロー（§2） | 困難 | chg_ipm + raster + enater の複合状態制御 |
| wait.h 過渡状態（§3） | 困難（内部状態依存）| 残 1 分岐（旧アーティファクト16はinline抑制で解消）|
| **サブ優先度機能（§4, §7）** | **可能（最有力）** | `ENA_SPR(tskpri)` 静的API で `subprio_primap` ビットを立て、当該優先度のタスク + `chg_spr` を組み合わせれば到達。auto_code は `ENA_SPR(13)` を持つが当該優先度のタスク構成が不足。最大 +約15実分岐 |
| time_event.c 非TM path（§5-c/d/e） | 困難 | ターゲットHW構成・長期タイムアウト依存 |
| exception.c xsns_dpn 残1（§6） | 完了（`p_runtsk==NULL`）/ `kerflg_table` は不要 | `p_runtsk==NULL`: `xsns_dpn_W-b`（custom idle 方式）で到達済み（§6）。`kerflg_table`: 構造的到達不能 |
| alarm/cyclic force_unlock（§8） | 完了 | WBテストで到達済み |

**次の最有力候補はサブ優先度機能（§4, §7, 19分岐）**: `ENA_SPR` で特定優先度をサブ優先度スケジューリング対象にし、その優先度に複数タスクを作成して `chg_spr` / mutex 優先度継承を試験することで、`subprio_primap & PRIMAP_BIT(pri)` 真分岐群に到達できる。ただし cfg 設計と複数タスクの優先度・サブ優先度の組合せ制御が必要。
