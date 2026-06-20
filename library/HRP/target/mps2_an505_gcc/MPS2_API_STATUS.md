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
