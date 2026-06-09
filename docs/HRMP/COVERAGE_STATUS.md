# HRMP3 カバレッジ計測ステータス（移植進行中・1点で停止）

> **状態（2026-06-09）：計測未完了だが大きく前進。** HRMP3 は HRP3 と異なり TTSP3 で
> ビルド・実行でき、GCOV計装の移植も動作（gcno生成）まで到達。残る単一ブロッカーは
> 保護多パスリンク（cfg2_out）でのツールチェーン **multilib 不一致**。

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

## 残る単一ブロッカー：multilib 不一致（cfg2_out 中間リンク）

HRMP は保護カーネルで **3パスリンク（cfg1→cfg2→cfg3）**。その cfg2_out 中間リンクで：

```
ld: libgcov.a(_gcov_info_to_gcda.o): undefined reference to `strlen'
ld: librdimon.a(syscalls.o): undefined reference to `strlen'
```

エラーのライブラリパスが **`arm-none-eabi/13.2.1/thumb/v7-a+fp/hard/`**（thumb）である一方、
カーネルは **`-mcpu=cortex-a9+nofp`（ARM）** でビルドされる。`-mcpu=cortex-a9+nofp` と
`-mfloat-abi=hard -mfpu=vfpv3-d16` の組合せで，自動的に引かれる libgcov/librdimon の
multilib variant がカーネル本体（および libc）と一致せず，`strlen`（libc）が解決できない。

- 解決済みの先行エラー：`__gcov_merge_add`/`_open` の discard（→ ATT_MOD 配置で解消）、
  `end` 未定義（→ ldscript の `PROVIDE(end)` で解消）。
- 残課題はこの multilib 整合のみ。`-mcpu=cortex-a9+nofp` の `+nofp` がFP無しCPUを示す一方で
  hard-float ABI を要求する矛盾が一因と見られる。

### 解決の方向（将来）
- cfg2_out リンクで libgcov/librdimon を **カーネルと同じ multilib**（arm cortex-a9 hard-float）から
  引かせる（明示パス指定 or `-marm` 等のフラグ整合）。kernel ビルドフラグに触れるため要検証。
- もしくは cfg2_out 中間リンクを gcov ライブラリ非依存にする（計装オブジェクトを cfg2 段で
  含めない）方法の調査。
- FMP3 は単一パスリンクのため本問題は発生しない（HRMP の保護多パス固有）。

---

## 参考
- ASP3：`docs/ASP/`（98.3%）／FMP3：`docs/FMP/`（93.9%）／HRP3：`docs/HRP/COVERAGE_STATUS.md`（ビルド不可で延期）
- 計画・後段方針：`docs/WHITEBOX_PLAN.md` §10/§11 Q4
- 計装の雛形：`../fmp3_3.4/target/zybo_z7_gcc/`
