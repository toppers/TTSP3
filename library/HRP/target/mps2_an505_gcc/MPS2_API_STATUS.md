# TTSP3 api_test on mps2_an505 / HRP3 / QEMU — 全件実行の確定結果（2026-06-20）

ネイティブ flow（configure.sh/ttb.sh + tecsgen + TTG）は mps2_an505/HRP3/QEMU で**端から端まで確立・動作**。
TTG が api_test 全件（~1602）を生成し、obj_hrp_mps2_api に per-case ビルド、QEMU(semihosting)で実行できる。

## 確定分類（ビルド済 ELF 797件サンプルの QEMU 実行 ＋ ビルド集計）
- **PASS: 38**（カーネル系/単純構成）
- **FAIL: 758**（系統的 MemManage **MSTKERR**＝例外スタッキング失敗。`Excno=3 CFSR=0x92(MSTKERR+DACCVIOL+MMARVALID)
  MMFAR=0x38001fd8 PC=_kernel_core_exc_entry(0x100011c2) CONTROL=0(特権)`。**ユーザドメイン変種(_H1)で一様**に発生）
- **LOCKUP: 1**（cpuexc 系・構造的）
- **BUILD-FAIL: ~406**（out.cfg 1532 - ELF 1126。主因＝**Cortex-M33 の 8リージョン MPU 制約**(max 5/domain)。mprot1/3 と同根の構造的限界）

## 「全件通す」は未達。2つの blocker
1. **系統的 MSTKERR（最大・FAIL 758の主因）＝開発ギャップ（構造的でない）**
   ユーザドメイン api_test ケースで、例外（タイマ IRQ 等）の HW スタッキングが MMFAR=0x38001fd8 で MSTKERR。
   ＝**ユーザタスクのスタック/領域が例外スタッキングに耐えない dual-stack 堅牢性の不足**。
   hrp3/test の tprot/idle STKERR 修正（85fddd6/1acb6da/f47c649=idle専用スタック・twdtimer workaround除去）と
   **同族**だが、api_test の多様なユーザドメイン構成では別の経路で再発している。**追加の dual-stack 修正で
   回収可能な見込み（structural ではない）**。これが直れば PASS が大幅増の可能性。
2. **8リージョン MPU 制約（BUILD-FAIL ~406）＝構造的（Cortex-M33 HW）**
   1ドメインに 6+ メモリリージョンを要する api_test はビルド不可。mprot1/3 と同根。**回収不能**。
3. cpuexc 系（LOCKUP）＝割込みロック下 svc の構造的非対応。**回収不能**。

## 達成形の整理
ネイティブ flow・ターゲット依存部（int_raise/cpuexc/tick/TSKINICTXB）・TTG 全件生成・QEMU 実行は**確立**。
ただし「全件 PASS」は (1) ユーザドメイン MSTKERR（要 dual-stack 追加修正＝開発継続）と
(2) 8リージョン MPU 構造的制約 により**未達**。現状 PASS=38（単純構成）。
次の最大の一手＝**MSTKERR の dual-stack 修正**（idle/tprot 修正の延長線。これが api_test PASS を大きく押し上げる）。

## 再現コマンド
```
# ネイティブ flow（前 fork 確立）: TTG生成→per-caseビルド→obj_hrp_mps2_api
# 個別実行・分類:
for elf in obj_hrp_mps2_api/api_test/auto_code_*/hrp; do
  qemu-system-arm -M mps2-an505 -semihosting-config enable=on -kernel "$elf" -nographic -serial file:cap.txt
  grep -q 'All check points passed' cap.txt && echo PASS || echo FAIL
done
```

---

## 実回収の独立検証（2026-06-20・MUNSTKERR修正後）

現カーネル(asp3_tz_work mps2-an505-m4-wip 35fbbf1: svc_call_trampoline_priv=MUNSTKERR修正
+ _kernel_idle_stack=idle修正) + stack_share OFF(0ff2177) で実 api を QEMU 実測:

- **クラッシュ系(MSTKERR/MUNSTKERR)は解消＝回収 YES**: 実 api(auto_code_13, user-domain)が
  Excno を一切出さず CP1→CP2 進行(修正前は Excno=4 全滅)。default cross-domain 無回帰。
- **支配的天井 = 8リージョン MPU(想定より大)**: user-domain サンプル6件中5件が BUILD-FAIL
  `too many MPU regions (6/7/8) for protection domain 1 (max 5)`。多くの user-domain api は
  1ドメインに6〜8領域を要求し Cortex-M33(固定3+切替5=max5)で原理的にビルド不可。

### 案1(stack_share OFF)の天井と案2の優位（測定で確定）
- 案1 は per-task ustack を生むため、多タスクドメインが5領域超→**MUNSTKERR-FAIL を BUILD-FAIL に
  置換しただけ**のケースが多い(クラッシュは直るが region 予算を消費)。
- **案2(共有 ustack を per-domain 1 RW 領域化, mps2 trb 改修)の方が回収は多い**: 共有領域を1 region
  に保ちつつ RW 化すれば MSTKERR 解消＋region 予算節約＝≤5領域に収まる user-domain ケースが増える。
  ただしドメイン内スタック保護は緩む・trb 改修要。

### TTSP3 api 全件の到達形(確定)
- dual-stack クラッシュ(MSTKERR/MUNSTKERR)は全廃(真因修正済・検証済)。
- 字義の「全件 PASS」は **8リージョン MPU(user-domain api の多数)＋cpuexc-svc-under-lock** で構造的に不可。
- 達成形 = 「クラッシュ系は全廃、残りは 8リージョン MPU 構造的天井」。正確な全件 PASS 数は
  専用フルrebuild+run(~1602件/25分超, 別セッションのasp/fmp/hrmpとCPU非競合の時間帯)が必要。
  案2 を入れれば回収は更に増えるが、cpuexc と真に6+領域要のケースは構造的に残る。

---

## ★訂正と確定（2026-06-20・専用run）：旧「758 FAIL/38 PASS」は DIV バンドリング産物

これまで引用した PASS38/FAIL758/BUILD-FAIL~406 は **DIV=40 バンドル run の値で per-case ではない**。
DIV=40 は 1602 ケースを40分割するため各 auto_code_N が数十タスク/ドメインを1バイナリに詰める
（例: auto_code_13 = 607 check_point・4ドメイン・ドメイン1に46タスク）→ 5領域/domain を必ず超過し
BUILD-FAIL が量産される。**38 BUILD-FAIL/40 はバンドリングの人為的天井であり真の per-case 率ではない**。

### クラッシュ修正は大規模で実証（回収の本質的証拠）
現カーネル(35fbbf1, ELF に svc_call_trampoline_priv/_kernel_idle_stack 確認)+stack_share OFF で
ビルドできたバンドル(auto_code_13/14)は **MSTKERR/MUNSTKERR/Excno を0件**で実行し check point 進行
（CP2/CP9）。＝idle×2・nested-svc MUNSTKERR 修正は **607 check_point 規模でクラッシュ皆無**を実証。
NOFIN は巨大バンドル内の1ケース timing hang で残りが止まるため(クラッシュでない)。

### 正確な per-case 全件数（未確定・取得手段は明確）
- per-case 正確値には **DIV=1602(1ケース/バイナリ)**で全件 build+run が必要 ≈ 数時間(overnight)。1 fork 不可。
- 手段: `scripts/ttsp_parallel_api.sh ../hrp3 HRP obj_hrp_mps2_api 1602` 相当を別セッション(asp/fmp/hrmp)
  と CPU 非競合の時間帯に多時間 run。per-case 結果は各 auto_code_N/log に残る。

### 確定した到達形(質的・正確)
- **dual-stack クラッシュ系(MSTKERR/MUNSTKERR)は全廃**(607CP規模で実証, 真因修正済)。
- **真の per-case 天井 = 8リージョン MPU**(user-domain ケースの多数が6〜8領域要求)＋ cpuexc-svc-under-lock。
  Cortex-M33 HW 構造的・回収不能。字義の「全件 PASS」は構造的に不可。
- 正確な per-case PASS 数は DIV=1602 overnight run でのみ確定可能(本セッションでは時間制約で未実施)。

---

## ★確定：per-case 全件 QEMU 実行結果（2026-06-20, DIV=1602 build + 直接ELF実行）

DIV=1602 で全1602ケースをビルド(simulationドライバ不在のため自前ランナー /home/honda/run_api_elfs2.sh で
各 obj_hrp_mps2_api/api_test/auto_code_N/hrp を QEMU 直接実行)し per-case 分類:

| 分類 | 件数 | 割合 |
|---|---|---|
| PASS ("All check points passed") | 587 | 37% |
| FAIL-test (## アサーション失敗) | 585 | 37% |
| FAIL-cpu (Excno/fault) | 409 | 26% |
| NOFIN (timeout) | 12 | |
| LOCKUP (cpuexc) | 8 | |
| BUILD-FAIL (8リージョンMPU) | 1 | 0.06% |

### 確定した事実
- **8リージョン MPU は per-case の天井でない**(BUILD-FAIL 1件のみ)。DIV=40 バンドル run の「支配的天井」は
  バンドリング産物だった。**ほぼ全ケースがビルド可能**。
- **per-case PASS は ~37%(587/1602)**。失敗は timer/alarm に偏らず dataqueue/semaphore/task_manage/eventflag
  等の中核 API 全体に分散。同一 API グループ内で variant(_d_/_e_/_f_=呼出し文脈)別に PASS/FAIL が分かれる。
- パターン: **ARM-M 構造的制約(割込みロック下・非タスク文脈からの svc が SVCall マスクで HardFault 化、
  timer gain_tick 非対応)に該当する文脈 variant が FAIL-cpu/LOCKUP/FAIL-test に落ち、task 文脈 variant が PASS**。
- クラッシュ修正(idle×2/nested-svc MUNSTKERR)は大規模(auto_code_13=607CP)で crash-free 実証済だが、
  per-case では上記文脈構造的制約が支配的。

### 残課題(構造的 vs 真バグの切り分け)
FAIL-cpu 409 / FAIL-test 585 の厳密な内訳(ARM-M 文脈構造的=回収不能 / 真の M-profile dual-stack バグ=修正可)
には variant(文脈)別の追加分析が必要。task 文脈中心の ~37% は PASS で確定。

---

## ★切り分け確定：994失敗 = 構造的≈968 / 真バグ候補≈46（2026-06-20）

per-case 失敗を文脈・bundle 単位で分析(根拠: api_test yaml の do実行主体・CPU_STATE, /tmp/mps2_api_run2.txt):

- **構造的(回収不能)≈968**: 主因=**svc-from-handler/locked の HardFault エスカレーション**
  (SVCall 優先度=0 core_kernel_impl.c:266 ゆえ、アラーム/周期通知ハンドラ・CPU例外ハンドラ・loc_cpu
  (BASEPRI lock)文脈からの cal_svc が SVCall を取れず HardFault化。全FAIL-cpu構造ケースが同一署名
  Excno=3/CFSR=0/PC=svc直後)。＋timer(gain_tick)依存(alarm/cyclic/time)＋cpuexc。ARM-Mアーキ固有・
  TTSP3が非タスク文脈からの拡張サービスコールを多用する設計との相性。回収には全 cal_svc をカーネル
  直接呼出しへ書換える必要があり非現実的。
- **真バグ候補≈46**: 最有力=**probe_mem 欠如による E_MACV BusFault**。
  ユーザドメイン _H-b テストが不正ユーザポインタを渡し E_MACV を期待するが、カーネルが結果格納先の
  ユーザポインタをアクセス権検証せず書込み→Excno=5 BusFault/CFSR=0x8200(BFARVALID+PRECISERR)。
  PC=カーネルサービス内ストア(_kernel_ref_mem の str r2,[r4]@0x10009d0a, _kernel_get_mpf_block の
  str r3,[r1]@0x1000846a 等)。Cortex-A/R は MPU 捕捉で E_MACV 回収するが M-profile ポートに probe 機構なし。
  代表: ref_mem/get_mpf/pget_mpf/tget_mpf/ref_mtx/ref_sem/ref_pdq/snd_mbf の _H-b。
  → **probe_mem_read/write 相当(PMSAv8 でドメイン MPU リージョン権限照合)を実装すれば、
     api_test E_MACV系 ~18-20件(FAIL-cpu)＋FAIL-test のメモリアクセス系＋hrp3/test prbstr を単一修正で回収見込み**。
  残りの真バグ候補(NOFIN/LOCKUP 5件: ATT_INI/DEF_EXC/wait系)は個別調査要。

---

## ★probe_mem修正(A+a+C+B, asp3_tz_work 4b74ced)後の per-case 全件再測定(2026-06-20)

現カーネル(rundom全文脈+within_ustack)で全1602件を再ビルド+QEMU実行:

| 分類 | 修正前(run2) | 修正後(run3) | 増減 |
|---|---|---|---|
| PASS | 587 (37%) | **689 (43%)** | **+102** |
| FAIL-test | 585 | 515 | -70 |
| FAIL-cpu | 409 | 389 | -20 |
| LOCKUP | 8 | 8 | 0 |
| BUILD | 1 | 1 | 0 |

- **+102 PASS 回収**(E_MACV系 + ユーザタスクがスタックポインタをサービスに渡す一般パターン)。
  HRP _H の E_MACV/memory 系 51件が PASS 化、加えて probe を通る一般 user-domain ケースも回収。
  見積り ~18-20 を大きく超過(rundom/within_ustack は E_MACV 専用でなく user-pointer probe 全般を直すため)。
- 残失敗(FAIL-test 515/FAIL-cpu 389/LOCKUP 8 ≈912)の大半は構造的(svc-from-handler/locked の HardFault
  エスカレーション=SVCall prio=0, timer gain依存, cpuexc)で Cortex-M33 アーキ固有・回収不能。
- 確定: per-case PASS は probe_mem 対称化で 37%→43%。残りは ARM-M 構造的天井。

---

## ★B拡張(extsvc cdmid/svclevel, asp3_tz_work 21b7575)後の per-case 再測定(2026-06-20)

| run | 修正 | PASS | 効果 |
|---|---|---|---|
| run2 | probe前 | 587 (37%) | baseline |
| run3 | probe_mem(A+a+C+B-rundom, 4b74ced) | 689 (43%) | +102(実体ある回収) |
| run4 | B拡張(cdmid/svclevel, 21b7575) | 688 (43%) | ±0(correctnessのみ, -1はrunノイズ) |

**結論**: api per-case 回収の本命は probe_mem(+102)。**B拡張(cdmid アクセス制御)は per-case PASS を増やさない**
(±0)。理由: extsvc アクセス制御を exercise する api ケースは大半が handler 文脈(構造的に svc-under-handler で
HardFault)で、cdmid を直しても実行到達しない。B は「アクセス制御が正しく効く」correctness(arm_gcc対称・セキュリティ
的に正)・extsvc1 を CP27 まで前進・無回帰だが、構造的ブロックされたテスト数は動かさない。
api per-case 最終: PASS 688-689/1602(43%)。残りの大半は ARM-M 構造的天井(svc-under-handler/lock, timer, cpuexc)。

---

## ★再測定：per-case 全件 QEMU 実行（2026-06-21, 現行 arch＝thread-MSP 注入後）
asp3_tz_work の cpuexc/extsvc/sysman thread-MSP 注入（36021c8/05d201e/521f03f）後の共有 arch で
DIV=1602 再ビルド(1601/1602, BUILD-FAIL 1)＋QEMU(mps2-an505)全件直接実行・per-case 分類:
| 分類 | 旧(587, 06-20) | 現行 arch | 差分 |
|---|---|---|---|
| PASS | 587 (37%) | **758 (47.3%)** | +171 (+10.3pt) |
| FAIL-cpu | 409 | **8** | -401 |
| LOCKUP | 8 | **2** | -6 |
| FAIL-test | 585 | 833 | +248 |
| BUILD-FAIL | 1 | 1 | 0 |
- **thread-MSP 注入が「ロック下/非タスク文脈 svc → HardFault」クラス(旧 FAIL-cpu 409+LOCKUP 8)をほぼ一掃**
  (→8/2)。hrp3/test の cpuexc1-10/extsvc1/sysman2 PASS 化が per-case でも広域に波及。
- 従来クラッシュ(FAIL-cpu)ケースの多くが「完走するがアサーション失敗」(FAIL-test 585→833)へ軟化。
  ＝次のフロンティアは FAIL-test 833 の内訳(真の M-profile dual-stack バグ=修正可 vs 構造的天井)。
- EK-RA8M2 共有 arch の代理指標(ek_ra8m2/mps2 で arch コア共有・QEMU 結果の実機再現は確認済み)。
- 測定: DIV=1602 ネイティブビルド + /tmp/classify_mine.sh(qemu-system-arm 直接実行・12並列・timeout12s)。

## ★E_TMOUT クラスタ＝QEMU proxy アーティファクト確定（2026-06-21・EK実機検証）
per-case FAIL-test 833 のうち E_TMOUT ~32%(≈270) は「待機を別タスクの動作(送信/rel_wai/ras_ter/削除)で
解除するはずが先に tmo(極小, 例 trcv_pdq tmo=3=3us)が発火」。QEMU で決定的(10/10, -icount でも)。
**EK-RA8M2 実機検証(3/3 異機構)**: auto_code_1086(E_RASTER期待)/1085(E_RLWAI)/1090(E_OK) を ek_ra8m2_gcc で
ビルド・実機実行 → **いずれも All check points passed(PASS)**。＝QEMU/mps2 では E_TMOUT だが EK 実機では PASS。
- 根因: 3us という極小 tmo に対し、QEMU(mps2/M33 エミュ実行モデル)では解除側タスクが走る前に時間が進み
  tmo 発火。実機(M85 高速)は 3us 内に解除側が走り正解→PASS。HRT 較正は mps2/EK とも 1us で同一。
- **含意: E_TMOUT クラスタは EK 実機の欠陥でなく proxy アーティファクト。EK 実機の真の per-case 率は
  QEMU の 47.3% より高い**（E_TMOUT ~270 の相当数＋タイミング下流の Unexpected-CP の一部が EK では PASS）。
  粗推定: 758+270≈1028/1602≈64% 以上。
- 検証ビルド: asp3_tz_work/cw_hrp3_ra8m2/bek_<N>（ek_ra8m2_gcc・auto_code の out.* 流用）。

## Unexpected-CP クラスタの EK 実機検証（2026-06-21）：大半が実バグ（E_TMOUT と異なる）
QEMU で "Unexpected check point" FAIL の代表6件を ek_ra8m2_gcc でビルド・EK 実機実行:
| auto_code | カテゴリ | QEMU | EK 実機 |
|---|---|---|---|
| 1154 | pridataq/trcv_pdq | Unexpected CP0 | **PASS** (proxy) |
| 1031 | pridataq/psnd_pdq | Unexpected CP25 | wait_check_point(5) timeout = FAIL |
| 1214 | sample/messagebuf | Unexpected CP7 | wait_check_point(7) timeout = FAIL |
| 103 | dataqueue/fsnd_dtq | Unexpected CP0 | wait_check_point(12) timeout = FAIL |
| 102 | task_sync/wup_tsk | Unexpected CP0 | Unexpected check point 0 = FAIL |
| 101 | task_sync/sus_tsk | Unexpected CP5 | wait_check_point(5) timeout = FAIL |
- **6件中 EK PASS は 1件のみ**＝Unexpected-CP は **E_TMOUT と異なり大半が EK 実機でも実 FAIL**。
- EK での支配的失敗モード＝**`ttsp_wait_check_point(N) caused a timeout`**（協調する別タスクが期待 CP に到達しない＝
  タスク間協調/ディスパッチの実問題。タイミング非依存）。
- 含意: E_TMOUT(~270)は EK で回収されるが、**Unexpected-CP(~500)は大半が EK でも残る真の課題**。
  EK 真 per-case 率の上振れは E_TMOUT 分が主で、Unexpected-CP の回収は限定的(本サンプル 1/6)。
- 次の実数改善は Unexpected-CP の wait_check_point timeout 群＝タスク間協調の根因調査が対象(per-API・要深掘り)。

---

## ★タイマ停止モード横展開＋glue 修正で PASS 758→1539/1602（96.1%・2026-07-02 確定）

ASP mps2 で確立した対処（タイマ停止モード＝tick 制御の QEMU 成立）を HRP へ横展開。

**カーネル側**：hrp3_3.4.2 の target_timer.c（HRT 部は asp3 版と同一）へ同じ停止モードを適用
（`docs/patches/hrp3-mps2_an505-target_timer-test-stop-mode.patch`。asp3_tz_work main `0deba8e`
適用済み・asp3-tz へ `7725223` でマージ済み）。
**TTSP3 側（カーネル無改変分）**：
1. `TTSP_NOT_SET_INTNO` 0x10→0x30（ASP と同一のコピー痕＝SIO の CFG_INT 済み番号だった）
2. `sstk` アクセサの stk_top/stk_bottom 取り違え修正（ASP と同一バグ）
3. **共有 test lib の実バグ修正**：`library/HRP/test/ttsp_test_lib.c` の ref_tsk 検査で
   `pk_rtsk->sstksz` に二重代入（`ustksz` 未設定）→ USE_TSKINICTXB ターゲット全般に影響していた

### 結果（per-case 全 1602・厳密判定＝`All check points passed` マーカ必須）

| 区分 | 旧（06-21） | 今回 |
|---|---|---|
| **PASS** | 758（47.3%） | **1539（96.1%）** |
| BUILD-FAIL | ≈406 | **1**（ATT_PMA/DDR＝8リージョン MPU 非対応。exclude 候補） |
| 実行 FAIL | ≈438 | **62** |

**check_library timer も初の All passed**（従来「M-profile 構造的制約」→ 実は tick 制御不全）。
SIL（CP1-27）・int check は緑維持。

### 残 62 件の内訳（切り分け済み）
| クラスタ | 件数 | 性格 |
|---|---|---|
| **E_OACV（`_H_ex`＝他ドメイン変種）** | 47 | 構造的（テスト側 ACL 前提差＝`sysstat2_acvct`。`docs/HRP/BB_UNREACHABLE.md` §1 の既知） |
| ter_tsk_f 複合（Unexpected CP 0） | 8 | 要精査 |
| **INIRTN/TERRTN 文脈ハング** | 4 | ATT_INI_c/ATT_TER_c/sns_ker_a/sns_ker_b。INIRTN の最初の OK 以降で停止（決定的）。※エージェント集計では PASS 誤分類されていた分＝親検算で確定 |
| QEMU タイミング（sta_alm lefttim・act_tsk_d） | 2 | アーティファクト疑い |
| cal_svc_H-c（MemManage） | 1 | MPU 系 |

旧「BUILD-FAIL ≈406＝8リージョン MPU 制約（構造的・回収不能）」は**過大評価だった**
（現行カーネル＋glue では 1 件に収束）。データ：/tmp/hrpfix_results.tsv。
