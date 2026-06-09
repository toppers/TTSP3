# HRMP3 カバレッジ計測ステータス（後段・延期中）

> **状態（2026-06-09）：未計測（延期）。** ASP3（docs/ASP/）・FMP3（docs/FMP/）と同条件の
> gcov(C1)計測の前提が未整備のため延期する。計画上も HRP/HRMP は後段扱い
> （`AGENTS.md`、`docs/WHITEBOX_PLAN.md` §11 Q4）。
>
> 計測が可能になった時点で、本ファイルを ASP/FMP と同形式の
> `WB_COVERAGE.md`・`WB_UNREACHABLE.md` に置き換える。

---

## 計測に至らない理由

HRMP3 は **保護（HRP系）＋マルチプロセッサ（FMP系）の複合プロファイル**であり、
HRP3・FMP3 の双方のブロッカーを併せ持つと見込まれる。HRP3 で実測したブロッカー
（詳細は `docs/HRP/COVERAGE_STATUS.md`）は HRMP3 にもそのまま該当する：

### ブロッカー① GCOV計装インフラがカーネルに無い
- `../hrmp3_3.4/target/zybo_z7_gcc/` は `ENABLE_GCOV=0`（計装未移植）。
- 保護カーネルのため、リンカスクリプトが TECS テンプレート（`arch/gcc/ldscript.trb` 系）から
  構成時生成され、gcov セクション配置を保護ドメイン整合で組み込む必要がある。

### ブロッカー② TTSP3 で緑にビルドできない（GCOV無関係・より根本）
- HRMP3 も TECS の SVC プラグインを使用するため、HRP3 と同種の TECS 二重make問題が予想される。
- 保護多パスビルドのターゲット依存テストオブジェクトの link 統合も同様の課題になる見込み。
- 加えて FMP 系のマルチコア（QEMU `-smp 2`）駆動で、gcov ダンプを行うマスタPEと
  他PEの終了同期（FMP3 の `TOPPERS_TMASTER_PRCID` ガード相当）が必要。

> 注：本ステータスは HRP3 での実測ブロッカーからの**類推**を含む。HRMP3 単体のビルド実測は
> 未実施（HRP3 の bring-up を先行させる方針のため）。

---

## 計測を可能にするための作業順序（将来）

HRP3 の bring-up・GCOV移植（`docs/HRP/COVERAGE_STATUS.md`）で方法論を確立した後、
マルチコア固有の追加対応（gcov ダンプのPE同期、`-smp 2` 実行、`--filter /hrmp3/kernel/`）を
加えて展開する。

---

## 参考

- HRP3 ステータス（実測ブロッカー詳細）：`docs/HRP/COVERAGE_STATUS.md`
- ASP3 計測結果：`docs/ASP/`（98.3%）／FMP3 計測結果：`docs/FMP/`（93.9%）
- ホワイトボックス計画・後段方針：`docs/WHITEBOX_PLAN.md` §10/§11 Q4
- マルチコア gcov ダンプの雛形：`../fmp3_3.4/target/zybo_z7_gcc/target_kernel_impl.c`
  （`software_term_hook` 内の `TOPPERS_TMASTER_PRCID` ガード）
