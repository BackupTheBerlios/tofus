OUTPUT_FORMAT("binary")
ENTRY(start)
SECTIONS
{
  .text  0x100000 : {
    *(.text)
  }
  .data  : {
    *(.data)
  }
  .bss  :
  { 					
    *(.bss)
  }
}
