# HRP3 カバレッジ計測ステータス（計測完成・line 79.6%/branch 69.8%）

> **状態（2026-06-09 更新・計測完成）：HRP3 で gcov(C1) 計測が完全動作。**
> check_library + API 20分割（19/20 集計）で **line 79.6% (2653/3334) / branch 69.8% (1769/2533)**。
> → 計測結果は [WB_COVERAGE.md](WB_COVERAGE.md)、未到達分析は [WB_UNREACHABLE.md](WB_UNREACHABLE.md)。
> 主要な標準API（task/semaphore/eventflag/dataqueue/pridataq/mutex/mempfix/alarm/cyclic/
> wait/interrupt）は line 90〜100%。残ギャップは保護ドメイン機能と E_OACV 早期終了（test-design）。
>
> 本ファイルは計測に至るまでの bring-up（方式A）・GCOV計装移植・真因記録を保持する。
>
> ---
>
> ## GCOV計装の移植（完了・2026-06-09）
>
> HRMP3 と同方式で HRP3 カーネル（`../hrp3_3.4/`、SVN・ttsp3 git 外）へ移植。HRP3 は単一コアの
> ため prcid ガード／atomic 更新は不要。
>
> | ファイル | 内容 |
> |---|---|
> | `target/zybo_z7_gcc/Makefile.target` | `ENABLE_GCOV` ブロック（`--coverage -fprofile-info-section`, `-DTOPPERS_ENABLE_GCOV`, `-specs=rdimon.specs`） |
> | `target/zybo_z7_gcc/target_kernel_impl.c` | ベアメタルgcovランタイム（`__gcov_info_to_gcda`＋セミホスティング, 静的 `gcov_heap_pool` `_sbrk`, `software_init/term_hook`） |
> | `target/zybo_z7_gcc/target_ldscript.trb`（新規） | `GenerateProvide`（`$modnameReplace` ワイルドカード＋`__gcov_info_start/end`→`__start/__end_rodata_kernel_A1001` エイリアス）／`GcovLdscriptAppendGroup`。`target_{kernel,opt,mem}.trb` から IncludeTrb（`arch/gcc/ldscript.trb` は無変更） |
> | `target/zybo_z7_gcc/target_mem.cfg` | `KERNEL_DOMAIN { ATT_SEC(".gcov_info", { TA_NOWRITE\|TA_KEEP, "DDR" }); }` |
>
> TTSP3側（本リポジトリ・git）：
> - `library/HRP/check_library/{exception,interrupt,timer}/out.cfg`＋`library/HRP/test/ttsp_obj_tail.cfg`：`ATT_MOD("libgcov.a")`/`("librdimon.a")` 追記（非GCOV時は無害）
> - `library/HRP/target/zybo_z7_gcc/ttsp_target.sh`：`MAKE_OPT="${TTSP_MAKE_OPT:-}"`
> - `library/HRP/target/zybo_z7_gcc/ttsp_target_test.h`：`RAISE_CPU_EXCEPTION` に `teq r0, r0` 前置（下記）
> - `scripts/ttsp_parallel_api.sh`：HRP 対応（TTGフラグ `-h`、方式A の COBJS 非上書き、libgcov 追記）
> - `scripts/coverage_gcov_hrp.sh`（新規）：smoke/bb/all（単一コア `-smp 1`、`--filter /hrp3/kernel/`）
>
> ## 解決したGCOV固有バグ：CPU例外テストの条件付き未定義命令
>
> 計装版 check_library/exception が checkpoint 2 でタイムアウトした。QEMU `-d int` トレースで
> **未定義命令例外が発火していない**ことを確認。`RAISE_CPU_EXCEPTION` は `.long 0x06000010`
> ＝**条件フィールド EQ の未定義命令**で，Z=1 のときだけトラップする。非計装では直前の
> `if (excno == TTSP_EXCNO_A)` 比較が残す Z=1 に依存して発火していたが，`--coverage` 計装では
> ブロックのカウンタ加算が比較と本命令の間に挿入されて Z をクリアし，条件不成立で例外が
> 起きなかった。`teq r0, r0` を前置して常に Z=1 を保証して解消（非計装の動作は不変）。

---

## 解決：方式A（APPL_COBJS を破壊的に上書きしない）実装済み（2026-06-09）

ttb.sh の HRP `APPL_COBJS_COMMON` には**旧命名の TECS オブジェクトがハードコード**
（`tHRPSVCPlugin_<sig>SVCCaller_<cell>_<port>_tecsgen.o` 等）されており、これが make 上書きで
渡されて「No rule to make target」の出所だった。サンプル解析で真因（COBJS 破壊的上書きが
TECS celltype を落とす）を確定（後述）。

**実装した解決（方式A）**：
- `ttb.sh`：HRP のとき `TEST_LIB_FILE` に TTSP3 のテスト用追加オブジェクト
  （ttsp_test_lib.o/log_output.o/vasyslog.o/t_perror.o/strerror.o/ttsp_mem_obj_*.o/
  ttsp_target_test.o）を設定し、configure の `-U`（→APPLOBJS）で渡す。
- `scripts/common.sh`（`make_for_common`）：HRP のとき KERNEL_COBJS/APPL_COBJS を**上書きせず**
  `make $MAKE_OPT` のみ実行。configure 生成 Makefile の
  `APPL_COBJS := @(APPLOBJS) $(TECS_USER_COBJS) $(TECS_OUTOFDOMAIN_COBJS) ...` により
  テストオブジェクト＋TECS celltype（**tecsgen が生成する正しい新命名**）が両立してビルドされる。
- 旧命名ハードコードに依存しなくなった。ASP/FMP/HRMP は分岐外で影響なし（regression 無しを確認）。

→ **結果**：`ttb.sh ../hrp3/ HRP` の check_library で exception/interrupt/timer の3種すべてが
ビルド成功し、QEMU（単一コア）で「All check points passed」。

> 残：API テストの並列ドライバ（ttsp_parallel_api.sh）は ASP/FMP/HRMP 対応。HRP を加える場合は
> 同様に「-U でテストオブジェクト追加・COBJS 非上書き」を適用する。

---

## 真因（サンプル解析・2026-06-09）

> **サンプルビルドの解析で原因を確定。HRP3 カーネル本体（tecsgen 含む）は健全**。
> 問題は **TTSP3 の HRP ビルドハーネス**にある（前回記載の「tecsgen 命名不整合（バグ）」説は誤りと判明）。

### 決め手：HRP3 サンプルは正常にビルドできる
- `ruby hrp3/configure.rb -T zybo_z7_gcc` でサンプルを構成し `make` → **初回で成功**（`hrp` 生成）。
- 生成物（gen/Makefile.tecsgen, cfg2_out.ld）は **新命名 `tHRPSVCCaller_<sig>` のみ**、
  旧命名 `tHRPSVCPlugin_<Sig>SVCCaller_<Cell>_<Entry>` は **0 件**。SVCプラグイン
  （`HRPSVCThroughPlugin.new(...,'SysLog','eSysLog',tSysLog)`）の呼び出しもサンプルと TTSP3 で同一。
  → HRP3 の tecsgen は正常。旧名は TTSP3 ビルドの過渡で派生する症状にすぎない。

### 構造的背景
- **HRP3 の syssvc は TECSコンポーネント化**（`tSysLogAdapter.c`/`tSysLog.c`/`tSerialAdapter.c` 等の
  celltype）。サンプル既定ビルドは `APPL_COBJS := out.o $(TECS_USER_COBJS) $(TECS_OUTOFDOMAIN_COBJS)`
  で celltype/SVC オブジェクトを自動的に含めてビルドする。
- **HRMP3 の syssvc は従来型**（`syslog.c` のみ、TECS celltype 無し）→ HRMP3 は影響を受けない。

### 根本原因：APPL_COBJS の破壊的上書き
TTSP3 は全プロファイル共通で `make ... KERNEL_COBJS="..." APPL_COBJS="out.o ttsp_test_lib.o ..."` と
**オブジェクトリストを上書き**する。これにより Makefile 既定の
`$(TECS_KERNEL_COBJS)`/`$(TECS_USER_COBJS)`/`$(TECS_OUTOFDOMAIN_COBJS)`（HRP の celltype＝
tSysLogAdapter.o 等）が**脱落**し、cfg 生成 ldscript が参照するのに自動ビルドされず
「cannot find tSysLogAdapter.o」で失敗する。
（「No rule ... tHRPSVCPlugin_...」の旧名エラーは上書き＋初回makeの過渡で生じる派生症状。）

- 単純に `APPL_COBJS` へ `$(TECS_OUTOFDOMAIN_COBJS)` 等を足すと、これらは `$(_TECS_OBJ_DIR)` 接頭辞で
  `objs/` 前提の APPL_COBJS パターン規則と**接頭辞が不一致**となり、`.s` 規則が誤発火して
  `gcc -S -o X.o`（入力無し）→「no input files」で失敗する（`Makefile:703 ignoring old recipe` 併発）。

### 確認された事実
- 不足する TECS オブジェクトを**明示ビルド**（`make objs/<name>.o`）して再リンクすれば hrp は完成し、
  QEMU で緑（**実行可能性は確証済み**）。
- `scripts/common.sh` への一時リトライ追加は安定せず共有コードを複雑化するため revert 済み。

### 信頼できるビルドへの選択肢（将来）
- (A) **TTSP3 の HRP ビルドで APPL_COBJS を破壊的に上書きしない**。サンプル同様 Makefile 既定の
  TECS オブジェクトを残しつつ、TTSP3 テストの追加オブジェクト（ttsp_test_lib.o/ttsp_target_test.o/
  ttsp_mem_obj_*.o）を**追記**する（例：sample/Makefile に EXTRA_APPL_COBJS フックを設け TTSP3 が追加）。最もクリーン。
- (B) **HRP3 の syssvc を従来型（非TECS）に**（HRMP3 と同様 syslog.c 構成）。HRP テストの
  ターゲット構成変更で TECS celltype 依存を回避。
- (C) ビルドドライバで TECS オブジェクトを正しい接頭辞・規則ルート（SYSSVC 経路）で明示ビルドする。

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
