# HRMP3 カバレッジ計測ステータス（spinlock sysstat1 移行後・line 91.3%/branch 82.1%）

> **合否（PASS/FAIL）の現状は `docs/STATUS.md` が正本**（本ファイルはカバレッジ%が主）。
> 2026-06-13 実測（非GCOV・`ci_run.sh HRMP`）：check_library 緑・cfg-error OK=156、
> **API は 14/20**（5群が `chg_spr` 未定義で link失敗＝HRMP3 3.4 にサブ優先度なし／1群NG）。
> ※本ファイル下記の「3群 overlap」等は GCOV 計装時の別事象。

> **状態（2026-06-09）：spinlock（loc_spn/try_spn/unl_spn）の sysstat1_acvct.acptn2 移行
> （HRMP spin_lock TESRY 5ファイル×5ケースに CPU_STATE1 access1-4 追加）後、
> スピンロック E_OACV を解消。check_library + API 20分割で line 91.3% / branch 82.1%
> （ベースライン比 +15.9pp/+18.4pp）。15/17 runnable グループで All check points passed。**
>
> （旧ベースライン 2026-06-09：line 75.4% / branch 63.7%。詳細は下記§「カバレッジ結果」）

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

## API auto-code 対応：完了（gcov計測は全20分割で動作）

`scripts/ttsp_parallel_api.sh` に HRMP 対応を追加（2026-06-09）：
- KERNEL_COBJS/APPL_COBJS（domain/memory/messagebuf/svc_table/spin_lock・mem_obj 群）
- TTG フラグ `-H`（FMPは -f）、`-smp $PROCESSOR_NUM`
- GCOV計装時は TTG生成 out.cfg に `ATT_MOD("libgcov.a")`/`ATT_MOD("librdimon.a")` を追記
  （TTG は libc.a までしか ATT_MOD せず、未追記だと libgcov/librdimon の .text が
  `/DISCARD/` で破棄されリンク失敗するため）.

→ **全20分割 + check_library で gcda 生成・カバレッジ抽出に成功**（`bb` モード）。
gcov_info のラベル（`__start_rodata_kernel_A1001`）は check_library/API で同一＝安定。

## カバレッジ結果（2026-06-09 `bb` ＋ spinlock sysstat1 移行後）

**line 91.3% (4253/4658) / branch 82.1% (2215/2697)**。
（旧ベースライン: line 75.4% (3510/4658) / branch 63.7% (1719/2697)）

主要API は高カバレッジ：alarm 99.2%, cyclic 99.2%, dataqueue 95.5%, eventflag 98.3%,
mempfix 98.0%, mutex 98.5%, pridataq 95.8%, semaphore 97.7%, task 98.7%, task_sync 98.3%,
task_refer 91.8%, wait 100.0%, interrupt 93.5%, spin_lock 100.0%, messagebuf 90.7%。

### ベースライン比較

| ファイル | 旧 line | 新 line | 旧 branch | 新 branch |
|---|---|---|---|---|
| messagebuf.c | 4.1% | 90.7% | 2.0% | 56.0% |
| sys_manage.c | 92.2% | 96.0% | 70.1% | 76.6% |
| task_sync.c | 98.3% | 98.3% | 91.8% | 95.9% |
| time_manage.c | 98.7% | 98.7% | 82.5% | 82.5% |
| spin_lock.c | — | 100.0% | — | 81.4% |
| **TOTAL** | **75.4%** | **91.3%** | **63.7%** | **82.1%** |

### IPI割込みバグの修正（24%→75% に向上）
当初 24%/13% で頭打ちだった主因は、ティック更新用プロセッサ間割込みの番号
`TTSP_IPI_INTNO=0x001e`（PPI）が `gicd_raise_sgi()` の GICD_SGIR INTIDフィールド（4bit）で
`0x1e&0xF=14` に折り返され **SGI 14 が誤発火→未登録→緊急停止**していたこと。
alarm/cyclic/timer 等ティック更新を伴うテストが全滅していた。FMP は 2026-06-06 に
`0x0004`（SGI 4）へ修正済みだったが HRMP は未適用だった → 同修正を適用（`ttsp_target_test.h`）。
診断は `default_int_handler` に intno を一時出力して SGI 14 を特定（確認後リバート）。
→ check_library timer も「All check points passed」に回復。

### 残課題（さらなる向上）
- **acptn2 競合（auto_code_16）**：`HRP_interrupt_dis_int_H_a` が E_OK（期待 E_OACV）。
  `dis_int` と `loc/try/unl_spn` が同一 `sysstat1_acvct.acptn2` を参照するため、spinlock 用に
  DOM1 を acptn2 に追加すると `dis_int` も通るようになる設計上の競合。
  `dis_int_H-a.yaml`（`api_test/HRP/interrupt/dis_int/`）は「DOM1 が acptn2 を持たない環境」前提で
  E_OACV を期待するが、spinlock テストと同一バイナリでは共存不可。
  → HRP interrupt テストと HRMP spinlock テストを別グループに分割するか、`dis_int_H-a.yaml` の
    expected を修正する必要がある（HRMP3 3.4 では spinlock ≡ dis_int ≡ acptn2 が仕様設計）。
- **alarm チェックポイント順序（auto_code_18）**：`ASP_alarm_sta_alm_d_1_H3` が
  `Unexpected Check Point : 7`。SMP タイミング起因の既存問題（spinlock 移行と無関係）。
- **HRMPビルド失敗**（3グループ: auto_code_14/17/19）：`target_mem.cfg:36: E_SYS: memory objects overlap`
  （gcov 計装による増大。gcov 固有）。非計装では正常ビルド可。
- 低カバレッジ残存：domain.c 19%, mem_manage.c 58%, memory.c 79%, svc_table.c 0%。
  → 保護ドメイン固有テストの拡充が次段階。
- gcov 計装・ダンプ機構は全グループで完全動作（計測基盤は完成）。

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
- ASP3：`docs/ASP/`（98.3%）／FMP3：`docs/FMP/`（93.9%）／HRP3：`docs/HRP/`（79.6%）
- 計画・後段方針：`docs/WHITEBOX_PLAN.md` §10/§11 Q4
- 計装の雛形：`../fmp3_3.4/target/zybo_z7_gcc/`
