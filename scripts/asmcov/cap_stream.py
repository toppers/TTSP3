#!/usr/bin/env python3
"""
cap_stream.py — QEMU の -d トレースを「サイズ上限つき」で受けるストリームフィルタ。

  mkfifo trace.fifo
  python3 cap_stream.py OUT CAP_BYTES < trace.fifo &
  qemu-system-arm ... -d in_asm,exec,nochain -D trace.fifo

長時間走るテスト（例: check_library/timer は連続計測系で「All check points passed」を
出さずアイドルでスピンし続け QEMU が自走終了しない）では `-d exec` のログが無制限に
膨張し，数十 GB に達してディスクを溢れさせる．

本フィルタは OUT に先頭 CAP_BYTES までを書き，**それ以降の入力は読み捨てる**（書かない）．
読み口は閉じない＝FIFO を塞がないので QEMU はブロックせず最後まで進行し，semihosting
終了か timeout で止まる（読み口を閉じると QEMU が write でブロックし結局 timeout まで
待つので逆効果．それを避けるため drain する）．CAP_BYTES（既定 256MiB 相当）は実テスト
ロジックの実行を十分に包含する大きさで，これを超えるのはアイドル反復のログのみ．
したがって捕捉されるのは「実行の先頭プレフィックス」＝実際に観測された命令/エッジのみで，
C0/C1 を過大報告しない（健全．極端に遅く初出する経路だけ僅かに過小になり得る）．

短時間で semihosting 終了するテスト（exception/interrupt 等）は CAP に達しないので，
全トレースがそのまま OUT に入る（挙動は素の -D と同じ）．
"""
import sys

def main():
    if len(sys.argv) != 3:
        sys.exit("usage: cap_stream.py OUTFILE CAP_BYTES")
    outpath = sys.argv[1]
    cap = int(sys.argv[2])
    written = 0
    src = sys.stdin.buffer
    CHUNK = 1 << 20  # 1 MiB
    with open(outpath, "wb") as out:
        while True:
            buf = src.read(CHUNK)
            if not buf:
                break
            if written < cap:
                room = cap - written
                out.write(buf[:room])
                written += min(len(buf), room)
                if written >= cap:
                    out.flush()
            # cap 到達後は読み捨て（QEMU をブロックさせないため読み続ける）

if __name__ == "__main__":
    main()
