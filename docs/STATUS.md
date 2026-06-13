# STATUS.md — TTSP3 現状ステータス（AI向け単一・機械可読ソース）

> **目的**：profile×target ごとの「**現在の合格基準・既知残・カバレッジ・実行コマンド**」を
> 1か所に集約し、AI/人が**再計測せずに**「ある失敗が退行か既知差分か」を即判定できるようにする。
> 各セルは**測定値＋最終確認日＋出典**を持つ。値は他文書（`DIVERGENCE_MAP.md`・各 `BB_COVERAGE.md`・
> `issues/` 等）に散在していたものの正本。**更新手順は末尾**。
>
> 凡例：✅=緑（基準達成）／⚠=既知残あり（退行ではない）／❓=未測定（QEMU等で測定可）／⛔=本環境で測定不可（実機/別環境）／—=非対応・対象外

---

## 1. API/テスト 合格基準（green baseline）

| Profile | Target | API（auto_code 20分割） | check_library | cfg-error | 最終確認 | 出典/コマンド |
|---|---|---|---|---|---|---|
| FMP | **zybo_z7_gcc**（主） | ✅ 20/20 | ✅ exc/int/timer | ✅ OK=159（許容 `DEF_INH_c`） | 2026-06-13 実測 | `bash scripts/ci_run_fmp.sh` → `PASS=182 FAIL=0` |
| FMP | **linux_gcc**（副・native） | ⚠ **13/20**（残7＝§3） | ✅ int／— exc（注1）／— timer（注2） | ⚠ POSIX OK=149/160（注3） | 2026-06-13 実測（API）/2026-06-08（cfg） | `TTSP_TARGET_NAME=linux_gcc bash scripts/ttsp_parallel_api.sh ../fmp3/ FMP obj_fmp_posix 20` |
| FMP | imx8mm_evk_arm64_gcc | ⛔ 本環境測定不可 | — | — | — | `USE_QEMU=false`＝実機/別環境。arm64 |
| ASP | **zybo_z7_gcc**（主） | ✅ 20/20 | ✅ exc/int/timer | ✅ OK=113/0 | 2026-06-13 実測 | `bash scripts/ci_run.sh` → `PASS=143 FAIL=0`（scratch 7 含む） |
| ASP | lpc55s69evk_gcc（M33） | ⛔ 本環境測定不可 | — | — | — | 実機（Cortex-M33）。asp3_core 後段の雛形 |
| ASP | nucleo_f401re_gcc（M4） | ⛔ 本環境測定不可 | — | — | — | 実機（Cortex-M4） |
| HRP | zybo_z7_gcc | ✅ **20/20** | ✅ exc/int/timer | ✅ OK=113/0 | 2026-06-13 実測 | `bash scripts/ci_run.sh HRP` → `PASS=136 FAIL=0`（完全グリーン） |
| HRP | zcu102_r5_gcc（R5） | ✅ **20/20**（注7：ATT_PMA 1件を能力差で除外済） | ✅ exc/int/timer | ❓ 未測定 | 2026-06-14 実測 | `TTSP_TARGET_NAME=zcu102_r5_gcc PAR_GROUPS=6 bash scripts/ttsp_parallel_api.sh ../hrp3/ HRP obj 20`（要 upstream QEMU11 aarch64・`parallel_simulation()`。`exclude_tests.txt` 自動適用） |
| HRMP | zybo_z7_gcc | ⚠ **14/20**（注6） | ✅ exc/int/timer | ✅ OK=156（許容 `DEF_INH_c`） | 2026-06-13 実測 | `bash scripts/ci_run.sh HRMP` → `PASS=173 FAIL=6`（FAIL=API注6の既知） |

> **統一ランナー**：4プロファイルとも **`bash scripts/ci_run.sh <ASP|FMP|HRP|HRMP>`**（zybo・QEMU）で実行可。
> 末尾に正規化 `VERDICT:` 行（STATUS のベースライン比較）を出す。`ci_run.sh`（引数なし=ASP）／`ci_run_fmp.sh`
> は後方互換で残置。`RESULT` は厳密合否（HRMP の既知 build失敗も FAIL に数える）、`VERDICT` は退行判定
> （HRMP は API=14/20 でも `OK(baseline)`）。linux_gcc は native のため `ttsp_parallel_api.sh` を直接使う。
>
> **基本方針**（`DIVERGENCE_MAP.md`）：**主ターゲットは zybo_z7_gcc（QEMU）**。FMP linux_gcc は副次・
> 実装不安定扱い。HRMP3/HRP3 対応は後回し。「zybo で緑なら POSIX 固有の残は深追いしない」。

---

## 2. カバレッジ（分岐 C1, gcov・参考）

| Profile | C1（all＝BB+WB） | 出典 | 備考 |
|---|---|---|---|
| ASP | 1373/1379 ≈ 99.6% | `docs/ASP/ALL_COVERAGE.md` | simt スイート込み |
| FMP | 1550/1597 ≈ 97.1% | `docs/FMP/ALL_COVERAGE.md` | bb=1533/1597 |
| HRMP | branch 82.1%（line 91.3%） | `docs/HRMP/COVERAGE_STATUS.md` | check_library+API20分割 |
| HRP（zybo） | branch 81.7%（line 89.4%） | `docs/HRP/COVERAGE_STATUS.md` | 19/20集計 |
| HRP（**zcu102_r5**／R5・QEMU） | branch 81.2%（line 89.5%） | `docs/HRP/COVERAGE_R5.md`（注8） | check_library 3/3＋API 18/20。upstream QEMU |

> 計測条件は各 `BB_COVERAGE.md`（`-O2`＋インライン抑制＋`-DNDEBUG`）。`scripts/coverage_gcov_<prof>.sh`。
> R5（zcu102_r5_gcc）は `scripts/coverage_gcov_hrp_r5.sh [smoke|bb|all]`（upstream QEMU・semihosting）。

---

## 3. 既知残の正本（退行ではない＝判定時に除外してよい）

### FMP linux_gcc — API 残7グループ（DIV=20。**群番号は分割依存**＝該当テスト名/理由で同定すること）
| 該当テスト/系 | 症状 | 理由（ターゲット特性） |
|---|---|---|
| `clr_int` 異常系（複数群） | 異常系で `E_OK` が返る | グローバルIRC＝割込み番号異常系がローカルIRC前提と不一致 |
| `prb_int` | `E_OBJ(-41)` vs 期待 `E_PAR` | 同上 |
| `CRE_TSK`（stk 検査系） | `rtsk.stk==指定` 不成立 | `USE_TSKINICTXB`（stk 非保持）ターゲット |
| `adj_tim`（時刻調整系） | systim 値ずれ | `FUNC_TIME=false`＝実時間（CLOCK_MONOTONIC）駆動で時刻停止不可 |

※ 直近の DIV=20 実測では失敗群＝`{3,6,11,12,13,15,19}` で安定（暫定版ベースライン `fmp3_git` と一致）。
**この7群以外が落ちたら退行を疑う**。出典：`DIVERGENCE_MAP.md` E節。

### FMP linux_gcc — cfg-error 残10件（POSIX固有）
`DEF_ICS`系7（`OMIT_ISTK`）／`CRE_TSK_d-2,d-3,e`（スタック指定不可）。出典：`DIVERGENCE_MAP.md` E節 B。

### 全プロファイル共通の許容残
`DEF_INH_c`（ASPテスト×FMP/HRMPプロファイル相互作用。`ci_run_fmp.sh` の `CFGERR_ALLOW_NG` 既定）。

---

## 注

- **注1（FMP linux_gcc の exception check 未対応）**：共有の
  `library/FMP/check_library/exception/out.cfg` が `TTSP_EXCNO_C` を要求するが、
  `library/FMP/target/linux_gcc/ttsp_target_test.h` が未定義のため**ビルド不可**（zybo は定義あり）。
  → 詳細は `docs/TARGETS.md`。
- **注2**：`FUNC_TIME=false` のため timer check はそもそも対象外。
- **注3**：cfg-error は 2026-06-08 の TESRY 更新後の値（POSIX OK=149/160）。
- **注4**：HRP API は本セッション実測で並列ドライバ（`ttsp_parallel_api.sh`，2026-06-09 で HRP 対応）が
  動作し **20/20 緑**（QEMU・execute.log 実体確認）。旧 `docs/HRP/COVERAGE_STATUS.md` の「19/20集計／
  並列未対応」は更新前の記述。check_library/cfg-error は未測定。
- **注5**：HRMP は `DEF_INH_c` ほか（`docs/HRMP/COVERAGE_STATUS.md`／`DIVERGENCE_MAP.md` C）。
- **注7（HRP zcu102_r5 20/20＝ATT_PMA 除外後）**：2026-06-14 実測。check_library exc/int/timer 緑、
  API **20群すべて** QEMU(`xlnx-zcu102`/Cortex-R5)で All check points passed（green 20/20、execute.log 実体確認）。
  - **能力差テストの除外**：ATT_PMA（物理メモリ領域・TESRY `type: PHYSICAL_MEMORY`）は MPU(PMSAv7) が
    アドレス変換を持たず原理的に実現できない（`out.cfg: E_NOSPT`。kernel `chip_design.md §「意図的な割切り」4項`／
    `target_user.txt`「ATT_PMA非サポート」）。HRP で ATT_PMA を生む唯一の元 `api_test/HRP/sample/hrp_parameter.yaml`
    を、ターゲット依存の除外リスト **`library/HRP/target/zcu102_r5_gcc/exclude_tests.txt`** で TTSP 生成から外す
    （`scripts/ttsp_parallel_api.sh` が `grep -vF` で適用・除外件数をログ表示。yaml 本体は削除せず zybo には不影響）。
  - 旧 19/20（除外前）は「残1群が ATT_PMA で build 不可」だったもの。**ファイル欠落＝コミット忘れではなく R5/MPU の
    能力差**。除外により対象内テストは 20/20 完全グリーン。実行には upstream QEMU 11（aarch64）が必要（8.2.2 不可）。
- **注8（HRP zcu102_r5 gcov カバレッジ）**：2026-06-14 実測。R5（Cortex-R5／PMSAv7 MPU）の
  ターゲット依存部に gcov 対応を追加（`hrp3/target/zcu102_r5_gcc` の Makefile.target／
  target_kernel_impl.c／target_ldscript.trb／target_mem.cfg＋chip 側 `arch/arm_gcc/zynqmp_r5/
  chip_ldscript.trb` の `GenerateProvide` フック呼出し）して計測可能にした。upstream QEMU
  （`xlnx-zcu102`/aarch64）を `-semihosting` 起動し，`target_exit` のセミホスティング終了で
  `.gcda` をホストへ直接書き出す。**line 89.5%／branch 81.2%**（check_library 3/3＋API 18/20）で
  **zybo（89.4%／81.7%）と同等**。計測対象外の2群＝(a) **group17：ATT_PMA 非サポート**（R5/MPU の
  能力差。非gcov でも build 不可＝注7と同根）、(b) **group19：gcov 計装による memory objects overlap**
  （gcov 計装で各保護ドメインのコード/データが約2倍に膨張して保護ドメイン境界が重なる。
  **zybo HRP/HRMP でも同じ gcov 計装時に group14/17/19 が overlap で脱落する既知事象**＝R5/MPU 固有
  ではなく gcov×保護ドメインの共通制約。R5 では PMSAv7 の 2のべき乗アラインで更に増幅。DDR 拡大では
  解消せず）。gcov 時のみ DDR を 16MB→64MB（`#ifdef
  TOPPERS_ENABLE_GCOV`）に拡大して大きいテストの DDR overflow を回避（非gcov の配置は不変）。
  実行: `bash scripts/coverage_gcov_hrp_r5.sh bb`（要 upstream QEMU 11 aarch64）。
- **注6（HRMP zybo 14/20 の内訳）**：本セッション実測。**5群が link 失敗**＝
  `undefined reference to chg_spr`（HRMP3 **3.4 にサブ優先度API `chg_spr` が無い**のに TESRY が
  chg_spr 系を生成。プロファイル×仕様差＝3.4 と 3.7 の差）。残1群は実行時 NG。
  HRMP は「後回し」方針（`DIVERGENCE_MAP.md`）で専用 CI 無し。要セットアップ精査。

---

## 更新手順

1. 値を変えるときは**実測コマンドを回し**、`PASS=…/FAIL=…` や `GREEN=N/20` を本表に転記
   （「通るはず」で更新しない＝`execute.log` の合否が根拠：`AGENTS.md` §4）。
2. **最終確認日**と**出典/コマンド**を必ず併記。❓は測定したら ✅/⚠ に更新。
3. 既知残が増減したら §3 を更新（群番号ではなく**テスト名・理由**で書く）。
4. カバレッジは `scripts/coverage_gcov_<prof>.sh` 後に §2 と各 `BB/ALL_COVERAGE.md` を更新。

> 関連：能力（QEMU/FUNC_TIME/IRC/例外機構/非対応）は **`docs/TARGETS.md`**。
> 仕様差分・改変台帳は `DIVERGENCE_MAP.md`。
