/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 *
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2018 by FUJI SOFT INCORPORATED
 *
 *  上記著作権者は，以下の(1)〜(4)の条件を満たす場合に限り，本ソフトウェ
 *  ア（本ソフトウェアを改変したものを含む．以下同じ）を使用・複製・改
 *  変・再配布（以下，利用と呼ぶ）することを無償で許諾する．
 *  (1) 本ソフトウェアをソースコードの形で利用する場合には，上記の著作
 *      権表示，この利用条件および下記の無保証規定が，そのままの形でソー
 *      スコード中に含まれていること．
 *  (2) 本ソフトウェアを，ライブラリ形式など，他のソフトウェア開発に使
 *      用できる形で再配布する場合には，再配布に伴うドキュメント（利用
 *      者マニュアルなど）に，上記の著作権表示，この利用条件および下記
 *      の無保証規定を掲載すること．
 *  (3) 本ソフトウェアを，機器に組み込むなど，他のソフトウェア開発に使
 *      用できない形で再配布する場合には，次のいずれかの条件を満たすこ
 *      と．
 *    (a) 再配布に伴うドキュメント（利用者マニュアルなど）に，上記の著
 *        作権表示，この利用条件および下記の無保証規定を掲載すること．
 *    (b) 再配布の形態を，別に定める方法によって，TOPPERSプロジェクトに
 *        報告すること．
 *  (4) 本ソフトウェアの利用により直接的または間接的に生じるいかなる損
 *      害からも，上記著作権者およびTOPPERSプロジェクトを免責すること．
 *      また，本ソフトウェアのユーザまたはエンドユーザからのいかなる理
 *      由に基づく請求からも，上記著作権者およびTOPPERSプロジェクトを
 *      免責すること．
 *
 *  本ソフトウェアは，無保証で提供されているものである．上記著作権者お
 *  よびTOPPERSプロジェクトは，本ソフトウェアに関して，特定の使用目的
 *  に対する適合性も含めて，いかなる保証も行わない．また，本ソフトウェ
 *  アの利用により直接的または間接的に生じたいかなる損害に関しても，そ
 *  の責任を負わない．
 *
 *  $Id: ttsp_target_test.c 36 2019-03-18 06:16:26Z fujisft-shigihara $
 */

#include "kernel/kernel_impl.h"
#include "kernel/time_event.h"
#include "kernel/pcb.h"
#include <sil.h>
#include "arm64.h"
#include "ttsp_target_test.h"


/*------------------------------------------------------------------*/
/*  TTSP3ビルド時 _RUN_TTSP3_ を定義して全体をビルドする必要がある  */
/*  ttsp3/library/FMP/target/imx8mm_evk_arm64_gcc/ttsp_target.sh の */
/*  CONFIG_OPT で定義している                                       */
/*------------------------------------------------------------------*/



/* DEF_ICSテスト用 */
STK_T nontask1_stack[TTSP_NON_TASK_STACK_SIZE];
STK_T nontask2_stack[TTSP_NON_TASK_STACK_SIZE];

volatile HRTCNT stop_time, cval_time;
volatile HRTCNT temp_gtc = 0U;
volatile bool_t stop_tick = false;
volatile bool_t tick_int = false;
extern HRTCNT timer_hrtcnt;   /*  ttsp3   */
/*
 *  ティック更新の停止
 *  ※ティックは止められないため、割り込みマスクの操作とする
 */
void
ttsp_target_stop_tick(void)
{
    /*  停止中指定  */
    stop_tick = true;
    /*  カウンタ初期化  */
    temp_gtc = 0U;

    /*  割り込みマスク  */
    dis_int(INTNO_TIMER_PRC1);
#if defined(TOPPERS_TZ_S)
    CNTPS_CTL_EL1_WRITE((uint32_t)(CNTPS_CTL_IMASK_BIT));
#else
    CNTP_CTL_EL0_WRITE((uint32_t)(CNTP_CTL_IMASK_BIT));
#endif

    /*  現在カウンタ値読み込み  */
#if defined(TOPPERS_TZ_S)
	CNTPCT_EL0_READ(stop_time);
#else /* !TOPPERS_TZ_S */
	CNTPCT_EL0_READ(stop_time);
#endif /* TOPPERS_TZ_S */

    /*  タイムアップ取得    */
#if defined(TOPPERS_TZ_S)
	CNTPS_CVAL_EL1_READ(cval_time);
#else
	CNTP_CVAL_EL0_READ(cval_time);
#endif
}

/*
 *  ティック更新の再開
 *  ※ティックは止められないため、割り込みマスクの操作とする
 */
void
ttsp_target_start_tick(void)
{
    /*  停止中指定  */
    stop_tick = false;

    ena_int(INTNO_TIMER_PRC1);

#if defined(TOPPERS_TZ_S)
    CNTPS_CTL_EL1_WRITE((uint32_t)CNTPS_CTL_ENABLE_BIT);
#else
    CNTP_CTL_EL0_WRITE((uint32_t)CNTP_CTL_ENABLE_BIT);
#endif
}

/*  クロックカウンタをnsecへ変換    */
HRTCNT
hrt_get_temp_gtc(void)
{
	return((HRTCNT)(temp_gtc / timer_clock));
}

/*
 *  ティックの更新
 */
void
ttsp_target_gain_tick(void)
{
    HRTCNT  base_time, cur_time, comp_val;
    ER  err;

	/* 現在のGTC値，コンペア値，高分解能タイマ値を取得 */
#if defined(TOPPERS_TZ_S)
	CNTPS_CVAL_EL1_READ(comp_val);
#else
	CNTP_CVAL_EL0_READ(comp_val);
#endif
	temp_gtc = target_timer_get_count();    /*  タイマーカウンタ値取得  */
	base_time = hrt_get_temp_gtc();         /*  temp_gtcをusecへ変換    */

    /*  タイマーカウント処理    */
	while(1) {
		/* 高分解能タイマ値が2us進むまで，コピーしたGTC値をインクリメントする */
		temp_gtc++;
        /*  temp_gtcに対するカウンタ値取得  */
		cur_time = hrt_get_temp_gtc();

        /*  2usec経過した時点で終了 */
		if ((base_time + 2U) == cur_time) {
			/* 2us進む直前のGTC値を採用する(1usの最大範囲まで進める) */
			temp_gtc--;
			stop_time = temp_gtc;
			break;
		}
        /*  カウントアップしている場合、割り込みを入れる  */
        if( (temp_gtc == comp_val) && (tick_int == false))
        {
            err = ena_int(INTNO_TIMER_PRC1);
            stop_time = temp_gtc;
            ttsp_int_raise(INTNO_TIMER);
            err = dis_int(INTNO_TIMER_PRC1);
            break;
        }
	}   /*  while(1)    */

	/*  カウントは止まらないので何もしない  */

}

/*
 *  割込みの発生
 */
void
ttsp_int_raise(INTNO intno)
{
uint32_t regs, rege, cnt;

	raise_int(intno);

    /*  割り込みが入るまで待機  */
    regs=0;
    cnt=0;
    while(1)
    {
        /*  割り込みが入るとカウンタが止まる    */
#if defined(TOPPERS_TZ_S)
        CNTPS_CTL_EL1_READ(rege);
#else
        CNTP_CTL_EL0_READ(rege);
#endif
        if(rege == regs)
        {
            cnt++;
            if(cnt > 30)
                break;
        }
        else
        {
            regs = rege;
            cnt = 0;
        }
    }
}

/*
 *  CPU例外の発生
 */

void
ttsp_cpuexc_raise(EXCNO excno)
{
	if ((excno == TTSP_EXCNO_A) || (excno == TTSP_EXCNO_PE2_A) ||
	    (excno == TTSP_EXCNO_PE3_A) || (excno == TTSP_EXCNO_PE4_A)) {
		RAISE_CPU_EXCEPTION;
	}
}

/*
 *  CPU例外発生時のフック処理
 */
void
ttsp_cpuexc_hook(EXCNO excno, void* p_excinf)
{
}

/*
 *  割込み要求のクリア
 */
void
ttsp_clear_int_req(INTNO intno)
{
    clear_int(intno);
}
