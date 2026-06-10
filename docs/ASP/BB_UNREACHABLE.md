# BB_UNREACHABLE.md — ASP3 kernel/ BBテスト未到達分岐の分析とWBテスト対応

> 更新: 2026-06-10
> 対象: ASP3 3.7.2 `kernel/`
> 方式: gcov（`bash scripts/coverage_gcov_asp.sh all` / `bb`）

このファイルは **BBテスト（自動生成）で到達できない分岐** の顛末を記録する。
- **第1部**: BBの穴を手書き WBテスト（方式2）で到達させたもの — テスト内容と到達手法（`bb`→`all` で +9 分岐）
- **第2部**: WBテストを加えてもなお到達しない分岐 — 到達不能理由と分類（残存 10 分岐, `all` 1369/1379 = 99.3%）

関連:
- BBテストのみのカバレッジ（ファイル別） → [`BB_COVERAGE.md`](BB_COVERAGE.md)
- BBテスト + WBテスト統合の最終カバレッジ・per-API・BBテスト追加履歴 → [`ALL_COVERAGE.md`](ALL_COVERAGE.md)

**計測条件（コンパイルオプション）:**
- `ENABLE_GCOV=true` — gcov 計装ビルド（`-fprofile-arcs -ftest-coverage`）
- `-DNDEBUG`（`COPTS` 経由） — `assert()` を `((void)(0))` に展開し分岐ノードを消滅させる（assert 失敗パスは仕様適合性の分岐ではないため）
- **`-O2` + インライン抑制**（`-fno-inline -fno-inline-functions-called-once -fno-inline-small-functions`） — `-O2` の `static inline`（`Inline` マクロ）展開による gcov 分岐水増しアーティファクト（wait.h 16→64 等）を除去するため、`-O2` を維持したまま inline のみ抑制する。各 inline 関数を1実体として計測し、論理分岐がそのまま反映され bb/all の分母も一致する（理由詳細は [`BB_COVERAGE.md`](BB_COVERAGE.md) 計測条件）。これにより旧版の「wait.h アーティファクト（第2部 §5）」は解消（現 14/14 = 100%）。

**分類凡例:**
- **構造的到達不能**: カーネルの不変条件（恒真 flag、整合性保証ポインタ等）により実行時に到達できない。
- **実用的到達不能**: 理論上は可能だが QEMU では非現実的な前提（64 bit カウンタ折返し、数千秒タイマ等）が必要。
- **到達困難（制約あり）**: 理論的には到達可能だが、複数条件が同時成立する必要があり、コストに対して価値が低い。
- **到達困難（内部状態依存）**: 外部 API 操作では再現が難しい内部データ構造・状態が必要。
- **計測アーティファクト**: コンパイラの最適化（インライン展開）により同一ソース行が複数 call-site インスタンスとして追跡され、一部インスタンスが未到達になるもの。論理的カバレッジは確認済み。

---

# 第1部 — BBの穴を WBテストで到達（方式2: 手書き）

> BBテスト（`bb` モード、1360/1379 = 98.6%）では到達できない分岐を、ソースを直接読んで設計した手書き WBテストで補う。WBテストを加えた `all` モードは 1369/1379 = 99.3%（`chg_ipm_f` BB追加後）。
> 各分岐について「分岐の意味」「`bb` で未到達となる理由」「WBテストの到達手法」を示す。**WBテストの妥当性**（分岐の意味を正しく検証しているか等）は、これをもとに人間が確認する。
>
> ※ 計測は `-O2` + インライン抑制。`bb`/`all` で分母 1379 が一致する（旧 -O2 のインライン展開差による分母変動は解消）。

## WBテストによるカバレッジ寄与サマリ

WBテスト（方式2）は `bb` → `all` で **+9 分岐**（alarm/cyclic/exception 各 +1、mempfix +2、time_event +4）を追加する。

> `task_manage.c` L137 br[1]（`TA_NOACTQUE` → E_QOVR）は 2026-06-10 に BBテスト `act_tsk_c-3`（YAML 自動生成）が追加され、`bb` モードでも到達済みとなった。WBテスト `act_tsk_W-a` は削除し、本表から除外した。

| ファイル | `bb` 分岐 | `all` 分岐 | 増分 | WBテスト |
|---|---|---|---|---|
| alarm.c | 31/32 | 32/32 | +1 | `alarm_W-a` |
| cyclic.c | 35/36 | 36/36 | +1 | `cyclic_W-a` |
| exception.c | 6/8 | 7/8 | +1 | `xsns_dpn_W-a` |
| mempfix.c | 86/88 | 88/88 | +2 | `rel_mpf_W-a` / `rel_mpf_W-b` |
| time_event.c | 48/56 | 52/56 | +4 | `time_event_W-a`（複合条件×2 + 早期break）/ `time_event_W-b`（go-up） |
| **合計** | **1360/1379 (98.6%)** | **1369/1379 (99.3%)** | **+9** | — |

> ※ `bb` 合計 1360・`all` 合計 1369 は `chg_ipm_f.yaml`（BB, +1）追加後の値。WB 寄与 +9 は不変（chg_ipm とは独立）。

> ※ インライン抑制計測のため分岐番号は旧 -O2 と異なる（例: exception.c は 6→8 分岐、mempfix.c は 90→88 分岐）。以降の各節の行番号・branch 番号は論理分岐の意味を示すもので、gcov 上の番号と一致しない場合がある。

> 補足: `adj_tim_W-a.yaml`（`api_test/ASP/time_manage/adj_tim/`）はホワイトボックス意図のテストだが **方式1（YAML 自動生成）** であり、`bb` モードに統合済み（check_adjtim L533 br[1] を到達済み）。本ファイルの方式2集計には含めない。

## WBテストカタログ（方式2: 手書き）

内部カーネル機能（APIではない）を対象とするテストは `wb_test/ASP/` に分類し、特定APIのパラメータ検査を対象とするテストは `api_test/ASP/<API>/` 内に残す。

| WBテスト | 対象分岐 | 内容 | 配置 |
|---|---|---|---|
| `alarm_W-a` | alarm.c L241 br[1] | 通知ハンドラが `iloc_cpu()` を保持して戻る → `lock_cpu()` スキップ | [out.c](../../wb_test/ASP/alarm/alarm_W-a/out.c) |
| `cyclic_W-a` | cyclic.c L259 br[1] | 周期ハンドラが `iloc_cpu()` を保持して戻る → `lock_cpu()` スキップ | [out.c](../../wb_test/ASP/cyclic/cyclic_W-a/out.c) |
| `xsns_dpn_W-a` | exception.c L102 br[1] | `ATT_INI` 初期化ルーチンから `xsns_dpn(NULL)` を呼び出す → `kerflg==false` で短絡評価 → `state=true` | [out.c](../../wb_test/ASP/exception/xsns_dpn_W-a/out.c) |
| `rel_mpf_W-a` | mempfix.c L309 br[0] | `rel_mpf`: ミスアライメントポインタ → `E_PAR` | [out.c](../../api_test/ASP/mempfix/rel_mpf/rel_mpf_W-a/out.c) |
| `rel_mpf_W-b` | mempfix.c L310 br[0] | `rel_mpf`: blkidx 範囲外 → `E_PAR` | [out.c](../../api_test/ASP/mempfix/rel_mpf/rel_mpf_W-b/out.c) |
| `time_event_W-a` | time_event.c L221 / L231 | `tmevt_down`: 右子ノードなし + 早期 break（heap sift-down） | [out.c](../../wb_test/ASP/time_event/time_event_W-a/out.c) |
| `time_event_W-b` | time_event.c L302 br[0] | `tmevtb_delete`: go-up パス（last < parent） | [out.c](../../wb_test/ASP/time_event/time_event_W-b/out.c) |

---

## 1-1. alarm.c — `_kernel_call_alarm` L241 br[1]

**ソース** (`asp3/kernel/alarm.c` L235–243):
```c
unlock_cpu();                                                         /* L235 */
(*(p_almcb->p_alminib->nfyhdr))(p_almcb->p_alminib->exinf);          /* L238: ハンドラ呼出し */
if (!sense_lock()) {                                                  /* L241 */
    lock_cpu();
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L241 br[1]（`sense_lock() == true`） | ハンドラが CPU ロック（`iloc_cpu()`）を保持したまま戻る → `lock_cpu()` はスキップ | `call_alarm` はハンドラを `unlock_cpu()` 後に呼び出し、戻り後に `sense_lock()` で CPU ロック状態を確認する。BB テストのハンドラは CPU ロックを操作せず、戻り時は常にロック解除状態（`sense_lock() == false`）になる。`iloc_cpu()` を保持して戻るシナリオは自動生成テストでは生成されない。 |

**WBテスト** [`alarm_W-a`](../../wb_test/ASP/alarm/alarm_W-a/out.c): アラーム通知ハンドラ内で `iloc_cpu()` を呼び出し、CPU ロックを保持したまま戻ることで L241 br[1] を到達させる。

---

## 1-2. cyclic.c — `_kernel_call_cyclic` L259 br[1]

**ソース** (`asp3/kernel/cyclic.c` L253–261):
```c
unlock_cpu();                                                         /* L253 */
(*(p_cyccb->p_cycinib->nfyhdr))(p_cyccb->p_cycinib->exinf);          /* L256: ハンドラ呼出し */
if (!sense_lock()) {                                                  /* L259 */
    lock_cpu();
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L259 br[1]（`sense_lock() == true`） | 周期ハンドラが CPU ロックを保持したまま戻る | §1-1（alarm.c L241）と同構造。`call_cyclic` も同一パターンで実装されており、BB テストでは非網羅。 |

**WBテスト** [`cyclic_W-a`](../../wb_test/ASP/cyclic/cyclic_W-a/out.c): 周期通知ハンドラ内で `iloc_cpu()` を呼び出し、CPU ロックを保持したまま戻ることで L259 br[1] を到達させる。

---

## 1-3. mempfix.c — `rel_mpf` L309 / L310 br[0]

**ソース** (`asp3/kernel/mempfix.c` L307–311):
```c
CHECK_PAR(p_mpfcb->p_mpfinib->mpf <= blk);                                    /* L307 */
blkoffset = ((char *) blk) - (char *)(p_mpfcb->p_mpfinib->mpf);               /* L308 */
CHECK_PAR(blkoffset % p_mpfcb->p_mpfinib->blksz == 0U);                       /* L309 */
CHECK_PAR(blkoffset / p_mpfcb->p_mpfinib->blksz < p_mpfcb->unused);           /* L310 */
blkidx = (uint_t)(blkoffset / p_mpfcb->p_mpfinib->blksz);                     /* L311 */
```

`CHECK_PAR(cond)` は `cond` が偽のとき `E_PAR` を返す。L309 br[0] / L310 br[0] は各 CHECK_PAR の「偽（エラー）」分岐。

### 1-3-a. L309 br[0]（ミスアライメントポインタ → E_PAR）

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L309 br[0]（`blkoffset % blksz != 0U` → E_PAR） | `rel_mpf` に渡すポインタがブロックサイズに整合しない | BB テストは常に `get_mpf` で取得したポインタを `rel_mpf` に渡す。`get_mpf` はブロックサイズ境界に整合したポインタのみ返すため、ミスアライメントポインタは自動生成テストでは発生しない。 |

**WBテスト** [`rel_mpf_W-a`](../../api_test/ASP/mempfix/rel_mpf/rel_mpf_W-a/out.c): `pget_mpf` で取得したブロックポインタにオフセットを加えたミスアライメントポインタを `rel_mpf` に渡し、`E_PAR` が返ることを確認。

### 1-3-b. L310 br[0]（ブロックオフセット範囲外 → E_PAR）

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L310 br[0]（`blkidx >= p_mpfcb->unused` → E_PAR） | `blkoffset / blksz` で得られる index が割当て済みブロック数を超過 | BB テストは正規ポインタのみ使用。プール管理領域外（`unused` を超えた index に対応する）アドレスを渡すケースは自動生成テストでは発生しない。 |

**WBテスト** [`rel_mpf_W-b`](../../api_test/ASP/mempfix/rel_mpf/rel_mpf_W-b/out.c): 2回の `pget_mpf` 後に `unused=2` の状態で `blkidx=2` になるアドレスを `rel_mpf` に渡し、`E_PAR` が返ることを確認。

---

## 1-4. time_event.c — `tmevt_down` L221 / L231（`time_event_W-a`）

**ソース** (`asp3/kernel/time_event.c` L215–228):
```c
while ((child = LCHILD(index)) <= LAST_INDEX()) {             /* L215: 左子あり */
    if (child + 1 <= LAST_INDEX()                             /* L221: 右子の有無 + 早い方の選択 */
            && EVTTIM_LT(HEAP_NODE(child + 1)->evttim,
                                    HEAP_NODE(child)->evttim)) {
        child = child + 1;
    }
    if (EVTTIM_LE(evttim, HEAP_NODE(child)->evttim)) {        /* L231: break 判定 */
        break;
    }
    HEAP_NODE(index) = HEAP_NODE(child);
    HEAP_NODE(index)->index = index;
    index = child;
}
```

L221 は `child + 1 <= LAST_INDEX()`（右子の有無）と `EVTTIM_LT(...)`（左右どちらが早いか）の複合条件で、gcov 上は 2 分岐に展開される。

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L221（`child + 1 > LAST_INDEX()`） | 現レベルに左の子しか存在しない（右子ノードがヒープ末尾を超える） | BB テストのタイムイベント登録・削除パターンでは、`tmevt_down` が呼ばれる時点でヒープが常に当該レベルに右子を持つ形になる。「左子のみ」状態は特定の登録順序・数でのみ発生し、自動生成テストでは生成されない。 |
| L231 br[0]（`EVTTIM_LE(evttim, child->evttim)` が真 → break） | 挿入ノードの発生時刻が選択した子ノード以前 → 現在の `index` が挿入位置 | BB テストのパターンでは sift-down が末尾まで進むか 1 段のみで終わるため「中間で止まる」ケースが生じない。 |

**WBテスト** [`time_event_W-a`](../../wb_test/ASP/time_event/time_event_W-a/out.c): 複数タイムイベントを特定の順序で登録・期限切れさせ、sift-down 時に右子が存在しないヒープ形状を手書きで構築。さらに挿入ノードが左子より早い発生時刻になるよう配置し、L221（右子なし）・L231（早期 break）を同一テスト実行で同時にカバー。

---

## 1-5. exception.c — `xsns_dpn` L102 br[1]（`xsns_dpn_W-a`）

**ソース** (`asp3/kernel/exception.c` L101–102):
```c
state = (kerflg && exc_sense_intmask(p_excinf) && enadsp
                        && p_runtsk != NULL) ? false : true;
```

`&&` の短絡評価による 6 分岐のうち、BB テストで 4/6 をカバー済み。残 2 分岐のうち 1 分岐を `xsns_dpn_W-a` でカバーする（残 1 分岐は第2部 §1）。

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L102 br[1]（`-O2` 最適化後の短絡評価分岐） | `kerflg == false` → 短絡評価で `state=true` | `kerflg` はカーネルスケジューラ起動後（`startup.c` L125）に `true` にセットされる。BB テストのシナリオはすべてカーネル起動後であるため `kerflg==false` のパスは自動生成テストでは到達不能。 |

> **gcov 分岐番号について**: `-O2` 最適化により、`kerflg=false` の短絡評価パスは `exception.c` の L101 ではなく L102 の分岐 br[1] として計装される。これは GCC が複合条件式を最適化した結果であり、実行パスとしては `xsns_dpn_W-a` が `kerflg=false` をカバーしていることに変わりはない。

**WBテスト** [`xsns_dpn_W-a`](../../wb_test/ASP/exception/xsns_dpn_W-a/out.c): `ATT_INI` で登録した初期化ルーチン `xsns_dpn_W_a_init()` から `xsns_dpn(NULL)` を呼び出す。`startup.c` では初期化ルーチン呼出し（L112-113）が `kerflg=true`（L125）より前に行われるため、呼び出し時点で `kerflg==false`。短絡評価により `state=true` が返ることを初期化ルーチン内で `init_result` に保存し、後で `main_task` が `check_value` で検証する。

---

## 1-6. time_event.c — `tmevtb_delete` L302 br[0]（`time_event_W-b`）

**ソース** (`asp3/kernel/time_event.c` L298–320):
```c
event_evttim = HEAP_NODE(last_index)->evttim;
if (index > ROOT_INDEX                                         /* L300 */
        && EVTTIM_LT(event_evttim,                             /* L302 */
                    HEAP_NODE(parent = PARENT(index))->evttim)) {
    /* 最後尾ノードが削除位置の親より前 → 上方向に挿入位置を探す */
    HEAP_NODE(index) = HEAP_NODE(parent);
    HEAP_NODE(index)->index = index;
    index = tmevt_up(parent, event_evttim);
}
else {
    index = tmevt_down(index, event_evttim);  /* go-down */
}
```

| gcov 位置 | 条件 | BBテストで未到達の理由 |
|---|---|---|
| L302 br[0]（go-up 条件が真） | 削除ノードを最後尾ノードで置き換えた際、最後尾ノードの発生時刻が削除位置の親ノードより前 → ヒープ性質を回復するため上方向に移動 | BB テストの削除パターンでは、最後尾ノードが削除位置の親より後の時刻になるため常に go-down パスを通る。go-up が発生するには削除対象が「ヒープ下部の大きい値を持つノード」かつ最後尾が「比較的早い時刻」という特定の配置が必要。 |

**WBテスト** [`time_event_W-b`](../../wb_test/ASP/time_event/time_event_W-b/out.c): ヒープ中間ノードの削除時に最後尾ノードの発生時刻が削除位置の親ノードより早くなるよう、複数タイムイベントの発生時刻と削除順序を手書きで設計。

---

# 第2部 — WBテストでも到達しない残存分岐

> `all` モード（BBテスト + WBテスト）での残存 10 分岐の詳細分析。到達不能理由・分類を示す。
> （旧 -O2 計測の wait.h/wait.c/task.c インライン展開アーティファクトはインライン抑制で解消したため本部から除外。）

## 1. exception.c — `xsns_dpn`（1 branch, 87.5%）

**ソース** (`asp3/kernel/exception.c` L101–102):
```c
state = (kerflg && exc_sense_intmask(p_excinf) && enadsp
                        && p_runtsk != NULL) ? false : true;
```

`&&` の短絡評価により GCC（`-O2`）は 6 分岐を生成する。BB テストで 4/6、WBテスト `xsns_dpn_W-a` で +1 = 5/6 をカバー済み。

**カバレッジ済みシナリオ一覧** (4 + 1 = 5 分岐):

| シナリオ | 条件 | カバー手段 |
|---|---|---|
| 通常実行中 | kerflg=T, exc_sense_intmask=T, enadsp=T, p_runtsk≠NULL → state=false | BB テスト（多数） |
| 割込みコンテキスト/CPUロック例外 | exc_sense_intmask=F → state=true | BB テスト（check_library/exception 等） |
| `dis_dsp()` 後の例外 | enadsp=F → state=true | BB テスト `xsns_dpn_b-4.yaml` |
| — | 上記シナリオの対 分岐（複数通過） | BB テスト（union） |
| 初期化ルーチン中 | kerflg=F → state=true（短絡評価） | WBテスト `xsns_dpn_W-a` |

**残存未到達（1 分岐）:**

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L102 br[2] | `p_runtsk == NULL` → state=true | アイドルループ中（全タスクが休眠または待ち）に CPU 例外が発生した場合のパス。テスト実行中は常に MAIN_TASK が `running` 状態にあるため `p_runtsk != NULL`。この状態を作るには全タスクを待ち状態にした上でアイドルループ中に CPU 例外を発火させる必要があるが、zybo_z7_gcc / QEMU 環境では例外を任意タイミングで起動する機構がなく再現不可能。 | **構造的到達不能**（テスト文脈） |

> **gcov 分岐番号について**: `-O2` では複合条件のコンパイル順序が最適化により変化し、各条件と gcov の branch 番号の対応がソース上の位置と一致しない場合がある。上表の L102 br[2] は、BB テスト（4 分岐カバー）+ xsns_dpn_W-a（kerflg=F カバー）を加えた後に唯一残る未到達分岐を指す。到達させるための残条件として `p_runtsk==NULL` 以外のシナリオは全て BB または xsns_dpn_W-a で消化済みであることを論理的に確認済み。

**結論**: 残 1 分岐は WB テスト追加不要。

---

## 2. mutex.c — `remove_mutex` L227 br[1]（1 branch, 99.3%）

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

---

## 3. task_refer.c — `ref_tsk` L131 br[10]（1 branch, 97.1%）

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

**switch JT 無効化オプション（`-fno-jump-tables`）の検討**: `-fno-jump-tables` で switch を比較連鎖に変換すれば JT 境界チェック分岐は消えるが、**採用しない**。理由:
- 全 switch に効く大域フラグで（関数単位指定はカーネル編集＝禁則②）、他関数の switch（dataqueue 等）の分岐数も総ずれする
- production は JT を使うため実バイナリから乖離する
- 比較連鎖でも末尾 default/else が残り、未到達が消えず移動するだけの可能性
- インライン抑制（隠れた論理カバレッジの顕在化）と異なり、これは到達不能な安全チェックを分母から消すだけの cosmetic な操作

**結論**: コンパイラ挿入の安全チェックであり **構造的到達不能**。WB テスト・コンパイルオプション変更ともに不要。

---

## 4. time_manage.c — `adj_tim` L168 br[0]（1 branch, 95.5%）

**ソース** (`asp3/kernel/time_manage.c` L168):
```c
if (current_evttim < monotonic_evttim) {
```

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L168 br[0] | 64 bit `EVTTIM` 折返し後に `current_evttim < monotonic_evttim` | `EVTTIM` は uint64_t。折返しには約 5.85 × 10¹¹ 年の連続動作が必要。QEMU テストでは不可能。 | **実用的到達不能** |

**結論**: WB テストは不要。

---

## 5. interrupt.c — `clr_int` / `ras_int`（2 branches, 96.8%）

> 旧版 §5（wait.h インライン展開アーティファクト 15 分岐）は **インライン抑制で解消**（wait.h 14/14 = 100%）したため削除。
> インライン抑制により `clr_int`/`ras_int` の実分岐が顕在化し、interrupt.c の未到達が 1→3 に増えた（旧 -O2 ではインライン併合で `clr_int`/`ras_int` が 8/8 と見えていた）。その後 `chg_ipm` の 1 分岐は **`chg_ipm_f.yaml`（BB）で到達済み**となり、残存は `clr_int`/`ras_int` の 2 分岐。

各未到達分岐の正体を特定した（`ena_int` は `check_intno_cfg` 1条件のみで 100%、`clr_int`/`ras_int` は `&& check_intno_clear/raise` の**第2条件**が追加されている点が差）。

| 関数 | 未到達分岐 | 未到達理由 | 分類 |
|---|---|---|---|
| `clr_int` | `check_intno_clear(intno)` が偽 → `E_OBJ` | zybo（GIC）の [`gic_kernel_impl.h`](../../../asp3/arch/arm_gcc/common/gic_kernel_impl.h) で `check_intno_clear` は **`return(true)` 恒真**。「configured だが clear 不可な割込み」が存在せず false 分岐に到達できない（カーネル編集なしには不可＝禁則②）| **構造的到達不能（ターゲット依存: GIC 恒真）** |
| `ras_int` | `check_intno_raise(intno)` が偽 → `E_OBJ` | 同上（`check_intno_raise` も `return(true)` 恒真）| **構造的到達不能（ターゲット依存: GIC 恒真）** |

> **`chg_ipm` は到達済み**: `if (p_runtsk->raster && p_runtsk->enater)` 真（自タスク終了）パスは **`chg_ipm_f.yaml`（BB・方式1、2026-06-10 追加）で到達**（chg_ipm 13/14→14/14、All check points passed で検証済み）。手順は `ena_dsp_b-4.yaml` と同型（dister+raster → chg_ipm(マスク) → ena_ter → chg_ipm(TIPM_ENAALL) で自終了）。

**結論**:
- `clr_int`/`ras_int`: zybo（GIC）では `check_intno_clear`/`check_intno_raise` が恒真のため**構造的到達不能**。非クリア/非要求可能な割込みを持つ別ターゲットでのみ到達可（BB/WB ともに zybo では不可）。
- `chg_ipm`: **解消済み**（`chg_ipm_f.yaml`）。

---

## 6. time_event.c — 内部タイムイベント管理（4 branches, 92.9%）

### 7-a. `_kernel_update_current_evttim` L390 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L390 br[0]（`current_evttim < monotonic_evttim`） | 64 bit EVTTIM 折返し後の単調増加保証パス | §4 と同構造。約 5.8 × 10¹¹ 年の連続動作が必要。 | **実用的到達不能** |

### 7-b. `_kernel_set_hrt_event` L439 br[0]

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L439 br[0]（`hrtcnt > HRTCNT_BOUND`） | 次タイムイベントまで HRTCNT_BOUND（≈ 4,000 秒）超の待ち | QEMU テストの時間スケールでは発生しない。 | **実用的到達不能** |

### 7-c. `_kernel_signal_time` L624 br（`nocall == 0`）

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| L624 br[0]（`nocall == 0`） | HRT 割込みが発生したが期限切れイベントが 0 件 | spurious interrupt / early fire が必要。QEMU の cycle-accurate モデルでは再現困難。 | **実用的到達不能**（タイミング依存） |

### 7-d. `_kernel_tmevt_down`（内部状態依存 ×1）

| gcov 位置 | 条件 | 未到達理由 | 分類 |
|---|---|---|---|
| sift-down 内部分岐 ×1 | 特定のヒープ配置でのみ通る経路 | `tmevt_down` の L221/L231 周辺は WBテスト [`time_event_W-a`](../../wb_test/ASP/time_event/time_event_W-a/out.c) で大半を到達済み（本ファイル第1部 §1-4）だが、残 1 分岐は更に特定のヒープ深さ・配置を要し、外部 API 操作での再現が難しい。 | **到達困難（内部状態依存）** |

**結論（time_event.c 全体）**: 残 4 未到達分岐はすべて WB テスト追加不要（実用的到達不能 ×3 + 内部状態依存 ×1）。

---

## サマリ（残存 10 未到達分岐、`all` モード: 1369/1379 = 99.3%、-O2+インライン抑制）

| ファイル | 未到達数 | 分類 | 対応方針 |
|---|---|---|---|
| time_event.c | 4 | 実用的到達不能 ×3（64bit折返し/HRTCNT_BOUND/nocall）+ 内部状態依存 ×1 | 不要 |
| interrupt.c | 2 | 構造的到達不能（`clr_int`/`ras_int`: GIC で check_intno_clear/raise 恒真） | 不要（zybo） |
| exception.c | 1 | 構造的到達不能（`p_runtsk==NULL` テスト文脈） | 不要 |
| mutex.c | 1 | 構造的到達不能（`remove_mutex` NULL exit） | 不要 |
| task_refer.c | 1 | 構造的到達不能（switch JT 境界チェック） | 不要 |
| time_manage.c | 1 | 実用的到達不能（64 bit 折返し） | 不要 |
| **合計** | **10** | — | 全て WB/追加 BB テスト不要と判断 |

> 旧 -O2 計測で残存に計上していた wait.h(15)/wait.c(2)/task.c(4) のインライン展開アーティファクトは、インライン抑制（`-fno-inline` 系）で解消（各 100%）。`bb`/`all` の分母も 1379 で一致する。
> `chg_ipm` の raster&&enater 自終了分岐は `chg_ipm_f.yaml`（BB）で到達し、11→10 に減少。

**現状の 99.3%（1369/1379、`all` モード）はテスト充足率として十分。**  
残存 10 箇所は、カーネルの不変条件・物理的制約・タイミング依存性により到達不能または到達困難であり、テストを追加しても仕様適合性の確認にはならない。
