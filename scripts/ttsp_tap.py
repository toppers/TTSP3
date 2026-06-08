#!/usr/bin/env python3
"""
ttsp_tap.py -- TTSP3 execute.log → TAP 13 / structured events (NDJSON)

Usage:
  # TAP (default): CI/エージェントが "ok / not ok" で合否判定
  python3 scripts/ttsp_tap.py obj_asp_gcov/api_test/auto_code_*/execute.log

  # ディレクトリ指定（execute.log を自動検索）
  python3 scripts/ttsp_tap.py --dir obj_asp_gcov/api_test [auto_code_4 ...]

  # 特定テストのみ抽出
  python3 scripts/ttsp_tap.py --filter wup_tsk ... execute.log

  # 構造化イベント (NDJSON): エージェントが EV= で挙動検証
  python3 scripts/ttsp_tap.py --events ... execute.log

  # 期待イベント列との照合
  python3 scripts/ttsp_tap.py --expect expected.json ... execute.log

Exit code: 0=全PASS, 1=FAIL/不一致あり
"""

import argparse
import json
import os
import re
import sys


# ---------------------------------------------------------------------------
# ログ解析
# ---------------------------------------------------------------------------

# execute.log の行パターン
_RE_START  = re.compile(r'^(\S+): Start$')
_RE_OK     = re.compile(r'^(\S+): OK$')
_RE_CP     = re.compile(r'^Check point (\d+) passed\.$')
_RE_FINISH = re.compile(r'^All check points passed\.$')
_RE_ERR    = re.compile(r'^## (.+)$')


def parse_log(path: str) -> list[dict]:
    """
    execute.log を解析し、テストケースリストを返す。

    各要素:
        name    : テストケース名 (例 "ASP_task_sync_wup_tsk_W_c")
        group   : グループ名    (例 "auto_code_12")
        ok      : bool
        cps     : 通過したチェックポイント番号リスト
        errors  : "## " 行のリスト（失敗理由）
    """
    group = os.path.basename(os.path.dirname(os.path.abspath(path)))
    tests = []
    current = None
    cps: list[int] = []
    errors: list[str] = []

    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\r\n")

            m = _RE_START.match(line)
            if m:
                current = m.group(1)
                cps = []
                errors = []
                continue

            m = _RE_OK.match(line)
            if m and current == m.group(1):
                tests.append(dict(name=current, group=group, ok=True,
                                  cps=list(cps), errors=[]))
                current = None
                continue

            m = _RE_CP.match(line)
            if m and current:
                cps.append(int(m.group(1)))
                continue

            m = _RE_ERR.match(line)
            if m:
                msg = m.group(1)
                errors.append(msg)
                if current:
                    tests.append(dict(name=current, group=group, ok=False,
                                      cps=list(cps), errors=list(errors)))
                    current = None
                continue

    return tests


def _classify_error(errors: list[str]) -> str:
    """エラー種別を返す（TAP / events の severity 欄用）."""
    for e in errors:
        if "caused a timeout" in e:
            return "timeout"
        if "Unexpected check point" in e:
            return "wrong_checkpoint"
        if "Assertion" in e:
            return "assertion"
        if "Unexpected value" in e:
            return "value_mismatch"
        if "Unexpected error" in e:
            return "ercd_mismatch"
        if "Internal inconsistency" in e:
            return "internal_error"
    return "unknown"


# ---------------------------------------------------------------------------
# TAP 13 出力
# ---------------------------------------------------------------------------

def emit_tap(all_tests: list[dict], out=sys.stdout) -> bool:
    """
    TAP 13 形式を出力し、全PASS なら True を返す。

    フォーマット:
        TAP version 13
        1..N
        ok 1 - auto_code_4/ASP_semaphore_wai_sem_i_2_3
        not ok 2 - auto_code_4/ASP_staticAPI_DEF_EXC_d
          ---
          severity: timeout
          message: 'ttsp_wait_check_point(529) caused a timeout'
          last_checkpoint: 528
          checkpoint_count: 2
          ...
    """
    print("TAP version 13", file=out)
    print(f"1..{len(all_tests)}", file=out)
    all_pass = True

    for i, t in enumerate(all_tests, 1):
        label = f"{t['group']}/{t['name']}"
        if t["ok"]:
            print(f"ok {i} - {label}", file=out)
        else:
            all_pass = False
            print(f"not ok {i} - {label}", file=out)
            print("  ---", file=out)
            print(f"  severity: {_classify_error(t['errors'])}", file=out)
            for e in t["errors"]:
                # YAML-safe: シングルクォートで囲む（'内の'は''にエスケープ）
                safe = e.replace("'", "''")
                print(f"  message: '{safe}'", file=out)
            if t["cps"]:
                print(f"  last_checkpoint: {t['cps'][-1]}", file=out)
                print(f"  checkpoint_count: {len(t['cps'])}", file=out)
            print("  ...", file=out)

    return all_pass


# ---------------------------------------------------------------------------
# 構造化イベント出力 (NDJSON)
# ---------------------------------------------------------------------------

def emit_events(all_tests: list[dict], out=sys.stdout) -> bool:
    """
    NDJSON 形式でイベント列を出力する。1行 = 1JSON オブジェクト。

    イベント種別:
        GROUP_START / GROUP_END
        TEST_START / TEST_PASS / TEST_FAIL
        CP            : チェックポイント通過

    "T" フィールド: シーケンス番号（QEMU からリアルタイムクロックが
                    取れないため、ログ内の通過順序で代替）
    """
    seq = 0

    def ev(**kwargs):
        nonlocal seq
        seq += 1
        print(json.dumps({"T": seq, **kwargs}, ensure_ascii=False), file=out)

    last_group = None
    all_pass = True

    for t in all_tests:
        if t["group"] != last_group:
            if last_group is not None:
                ev(EV="GROUP_END", GROUP=last_group)
            ev(EV="GROUP_START", GROUP=t["group"])
            last_group = t["group"]

        ev(EV="TEST_START", NAME=t["name"], GROUP=t["group"])
        for cp in t["cps"]:
            ev(EV="CP", N=cp)

        if t["ok"]:
            ev(EV="TEST_PASS", NAME=t["name"], CPS=len(t["cps"]))
        else:
            all_pass = False
            ev(EV="TEST_FAIL",
               NAME=t["name"],
               SEVERITY=_classify_error(t["errors"]),
               ERRORS=t["errors"],
               LAST_CP=t["cps"][-1] if t["cps"] else None)

    if last_group is not None:
        ev(EV="GROUP_END", GROUP=last_group)

    return all_pass


# ---------------------------------------------------------------------------
# 期待イベント列との照合
# ---------------------------------------------------------------------------

def _load_expected(path: str) -> dict:
    """
    期待イベント JSON を読む。

    形式例:
    {
      "ASP_task_sync_wup_tsk_W_c": {
        "ok": true,
        "min_cps": 2
      },
      "ASP_staticAPI_DEF_EXC_d": {
        "ok": true,
        "cps": [527, 528, 529, 530, 531]
      }
    }

    キー省略時は照合をスキップ。
    """
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def emit_expect_diff(all_tests: list[dict], expected: dict,
                     out=sys.stdout) -> bool:
    """
    期待列と実際を照合し TAP 形式で出力。
    expected に含まれないテストは skip (# SKIP) として出力する。
    """
    targets = [t for t in all_tests if t["name"] in expected]
    print("TAP version 13", file=out)
    print(f"1..{len(targets)}", file=out)

    all_pass = True
    for i, t in enumerate(targets, 1):
        exp = expected[t["name"]]
        label = f"{t['group']}/{t['name']}"
        mismatches = []

        # ok/fail 照合
        if "ok" in exp and t["ok"] != exp["ok"]:
            mismatches.append(
                f"ok: expected={exp['ok']}, actual={t['ok']}"
            )

        # 最低CP数照合
        if "min_cps" in exp and len(t["cps"]) < exp["min_cps"]:
            mismatches.append(
                f"checkpoint_count: expected>={exp['min_cps']}, actual={len(t['cps'])}"
            )

        # CP列完全一致照合
        if "cps" in exp and t["cps"] != exp["cps"]:
            mismatches.append(
                f"cps: expected={exp['cps']}, actual={t['cps']}"
            )

        if not mismatches:
            print(f"ok {i} - {label}", file=out)
        else:
            all_pass = False
            print(f"not ok {i} - {label}", file=out)
            print("  ---", file=out)
            for m in mismatches:
                print(f"  mismatch: '{m}'", file=out)
            print("  ...", file=out)

    return all_pass


# ---------------------------------------------------------------------------
# ログ収集ヘルパー
# ---------------------------------------------------------------------------

def _collect_logs(args_logs: list[str], base_dir: str,
                  groups: list[str]) -> list[str]:
    """引数から execute.log パスのリストを構築する."""
    paths = []

    if args_logs:
        paths = list(args_logs)
    elif base_dir:
        if groups:
            for g in groups:
                p = os.path.join(base_dir, g, "execute.log")
                if os.path.isfile(p):
                    paths.append(p)
                else:
                    print(f"[warn] not found: {p}", file=sys.stderr)
        else:
            # base_dir 以下の auto_code_*/execute.log を全収集
            for entry in sorted(os.listdir(base_dir)):
                p = os.path.join(base_dir, entry, "execute.log")
                if os.path.isfile(p):
                    paths.append(p)

    if not paths:
        print("[error] execute.log が見つかりません。引数または --dir を確認してください。",
              file=sys.stderr)
        sys.exit(2)

    return paths


# ---------------------------------------------------------------------------
# メイン
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="TTSP3 execute.log → TAP 13 / NDJSON events",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("logs", nargs="*",
                    help="execute.log ファイル (複数可)")
    ap.add_argument("--dir", metavar="OBJDIR",
                    help="obj_asp_gcov/api_test など。省略時は logs 引数を使用")
    ap.add_argument("--groups", nargs="*", metavar="GROUP",
                    help="--dir と併用: 対象グループ名 (例 auto_code_4)")
    ap.add_argument("--filter", metavar="PATTERN",
                    help="テスト名に PATTERN を含むものだけ対象")
    ap.add_argument("--events", action="store_true",
                    help="TAP の代わりに NDJSON イベント列を出力")
    ap.add_argument("--expect", metavar="JSON",
                    help="期待イベント JSON ファイル (--events 不使用時)")
    args = ap.parse_args()

    logs = _collect_logs(args.logs, args.dir, args.groups or [])

    # 全ログ解析
    all_tests: list[dict] = []
    for path in logs:
        try:
            all_tests.extend(parse_log(path))
        except OSError as e:
            print(f"[warn] {e}", file=sys.stderr)

    # フィルタ
    if args.filter:
        pat = args.filter.lower()
        all_tests = [t for t in all_tests if pat in t["name"].lower()]

    if not all_tests:
        print("[warn] 対象テストケースが 0 件です。", file=sys.stderr)
        sys.exit(2)

    # 出力
    if args.events:
        ok = emit_events(all_tests)
    elif args.expect:
        expected = _load_expected(args.expect)
        ok = emit_expect_diff(all_tests, expected)
    else:
        ok = emit_tap(all_tests)

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
