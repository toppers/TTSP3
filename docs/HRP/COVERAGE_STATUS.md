# HRP3 カバレッジ計測ステータス（実行は可・ビルドが flaky）

> **状態（2026-06-09 更新）：HRP3 は QEMU で実行可能（緑）であることを確認。**
> check_library/exception を手動ビルド（後述の二重make）して QEMU 実行 →「All check points passed」。
> ただし TTSP3 の通常ビルドは **TECS の SVCプラグイン命名 flaky** で安定して通らない（後述）。
> gcov 計測の前提（GCOV計装）は HRMP3 と同方式で適用可能（`docs/HRP3_GCOV.md`、HRP3は単一コア）。

---

## 実行可能性の確認（2026-06-09）

- HRMP3 の保護ビルド知見を適用し、check_library/exception を
  `make KERNEL_COBJS=... APPL_COBJS=...`（HRP3用の全オブジェクト）で**二重make**したところ
  ビルド成功（`hrp` 生成）。QEMU（単一コア、`-smp` 無し）で実行し
  **「All check points passed」**＝HRP3 は TTSP3 で実行可能。

## ビルドの残課題：HRP3 tecsgen の SVCプラグイン命名不整合（根本原因・2026-06-09 調査）

### 構造的背景：HRP3 は syssvc が TECSコンポーネント化されている
- **HRP3 の syssvc**：`tSysLogAdapter.c`/`tSysLog.c`/`tSerialAdapter.c` 等 TECS celltype（.cdl+.c）。
- **HRMP3 の syssvc**：`syslog.c`/`syslog.cfg`/`syslog.h` の従来型（TECS celltype 無し）。
- このため HRMP3 は初回ビルドで成功するが、HRP3 は TECS の celltype/SVC オブジェクトに強く依存。

### 不具合の連鎖（2点）
1. **tecsgen の SVCプラグイン命名不整合**：HRP3 の `tecsgen/tecslib/plugin/` で
   - `HRPSVCSignaturePlugin.rb` は **新命名** `tHRPSVCCaller_<sig>` の celltype を生成（L63）。
   - `HRPSVCThroughPlugin` 等は **旧命名** `tHRPSVCPlugin_<Sig>SVCCaller_<Cell>_<Entry>` の
     セル/オブジェクトを参照する（コメントにも旧命名が残る）。
   - 結果、make が `objs/tHRPSVCPlugin_sSysLogSVCCaller_SysLog_eSysLog_tecsgen.o`（旧名）を要求するが
     その `.c` は生成されず（新名のみ）「No rule to make target ...」で失敗。どのファイルにも旧名は
     無いのに make が要求＝tecsgen のプラグイン版不整合。再make でも安定解消しない。
2. **APPL_COBJS 上書きによる celltype オブジェクトの脱落**：TTSP3 のビルドは
   `make ... APPL_COBJS="out.o ttsp_test_lib.o ..."` で上書きするため、Makefile 既定の
   `APPL_COBJS := ... $(TECS_USER_COBJS) $(TECS_OUTOFDOMAIN_COBJS)`（celltype＝tSysLogAdapter.o 等）が
   落ち、cfg生成 ldscript が参照するのに自動ビルドされず「cannot find tSysLogAdapter.o」で失敗。
   （HRMP3 は celltype が無いため無関係。）

### 確認された事実
- 不足オブジェクトを**1つずつ明示ビルド**（`make objs/<name>.o`）して再リンクすれば hrp は完成し、
  QEMU で緑になる（＝実行可能性は確証済み）。ただし ①の旧名不整合が初回makeを止めるため、
  ビルドスクリプトのリトライだけでは安定して通せない。
- `scripts/common.sh` への一時リトライ追加は ①に対して安定せず、共有コードを複雑化するため revert 済み。

### 信頼できるビルドへの選択肢（将来）
- (A) **hrp3 の tecsgen プラグイン命名を整合**（HRPSVCThroughPlugin と HRPSVCSignaturePlugin の
  旧/新命名を統一）。最も根本的だが kernel(hrp3) 側 tecsgen の修正が必要。
- (B) **HRP3 の syssvc を従来型（非TECS）に**（HRMP3 と同様 syslog.c 構成）。TTSP3 の HRP テスト
  ターゲット構成変更で回避。
- (C) ビルドドライバで TECS celltype オブジェクトを明示ビルドする手順を組み込む（②は
  APPL_COBJS に `$(TECS_OUTOFDOMAIN_COBJS)` を SYSSVC 経路で追加、①は tecsgen 整合が前提）。

いずれかで安定ビルドできれば、HRMP3 と同方式（`docs/HRP3_GCOV.md`、HRP3 は単一コア）で gcov 計測へ進める。

---

## 計測に至らなかった理由（ブロッカー連鎖）

HRP3 に対して `coverage_gcov_*.sh` 相当を流すだけでは計測できない。2層のブロッカーがある。

### ブロッカー① GCOV計装インフラがカーネルに無い

ASP3/FMP3 の `target/zybo_z7_gcc/` には計測用の計装が移植済みだが、HRP3 には無い（`ENABLE_GCOV=0`）。

| 計装箇所 | ASP3/FMP3 | HRP3 |
|---|---|---|
| `Makefile.target` | `--coverage -fprofile-info-section` + `-DTOPPERS_ENABLE_GCOV` | ❌ 無し |
| `target_kernel_impl.c` | ベアメタルgcovランタイム（`__gcov_info_to_gcda`＋セミホスティングダンプ、約100行） | ❌ 無し |
| リンカ | `.gcov_info` セクション収集 + `_heap`/`_heap_limit` | ❌ 無し |

さらに HRP3 は**保護カーネル**で、リンカスクリプトが `arch/gcc/ldscript.trb`（TECSテンプレート）から
**構成時に生成**される。`.gcov_info` 収集と gcov カウンタ配置を保護ドメイン整合で組み込む必要があり、
ASP/FMP の静的 `zybo_z7.ld` への追記より難度が高い。

### ブロッカー② HRP3 が TTSP3 で緑にビルドできない（GCOV無関係・より根本）

`ttb.sh ../hrp3/ HRP` の check_library ビルドで、計装以前に以下が連鎖的に発生した（2026-06-09 実測）。

1. **TECS 初回 `-include Makefile.tecsgen` が stale 名を掴む**
   - 旧プラグイン名 `tHRPSVCPlugin_sSysLogSVCCaller_SysLog_eSysLog_tecsgen.c` で
     `make: *** No rule to make target ...` で停止。
   - 原因：HRP3 3.4 の tecsgen は新名 `tHRPSVCCaller_sSysLog` を生成するが、初回makeが
     旧名を含む依存を参照する。**make を2回連続実行**すると tecsgen が
     `Makefile.tecsgen` を新名で再生成して通過する。
2. その先で **`ld: cannot find ttsp_target_test.o`**
   - `APPL_COBJS_TARGET=objs/ttsp_target_test.o`（`library/HRP/target/zybo_z7_gcc/ttsp_target_test.c`）が
     保護3パスビルド（cfg1→cfg2→cfg3）の `cfg2_out` リンク時に未コンパイル。

→ HRP3 は **TTSP3 での bring-up（TECS版差の吸収・保護多パスビルド統合）が未完**。
この bring-up が、GCOV計装・カバレッジ計測の**前提**になる。

---

## 計測を可能にするための作業順序（将来）

1. **HRP3 の TTSP3 bring-up**（ブロッカー②）
   - TECS 二重make問題への対応（ビルドドライバで tecsgen パスを先行させる／make 2回化）。
   - `ttsp_target_test.o` を保護多パスビルドの link 経路に正しく載せる。
   - check_library → API auto-code が QEMU で緑になることを確認。
2. **GCOV計装の保護カーネル向け移植**（ブロッカー①）
   - `Makefile.target` に ENABLE_GCOV ブロック追加（FMP3 を雛形）。
   - `target_kernel_impl.c` に gcovランタイム移植（HRP3 は単一コア → FMP のマルチコアガード不要）。
   - `arch/gcc/ldscript.trb` に `.gcov_info` 収集と `_heap`/`_heap_limit`、gcov カウンタの
     保護ドメイン配置を追加。
3. **計測スクリプト整備**（`scripts/coverage_gcov_hrp.sh`、ASP/FMP を雛形）→ 計測 → 本ファイルを
   `WB_COVERAGE.md` / `WB_UNREACHABLE.md` に置換。

---

## 参考

- ASP3 計測結果：`docs/ASP/`（98.3% = 1434/1459）
- FMP3 計測結果：`docs/FMP/`（93.9% = 1575/1677）
- ホワイトボックス計画・後段方針：`docs/WHITEBOX_PLAN.md` §10/§11 Q4
- 計装の雛形：`../fmp3_3.4/target/zybo_z7_gcc/`（Makefile.target / target_kernel_impl.c / zybo_z7.ld）
