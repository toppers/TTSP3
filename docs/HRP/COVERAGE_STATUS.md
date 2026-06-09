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

## ビルドの残課題：TECS SVCプラグイン命名の flaky

- HRP3 の check_library/API ビルドは初回 make が
  `No rule to make target 'tHRPSVCPlugin_sSysLogSVCCaller_SysLog_eSysLog_tecsgen.c'` で失敗する。
  これは TECS の保護ドメイン間SVCプラグインが生成する **旧命名**（`tHRPSVCPlugin_<sig>SVCCaller_<cell>_<port>`）と
  **新命名**（`tHRPSVCCaller_<sig>`）が実行間で揺れ、make が startup 時に stale な
  `gen/Makefile.tecsgen` の OBJS（旧名）を掴むために起こる．
- **二重make で通る場合があるが安定しない**（tecsgen 再実行で命名が旧/新に揺れるため）。
  `scripts/common.sh` の `make_for_common`（RULE_BUILD）に失敗時1回リトライを追加したが、
  クリーンビルドでは安定解消に至らない。
- **HRMP3（同じ保護＋SVCプラグイン）は初回ビルドで成功**しており、本問題は HRP3 の
  tecsgen 構成に固有と見られる（hrp3 は `tecsgen/tecslib/plugin/HRPSVC*Plugin.rb` を持つ）。
- 信頼できる解消には HRP3 の tecsgen プラグイン命名の決定性確保（旧/新命名の統一）という
  深い TECS 内部調査が必要。これが解ければ HRMP3 と同様に gcov 計測へ進める。

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
