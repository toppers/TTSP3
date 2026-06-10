/* gcov dump (simtimer_ct11mpcore_gcc 用, zybo の gcov 機構を流用・計測インフラ) */
#include "kernel/kernel_impl.h"
#ifdef TOPPERS_ENABLE_GCOV

/*
 *  現行 arm-none-eabi の libgcov はフリースタンディング構成で，
 *  ctor/dtor 方式（__gcov_init/__gcov_exit）の終了時ダンプを持たない．
 *  -fprofile-info-section でコンパイルし，リンカスクリプトが収集する
 *  .gcov_info セクションを __gcov_info_to_gcda() で走査して，
 *  セミホスティング（librdimon）のファイルI/Oで gcda を直接書き出す．
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <gcov.h>

/* defined by the linker script (zybo_z7.ld). */
extern const struct gcov_info *const __gcov_info_start[];
extern const struct gcov_info *const __gcov_info_end[];

/* the newlib libgloss */
void initialise_monitor_handles(void);

/* overwrite the newlib libgloss's _sbrk. */
void *
_sbrk(int incr)
{
	extern char _heap[]; /* defined by the linker script. */
	extern char _heap_limit[]; /* defined by the linker script. */
	static char *heap_end;
	char *prev_heap_end;

	if (heap_end == 0) {
		heap_end = _heap;
	}
	if (heap_end + incr < _heap_limit) {
		prev_heap_end = heap_end;
		heap_end += incr;
		return (void *) prev_heap_end;
	} else {
		errno = ENOMEM;
		return (void *)-1;
	}
}

/*
 *  __gcov_info_to_gcda() 用コールバック
 */
static FILE *gcov_fp;

/*
 *  セミホスティング SYS_WRITE0（診断出力用．
 *  セミホスティングSVCはr0に戻り値を書くため出力制約が必須）
 */
static void
sh_write0(const char *s)
{
	register int r0 asm("r0") = 0x04;
	register const char *r1 asm("r1") = s;
	Asm("svc 0x00123456" : "+r"(r0) : "r"(r1) : "memory");
}

static void
gcov_filename_fn(const char *filename, void *arg)
{
	gcov_fp = fopen(filename, "wb");
	if (gcov_fp == NULL) {
		sh_write0("GCOV: fopen failed: ");
		sh_write0(filename);
		sh_write0("\n");
	}
}

static void
gcov_dump_fn(const void *buffer, unsigned count, void *arg)
{
	if (gcov_fp != NULL) {
		fwrite(buffer, 1, count, gcov_fp);
	}
}

static void *
gcov_allocate_fn(unsigned length, void *arg)
{
	return malloc(length);
}

void
toppers_gcov_start(void)
{
	initialise_monitor_handles();
}

void
toppers_gcov_end(void)
{
	const struct gcov_info *const *info;

	for (info = __gcov_info_start; info != __gcov_info_end; info++) {
		gcov_fp = NULL;
		__gcov_info_to_gcda(*info, gcov_filename_fn, gcov_dump_fn,
											gcov_allocate_fn, NULL);
		if (gcov_fp != NULL) {
			fclose(gcov_fp);
			gcov_fp = NULL;
		}
	}
}

void
software_init_hook(void)
{
	toppers_gcov_start();
}

void
software_term_hook(void)
{
	toppers_gcov_end();
}

#endif /* TOPPERS_ENABLE_GCOV */
