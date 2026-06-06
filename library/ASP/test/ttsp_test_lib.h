/*
 *  TTSP3
 *      TOPPERS Test Suite Package 3
 * 
 *  Copyright (C) 2010-2011 by Center for Embedded Computing Systems
 *              Graduate School of Information Science, Nagoya Univ., JAPAN
 *  Copyright (C) 2010-2011 by Digital Craft Inc.
 *  Copyright (C) 2010-2011 by NEC Communication Systems, Ltd.
 *  Copyright (C) 2010-2020 by FUJI SOFT INCORPORATED
 *  Copyright (C) 2010-2011 by Industrial Technology Institute,
 *								Miyagi Prefectural Government, JAPAN
 * 
 *  上記著作権者は，以下の(1)～(4)の条件を満たす場合に限り，本ソフトウェ
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
 *  $Id: ttsp_test_lib.h 72 2020-03-19 08:08:03Z fujisft-shigihara $
 */

/* 
 *		テストプログラム用ライブラリ
 */

#ifndef TTSP_TEST_LIB_H
#define TTSP_TEST_LIB_H

#include <kernel.h>
#include <t_stddef.h>
#include <queue.h>
#include <sil.h>

#define TTSP_ASP

/*
 *  ターゲット依存の定義
 */
#include "ttsp_target_test.h"

/*
 *  メモリ保護向けの抽象化マクロ
 */

#define TTSP_ADJ_TIM(adjtim)							adj_tim(adjtim)
#define TTSP_SET_TIM(systim)							set_tim(systim)
#define TTSP_GET_TIM(p_systim)							get_tim(p_systim)
#define TTSP_STA_ALM(almid, almtim)						sta_alm((almid), (almtim))
#define TTSP_STA_CYC(cycid)								sta_cyc(cycid)
#define TTSP_ENA_INT(intno)								ena_int(intno)
#define TTSP_LOC_CPU()									loc_cpu()
#define TTSP_UNL_CPU()									unl_cpu()
#define TTSP_DIS_DSP()									dis_dsp()
#define TTSP_CHG_IPM(intpri)							chg_ipm(intpri)
#define TTSP_ROT_RDQ(tskpri)							rot_rdq(tskpri)
#define TTSP_ACT_TSK(tskid)								act_tsk(tskid)
#define TTSP_CHG_PRI(tskid, tskpri)						chg_pri((tskid), (tskpri))
#define TTSP_WUP_TSK(tskid)								wup_tsk(tskid)
#define TTSP_SUS_TSK(tskid)								sus_tsk(tskid)
#define TTSP_REL_WAI(tskid)								rel_wai(tskid)
#define TTSP_RAS_TER(tskid)								ras_ter(tskid)
#define TTSP_WAI_SEM(semid)								wai_sem(semid)
#define TTSP_TWAI_SEM(semid, tmout)						twai_sem((semid), (tmout))
#define TTSP_SIG_SEM(semid)								sig_sem(semid)
#define TTSP_INI_SEM(semid)								ini_sem(semid)
#define TTSP_SET_FLG(flgid, setptn)						set_flg((flgid), (setptn))
#define TTSP_INI_FLG(flgid)								ini_flg(flgid)
#define TTSP_SND_DTQ(dtqid, data)						snd_dtq((dtqid), (data))
#define TTSP_PSND_DTQ(dtqid, data)						psnd_dtq((dtqid), (data))
#define TTSP_TSND_DTQ(dtqid, data, tmout)				tsnd_dtq((dtqid), (data), (tmout))
#define TTSP_FSND_DTQ(dtqid, data)						fsnd_dtq((dtqid), (data))
#define TTSP_RCV_DTQ(dtqid, p_data)						rcv_dtq((dtqid), (p_data))
#define TTSP_PRCV_DTQ(dtqid, p_data)					prcv_dtq((dtqid), (p_data))
#define TTSP_TRCV_DTQ(dtqid, p_data, tmout)				trcv_dtq((dtqid), (p_data), (tmout))
#define TTSP_INI_DTQ(dtqid)								ini_dtq(dtqid)
#define TTSP_SND_PDQ(pdqid, data, datapri)				snd_pdq((pdqid), (data), (datapri))
#define TTSP_PSND_PDQ(pdqid, data, datapri)				psnd_pdq((pdqid), (data), (datapri))
#define TTSP_TSND_PDQ(pdqid, data, datapri, tmout)		tsnd_pdq((pdqid), (data), (datapri), (tmout))
#define TTSP_RCV_PDQ(pdqid, p_data, p_datapri)			rcv_pdq((pdqid), (p_data), (p_datapri))
#define TTSP_PRCV_PDQ(pdqid, p_data, p_datapri)			prcv_pdq((pdqid), (p_data), (p_datapri))
#define TTSP_TRCV_PDQ(pdqid, p_data, p_datapri, tmout)	trcv_pdq((pdqid), (p_data), (p_datapri), (tmout))
#define TTSP_INI_PDQ(pdqid)								ini_pdq(pdqid)
#define TTSP_UNL_MTX(mtxid)								unl_mtx(mtxid)
#define TTSP_INI_MTX(mtxid)								ini_mtx(mtxid)
#define TTSP_GET_MPF(mpfid, p_blk)						get_mpf((mpfid), (p_blk))
#define TTSP_PGET_MPF(mpfid, p_blk)						pget_mpf((mpfid), (p_blk))
#define TTSP_TGET_MPF(mpfid, p_blk, tmout)				tget_mpf((mpfid), (p_blk), (tmout))
#define TTSP_REL_MPF(mpfid, blk)						rel_mpf((mpfid), (blk))
#define TTSP_INI_MPF(mpfid)								ini_mpf(mpfid)


/*
 *  自己診断関数の型
 */
typedef ER (*BIT_FUNC)(void);

/*
 *  自己診断関数の設定
 */
extern void	set_bit_func(BIT_FUNC bit_func);

/*
 *  テストライブラリ用変数初期化
 */
extern void	ttsp_initialize_test_lib(void);

/*
 *  チェックポイント
 */
extern void	ttsp_check_point(uint_t count);

/*
 *  チェックポイントがcountになるのを待つ
 */
extern void	ttsp_wait_check_point(uint_t count);

/*
 *  完了チェックポイント
 */
extern void	ttsp_check_finish(uint_t count);

/*
 *	チェックポイント通過の状態取得
 */
extern bool_t	ttsp_get_cp_state(void);

/*
 *	チェックポイント通過の状態設定
 */
extern void	ttsp_set_cp_state(bool_t state);

/*
 *  条件チェック
 */
extern void	_check_assert(const char *expr, const char *file, int_t line);
#define check_assert(exp) \
	((void)(!(exp) ? (_check_assert(#exp, __FILE__, __LINE__), 0) : 0))

/*
 *  値チェック
 */
extern void	_check_value(const char *var, const char *expected_var, long_t act_var, const char *file, int_t line);
#define check_value(var, expected_var) \
	((void)((var) != (expected_var) ? (_check_value(#var, #expected_var, (long_t)(var), __FILE__, __LINE__), 0) : 0))

/*
 *  エラーコードチェック
 */
extern void	_check_ercd(ER ercd, const char *file, int_t line);
#define check_ercd(ercd, expected_ercd) \
	((void)((ercd) != (expected_ercd) ? \
					(_check_ercd(ercd, __FILE__, __LINE__), 0) : 0))


/*
 *  ref_tsk代替関数
 */
typedef struct t_ttsp_rtsk {
	STAT		tskstat;	/* タスク状態 */
	PRI			tskpri;		/* タスクの現在優先度 */
	PRI			tskbpri;	/* タスクのベース優先度 */
	STAT		tskwait;	/* 待ち要因 */
	ID			wobjid;		/* 待ち対象のオブジェクトのID */
	TMO			lefttmo;	/* タイムアウトするまでの時間 */
	uint_t		actcnt;		/* 起動要求キューイング数 */
	uint_t		wupcnt;		/* 起床要求キューイング数 */
	bool_t		raster;		/* タスク終了要求状態 */
	bool_t		dister;		/* タスク終了禁止状態 */
	ATR			tskatr;		/* タスク属性 */
	intptr_t	exinf;		/* タスクの拡張情報 */
	PRI			itskpri;	/* タスクの起動時優先度 */
	size_t		stksz;		/* スタック領域のサイズ */
	void		*stk;		/* スタック領域の先頭番地 */
	uint_t		porder;		/* 同一優先度タスク内での優先順位 */
	uint_t		mtxcnt;		/* ロックしているミューテックス数 */
} T_TTSP_RTSK;

extern ER ttsp_ref_tsk(ID tskid, T_TTSP_RTSK *pk_rtsk);
extern ER ttsp_ref_loc_mtx(ID tskid, uint_t order, ID *p_mtxid);


/*
 *  ref_sem代替関数
 */
typedef struct t_ttsp_rsem {
	uint_t	semcnt;		/* セマフォの資源数 */
	ATR		sematr;		/* セマフォ属性 */
	uint_t	isemcnt;	/* セマフォの初期資源数 */
	uint_t	maxsem;		/* セマフォの最大資源数 */
	uint_t	waitcnt;	/* 待ちタスクの数 */
} T_TTSP_RSEM;

extern ER ttsp_ref_sem(ID semid, T_TTSP_RSEM *pk_rsem);


/*
 *  セマフォの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_sem(ID semid, uint_t order, ID *p_tskid);



/*
 *  ref_flg代替関数
 */
typedef struct t_ttsp_rflg {
	FLGPTN	flgptn;		/* イベントフラグの現在のビットパターン */
	ATR		flgatr;		/* イベントフラグ属性 */
	FLGPTN	iflgptn;	/* イベントフラグのビットパターンの初期値 */
	uint_t	waitcnt;	/* 待ちタスクの数 */
} T_TTSP_RFLG;

extern ER ttsp_ref_flg(ID flgid, T_TTSP_RFLG *pk_rflg);


/*
 *  イベントフラグの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_flg(ID flgid, uint_t order, ID *p_tskid, FLGPTN *p_waiptn, MODE *p_wfmode);



/*
 *  ref_dtq代替関数
 */
typedef struct t_ttsp_rdtq {
	uint_t	sdtqcnt;	/* データキュー管理領域に格納されているデータの数 */
	ATR		dtqatr;		/* データキュー属性 */
	uint_t	dtqcnt;		/* データキューの容量 */
	uint_t	swaitcnt;	/* 送信待ちタスクの数 */
	uint_t	rwaitcnt;	/* 受信待ちタスクの数 */
} T_TTSP_RDTQ;

extern ER ttsp_ref_dtq(ID dtqid, T_TTSP_RDTQ *pk_rdtq);


/*
 *  データキュー管理領域に格納されているデータ参照関数
 */
extern ER ttsp_ref_data(ID dtqid, uint_t index, intptr_t *p_data);


/*
 *  データキューの送信待ちタスク参照関数
 */
extern ER ttsp_ref_swait_dtq(ID dtqid, uint_t order, ID *p_tskid, intptr_t *p_data);


/*
 *  データキューの受信待ちタスク参照関数
 */
extern ER ttsp_ref_rwait_dtq(ID dtqid, uint_t order, ID *p_tskid);



/*
 *  ref_pdq代替関数
 */
typedef struct t_ttsp_rpdq {
	uint_t	spdqcnt;		/* 優先度データキュー管理領域に格納されているデータの数 */
	ATR		pdqatr;			/* 優先度データキュー属性 */
	uint_t	pdqcnt;			/* 優先度データキューの容量 */
	PRI		maxdpri;		/* データ優先度の最大値 */
	uint_t	swaitcnt;		/* 送信待ちタスクの数 */
	uint_t	rwaitcnt;		/* 受信待ちタスクの数 */
} T_TTSP_RPDQ;

extern ER ttsp_ref_pdq(ID pdqid, T_TTSP_RPDQ *pk_rpdq);


/*
 *  優先度データキュー管理領域に格納されているデータ参照関数
 */
extern ER ttsp_ref_pridata(ID pdqid, uint_t index, intptr_t *p_data, PRI *p_datapri);


/*
 *  優先度データキューの送信待ちタスク参照関数
 */
extern ER ttsp_ref_swait_pdq(ID pdqid, uint_t order, ID *p_tskid, intptr_t *p_data, PRI *p_datapri);


/*
 *  優先度データキューの受信待ちタスク参照関数
 */
extern ER ttsp_ref_rwait_pdq(ID pdqid, uint_t order, ID *p_tskid);


/*
 *  ref_mpf代替関数
 */
typedef struct t_ttsp_rmpf {
	uint_t	fblkcnt;	/* 固定長メモリプール領域の空きメモリ領域に割り付けることができる固定長メモリブロックの数 */
	ATR		mpfatr;		/* 固定長メモリプール属性 */
	uint_t	blkcnt;		/* メモリブロック数 */
	uint_t	blksz;		/* メモリブロックのサイズ */
	uint_t	waitcnt;	/* 待ちタスクの数 */
	void	*mpf;		/* 固定長メモリプール領域の先頭番地 */
} T_TTSP_RMPF;

extern ER ttsp_ref_mpf(ID mpfid, T_TTSP_RMPF *pk_rmpf);


/*
 *  固定長メモリプールの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_mpf(ID mpfid, uint_t order, ID *p_tskid);



/*
 *  ref_cyc代替関数
 */
typedef struct t_ttsp_rcyc {
	STAT		cycstat;	/* 周期ハンドラの動作状態 */
	RELTIM		lefttim;	/* 次に周期ハンドラを起動する時刻までの相対時間 */
	ATR			cycatr;		/* 周期ハンドラ属性 */
	intptr_t	exinf;		/* 周期ハンドラの拡張情報 */
	RELTIM		cyctim;		/* 周期ハンドラの起動周期 */
	RELTIM		cycphs;		/* 周期ハンドラの起動位相 */
} T_TTSP_RCYC;

extern ER ttsp_ref_cyc(ID cycid, T_TTSP_RCYC *pk_rcyc);



/*
 *  ref_alm代替関数
 */
typedef struct t_ttsp_ralm {
	STAT		almstat;	/* アラームハンドラの動作状態 */
	RELTIM		lefttim;	/* アラームハンドラを起動する時刻までの相対時間 */
	ATR			almatr;		/* アラームハンドラ属性 */
	intptr_t	exinf;		/* アラームハンドラの拡張情報 */
} T_TTSP_RALM;

extern ER ttsp_ref_alm(ID almid, T_TTSP_RALM *pk_ralm);



/*
 *  get_ipm代替関数
 */
extern ER ttsp_get_ipm(PRI *p_intpri);



/*
 *  set_tim代替関数
 */
extern ER ttsp_set_tim(SYSTIM systim);



/*
 *  get_tim代替関数
 */
extern ER ttsp_get_tim(SYSTIM *p_systim);



/*
 *  ref_mtx代替関数
 */
typedef struct t_ttsp_rmtx {
	ATR		mtxatr;     /* ミューテックス属性 */
	uint_t	ceilpri;    /* ミューテックスの上限優先度（内部表現）*/
	ID		htskid;     /* ミューテックスをロックしているタスクID */
	uint_t	waitcnt;    /* 待ちタスクの数 */
} T_TTSP_RMTX;

extern ER ttsp_ref_mtx(ID mtxid, T_TTSP_RMTX *pk_rmtx);

/*
 *  ミューテックスの待ちタスク参照関数
 */
extern ER ttsp_ref_wait_mtx(ID mtxid, uint_t order, ID *p_tskid);

#endif /* TTSP_TEST_LIB_H */
