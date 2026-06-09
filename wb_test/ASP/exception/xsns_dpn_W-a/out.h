/*
 *  white-box: kernel/exception.c L101 br — xsns_dpn: kerflg==false short-circuit
 *  L101 br[0]: kerflg==false — xsns_dpn called from ATT_INI before sta_ker sets kerflg=true
 *  route   : ATT_INI callback → xsns_dpn(NULL) → kerflg=false → short-circuit → state=true
 *  kernel  : ASP3 3.7.2
 */
#ifndef TOPPERS_TTG_HEADER
#define TOPPERS_TTG_HEADER

#include "ttsp_target_test.h"

extern void xsns_dpn_W_a_init(intptr_t exinf);
extern void main_task(intptr_t exinf);

#endif /* TOPPERS_TTG_HEADER */
