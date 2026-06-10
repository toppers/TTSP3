/*
 *  $Id: ct11mpcore.ld 1521 2022-02-06 01:15:43Z ertl-hiro $
 */

OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm","elf32-littlearm") 
OUTPUT_ARCH(arm)

SECTIONS {
	.text ALIGN(4) : {
		__start_text = .;
		KEEP(*(.vector))
		*(.text .text.*)
		*(.glue_7t)
		*(.glue_7)
		__end_kernel = .;
	}
	_etext = .;
	PROVIDE(etext = .);

	.rodata ALIGN(4) : {
		__start_rodata = .;
		KEEP(*(.rodata .rodata.*))
		/* GCOV SUPPORT (-fprofile-info-section) */
		. = ALIGN(4);
		PROVIDE(__gcov_info_start = .);
		KEEP (*(.gcov_info))
		PROVIDE(__gcov_info_end = .);
		/* GCOV SUPPORT */
		__end_rodata = .;
	}

	. = ALIGN(4);
	__start_idata = .;
	.data : AT(__start_idata) {
		__start_data = .;
		*(.data .data.*)
		__end_data = .;
	}
	__end_idata = __start_idata + SIZEOF(.data);
	_edata = .;
	PROVIDE(edata = .);

	.bss ALIGN(4) : {
		__start_bss = .;
		*(.bss .bss.*)
		*(COMMON)
		__end_bss = .;
	}

	. = ALIGN(4);
	_end = .;
	_heap = .;                 /* GCOV SUPPORT */
	_heap_size = 0x1000000;    /* GCOV SUPPORT */
	_heap_limit = _heap + _heap_size; /* GCOV SUPPORT */
	PROVIDE(end = .);
	.comment 0 : { *(.comment) }	

	/*
	 *  DWARF debug sections.
	 *  Symbols in the DWARF debugging sections are relative to
	 *  the beginning of the section so we begin them at 0.
	 */

	/* DWARF 1 */
	.debug			0 : { *(.debug) }
	.line			0 : { *(.line) }

	/* GNU DWARF 1 extensions */
	.debug_srcinfo	0 : { *(.debug_srcinfo) }
	.debug_sfnames	0 : { *(.debug_sfnames) }

	/* DWARF 1.1 and DWARF 2 */
	.debug_aranges	0 : { *(.debug_aranges) }
	.debug_pubnames	0 : { *(.debug_pubnames) }

	/* DWARF 2 */
	.debug_info		0 : { *(.debug_info) }
	.debug_abbrev	0 : { *(.debug_abbrev) }
	.debug_line		0 : { *(.debug_line) }
	.debug_frame	0 : { *(.debug_frame) }
	.debug_str		0 : { *(.debug_str) }
	.debug_loc		0 : { *(.debug_loc) }
	.debug_macinfo	0 : { *(.debug_macinfo) }

	/* SGI/MIPS DWARF 2 extensions */
	.debug_weaknames 0 : { *(.debug_weaknames) }
	.debug_funcnames 0 : { *(.debug_funcnames) }
	.debug_typenames 0 : { *(.debug_typenames) }
	.debug_varnames  0 : { *(.debug_varnames) }
}	
