# HRMP3 カバレッジ計測ステータス（移植進行中・gcdaダンプ直前で停止）

> **状態（2026-06-09）：計測未完了だが核心まで到達。** HRMP3 は HRP3 と異なり TTSP3 で
> ビルド・実行でき、GCOV計装移植も動作（gcno生成）、リンクも全解決、テスト緑、
> gcovダンプ（`toppers_gcov_end`）に到達するところまで確認。残るは **gcov支援データ
> （計408バイト）が未マッピング領域に置かれ、ダンプ中にフォールトする**1点のみ。

---

## 最新の根本原因（2026-06-09 実測・確定）

gcovダンプ経路を診断（セミホスティング出力＋CPSR読取）した結果：

1. **ダンプは特権(SVC)モードで動作**（CPSR=0xd3, mode[4:0]=0x13=SVC）。
   → 権限違反ではなく，アクセス先メモリの**未マッピング（変換フォールト）**が原因。
2. `__gcov_info_to_gcda`（libgcov）は `.text_shared`（0x1622e4・マッピング済み）に配置され
   **実行は成功**。gcovカウンタはカーネルドメイン（マッピング済み）にあり特権ダンプから読める。
   ヒープも `gcov_heap_pool`（.bss_kernel・マッピング済み静的配列）に変更済み。
3. **唯一の未マッピング**＝リンカスクリプト固定部末尾に置いた2セクション（計408B, アドレス0x200000〜
   ＝共有RW領域の終端 `__aend_mp_rwdata_shared=0x200000` の直後）：
   - `.gcov_info`（180B）：gcov_info ポインタ配列（`__gcov_info_start/end`）
   - `.gcov_libs`（228B）：`GROUP()` で**遅延に引かれた** `strlen`（libc）等。`__gcov_info_to_gcda`
     内の `dump_string` が `strlen` を呼ぶ → 未マッピングへのフェッチ → **フォールト**。
   - 遅延に引かれる理由：保護ドメインの配置パターン `libc.a(.text)`（非ワイルドカード）が
     フルパス書庫にマッチせず，かつ `GROUP()` がドメイン配置確定後に引くため orphan 化し，
     固定部末尾のワイルドカード catch（未マッピング）に落ちる。

## 残る単一タスク：408Bをマッピング済みドメイン領域へ

ユーザ方針（2026-06-09）：**マッピング済みドメイン領域に配置**（特権ダンプなのでカーネル/共有いずれも可）。

候補アプローチ：
- (a) `arch/arm_gcc/common/core_kernel.trb` の `.shared_code` と同様に，`.gcov_info` 等を
  無所属(共有)RWセクションとして登録し，コンフィギュレータに共有領域（マッピング済み）へ
  配置させる。strlen等の遅延 orphan は，共有テキスト領域のワイルドカード catch を
  動的出力に加える必要がある。
- (b) `target_mem.cfg`（target配下・編集可）に gcov 用の固定アドレスのカーネルアクセス可能
  メモリ領域を定義し，`ldscript.trb` で `.gcov_info`/`.gcov_libs` を `> その領域` に置く。
- いずれも HRMP の保護ドメイン/コンフィギュレータ機構の追加作業が必要。

> 旧記述（multilib不一致）は誤診だった。実測では全ライブラリが同一 multilib
> （thumb/v7-a+fp/hard）で，真因はリンク順序（解決済み）と上記の未マッピング配置。

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
