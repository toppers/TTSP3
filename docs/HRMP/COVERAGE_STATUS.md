# HRMP3 カバレッジ計測ステータス（gcovダンプ動作・API駆動のみ残）

> **状態（2026-06-09）：check_library で gcov 完全動作（gcda生成・カバレッジ抽出成功）。**
> HRMP3 の保護カーネルで gcov(C1) 計測の最難関（特権ダンプの未マッピングフォールト）を突破。
> 残るは **API auto-code の並列ドライバ（ttsp_parallel_api.sh）が HRMP（保護多パスビルド）
> 未対応**な点のみ。check_library のカバレッジは取得済み（startup.c 97%, task.c 52% 等）。

---

## 動作までの全解決チェーン（2026-06-09）

gcovダンプ経路を診断（セミホスティング出力＋CPSR読取）で確定し，順に解決：

1. **計装・リンク**：`Makefile.target` に ENABLE_GCOV、`target_kernel_impl.c` に gcov ランタイム
   （FMP雛形・特権SVCモードで動作）、`ldscript.trb` 末尾の `GROUP()` でライブラリ解決。
2. **ライブラリ配置**（strlen 未マッピングフォールト対策）：`ldscript.trb` の `$modnameReplace` で
   `libc.a`→`*libc.a:` 等ワイルドカード化。GROUP で遅延に引かれる libc/libgcov/librdimon の
   メンバ（strlen 等）をフルパス書庫にマッチさせ、マッピング済みの `.text_shared` 等へ配置。
3. **gcov_info 配置**（最重要）：`target_mem.cfg` に
   `KERNEL_DOMAIN { ATT_SEC(".gcov_info", { TA_NOWRITE|TA_KEEP, "DDR" }); }` を追加。
   - `TA_NOWRITE` で初期化済み読込専用データ扱い（`TA_MEMINI` 自動付与）＝**ロードされる**
     `.rodata_kernel`（マッピング済み）に配置。当初 `TA_KEEP` のみでは NOLOAD の
     `.noinit_kernel` に落ち、ポインタ値が**ロードされずダンプがフォールト**した。
   - ヒープは `target_kernel_impl.c` の `.bss_kernel` 静的配列 `gcov_heap_pool`（マッピング済み）。
4. **ラベル**：`ldscript.trb` で `__gcov_info_start/end` をコンフィギュレータ生成の
   `__start_rodata_kernel_A1001`/`__end_` にエイリアス（check_library 全3種で同一＝安定）。

→ **結果**：QEMU が正常終了し gcda 45ファイル生成、`/hrmp3/kernel/` のカバレッジ抽出に成功。

## 残るタスク：API auto-code の HRMP 対応

`scripts/ttsp_parallel_api.sh` が ASP/FMP のみ対応（PROFILE=HRMP でエラー）。HRMP は保護
多パスビルド（cfg1→cfg2→cfg3、libkernel.a、TECS、保護ドメイン）で、ASP/FMP の単一パス
直接makeモデルと異なるため、ドライバの HRMP 対応（または ttb.sh 経由のAPI生成）が必要。
これが入れば API テスト全体のカバレッジが取得できる（計装・ダンプ機構は実証済み）。

> 旧記述（multilib不一致／408B未マッピング）は調査途上の中間診断。最終的な真因と解決は上記。

---

## 試行で判明した重要事実

### HRP3 と違い HRMP3 は TTSP3 で動く
- check_library: `ttb.sh ../hrmp3/ HRMP` で **初回パスでビルド成功**（HRP3 の TECS二重make・
  ttsp_target_test.o リンク問題は HRMP3 では発生しない）。
- QEMU実行（`-smp 2`）：exception・interrupt は **緑**（All check points passed）。
  timer のみ末尾で `Unregistered interrupt occurs.`（QEMU-SMP のタイマ割込み端の問題。
  多数のチェックポイント通過後に発生。API計測の主対象ではない）。

### GCOV計装の移植は動作する（gcno生成を確認）
カーネル側（`../hrmp3_3.4/`、SVN・ttsp3 git 外）に FMP3 を雛形として移植済み：
| ファイル | 内容 |
|---|---|
| `target/zybo_z7_gcc/Makefile.target` | `ENABLE_GCOV` ブロック（`--coverage -fprofile-update=atomic -fprofile-info-section`、`-DTOPPERS_ENABLE_GCOV`、librdimon、ライブラリ群を **LDFLAGS** に配置） |
| `target/zybo_z7_gcc/target_kernel_impl.c` | ベアメタルgcovランタイム（`__gcov_info_to_gcda`＋セミホスティング、`_sbrk`、`software_init/term_hook`、マルチコアPE同期ガード） |
| `arch/gcc/ldscript.trb` | `.gcov_info` 収集（`__gcov_info_start/end` + KEEP）、`_heap`/`_heap_limit`、`end`/`_end` |

→ `task.o` 等が `--coverage` で計装され gcno 生成を確認。`-DNDEBUG` も適用。

### TTSP3側の整備（本コミットに含む・非GCOVビルドに無害と検証済み）
| ファイル | 変更 |
|---|---|
| `library/HRMP/target/zybo_z7_gcc/ttsp_target.sh` | `MAKE_OPT="${TTSP_MAKE_OPT:-}"`（ASP/FMP と同様、`ENABLE_GCOV=true` を make へ伝播） |
| `library/HRMP/check_library/{exception,interrupt,timer}/out.cfg` | `ATT_MOD("libgcov.a")`/`ATT_MOD("librdimon.a")`（保護ドメイン配置。未リンク時は ld がパターン無マッチで無害＝非GCOVビルドで3バイナリとも緑を確認） |
| `library/HRMP/test/ttsp_obj_tail{,_domain}.cfg` | 同上（API テスト共通 tail。TTG生成 out.cfg に追加される） |
| `scripts/coverage_gcov_hrmp.sh` | smoke/bb/all モード（ASP/FMP 雛形、`-smp 2`、`--filter /hrmp3/kernel/`、TECSリトライ） |

---

## 解決済みのリンク課題（履歴）

保護多パスリンク（cfg1→cfg2→cfg3）で順に発生し解消した：
1. `__gcov_merge_add`/`_open` が `/DISCARD/` で破棄 → libgcov.a/librdimon.a を ATT_MOD で
   保護ドメインに配置（`library/HRMP/*/out.cfg`・`ttsp_obj_tail*.cfg`）して解消。
2. `strlen` 未解決（リンク順序）→ `arch/gcc/ldscript.trb` 末尾の `GROUP( -lgcov -lrdimon -lc -lgcc )`
   ＋ワイルドカード catch で解消（リンクは通る。ただし strlen が遅延 orphan 化し未マッピング配置に
   なる副作用が，上記「最新の根本原因」§のランタイム・フォールトにつながっている）。
3. `end` 未定義（librdimon の _sbrk が参照）→ _sbrk を `.bss_kernel` の静的配列 `gcov_heap_pool`
   に置換し，librdimon の _sbrk を不要化して解消。

> ※当初「multilib 不一致」と誤診したが，実測では全ライブラリが同一 multilib
> （thumb/v7-a+fp/hard）。真因はリンク順序（解決済み）と未マッピング配置（残課題）。

---

## 参考
- ASP3：`docs/ASP/`（98.3%）／FMP3：`docs/FMP/`（93.9%）／HRP3：`docs/HRP/COVERAGE_STATUS.md`（ビルド不可で延期）
- 計画・後段方針：`docs/WHITEBOX_PLAN.md` §10/§11 Q4
- 計装の雛形：`../fmp3_3.4/target/zybo_z7_gcc/`
