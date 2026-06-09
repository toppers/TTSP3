# DIVERGENCE_MAP.md — 差分台帳

> **開発方針（2026-06-08）**：当面は **ASP3 / FMP3 を対象**に進め，**HRMP3 / HRP3 対応は後回し**。
> **基本ターゲットは zybo_z7_gcc（QEMU）**。POSIX(linux_gcc)は実装が不安定なため副次扱いとし，
> POSIX固有の残課題（FMP POSIX API残7グループ・cfg-error残10件）は zybo で緑なら深追いしない。
> HRMP3/HRP3 固有の課題（正系API立ち上げ・ttb.shのTECSオブジェクト自動導出化・
> HRMP3 zybo+QEMU ブート問題等）は本台帳に記録のみ残し，着手しない。
> 既着手の HRMP/HRP cfg-error 対応・set_dspflg 波及調査・FMP POSIXポート修正は完了済み（深追いしない）。

> 2つの差分を管理する。
> A) **仕様差分**：TTSP3 R3.1.0（仕様3.4.0）↔ 被テスト標準ASP3（3.7.2）
> B) **改変台帳**：TTSP3 R3.1.0 upstream からの本リポジトリの変更

---

## A. 仕様差分 3.4.0 → 3.7.2（当面の主作業）

ASP3変更履歴から、TTSP3のテスト/TTG/TESRYに影響しうる項目。状態欄を埋めながら潰す。

| 仕様変更 | 由来 | 影響範囲 | 状態 |
|---|---|---|---|
| 高分解能タイマ64bit化（HRTCNT型変更） | 3.4→3.5 | 時刻/タイマテスト・ターゲット依存タイマ | **影響なし確認**（2026-06-06。timerチェック＋時刻系APIテスト緑。要QEMUパッチ＝C表） |
| 静的API末尾 `;` 必須化 | 3.4→3.5 | 生成cfg・TESRY | **影響なし確認**（2026-06-06。TTG 3.2.0の生成cfgで全1788ファイルのビルド成功） |
| モノトニックタイマ拡張パッケージ追加 | 3.4→3.5 | time_manage テスト（任意） | 対象外（R3.1.0スイートにテストなし・任意パッケージ。実体は `extension/fch_mnt`＝API `fch_mnt`/`TOPPERS_SUPPORT_FCH_MNT`。**FMP3も非搭載確認**＝2026-06-08。標準の`monotonic_evttim`/`fch_hrt`とは別物。詳細SPEC37_PLAN P2-2） |
| サブ優先度の仕様変更 | 3.6→3.7 | task優先度系API（chg_spr/ENA_SPR） | **対応済確認**（2026-06-08。サブ優先度はASP3/HRP3では拡張パッケージ＝対象外、FMP3/HRMP3が標準搭載。FMPは chg_spr 65本＋ENA_SPR が既存し zybo autocode全緑＝3.7挙動と一致。NGKI3682廃止はCRE_MTX_F-c削除で対応済。詳細SPEC37_PLAN P2-1） |
| 優先度継承拡張パッケージ追加 | 3.6→3.7 | mutex 系（任意） | 対象外（任意パッケージ・既存mutex系テストは緑） |
| `CRE_XXX` のID衝突をエラー化 | 3.6→3.7 | 静的APIテスト（CRE_*のTESRY期待値） | **影響なし確認**（2026-06-06。コンフィグエラーテスト113/113 OK。TTG生成cfgはID一意で衝突せず） |
| 不正クラスIDのエラーチェック方法変更（静的APIへのチェック廃止→クラスの囲みに対してチェック） | FMP3 3.3.0 | コンフィグエラーテスト（`*_F-b`＝不正クラス指定の期待値） | **TESRY更新で対応済**（2026-06-08。`TTSP_INVALID_PRC_CLASS` 指定時の期待を `E_RSATR`→`E_ID`(illegal class) に変更．対象17件＝全`*_F-b`の不正クラス系＋`CRE_SPN_F-c`．zybo NG19→2／POSIX NG27→11．B表参照） |
| 【NGKI3682】の削除：サブ優先度使用のceilpri指定によるE_ILUSEエラーの廃止 | 3.6→3.7（サブ優先度仕様の刷新に伴う） | `CRE_MTX_F-c`（負テスト・FMP固有，`ASP:-`） | **精査確定（2026-06-08）→ テスト無効化の判断待ち**．旧spec3.4のNGKI3682「サブ優先度をサポートするカーネルでceilpriがサブ優先度使用の優先度ならE_ILUSE」を検証する負テスト．3.7では本制限が**削除**され当該組合せは有効（asp3 3.7.2／fmp3 3.4.0の`mutex.trb`は共にE_PAR範囲チェックのみでE_ILUSE検査なし．`asp3/doc/mutex_design.txt`はサブ優先度×ceiling昇格の相互作用を正式設計＝サポート対象）．CRE_MTX_F-cはエラー・警告0でkernel_cfg生成成功＝3.7で正当．cfg-errorフレームワークは「エラーコード期待」のみで「正常ビルド期待」を表現できないため，**テスト削除/無効化が必要**（期待値差替では対応不可） |
| objdumpダンプ形式対応 | 3.6→3.7 | cfg/ビルド（影響小） | **影響なし確認**（2026-06-06。全ビルド成功） |
| macOS/Linux POSIXシミュ追加 | 3.6→3.7 | 後段 host ターゲットで活用 | 後段 |
| **HRP/HRMP：システム状態アクセス許可ベクタの2分割＋強制操作の許可カテゴリ変更** | HRP3 3.3.0→3.4.0（`hrp3/doc/version.txt`「Release 3.3.0→3.4.0」§「システム状態のアクセス許可ベクタの仕様変更に対応」166-176行） | HRP/HRMP の API オートコード（保護ドメイン下の `sus_tsk`/`ter_tsk`/`rsm_tsk`/`chg_pri` の SAC・期待ercd・acvct assert） | **対応済（段階1+2実装・実測 line 89.4%/branch 81.7%、2026-06-09）**。①TTG `tools/ttg/common/bin/sys_state/CPUState.rb` の `SAC_SYS` 出力に sysstat2=`{TACP_SHARED×4}` を明示追加（層1）、②`api_test/HRP/task_term/ter_tsk/*_H_ex.yaml` 44ファイルの access2↔access3 を入替（層2・ter_tsk の acptn カテゴリ3.4変更に追従）。移行後 E_OACV 早期終了が完全に解消（19/19グループ `All check points passed.`）し、HRP line 79.6%→89.4%／branch 69.8%→81.7%（+9.8pp/+11.9pp）。根拠・詳細は `docs/HRP/TESRY_MIGRATION.md`・`docs/HRP/WB_UNREACHABLE.md §1`。HRMPも同一CPUState.rb共用のため同時対応（HRMP計測値は `docs/HRMP/` 参照） |

> **2026-06-06 全面実測**：ASP3 3.7.2 + zybo_z7_gcc + QEMU（要a9gtimerパッチ＝C表）で
> オートコード2202/2202・スクラッチ5/5・コンフィグエラー113/113 すべて緑。
> ただしツール側で ruby 3.x 対応が必要だった（B表のTTG改変）。
| ARMコア依存部見直し：`arm.c` 廃止（`arm.h`に統合） | 3.6→3.7 | `library/ASP/target/zybo_z7_gcc/ttsp_target.sh` の `KERNEL_COBJS_TARGET`（`objs/arm.o` 参照でリンク前に make が停止） | **対応済**（arm.o削除・改変明記。check_library 3モジュールのビルド成功を確認） |

> 3.4→3.7.2 全5区間の棚卸しと実装計画は **`docs/SPEC37_PLAN.md`** に集約（2026-06-08）。
> 3.5→3.6 の主項目（EXINF型変更＝影響なし確認）も同書に記載。
> 着手前に、3.7対応済みの公式TTSP3が無いか確認（重複作業回避）。

---

## B. 変更履歴（git移行以降）

TTSP3は**git-only管理**で、外部追従先（external upstream）は無い。
したがって本節は「upstream差分台帳」ではなく、**SVN由来のR3.1.0を起点とした変更の記録**（CHANGELOG的）。
詳細な履歴は git log / GitHub Releases が正本。ライセンス条件(2)「改変明記」の根拠も兼ねる。

| 起点/対象 | 変更種別 | 理由 | 状態 |
|---|---|---|---|
| TTSP3 R3.1.0（SVN由来） | 取り込み | git初期コミット（provenance。`docs/MIGRATION.md`） | 移行時 |
| （scaffold追加） | NEW | AGENTS/START/CI 等のgit管理基盤 | 済 |
| `library/ASP/target/zybo_z7_gcc/ttsp_target.sh` | 改変 | ASP3 3.7.0で廃止された `arm.c` 由来の `objs/arm.o` を `KERNEL_COBJS_TARGET` から削除 | 済（2026-06-06） |
| `tools/ttg/common/bin/CommonModule.rb` | 改変 | ruby 3.x対応：curses不在時に端末幅80へフォールバック／`Fixnum`→`Integer`（2箇所） | 済（2026-06-06） |
| `tools/ttg/common/bin/Config.rb` | 改変 | ruby 3.x対応：ruby 3.2で削除された `Object#=~` 対策にString判定ガード追加（3箇所） | 済（2026-06-06） |
| `scripts/ci_run.sh` | NEW（scaffold置換） | 非対話CIランナー実装：ttb.shを標準入力駆動でビルド→QEMU実行→合否判定（smoke/full） | 済（2026-06-06） |
| `.github/workflows/ci.yml` | 改変（scaffold具体化） | ASP3をZIP配布物で版固定取得、QEMU 11+a9gtimerパッチをソースビルド＆キャッシュ、ci_run.sh実行 | 済（2026-06-06） |
| `scripts/coverage_run.sh` `scripts/ttsp_coverage.py` `docs/COVERAGE.md` | NEW | カーネル非依存部の行カバレッジ計測（QEMU drcovプラグイン方式・ターゲット無計装）。初回計測 97.5% | 済（2026-06-06） |
| `library/FMP/test/ttsp_test_lib.c` | 改変 | FMP3 3.4.0対応：`make_non_runnable` のシグネチャ変更（3引数→2引数）に追従 | 済（2026-06-06） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target.sh` | 改変 | FMP3 3.4.0対応：`objs/arm.o` 削除（arm.c廃止）／`-S serial_cfg.o` 追加（serial設定データの分離先） | 済（2026-06-06） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target_test.h` | 改変 | FMP3 3.4.0対応：`TTSP_IPI_INTNO` を 0x1e（PPI）→ 0x04（SGI 4）に変更。`gicd_raise_sgi` はSGIのみ発行可能でPPI指定はSGI 14誤発火になるため（カーネルはSGI 0〜3使用） | 済（2026-06-06） |
| `tools/ttg/common/bin/process_unit/Execption.rb` | 改変 | FMP3 3.4.0対応：FMPでは `DEF_EXC` を例外発生PE専用クラス（`CLS_PRC<n>`）へ生成（コンフィギュレータが割付け可能プロセッサ＝例外発生PEを要求。マイグレーション可能クラス配置はE_RSATR）。固定クラス配置は旧FMP3でも正当＝後方互換 | 済（2026-06-06） |
| `api_test/FMP/staticAPI/DEF_ICS/DEF_ICS_F-{d-1-1,d-1-2,d-2,e,f-1-1,f-1-2,f-2}/out.cfg` | 改変 | FMP3 3.4.0対応：手書きcfg内の `DEF_EXC` を固定クラス `CLS_PRC1/CLS_PRC2` ブロックへ移動（上記TTG対応と同根） | 済（2026-06-06） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target.sh`（MAKE_OPT） | 改変 | `MAKE_OPT` を環境変数 `TTSP_MAKE_OPT` で上書き可能に（`ENABLE_GCOV=true` 投入用） | 済（2026-06-06） |
| `scripts/coverage_gcov_fmp.sh` `scripts/ttsp_gcov_report.py` | NEW | FMP GCOVカバレッジ計測（行＋分岐C1）。fmp3側のGCOV対応（メンテナ管理・`docs/COVERAGE.md` 参照）が前提 | 済（2026-06-06） |
| `scripts/ttsp_parallel_api.sh` | NEW | APIオートコードのグループ並列ドライバ（TTG＋make -j＋QEMUを並列化。ビルド約160分→約2分@32コア）。初回計測: FMP kernel/ 行96.4%・分岐81.5% | 済（2026-06-06） |
| `scripts/ttsp_parallel_cfgerr.sh` | NEW | コンフィグエラーテストの並列ドライバ（テストディレクトリ毎に独立のmake→期待エラーgrepを xargs -P 実行） | 済（2026-06-06） |
| `scripts/ci_run.sh`（並列化） | 改変 | ステージ2/4を並列ドライバへ置換。ローカルfull実行 約50分→34秒@32コア（PASS=141維持） | 済（2026-06-06） |
| `library/FMP/target/linux_gcc/`（4ファイル＋configure.yaml） | NEW | FMP3 POSIXターゲット依存部（FUNC_TIME=false・グローバルIRC・SIGFPE例外・ネイティブ実行） | 済（2026-06-07） |
| `tools/ttg`（TA_EDGE/int_trigger_atr） | 改変 | intatr許容値にTA_EDGE追加／設定キー`int_trigger_atr`新設（生成する全CFG_INTにOR。エッジ専用ターゲット用・既定は付加なし） | 済（2026-06-07） |
| `api_test/ASP/staticAPI/{DEF_INH/DEF_INH_e,CFG_INT/CFG_INT_d-1}.yaml` | 改変 | `intatr: TA_NULL`直書きを`ANY_ATT_INH`マクロ化（既定TA_NULLで従来ターゲット不変） | 済（2026-06-07） |
| `library/FMP/check_library/interrupt/out.cfg`＋zyboヘッダ | 改変 | CFG_INTトリガ属性を`TTSP_INT_TRIGGER_ATTR`マクロ化（zybo=TA_NULL，linux=TA_EDGE） | 済（2026-06-07） |
| `configure.sh`／`scripts/ttsp_parallel_api.sh` | 改変 | `TTSP_TARGET_NAME`環境変数でターゲット切替／linux_gccのネイティブ実行対応 | 済（2026-06-07） |
| `api_test/FMP/staticAPI/{ATT_INI,ATT_TER,CFG_INT,CRE_ALM,CRE_CYC,CRE_DTQ,CRE_FLG,CRE_ISR,CRE_MPF,CRE_MTX,CRE_PDQ,CRE_SEM,CRE_TSK,DEF_EXC,DEF_ICS,DEF_INH}/*_F-b/err_code.txt` ＋ `CRE_SPN/CRE_SPN_F-c/err_code.txt`（計17件） | 改変 | 3.4→3.7仕様差分対応：不正クラスID（`TTSP_INVALID_PRC_CLASS`）指定時の期待エラーを `E_RSATR`→`E_ID` に更新（FMP3 3.3.0の不正クラスIDチェック方式変更に追従）。検証：zybo cfg-error NG19→2・POSIX NG27→11（A表参照） | 済（2026-06-08） |
| api_test/* TESRY（残り） | 改変 | 3.4→3.7仕様差分対応の残：`CRE_MTX_F-c`（サブ優先度ceilpri・要精査）／POSIX固有のDEF_ICS・CRE_TSKスタック系（ターゲット特性） | 予定 |
| `scripts/ttsp_parallel_cfgerr.sh` | 改変 | HRP/HRMPプロファイル対応（KERNEL_COBJS/APPL_COBJSリスト追加。ttb.shより転記） | 済（2026-06-08） |
| `library/HRMP/test/ttsp_test_lib.c` | 改変 | HRMP3 3.4.0対応：`make_non_runnable` の3引数→2引数に追従（FMPと同根） | 済（2026-06-08） |
| `library/HRMP/target/zybo_z7_gcc/ttsp_target.sh` | 改変 | HRMP3 3.4.0対応：`objs/arm.o`削除（arm.c廃止）／CONFIG_OPTに`-S serial_cfg.o`追加（ASP/FMPと同根）。これらでHRMP cfg-error NG38→1（残DEF_INH_cはASPテスト×FMP/HRMPプロファイル相互作用＝E節C参照） | 済（2026-06-08） |
| `library/HRP/target/zybo_z7_gcc/ttsp_target.sh` | 改変 | HRP3 3.4.0対応：`objs/arm.o`削除（arm.c廃止） | 済（2026-06-08） |
| `scripts/ttsp_parallel_cfgerr.sh`（HRP分岐 APPL_COBJS_COMMON） | 改変 | HRP cfg-error の TECSアダプタ obj 名を tecsgen 1.8.0 実生成名へ修正。旧名 `tHRPSVCPlugin_sXxxSVCCaller_Yyy_eZzz_tecsgen.{c,o}` は当該 tecsgen が生成せず「No rule to make target …_tecsgen.c」で停止していた（3.4→3.7 の tecsgen 名称差分）。最小 out.cdl に対する gen/Makefile.tecsgen の実出力に合わせ `tHRPSVCBody_*`／`tHRPSVCCaller_*` 系へ置換。検証：`ttsp_parallel_cfgerr.sh ../hrp3_3.4/ HRP obj_hrp_cfgerr` で **OK=113 NG=0**（DEF_INH_c も含め全通過）。cfg-error は configurator 段で期待エラーを検出する負テストで、HRP集合は実質 ASP staticAPI（ASP で 113/113 確認済）＋HRP独自分0件のため divergence の新規カバレッジは無いが、HRP でも E_ID 等が正しく検出されることを確認 | 済（2026-06-08） |
| `ttb.sh`（HRP正系API用 APPL_COBJS_COMMON） | （後回し） | HRP正系APIテスト用の `tHRPSVCPlugin_*`（旧tecsgen名）が obsolete だが，正系cdlは tecsgen 1.8.0 で**27個**のTECSオブジェクトを生成（cfg-errorの12個より多い）．Makefile(line217)は `$(TECS_USER_COBJS) $(TECS_OUTOFDOMAIN_COBJS)` で自動導出できるが，ttb.shの`make APPL_COBJS=`コマンドライン上書きが抑制する設計課題．正しい対応は「TECSプロファイルでは自動導出に委ね，ハーネス固有obj(ttsp_test_lib.o/ttsp_mem_obj_*)のみ別途渡す」だが正系ビルドハーネス整備が前提＝**HRMP3/HRP3後回し方針により保留**（2026-06-08調査済） | 後回し |
| `scripts/ci_run_fmp.sh` ＋ `.github/workflows/ci.yml`（matrix化） | NEW/改変 | CIに FMP3 zybo を追加（A案）．ci.yml を ASP/FMP の matrix 並列に拡張（QEMU/ツールチェーン共通・ASP挙動不変）．FMP3 は `exshonda/fmp3`(commit固定)を git clone．ci_run_fmp.sh は check_library(3)＋API(20)＋cfg-error を判定し，cfg-error の既知残 DEF_INH_c を許容（CFGERR_ALLOW_NG）．ローカル検証 PASS=182/FAIL=0 | 済（2026-06-08） |
| `UPSTREAM_KERNEL.md`（FMP3行） | 改変 | FMP3版固定を記入：`exshonda/fmp3` commit 223ed7e（svn rev479 import＋修正） | 済（2026-06-08） |
| `library/ASP/target/zybo_z7_gcc/ttsp_target_test.{h,c}` ＋ `library/ASP/check_library/exception/out.{c,h,cfg}` | 改変 | 3.4→3.5差分（フェイタルデータアボートのCPU例外化・`EXCNO_FATAL`割付）の**専用テスト追加**：target に `TTSP_EXCNO_C=EXCNO_FATAL` と誘発マクロ `RAISE_FATAL_CPU_EXCEPTION`（SP不正化＋未定義命令＝asp3 core_test.h準拠）を追加し `ttsp_cpuexc_raise` に分岐追加。exceptionチェックを末尾拡張し `DEF_EXC(EXCNO_FATAL)` ハンドラ（復帰不可・`ttsp_check_finish`で終了）を追加。検証：zybo QEMU で cp1→13・`All check points passed.`、ASP full PASS=141/FAIL=0（cfg-error 113/113不変）。SPEC37_PLAN P1-3 参照 | 済（2026-06-08・ASP） |
| `library/FMP/target/zybo_z7_gcc/ttsp_target_test.{h,c}` ＋ `library/FMP/check_library/exception/out.{c,h,cfg}` | 改変 | 同上のFMP横展開（P1-3）：target に `TTSP_EXCNO_C=(0x10000\|EXCNO_FATAL)`（PE1）と `RAISE_FATAL_CPU_EXCEPTION` を追加し `ttsp_cpuexc_raise` に分岐追加。exceptionチェックの master PE クラス(CLS_PRC1)に `DEF_EXC(EXCNO_FATAL)` ハンドラ `exc_fatal` を追加し、バリア同期後に master(PE1)からフェイタルを発生。ハンドラ内のプロセッサID取得は `iget_pid` ではなく `sil_get_pid`（フェイタル経路ではカーネル状態が不整合となり得るため・`ttsp_mp_check_finish` と同じ取得元）。検証：zybo QEMU で `PE 1 : cp1→13`・`PE 1 : All check points passed.`、FMP full PASS=182/FAIL=0（cfg-error OK=159・既知残DEF_INH_cのみ）。SPEC37_PLAN P1-3 参照 | 済（2026-06-08・FMP） |
| `tools/ttg/common/bin/sys_state/CPUState.rb` | 改変 | HRP3 3.3→3.4 アクセス許可仕様対応（層1）：`SAC_SYS` の第2引数（sysstat2）を明示し `{TACP_SHARED, TACP_SHARED, TACP_SHARED, TACP_SHARED}` で全ドメイン許可。省略時は `TACP_KERNEL×4` 既定（`hrp3/kernel/kernel.trb` [NGKI0426]）となり、ユーザドメインからの強制操作が E_OACV になっていた。HRP/HRMP 共通（is_hrp?() 条件内の変更） | 済（2026-06-09） |
| `api_test/HRP/task_term/ter_tsk/*_H_ex.yaml`（44ファイル） | 改変 | HRP3 3.3→3.4 アクセス許可仕様対応（層2・HRP）：ter_tsk の許可カテゴリが 3.4.x で `acptn3`（管理操作）→`acptn2`（通常操作2）に変更されたため、各テストオブジェクトの access2↔access3 を入替。変更前は access3 に非KERNEL付与86件、access2 は全て KERNEL →変更後は逆。移行後 ter_tsk テスト起因の E_OACV 早期終了が消滅し、HRP line 89.4%/branch 81.7% を記録（ベースライン比+9.8pp/+11.9pp） | 済（2026-06-09） |
| `api_test/HRMP/task_term/ter_tsk/*_HM_ex.yaml`（80ファイル） | 改変 | HRP3 3.3→3.4 アクセス許可仕様対応（層2・HRMP）：HRP と同根。access3 に非KERNEL付与154件→access2 へ入替。移行後 E_OACV 早期終了が大幅解消し、HRMP line 91.0%/branch 81.3% を記録（ベースライン比+15.6pp/+17.6pp） | 済（2026-06-09） |
| `api_test/HRMP/spin_lock/{loc_spn,try_spn,unl_spn}/*_HM_ex.yaml`（5ファイル×5ケース） | 改変 | HRP3 3.3.2→3.4.0 spinlock sysstat1 対応（層3・HRMP 固有）：`loc_spn`/`try_spn`/`unl_spn` に `CHECK_ACPTN(sysstat1_acvct.acptn2, selfdom)` が追加（`hrmp3/doc/version.txt`）。DOM1 が呼び出し元のテストケース（HM1/3/4/5/7）の `pre_condition.CPU_STATE1` に `access1: TACP_KERNEL, access2: TACP(DOM1), access3: TACP_KERNEL, access4: TACP_KERNEL` を追加。修正後 auto_code_10/12: All check points passed。TOTAL HRMP line 91.3%/branch 82.1%（+0.3pp/+0.8pp）。副作用: `dis_int`/`ena_int` 等も acptn2 共有のため auto_code_16 の `dis_int_H-a` が E_OK に（設計上の競合） | 済（2026-06-09） |
| tools/ttg | 改変 | 3.7仕様への生成対応（上記 CPUState.rb 以外の残） | 予定 |
| library/*/target/* | NEW/改変 | asp3_core向けターゲット依存部追加（後段） | 後段 |

---

## C. 実行環境（QEMU）起因の課題

仕様差分でもTTSP3改変でもない、QEMUデバイスモデルと実機の挙動差。

| 課題 | 内容 | 対応 | 状態 |
|---|---|---|---|
| a9gtimer がENABLEビット無視でカウンタ前進 | QEMU 11.0.0 `hw/timer/a9gtimer.c` の `a9_gtimer_get_update()` がタイマ無効時もカウンタ読出し値を仮想時刻から計算するため、`ttsp_target_stop_tick()`（GTC停止）・`ttsp_target_gain_tick()`（COUNT書込み）が効かず timer チェックが失敗 | QEMU側にパッチ（`docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch`）。無効時は保持値 `s->counter` を返す＝実機準拠 | **対応済**（2026-06-06、timer チェック全パス確認） |

> パッチ適用手順：`cd ~/qemu/qemu-11.0.0 && patch -p1 < <ttsp3>/docs/patches/qemu-11.0.0-a9gtimer-honor-enable.patch && cd build && ninja qemu-system-arm`
> CIでQEMUを取得する場合も同パッチの適用が必要。

---

## D. FMP3対応の課題（解決済み）

| 課題 | 原因と解決 | 状態 |
|---|---|---|
| `sta_alm_d` 系テストのレース失敗 | **原因（実測で特定）**: `GTC_CTRL` は全体イネーブル（bit0・全PE共有）とコンペア/割込みイネーブル（PE毎バンク）が同居するレジスタ。TTSPの `ttsp_target_stop_tick()` が**ジャイアントロック無しの生RMW**で bit0 を落とすと、他PEのカーネル側RMW（`mpcore_gtc_set_cvr`/`target_hrt_clear_event`、glock下）が**読み置きした古い bit0=1 を書き戻し、停止したはずのGTCが再イネーブル**される。以後テスト全体で時刻が密かに進行し、`sta_alm(3µs)` が実時間3µs後に発火 → `almstat`/`lefttim` 検査と競争（フレーク）。HRTハンドラ発火カウンタと `GTC_CTRL=0x4207`（bit0=1）の事後ダンプで実証。**解決**: `ttsp_target_stop_tick`/`start_tick` のRMWを glock 保護（`library/FMP/target/zybo_z7_gcc/ttsp_target_test.c`）。検証: 単体40回＋全20グループ×10周（200ブート）全パス | **解決**（2026-06-06） |

> カーネル側への示唆（メンテナ向け）: `mpcore_gtc_set_cvr` のコメント「プロセッサ間排他制御をせずに呼び出して良い」は、**glock外からGTC_CTRLを触るコードが存在しない**ことが前提。bit0（共有）とバンクビットが同一レジスタに同居する構造上、ターゲット依存テストコード等がCTRLを触る場合は同じレースを踏むため、コメントへの前提条件の明記を推奨。

---

## E. FMP3 POSIXターゲット（linux_gcc）対応の状況（最終更新 2026-06-08）

TTSP3側の対応は完了（`library/FMP/target/linux_gcc/` 新設）。
**FUNC_TIME="false"**（実時間駆動・時刻停止不可），IRC=グローバル，例外=シグナル（SIGFPE）．

### 全テスト結果（fmp3側修正4件適用後）

| 項目 | 結果 |
|---|---|
| check_library 例外/割込み | ✅ 2/2 All check points passed（timerはFUNC_TIME=false対象外） |
| API TTG生成・cfg・ビルド | ✅ 20/20グループ（TTGにTA_EDGE対応・`int_trigger_atr` 追加で解消） |
| API 実行 | ✅ **13/20グループ緑（5周連続で安定）**．残7グループは下記の既知差分のみ（各1件） |
| コンフィグエラーテスト | ✅ TESRY更新後 **POSIX OK=149/160・zybo OK=159/161**（2026-06-08）．残NGは下記の要精査1件＋ターゲット特性のみ |
| 実行時間 | 全テスト一式 **約30秒**（check 2本＋API 20グループ＋cfg 160本）．prcid修正（fmp3側）による誤配送解消で**API実行が数分→1秒未満（200倍以上）** |

### fmp3側で解決済みの問題（2026-06-07〜08，計4件）

調査記録の正本は fmp3 リポジトリの issues/ に移動：
- カーネル共通部（set_dspflg 空レディキュー）：`fmp3/issues/20260607-1918_*_set-dspflg-empty-ready-queue/`
- POSIXポート3件（thread_ctrl RUN過渡＋述語待機／dispatch_and_migrate の stale runtsk／
  **prcid汚染（間欠ハングの根本原因・スレッド切替時のプロセッサID取得元の誤り）**）：
  `fmp3/target/linux_gcc/issues/20260607-2150_*_posix-smp-thread-switch/`

従来「残課題」としていた間欠ハング（eventflag等）・テスト内タイムアウトの
間欠フレーク（mempfix/dataqueue系）は，いずれも prcid 汚染の一過性誤配送が
原因と判明し，修正により消滅．

### API実行の残差分（7グループ・全て既知の仕様差/ターゲット特性）

1. clr_int系の異常系戻り値差（g6/g7/g14/g20: E_OK が返る）
2. prb_int の戻り値差（g15: E_OBJ(-41) vs 期待E_PAR）
3. ASP_staticAPI_CRE_TSK_h_1（g3）: `rtsk.stk==指定スタック` 期待 —
   USE_TSKINICTXBターゲット（stk未保持）では成立せず（TTG/TESRYの除外条件追加が将来課題）
4. adj_tim系の実時間タイミング依存（g9）

### コンフィグエラーテストNGの分類（当初 POSIX 27件／zybo 19件，2026-06-08）

**A. 仕様差分（zybo・POSIX共通＝ターゲット非依存）→ TESRY期待値の3.7系更新**
- **不正クラスID系17件（全`*_F-b`の不正クラス指定＋`CRE_SPN_F-c`）：対応済**．
  TTSP3の期待 `E_RSATR` を `E_ID`（illegal class）に更新．FMP3 3.3.0の仕様変更
  （不正クラスIDの検査を静的APIからクラスの囲みに対するチェックへ移行）に追従．
  → zybo NG19→2，POSIX NG27→11（B表に改変記録）
- **CRE_MTX_F-c（TA_CEILING×サブ優先度）：精査確定＝obsolete負テスト**．
  【NGKI3682】（サブ優先度使用ceilpri→E_ILUSE）が3.7のサブ優先度刷新で削除され，
  当該組合せは3.7で有効（kernel_cfg生成成功・エラー0）．FMP固有テスト（ASP:-）．
  cfg-errorフレームワークでは正常ビルド期待を表現できないため**テスト削除/無効化が必要**
  （A表参照．zybo/POSIX共通の残NG）

**B. POSIXターゲット特性（POSIXのみ，10件・残NG）**
- DEF_ICS系7件（a-1〜3,b,c,F-a,F-c）：OMIT_ISTK（非タスクコンテキストスタックは
  pthread管理）のため istksz/istk の検査が成立しない
- CRE_TSK_d-2/d-3/e：スタック指定不可ターゲット（USE_TSKINICTXB）のため
  stksz最小値・stkの検査が成立しない．
  ※付随発見：linux_gcc は CRE_TSK で stk≠NULL を黙って受理する
  （target_user.txt 制約(5)はNULL必須）．target_check.trb への検査追加が
  fmp3側の改善候補

**C. FMP/HRMP の残NG（1件）：DEF_INH_c — ASPテスト×FMPプロファイルの相互作用（精査済 2026-06-08）**
- DEF_INH_c は ASP の cfg-error テスト（`api_test/ASP/staticAPI/DEF_INH/DEF_INH_c`，
  共有 err_code.txt = `E_PAR`，NGKI3056：DEF_INH の inthdr が先頭番地として不正）．
- ASPプロファイル：意図どおり `E_PAR`（inthdr not aligned）→ **OK**．
- FMP/HRMPプロファイル：同テストが `E_RSATR` で先に停止 → grep不一致で NG．
  原因＝FMPの共有テスト囲み `ttsp_obj_head.cfg` は `CLASS(CLS_ALL_PRC1)`（全PE割付け）
  だが，テスト中の `CFG_INT(TTSP_INTNO_B)` の `TTSP_INTNO_B` は **PE1専用割込み**
  （0x10000|0x11）．「クラスの割付け可能プロセッサは割込み要求先の部分集合」という
  FMPマルチプロセッサ制約に違反し，DEF_INH の E_PAR より先に CFG_INT の E_RSATR が発火．
- 判定：**カーネルバグでも単純な3.4→3.7差分でもない**．ASPテストをFMPプロファイルで
  流用した際のプロファイル相互作用．err_code.txt は ASP/FMP 共有（E_PAR は ASP で正当）
  のため期待値差替では修正不可．FMP固有の割込み負テストは `DEF_INH_F-a`〜`F-d` が担う．
  zybo基準方針により**文書化のみ（残置）**．

---

## 更新手順

1. **カーネル**更新時は `UPSTREAM_KERNEL.md` の版を更新し、A表で影響を洗う（カーネルはSVN・別管理）
2. **TTSP3本体**はgit-onlyのため外部マージは無い。変更はPR→`main`、節目で **GitHub Releases/タグ**
3. 改変ファイルには改変した旨を明記（ライセンス条件(2)）
