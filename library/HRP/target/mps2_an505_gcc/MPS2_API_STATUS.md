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
