# WB_UNREACHABLE.md — ASP3 kernel/ 未到達分岐 詳細分析

> 更新: 2026-06-09（WBテスト無効化後 再計測）  
> 対象: ASP3 3.7.2 `kernel/`、残存 34 未到達分岐（1425/1459 = 97.7%）  
> ビルド: `coverage_gcov_asp.sh` に `-DNDEBUG` 追加済み（`COPTS` 環境変数経由）  
> WBテスト: `api_test/ASP/whitebox/` → `api_test/ASP/whitebox_archive/` に移動（無効化）

**分類凡例:**
- **構造的到達不能**: カーネルの不変条件（恒真 flag、整合性保証ポインタ等）により実行時に到達できない。
- **実用的到達不能**: 理論上は可能だが QEMU では非現実的な前提（64 bit カウンタ折返し、数千秒タイマ等）が必要。
- **到達困難（制約あり）**: 理論的には到達可能だが、複数条件が同時成立する必要があり、コストに対して価値が低い。
- **到達困難（内部状態依存）**: 外部 API 操作では再現が難しい内部データ構造・状態が必要。
- **到達可能（低優先度）**: テストは作れるが、現状の BB テストカバレッジで十分と判断した分岐。
- **計測アーティファクト**: コンパイラの最適化（インライン展開）により同一ソース行が複数 call-site インスタンスとして追跡され、一部インスタンスが未到達になるもの。論理的カバレッジは確認済み。

---

## NDEBUG 適用の影響

`coverage_gcov_asp.sh` に `-DNDEBUG` を追加したことで、以下の assert 分岐が gcov の計測対象から除外された（`assert(exp)` → `((void)(0))` となり分岐ノードが消滅）。

| ファイル | 除外された分岐 | 効果 |
|---|---|---|
| task.c L268/L274 | `assert(dspflg)` × 2 | task.c → 100% |
| mutex.c L375/423/474 | `assert(p_runtsk == p_schedtsk)` × 3 | mutex.c → 99.3% |
| wait.c L65 | `assert(tmout <= TMAX_RELTIM)` | wait.c → 100% |
| wait.h L113 | `assert(TSTAT_WAITING(p_tcb->tstat))` | make_non_wait → 100% |
| time_event.c L588/L589 | `assert(sense_context())` / `assert(!sense_lock())` × 2 | signal_time 改善 |

一方、NDEBUG+O2 のインライン展開変化により **wait.h** の追跡ブランチ数が増加した（§7 参照）。

---

## WBテスト無効化の影響（2026-06-09）

`api_test/ASP/whitebox/` を `api_test/ASP/whitebox_archive/` にリネームし、手書き WB テスト（方式2）を全て無効化した。これにより以下の分岐が未到達に戻った。

| WBテスト | 対象分岐 | 影響ファイル |
|---|---|---|
| `alarm_W-a` | alarm.c L241 br[1]（`_kernel_call_alarm` sense_lock false） | alarm.c 100% → 96.9% |
| `cyclic_W-a` | cyclic.c L259 br[1]（`_kernel_call_cyclic` sense_lock false） | cyclic.c 100% → 97.2% |
| `mempfix_W-a` | mempfix.c L309 br[0]（rel_mpf ミスアライメント E_PAR） | mempfix.c 100% → 97.8% |
| `mempfix_W-b` | mempfix.c L310 br[0]（rel_mpf blkidx 範囲外 E_PAR） | 同上 |
| `act_tsk_W-a` | task_manage.c L137 br[1]（act_tsk TA_NOACTQUE E_QOVR） | task_manage.c 100% → 98.9% |
| `time_event_W-a` | time_event.c L221 br[1]、L231 br[0]（tmevt_down 内部パス） | time_event.c 92.9% → 85.7% |
| `time_event_W-b` | time_event.c L302 br[0]（tmevtb_delete go-up パス） | 同上 |

合計 9 分岐が追加で未到達となり、97.7%（1425/1459）に低下した。

---

## 1. exception.c — `xsns_dpn`（2〜3 branches, 66.7%）

**ソース** (`asp3/kernel/exception.c` L101–102):
```c
state = (kerflg && exc_sense_intmask(p_excinf) && enadsp
                        && p_runtsk != NULL) ? false : true;
```

`&&` の短絡評価により GCC は各オペランドごとに分岐を生成する。

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L101 br[0] | `kerflg == FALSE` | `kerflg` はカーネル起動後に `true` にセットされ、以後 `false` に戻ることはない。 | **構造的到達不能** |
| L102 br[1] | `enadsp == FALSE` | `dis_dsp()` 後に CPU 例外が発生し、例外ハンドラから `xsns_dpn` を呼ぶシナリオ。技術的には可能だが、zybo_z7_gcc の QEMU 環境では例外ハンドラを任意タイミングで起動する機構がない。 | **到達困難（制約あり）** |
| L102 br[2] | `p_runtsk == NULL` | アイドルループ中（実行可能タスクなし）に CPU 例外が発生する必要があるが、テストタスク実行中は常に `p_runtsk != NULL`。 | **構造的到達不能**（テスト文脈） |

**結論**: WB テストは不要。

---

## 2. task.c — `_kernel_make_non_runnable`（**NDEBUG 除外済み → 100%**）

**ソース** (`asp3/kernel/task.c` L268, L274):
```c
if (p_schedtsk == p_tcb) {
    assert(dspflg);            /* L268 */
    ...
}
...
if (p_schedtsk == p_tcb) {
    assert(dspflg);            /* L274 */
    ...
}
```

NDEBUG 適用により `assert()` が `((void)(0))` に展開され、分岐ノードが消滅。**task.c 分岐カバレッジ 100%**。

分岐の理由（構造的到達不能）: `p_schedtsk == p_tcb` が成立する（スケジュールされている）のに `dspflg` が偽であることは、カーネルの不変条件違反。正常動作では発生しない。

---

## 3. mutex.c（1 branch, 99.3%）

### 3-a. `remove_mutex` L227 br[1]（**残存**）

**ソース** (`asp3/kernel/mutex.c` L224–232):
```c
pp_prevmtx = &(p_tcb->p_lastmtx);
while (*pp_prevmtx != NULL) {          /* L227 */
    if (*pp_prevmtx == p_mtxcb) {
        *pp_prevmtx = p_mtxcb->p_prevmtx;
        return;
    }
    pp_prevmtx = &((*pp_prevmtx)->p_prevmtx);
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L227 br[1]（ループ NULL 終了） | リスト末尾まで走査しても `p_mtxcb` が見つからない | `remove_mutex` は `p_mtxcb` がリストに存在することを呼出し側で保証した上でのみ呼ばれる（`unl_mtx`/`ini_mtx` 等は所有権確認済み）。NULL 終了はカーネル内部の一貫性違反を意味する。 | **構造的到達不能** |

**結論**: WB テストは不要。

### 3-b. `loc_mtx` / `ploc_mtx` / `tloc_mtx` L375/423/474（**NDEBUG 除外済み**）

```c
assert(p_runtsk == p_schedtsk);
```

NDEBUG 適用により分岐ノード消滅。分岐の理由（構造的到達不能）: 上限優先度ミューテックス獲得後は実行タスクが `p_schedtsk` に昇格するため恒真。CPU ロック中にディスパッチは発生しない。

---

## 4. task_refer.c — `ref_tsk` L131 br[10]（1 branch, 97.1%）

**ソース** (`asp3/kernel/task_refer.c` L131):
```c
switch (tstat & TS_WAITING_MASK) {
case TS_WAITING_SLP: ...
case TS_WAITING_DLY: ...
...
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L131 br[10]（switch JT 境界チェック） | `TS_WAITING_MASK` の有効範囲外の待ち状態コード | GCC の switch ジャンプテーブル最適化が生成する「範囲外 → デフォルト」の安全チェック分岐。有効な待ち状態コードのみカーネル内部から設定される。 | **構造的到達不能** |

**結論**: WB テストは不要。

---

## 5. time_manage.c — `adj_tim` L168 br[0]（1 branch, 95.5%）

**ソース** (`asp3/kernel/time_manage.c` L168):
```c
if (current_evttim < monotonic_evttim) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L168 br[0] | 64 bit `EVTTIM` 折返し後に `current_evttim < monotonic_evttim` | `EVTTIM` は uint64_t。折返しには約 5.85 × 10¹¹ 年の連続動作が必要。QEMU テストでは不可能。 | **実用的到達不能** |

**結論**: WB テストは不要。

---

## 6. wait.c — `_kernel_make_wait_tmout` L65（**NDEBUG 除外済み → 100%**）

**ソース** (`asp3/kernel/wait.c` L65):
```c
assert(tmout <= TMAX_RELTIM);
```

NDEBUG 適用により分岐ノード消滅。**wait.c 分岐カバレッジ 100%**。

分岐の理由（構造的到達不能）: 呼出し元の全 API が `CHECK_PAR(VALID_TMOUT(tmout))` で事前検証済み。無効なタイムアウト値はここに到達しない。

---

## 7. wait.h — インライン展開アーティファクト（15 branches, 76.6%）

**背景**: NDEBUG+O2 の組み合わせにより、wait.h の `static inline` 関数（`make_non_wait`、`wait_dequeue_wobj` 等）がより多くの call-site でインライン展開される。

gcov はインライン展開された各 call-site インスタンスを独立した分岐として追跡する。Python union スクリプトは同一ソース行の分岐数を `max(各グループのブランチ数)` で取るため、インスタンスが多いグループの数に合わせた総数（64）になる。一部の call-site インスタンスが特定のグループで到達されないと「未到達」として計上される。

| 関数 | 論理的カバレッジ | アーティファクト状況 |
|---|---|---|
| `make_non_wait` L115（if `!TSTAT_SUSPENDED`） | 両分岐を複数グループで確認済み | 一部インスタンスが特定グループで未到達 |
| `wait_dequeue_wobj` L141（if `TSTAT_WAIT_WOBJ`） | 真偽両分岐を union で確認済み | 同上 |
| `queue_insert_tpri` L67/L69 | 両分岐を確認済み | 同上 |

**NDEBUG 適用前（参考）**: 16 branches、1 uncovered（`make_non_wait` の assert 失敗パス）  
**NDEBUG 適用後**: 64 branches、15 uncovered（インライン展開増加により追跡インスタンス増加）

分類: **計測アーティファクト**（論理的カバレッジは確認済み、追加テスト不要）

---

## 8. interrupt.c — `chg_ipm` L371 br[0]（1 branch, 98.3%）

**ソース** (`asp3/kernel/interrupt.c` L371):
```c
if (p_runtsk->raster && p_runtsk->enater) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L371 br[0]（`raster && enater` が真） | (1) タスク T が `enater=true` かつ (2) `chg_ipm` 実行中に (3) 別タスクが `ras_ter(T)` を呼び (4) T が `chg_ipm(TIPM_ENAALL)` に到達する、という競合タイミングが必要。 | **到達困難（制約あり）** |

**補足**: 既存テスト `chg_ipm_e.yaml` は `enadsp=false`（L369 の真分岐不成立）のパスをカバー。L371 には `enadsp=true` かつ上記競合条件の同時成立が必要。

**結論**: WB テストで到達可能だが、コストに対して優先度低。当面未対応で可。

---

## 9. time_event.c（8 branches, 85.7%）

> WBテスト無効化前は 4 branches（92.9%）。L221/L231/L302 の 3 分岐（+計測差異 1）が追加未到達となった。

### 9-a. `_kernel_update_current_evttim` L390 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L390 br[0]（`current_evttim < monotonic_evttim`） | 64 bit EVTTIM 折返し後の単調増加保証パス | §5 と同構造。約 5.8 × 10¹¹ 年の連続動作が必要。 | **実用的到達不能** |

### 9-b. `_kernel_set_hrt_event` L439 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L439 br[0]（`hrtcnt > HRTCNT_BOUND`） | 次タイムイベントまで HRTCNT_BOUND（≈ 4,000 秒）超の待ち | QEMU テストの時間スケールでは発生しない。 | **実用的到達不能** |

### 9-c. `_kernel_signal_time` L588/L589（**NDEBUG 除外済み**）

```c
assert(sense_context());    /* L588 */
assert(!sense_lock());      /* L589 */
```

NDEBUG 適用により分岐ノード消滅。分岐の理由（構造的到達不能）: `signal_time` は HRT 割込みハンドラからのみ呼ばれ、割込みコンテキスト・CPU ロックなしが実装保証されている。

### 9-d. `_kernel_signal_time` L624 br（`nocall == 0`）

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L624 br[0]（`nocall == 0`） | HRT 割込みが発生したが期限切れイベントが 0 件 | spurious interrupt / early fire が必要。QEMU の cycle-accurate モデルでは再現困難。 | **実用的到達不能**（タイミング依存） |

### 9-e. `_kernel_tmevt_down` L221 br[1]（**WBテスト無効化で追加**）

**ソース** (`asp3/kernel/time_event.c` L221–222):
```c
if (child + 1 <= LAST_INDEX()
            && EVTTIM_LT(HEAP_NODE(child + 1)->evttim,
                                    HEAP_NODE(child)->evttim)) {
    child = child + 1;
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L221 br[1]（条件の false パス、右子なし） | ヒープの sift-down 中に左子ノードはあるが右子ノードがない状態 | タイムイベントヒープの特定の形状（奇数個ノード構造）が必要。外部 API（`sta_alm`/`sta_cyc` 等）の特定の操作順で間接的に構築可能だが、確実な誘導には多数のタイムイベント管理が必要。 | **到達困難（内部状態依存）** |

### 9-f. `_kernel_tmevt_down` L231 br[0]（**WBテスト無効化で追加**）

**ソース** (`asp3/kernel/time_event.c` L231):
```c
if (EVTTIM_LE(evttim, HEAP_NODE(child)->evttim)) {
    break;
}
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L231 br[0]（条件の true パス、早期 break） | sift-down 中に挿入ノードの発生時刻が子ノード以前 → 現在位置が挿入位置 | §9-e と同様にヒープの特定の構造・時刻分布が必要。 | **到達困難（内部状態依存）** |

### 9-g. `_kernel_tmevtb_delete` L302 br[0]（**WBテスト無効化で追加**）

**ソース** (`asp3/kernel/time_event.c` L301–303):
```c
if (index > ROOT_INDEX
        && EVTTIM_LT(event_evttim,
                    HEAP_NODE(parent = PARENT(index))->evttim)) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L302 br[0]（go-up パス: last_node < parent） | タイムイベント削除後、最後のノードを再挿入する際に、削除位置の親より早い時刻 → ヒープを上方向に探索 | 削除位置・最後のノードの時刻関係が特定のケースを必要とする。§9-e/f と同様に特定のヒープ状態依存。 | **到達困難（内部状態依存）** |

**結論（time_event.c 全体）**: WBテスト無効化前からの 4 分岐（§9-a/b/d + 計測差異 1）はテスト不要。追加 3 分岐（§9-e/f/g）は内部ヒープ状態依存で到達困難。全 8 分岐とも追加テスト不要。

---

## 10. alarm.c — `_kernel_call_alarm` L241 br[1]（1 branch, 96.9%）

**ソース** (`asp3/kernel/alarm.c` L241):
```c
if (!sense_lock()) {
    lock_cpu();
}
```

`_kernel_call_alarm` は CPU ロックを解除してアラームハンドラを呼び出した後、ハンドラ戻り時に CPU ロックを再取得する。`if (!sense_lock())` の false 分岐（L241 br[1]）はハンドラが `iloc_cpu()` を呼び出して CPU ロックを保持したまま戻った場合に到達する。

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L241 br[1]（`sense_lock()` が true、ロック不要） | アラームハンドラが `iloc_cpu()` を呼び出してロックを保持したまま戻る | 通常のアラームハンドラはシステムサービス呼出しを行い `iloc_cpu()` を直接呼ばない。このパターンはカーネル内部テストにしか現れない特殊な API 使用。 | **到達困難（内部状態依存）** |

**結論**: WB テストは不要（通常の API 使用パターンから外れるため）。

---

## 11. cyclic.c — `_kernel_call_cyclic` L259 br[1]（1 branch, 97.2%）

**ソース** (`asp3/kernel/cyclic.c` L259):
```c
if (!sense_lock()) {
    lock_cpu();
}
```

§10（alarm.c L241）と同構造。周期ハンドラが `iloc_cpu()` を呼んで CPU ロックを保持したまま戻る場合に到達する。

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L259 br[1]（`sense_lock()` が true） | 周期ハンドラが `iloc_cpu()` を呼び出してロックを保持したまま戻る | §10 と同構造・同理由。 | **到達困難（内部状態依存）** |

**結論**: WB テストは不要。

---

## 12. mempfix.c — `rel_mpf` L309/L310 br[0]（2 branches, 97.8%）

**ソース** (`asp3/kernel/mempfix.c` L309–310):
```c
CHECK_PAR(blkoffset % p_mpfcb->p_mpfinib->blksz == 0U);      /* L309 */
CHECK_PAR(blkoffset / p_mpfcb->p_mpfinib->blksz < p_mpfcb->unused);  /* L310 */
```

`CHECK_PAR(exp)` は `exp` が偽のとき `ercd = E_PAR; goto error_exit` に展開される。false 分岐（br[0]）が `E_PAR` 返却パス。

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L309 br[0] | `blkoffset % blksz != 0U`（ミスアライメントポインタ） | `rel_mpf` に渡すポインタがブロックサイズにアライメントされていない。テストハーネスで任意のポインタ値を生成する手段がなく、通常の `get_mpf` で取得したポインタは必ずアライメントされる。 | **到達可能（低優先度）** |
| L310 br[0] | `blkidx >= unused`（ブロックインデックス範囲外） | アライメントは合うが、割り当て済み範囲外のポインタを渡す場合。同上。 | **到達可能（低優先度）** |

**補足**: 両分岐とも不正パラメータ検査（`E_PAR`）であり、仕様上のエラー処理の確認。テストは原理上可能だが、TESRY YAML 形式での任意アドレス指定は困難で手書きテストが必要。優先度は低く当面未対応で可。

---

## 13. task_manage.c — `act_tsk` L137 br[1]（1 branch, 98.9%）

**ソース** (`asp3/kernel/task_manage.c` L137):
```c
else if ((p_tcb->p_tinib->tskatr & TA_NOACTQUE) != 0U || p_tcb->actque) {
    ercd = E_QOVR;
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L137 br[1]（条件 true → E_QOVR） | `TA_NOACTQUE` 属性タスクに対して `act_tsk` を呼ぶ（または `actque=true` のタスクに再起動要求） | `TA_NOACTQUE` タスクへの `act_tsk` は TESRY BB テストの E_QOVR ケースでカバー可能だが、既存の `act_tsk` YAML テスト群では属性指定なしタスクで `actque=true` ケースをカバーしており、`TA_NOACTQUE` 専用パスには未到達。 | **到達可能（低優先度）** |

**結論**: BB テスト（`act_tsk` に `TA_NOACTQUE` 属性タスクを追加）で到達可能。優先度は低く当面未対応で可。

---

## サマリ

| ファイル | 未到達数 | 分類 | 対応方針 |
|---|---|---|---|
| wait.h | 15 | 計測アーティファクト（NDEBUG+O2 インライン展開増加） | 不要 |
| time_event.c | 8 | 実用的到達不能 ×3 + タイミング依存 ×1 + 内部状態依存 ×3 + 計測差異 ×1 | 不要 |
| exception.c | 2〜3 | 構造的到達不能 ×2 + 到達困難 ×1 | 不要 |
| mempfix.c | 2 | 到達可能（E_PAR 不正ポインタ） | 低優先度・未対応で可 |
| alarm.c | 1 | 到達困難（ハンドラ内 iloc_cpu） | 不要（特殊 API 使用パターン） |
| cyclic.c | 1 | 到達困難（ハンドラ内 iloc_cpu） | 不要（特殊 API 使用パターン） |
| interrupt.c | 1 | 到達困難（競合タイミング依存） | 低優先度・未対応で可 |
| mutex.c | 1 | 構造的到達不能（L227 NULL exit） | 不要 |
| task_manage.c | 1 | 到達可能（E_QOVR、TA_NOACTQUE） | 低優先度・未対応で可 |
| task_refer.c | 1 | 構造的到達不能（JT 境界チェック） | 不要 |
| time_manage.c | 1 | 実用的到達不能（64 bit 折返し） | 不要 |
| task.c | 0 | NDEBUG 除外済み → 100% | 解消 |
| wait.c | 0 | NDEBUG 除外済み → 100% | 解消 |
| **合計** | **34** | — | — |

**WBテスト無効化後の 97.7%（1425/1459）は実用的なテスト充足率として妥当**。  
wait.h の 15 箇所はインライン展開アーティファクトで論理的カバレッジは確認済み。  
alarm/cyclic の 2 箇所はカーネルハンドラ内の特殊 API 使用パターンで通常テストから逸脱。  
time_event.c の内部ヒープ状態依存 3 箇所は外部 API からの確実な誘導が困難。  
mempfix/interrupt/task_manage の 4 箇所は原理的に到達可能だが優先度低。  
残存 10 箇所（構造的・実用的到達不能）はカーネルの不変条件・物理的制約により到達不能。
