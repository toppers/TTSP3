# SIL_TEST.md — SILテストの第3世代カーネル対応

> TTSP（旧世代・`ttsp_1.1.3`）の SILテストを **第3世代カーネル（ASP3 3.7.2 等）向けに移植**する記録と手順。
> 背景の比較検討は §1、ASP 移植の実装は §2、検証手順は §3、他プロファイル展開は §4。
> 規約は [`AGENTS.md`](../AGENTS.md)、合否は [`docs/STATUS.md`](STATUS.md)。

---

## 1. 背景：TTSP 1.1.3 と TTSP3 の差分（検討結果 2026-06-14）

`ttsp_1.1.3`（ASP/FMP・旧世代）と TTSP3（ASP3/FMP3/HRP3/HRMP3・3rd gen）を比較した結論：

| 観点 | 結論 |
|---|---|
| api_test / TTG | **TTSP3 が上位互換**（yaml 8,364 vs 4,259、ttg 115 vs 98 rb）。取り込み不要 |
| 1.1.3 固有 `mailbox`・`task_except` | **3rd gen で API 廃止**（`asp3/kernel/` に mbx/tex 無し）。取り込み不可 |
| **SILテスト** | TTSP3 では **未整備**（`sil_test/` は空・`scripts/sil_test.sh` の足場のみ残存）。**唯一の実質的な欠落** → 本書で着手 |
| カーネルライブラリ | TTSP3 未整備（`scripts/kernel_lib.sh` の足場のみ）。当面 defer |

> SILテストは [`AGENTS.md`](../AGENTS.md) §4 が「TTSP3 R3.1.0 未サポート」と明記する機能。1.1.3 の `sil_test/`
> は生成済み `out.{c,cfg,h}` のサンプルのみ（TTG 生成ルールは無い）。本書はそれを 3rd gen 向けに移植する。

### SILテストが検証する内容
1.1.3 `sil_test/ASP/out.c` は SIL（System Interface Layer）の以下を各実行文脈から検証する：
- 割込みロック：`SIL_LOC_INT`/`SIL_UNL_INT`/`SIL_PRE_LOC`
- メモリ空間アクセス：`sil_re/wr[bhw]_mem`（+ `_lem`/`_bem` エンディアン指定）、`SIL_ENDIAN_*`
- 微小待ち：`sil_dly_nse`
- カーネル状態参照：`sns_ker`

実行文脈：TASK / タスク例外 / ALARM / CYCLIC / CPU例外 / 割込みハンドラ / ISR。

---

## 2. ASP3 3.7.2 + zybo_z7_gcc への移植（実装済み・緑）

`sil_test/ASP/{out.c,out.h,out.cfg}`（UTF-8・改変明記済み）。**全チェックポイント緑**（§3）。
SIL マクロ本体は ASP3 3.7.2 `include/sil.h` に全て存在し名称変更は不要。差分は文脈側にあった：

| 改変 | 旧（1.1.3／2nd gen） | 新（3rd gen ASP3 3.7.2） | 理由 |
|---|---|---|---|
| タスク例外文脈 | `DEF_TEX`/`ena_tex`/`ras_tex`/`dis_tex`/`texhdr` | 削除（CP3/CP4 はプレースホルダ化） | 3rd gen にタスク例外機能なし |
| タイムイベント通知書式 | `CRE_ALM(ALM,{TA_NULL,0,almhdr})` | `CRE_ALM(ALM,{TA_NULL,{TNFY_HANDLER,0,almhdr}})` | 3.7 で通知方法ディスクリプタ入れ子化 |
| 同上（周期） | `CRE_CYC(CYC,{TA_NULL,0,cychdr,3,3})` | `CRE_CYC(CYC,{TA_NULL,{TNFY_HANDLER,0,cychdr},100000,100000})` | 通知書式＋下記 RELTIM 単位 |
| 周期の時間値 | `cyctim=3` | `cyctim=100000`（100ms） | 3.7 の RELTIM は **µs 単位**（`TSTEP_HRTCNT=1`）。3µs では重い周期ハンドラ（`sil_dly_nse(10ms)` 含む all_test）実行中に再発火し CP 順序が崩れる |
| 割込みハンドラ括り | `i_begin_int()`/`i_end_int()` | 削除 | 3rd gen の DEF_INH はカーネルが入口/出口処理（明示括り廃止） |
| ISR 文脈（ATT_ISR） | `ATT_ISR(...)` | 物理的に除去 | 標準 ASP3 zybo は DEF_INH モデルで ATT_ISR 非対応＋**cfg.rb は #ifdef を解釈しない**ため条件コンパイル不可（要物理除去） |
| include 規約 | `target_timer.cfg`/`syssvc/syslog.cfg`/`syssvc/serial.cfg` | `tecsgen.cfg`/`ttsp_target.cfg` | TTSP3 の API テスト生成cfg 規約に統一 |
| 文字コード | EUC-JP | UTF-8 | TTSP3 統一 |

> いずれも各ファイルに `【TTSP3向け改変 2026-06-14】` を明記（TTSPライセンス条件(2)）。
> ※ ATT_ISR の知見＝**cfg.rb の静的API抽出は `#ifdef`/`#if` を honor しない**（未定義ガードでも検出しエラー）。
> 条件付き除外は不可で、物理的にコメントアウト/削除する必要がある。

---

## 3. ビルド & 実行

### 正式ランナー（推奨）：`scripts/ci_run_sil.sh`
```bash
bash scripts/ci_run_sil.sh            # ASP/FMP/HRP/HRMP を順に build→QEMU→合否集計
bash scripts/ci_run_sil.sh HRP        # 個別プロファイル
```
内部で ttb.sh の SILメニュー（`2`→`1`）を非対話駆動し、`<obj>/sil_test/<kn>` を QEMU 実行（ASP/HRP=-smp 1、FMP/HRMP=-smp 2）、
`All check points passed.` を根拠に合否を集計（全緑で exit 0）。`.github/workflows/ci.yml` の ASP/FMP matrix にも統合済み。

### 手動レシピ（REF_MK 流用・参考・ASP/zybo）

`scripts/sil_test.sh` は TTG 生成ではなく `sil_test/<PROFILE>/*` を build dir にコピーしてビルドする方式
（ただし ttb.sh メニューでは TTSP3 で無効化されている）。下記は API テストの Makefile（REF_MK）を流用した
検証済み手順（要：一度 `bash scripts/coverage_gcov_asp.sh bb` 等で `obj_asp_gcov/api_test/auto_code_1/` を生成）：

```bash
export TTSP_TARGET_NAME=zybo_z7_gcc
KERNEL_COBJS_COMMON="objs/startup.o objs/task.o objs/wait.o objs/time_event.o objs/task_manage.o objs/task_refer.o objs/task_sync.o objs/task_term.o objs/taskhook.o objs/semaphore.o objs/eventflag.o objs/dataqueue.o objs/pridataq.o objs/mutex.o objs/mempfix.o objs/time_manage.o objs/cyclic.o objs/alarm.o objs/sys_manage.o objs/interrupt.o objs/exception.o"
APPL_COBJS_COMMON="objs/out.o objs/ttsp_test_lib.o objs/log_output.o objs/vasyslog.o objs/t_perror.o objs/strerror.o"
source library/ASP/target/zybo_z7_gcc/ttsp_target.sh   # KERNEL_COBJS_TARGET / APPL_COBJS_TARGET
REF_MK=obj_asp_gcov/api_test/auto_code_1/Makefile
dir=obj_asp_gcov/api_test/sil_asp; rm -rf "$dir"; mkdir -p "$dir/objs"
cp "$REF_MK" "$dir/Makefile"
cp sil_test/ASP/out.c sil_test/ASP/out.h sil_test/ASP/out.cfg library/ASP/test/out.cdl "$dir/"
( cd "$dir"
  make KERNEL_COBJS="$KERNEL_COBJS_COMMON $KERNEL_COBJS_TARGET" \
       APPL_COBJS="$APPL_COBJS_COMMON $APPL_COBJS_TARGET"
  timeout 120 qemu-system-arm -M xilinx-zynq-a9 -semihosting -m 512M \
       -serial null -serial mon:stdio -nographic -smp 1 -kernel asp < /dev/null > execute.log 2>&1 )
tail -3 "$dir/execute.log"   # → "All check points passed."
```

**検証結果（2026-06-14）**：`All check points passed.`（CP1〜22 全通過。TASK/ALARM/CYCLIC/CPU例外/割込みハンドラ
の各文脈で SIL メモリアクセス・割込みロック・sns_ker・sil_dly_nse を確認。タスク例外文脈は 3rd gen 非対応で
スキップ＝CP3/4 プレースホルダ）。

> §6 の注意（[`docs/RUNBOOK.md`](RUNBOOK.md)）：上記は `&&` チェーンを避け文を分離している（AI 環境の grep ラッパ対策は不要だがレシピの堅牢性のため）。

---

## 2b. FMP3 3.7 + zybo_z7_gcc への展開（実装済み・緑）

`sil_test/FMP/{out.c,out.h,out.cfg}`。**マルチプロセッサ SIL テスト**（`CLASS(CLS_PRCn)` で PE 別オブジェクト・
`ttsp_barrier_sync`・`ttsp_mp_check_point`・spinlock `SIL_LOC_INT_SPN`・`sil_get_pid`）を FMP3/zybo（**-smp 2**）で
**両 PE とも `All check points passed.`**（CP1-26 + barrier 8 phase）を確認。

ASP と同じ 3.4→3.7 改変（タスク例外・通知書式・RELTIM µs・i_begin_int・include）に加え、**FMP 固有**：

| 改変 | 旧（1.1.3） | 新（FMP3 3.7） | 理由 |
|---|---|---|---|
| クラス ID | `TCL_1_ONLY`/`TCL_2_ONLY`/… | `CLS_PRC1`/`CLS_PRC2`/…（TTSP3 FMP target 定義） | クラス命名が 3rd gen で変更 |
| システム時刻モード | `#ifdef TOPPERS_SYSTIM_LOCAL`/`GLOBAL` 分岐で ALM/CYC 生成 | **両マクロとも廃止**＝per-class で無条件生成（`CLASS(TCL_SYSTIM_PRC)` ブロックも削除） | FMP3 は LOCAL/GLOBAL systim 区別を持たない |
| ISR 文脈の無効化 | `#ifdef TTSP_INTNO_C` | `prc_info[].intno_c = TTSP_INVALID_INTNO`（実行時ガード `if(intno_c!=TTSP_INVALID_INTNO)` でスキップ） | ATT_ISR 非対応（out.c は #ifdef を gcc が解釈するので C 側ガードで可） |

> ※ ビルドは ASP と同型（REF_MK 流用＋`KERNEL_COBJS`/`APPL_COBJS` 指定）。FMP は `KERNEL_COBJS` に `spin_lock.o` を含め、
> QEMU は **-smp 2**。

## 2c. ユーザドメインからの SIL アクセステスト（HRP/HRMP・実装済み・緑）

保護カーネル（HRP/HRMP）に **ユーザドメイン(DOM1)タスク `sil_user_task`** を追加し、保護ドメイン下での SIL 発行挙動を検証。
- **HRP**：`DOMAIN(DOM1){ CRE_TSK(SIL_USER_TASK, ..&ttg_ustack[DOM1-1][0][0]..&ttg_sstack[0][0]); SAC_TSK(SHARED) }`。
  main_task（カーネルドメイン）が `act_tsk`→`slp_tsk` で起動・待機、ユーザタスクが check_of_sil_mem/sns_ker 後 `wup_tsk`（CP23-25）。
- **HRMP**：`CLASS(CLS_ALL_PRC1){ DOMAIN(DOM1){ CRE_TSK(SIL_USER_TASK, ..&ttg_ustack_prc1[DOM1-1][0][0]..&ttg_sstack_prc1[0][0]) } }`
  （per-PE スタック＋CLASS×DOMAIN ネスト）。マスタPE の main_task が起動・待機（CP23 を main 側で記録）。

**共通の構成要件**：out.h に `TTSP_STACK_SHARE_HRP`/`TTG_DOMAIN_NUM`/`TTG_STACK_NUM`、cfg に
`ATT_SEC(".ttg_stack_section…", …)`（無いと ttg_ustack が discard され未解決）。

**実測知見（ユーザドメインからの SIL 発行・HRP/HRMP zybo）：**
| SIL/操作 | ユーザドメインからの結果 | 正常系/異常系テスト |
|---|---|---|
| `sil_reb/wrb/reh/…_mem`（自タスクスタック対象） | **OK**（アクセス権のある領域なら発行可） | 正常系（check_of_sil_mem） |
| `SIL_LOC_INT`/`SIL_UNL_INT` | **OK** | 正常系（test_of_sns_ker 内） |
| `sns_ker` | **OK**（タスク文脈で false） | 正常系 |
| `get_tim`（SIL でなくサービス） | **E_OACV**（時刻管理サービスのアクセス保護） | **異常系・明示テスト（check_ercd(…, E_OACV)）** |
| `sil_dly_nse` | **Prefetch Abort（permission fault）**＝実装がカーネル専用テキスト＝DOM1 に実行権なし | 異常系（fault・知見記録） |
| `SIL_LOC_SPN`（SILスピンロック・HRMP） | **Data Abort（permission fault）**＝共有スピンロックは特権 | 異常系（fault・知見記録） |
| `sil_get_pid` | **不正値を返す**（MPIDR 読みが特権） | 異常系（`ttsp_mp_check_point` 不可・知見記録） |

### 異常系テストの扱い
- **明示的にテスト（CP に組込み）**：`get_tim → E_OACV` を `check_ercd(ercd, E_OACV)` で検証（サービスコールの
  アクセス保護が働くことを確認）。HRP api の保護テスト標準（E_OACV・138例）と同方式。
- **fault 系（sil_dly_nse / SIL_LOC_SPN / 不正アドレス sil_*_mem / sil_get_pid 不正値）**：CPU 例外（Prefetch/Data
  Abort）または特権レジスタ読みで、`ttsp_cpuexc_hook` が UNDEF 専用（空）のため **in-flow での捕捉・復帰ができない**。
  そのため明示 CP には組み込まず、上表の実測知見として記録（保護が働く＝fault することは確認済み）。
  ※ 将来：DABORT/PABORT を DEF_EXC で捕捉し p_excinf の PC を進める復帰機構を作れば fault 系も CP 化可能（target 依存）。

## 4. 残作業（ロードマップ）

- [x] **ASP3 3.7.2 + zybo**：緑（§2）
- [x] **FMP3 3.7 + zybo（-smp 2）**：緑（§2b）
- [~] **HRP への展開（着手・ビルド統合で保留）**：1.1.3 に SIL ソース無し＝**新規作成**。`sil_test/HRP/{out.c,out.h,out.cfg}`
      を ASP から派生・authoring 済み：
      - cfg を `KERNEL_DOMAIN { ... }` で包み（初版はカーネルドメイン実行＝保護違反回避）、`ttsp_svc.cfg` 追加、`SAC_TSK(MAIN_TASK, SHARED)`。
      - out.h に**インクルードガード**追加（HRP の cfg 生成経路で out.h が多重展開され enum 再宣言になるため）。
      - `inthdr`/`isr` の extern 宣言を**無条件化**（HRP の `kernel_cfg.c`＝割込みベクタ表は TTSP_INTNO_B 未定義の文脈で out.h を取り込むため）。
      - ⛔ **ビルド未達（本質的課題）**：HRP は**方式A（COBJS 非上書き・TECS コンポーネント化 syssvc・拡張SVC）**。
        ASP/FMP で使った「API テストの Makefile（REF_MK）流用」は、**REF_MK の APPLOBJS が元グループ（auto_code_1）の TECS 生成に固定**されており、
        SIL 用 cfg が必要とするコンポーネント（`svc_ini_mpf`/`svc_ref_mpf`/`svc_ext_ker`・`syslog_print`・`initialize_tecs`・out.o）と
        一致せずリンク不能。**HRP は正規の configure 経由ビルド（SIL 用に APPLOBJS/TECS を生成）が必須**＝下記「正式なランナー」と一体で解決する。
- [x] **HRMP3 3.7 + zybo（-smp 2）**：緑（ttb.sh 経由・両 PE `All check points passed.`）。HRP（保護）＋FMP
      （マルチプロセッサ）の合成。FMP の out.c（マルチプロセッサロジック）を流用し、out.cfg は FMP の per-PE
      `CLASS(CLS_PRCn){...}` の各ブロックを **`KERNEL_DOMAIN` で包み**、各 MAIN_TASKn に **SAC_TSK**、末尾に
      **ttsp_obj_tail.cfg 相当の ATT_MOD**（テストオブジェクトのドメイン割当）、`ttsp_svc.cfg`、out.h ガード、
      inthdr/isr 無条件宣言を適用。HRMP 固有：top-level の `ATT_INI(ttsp_test_lib_init)` を KERNEL_DOMAIN で包む。
- [x] **正式なランナー（ttb.sh SIL 再有効化）**：ttb.sh option 2 の `Not support in TTSP3` を解除し
      `source ./scripts/sil_test.sh` を復活。**ASP/FMP は ttb.sh 経由で緑を確認**（非対話駆動：`printf '2\n1\nq\n' | bash ttb.sh <OS_PATH> <PROFILE> <OBJ_DIR>` → `<OBJ_DIR>/sil_test/<asp|fmp>` を QEMU 実行。ASP=-smp 1／FMP=-smp 2）。
      sil_test.sh の configure 呼び出し（`-U $TEST_LIB_FILE`）が APPLOBJS を正しく生成する＝§3 の REF_MK 手動手順より正式。
- [x] **CI 統合 / 実行の自動化**：`scripts/ci_run_sil.sh`（ttb.sh SILメニュー駆動＋QEMU＋合否集計）。
      引数なしで ASP/FMP/HRP/HRMP を順に実行（兄弟カーネル/QEMU 非対応は SKIP）。`.github/workflows/ci.yml` の
      ASP/FMP matrix に「Run TTSP3 SIL tests」ステップを追加（HRP/HRMP は CI でカーネル未取得のため当面ローカル）。
      ローカル全緑実測：`bash scripts/ci_run_sil.sh` → PASS=4 FAIL=0。
- [x] **HRP3 3.7 + zybo**：緑（ttb.sh 経由・`All check points passed.`）。**根本原因の解明**：
      当初リンクで 135 未解決（`svc_*_mbf`/`svc_*_mpf`/`ttsp_svc_nest_error`・`almhdr`/`main_task` 等）。
      調査の結論＝extsvc 解決機構そのものではなく、**HRP はリンカスクリプト（cfg2_out.ld）を
      「保護ドメイン別のオブジェクト配置」で生成**するため、テストオブジェクト（out.o/ttsp_test_lib.o/log_output.o 等）の
      **`ATT_MOD`（ドメイン割当）が無いとリンカスクリプトにオブジェクトが配置されず未解決**になる、というもの。
      api は TTG が `library/HRP/test/ttsp_obj_tail.cfg` の ATT_MOD を出力して解決していた。
      **修正**：SIL cfg を `INCLUDE("ttsp_obj_head.cfg")`（`KERNEL_DOMAIN {` 開始）と
      `INCLUDE("ttsp_obj_tail.cfg")`（`}` 閉じ＋テストオブジェクトの ATT_MOD）で囲む構造に変更＝API テストと同一構造。
      加えて HRP 固有：`ttsp_svc.cfg` 追加・out.h インクルードガード・`inthdr`/`isr` の extern 無条件宣言。
- [ ] **DIVERGENCE_MAP 連携**：本移植の 3.4→3.7 差分（タスク例外廃止・通知書式・RELTIM µs・i_begin_int 廃止・
      FMP の systim モード廃止・クラス命名変更）を A 表に記録。
- [x] **ユーザドメイン SIL テスト（HRP/HRMP）**：両方とも実装済み・緑（§2c）。HRMP は per-PE スタック
      （`ttg_ustack_prc1`）＋`CLASS(CLS_ALL_PRC1){ DOMAIN(DOM1){ … } }` ネストで対応。
- [ ] **TTG 生成化（任意・将来）**：現状は生成済み out.* の手保守。SIL TESRY/生成ルールを TTG に持たせるかは要検討。

---

## 参照
- 旧 SIL テスト出典：`ttsp_1.1.3/sil_test/`（生成済みサンプル）
- SIL API：`asp3/include/sil.h`（3.7.2）
- 合否の正本：[`docs/STATUS.md`](STATUS.md)／操作手順：[`docs/RUNBOOK.md`](RUNBOOK.md)
