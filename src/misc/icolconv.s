/*         ______   ___    ___ 
 *        /\  _  \ /\_ \  /\_ \ 
 *        \ \ \L\ \\//\ \ \//\ \      __     __   _ __   ___ 
 *         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 *          \ \ \/\ \ \_\ \_ \_\ \_/\  __//\ \L\ \ \ \//\ \L\ \
 *           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 *            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 *                                           /\____/
 *                                           \_/__/
 *
 *      Asm routines for software color conversion.
 *      Suggestions to make it faster are welcome :)
 *
 *      By Isaac Cruz.
 *
 *      24-bit color support and non MMX routines by Eric Botcazou.
 *
 *      Support for rectangles of any width, 8-bit destination color
 *      and cross-conversion between 15-bit and 16-bit colors,
 *      additional MMX and color copy routines by Robert J. Ohannessian.
 *
 *      See readme.txt for copyright information.
 */


#include "src/i386/asmdefs.inc"


.text


#ifdef ALLEGRO_MMX

/* it seems pand is broken in GAS 2.8.1 */
#define PAND(src, dst)   \
   .byte 0x0f, 0xdb    ; \
   .byte 0xc0 + 8*dst + src  /* mod field */

/* local variables */
#define LOCAL1   -4(%esp)
#define LOCAL2   -8(%esp)
#define LOCAL3   -12(%esp)
#define LOCAL4   -16(%esp)


/* helper macros */
#define INIT_CONVERSION_1(mask_red, mask_green, mask_blue)                           \
      /* init register values */                                                   ; \
                                                                                   ; \
      movl mask_green, %eax                                                        ; \
      movd %eax, %mm3                                                              ; \
      punpckldq %mm3, %mm3                                                         ; \
      movl mask_red, %eax                                                          ; \
      movd %eax, %mm4                                                              ; \
      punpckldq %mm4, %mm4                                                         ; \
      movl mask_blue, %eax                                                         ; \
      movd %eax, %mm5                                                              ; \
      punpckldq %mm5, %mm5                                                         ; \
                                                                                   ; \
      movl ARG1, %eax                  /* eax = src_rect                 */        ; \
      movl GFXRECT_WIDTH(%eax), %edx   /* edx = src_rect->width          */        ; \
      movl GFXRECT_HEIGHT(%eax), %ecx  /* ecx = src_rect->height         */        ; \
      movl GFXRECT_PITCH(%eax), %esi   /* esi = src_rect->pitch          */        ; \
      movl GFXRECT_DATA(%eax), %eax    /* eax = src_rect->data           */        ; \
      shll $2, %edx                    /* edx = SCREEN_W * 4             */        ; \
      subl %edx, %esi                  /* esi = (src_rect->pitch) - edx  */        ; \
                                                                                   ; \
      movl ARG2, %ebx                  /* ebx = dest_rect                */        ; \
      shrl $1, %edx                    /* edx = SCREEN_W * 2             */        ; \
      movl GFXRECT_PITCH(%ebx), %edi   /* edi = dest_rect->pitch         */        ; \
      movl GFXRECT_DATA(%ebx), %ebx    /* ebx = dest_rect->data          */        ; \
      subl %edx, %edi                  /* edi = (dest_rect->pitch) - edx */        ; \
      shrl $1, %edx                    /* edx = SCREEN_W                 */        ; \
      movl %edx, %ebp


#define INIT_CONVERSION_2(mask_red, mask_green, mask_blue)                           \
      /* init register values */                                                   ; \
                                                                                   ; \
      movl mask_green, %eax                                                        ; \
      movd %eax, %mm3                                                              ; \
      punpckldq %mm3, %mm3                                                         ; \
      movl mask_red, %eax                                                          ; \
      movd %eax, %mm4                                                              ; \
      punpckldq %mm4, %mm4                                                         ; \
      movl mask_blue, %eax                                                         ; \
      movd %eax, %mm5                                                              ; \
      punpckldq %mm5, %mm5                                                         ; \
                                                                                   ; \
      movl ARG1, %eax                  /* eax = src_rect                 */        ; \
      movl GFXRECT_WIDTH(%eax), %edx   /* edx = src_rect->width          */        ; \
      movl GFXRECT_HEIGHT(%eax), %ecx  /* ecx = src_rect->height         */        ; \
      movl GFXRECT_PITCH(%eax), %esi   /* esi = src_rect->pitch          */        ; \
      movl GFXRECT_DATA(%eax), %eax    /* eax = src_rect->data           */        ; \
      addl %edx, %edx                  /* edx = SCREEN_W * 2             */        ; \
      subl %edx, %esi                  /* esi = (src_rect->pitch) - edx  */        ; \
                                                                                   ; \
      movl ARG2, %ebx                  /* ebx = dest_rect                */        ; \
      addl %edx, %edx                  /* edx = SCREEN_W * 4             */        ; \
      movl GFXRECT_PITCH(%ebx), %edi   /* edi = dest_rect->pitch         */        ; \
      movl GFXRECT_DATA(%ebx), %ebx    /* ebx = dest_rect->data          */        ; \
      subl %edx, %edi                  /* edi = (dest_rect->pitch) - edx */        ; \
      shrl $2, %edx                    /* edx = SCREEN_W                 */        ; \
      movl %edx, %ebp



#ifdef ALLEGRO_COLOR8

/* void _colorconv_blit_8_to_15 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT dest_rect)
 */
/* void _colorconv_blit_8_to_16 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT dest_rect)
 */
FUNC (_colorconv_blit_8_to_15)
FUNC (_colorconv_blit_8_to_16)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_8_to_16_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG1, %eax                    /* eax = src_rect         */
   movl GFXRECT_WIDTH(%eax), %edi     /* edi = src_rect->width  */
   movl GFXRECT_HEIGHT(%eax), %ecx    /* ecx = src_rect->height */
   movl GFXRECT_PITCH(%eax), %esi     /* esi = src_rect->pitch  */
   movl GFXRECT_DATA(%eax), %eax      /* eax = src_rect->data   */
   movl %ecx, LOCAL1                  /* LOCAL1 = SCREEN_H      */
   subl %edi, %esi
   movl %esi, LOCAL2                  /* LOCAL2 = src_rect->pitch - SCREEN_W */

   movl ARG2, %ebx                    /* ebx = dest_rect        */
   addl %edi, %edi                    /* edi = SCREEN_W * 2     */
   movl GFXRECT_PITCH(%ebx), %edx     /* edx = dest_rect->pitch */
   movl GFXRECT_DATA(%ebx), %ebx      /* ebx = dest_rect->data  */
   subl %edi, %edx
   movl %edx, LOCAL3                  /* LOCAL3 = (dest_rect->pitch) - (SCREEN_W * 2) */
   shrl $1, %edi                      /* edi = SCREEN_W                               */
   movl GLOBL(_colorconv_indexed_palette), %esi  /* esi = _colorconv_indexed_palette  */
   movl %edi, %ebp

   /* 8 bit to 16 bit conversion:
    we have:
    eax = src_rect->data
    ebx = dest_rect->data
    esi = _colorconv_indexed_palette
    edi = SCREEN_W
    LOCAL1 = SCREEN_H
    LOCAL2 = offset from the end of a line to the beginning of the next
    LOCAL3 = same as LOCAL2, but for the dest bitmap
   */

   _align_
   next_line_8_to_16:
      shrl $2, %edi             /* work with packs of 4 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_8_to_16  /* less than 4 pixels? Can't work with the main loop */
#endif

      _align_
      next_block_8_to_16:
         movl (%eax), %edx         /* edx = [4][3][2][1] */
         movzbl %dl, %ecx
         movd (%esi,%ecx,4), %mm0  /* mm0 = xxxxxxxxxx xxxxx[ 1 ] */
         shrl $8, %edx
         movzbl %dl, %ecx
         movd (%esi,%ecx,4), %mm1  /* mm1 = xxxxxxxxxx xxxxx[ 2 ] */
         punpcklwd %mm1, %mm0      /* mm0 = xxxxxxxxxx [ 2 ][ 1 ] */
         shrl $8, %edx
         movzbl %dl, %ecx
         movd (%esi,%ecx,4), %mm2  /* mm2 = xxxxxxxxxx xxxxx[ 3 ] */
         shrl $8, %edx
         movl %edx, %ecx
         movd (%esi,%ecx,4), %mm3  /* mm3 = xxxxxxxxxx xxxxx[ 4 ] */
         punpcklwd %mm3, %mm2      /* mm2 = xxxxxxxxxx [ 4 ][ 3 ] */
         addl $4, %eax
         punpckldq %mm2, %mm0      /* mm0 = [ 4 ][ 3 ] [ 2 ][ 1 ] */
         movq %mm0, (%ebx)
         addl $8, %ebx

         decl %edi
         jnz next_block_8_to_16

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_8_to_16:
         movl %ebp, %edi           /* restore width */
         andl $3, %edi
         jz end_of_line_8_to_16    /* nothing to do? */

         shrl $1, %edi
         jnc do_two_pixels_8_to_16

         movzbl (%eax), %edx        /* convert 1 pixel */
         movl (%esi,%edx,4), %ecx
         incl %eax
         addl $2, %ebx
         movw %cx, -2(%ebx)

      do_two_pixels_8_to_16:
         shrl $1, %edi
         jnc end_of_line_8_to_16
         movzbl (%eax), %edx        /* convert 2 pixels */
         movzbl 1(%eax), %ecx
         movl (%esi,%edx,4), %edx
         movl (%esi,%ecx,4), %ecx
         shll $16, %ecx
         addl $2, %eax
         orl %ecx, %edx
         addl $4, %ebx
         movl %edx, -4(%ebx)

   _align_
   end_of_line_8_to_16:
#endif

      movl LOCAL2, %edx
      addl %edx, %eax
      movl LOCAL3, %ecx
      addl %ecx, %ebx
      movl LOCAL1, %edx
      movl %ebp, %edi             /* restore width */
      decl %edx
      movl %edx, LOCAL1
      jnz next_line_8_to_16

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



/* void _colorconv_blit_8_to_32 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_8_to_32)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_8_to_32_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG1, %eax                    /* eax = src_rect         */
   movl GFXRECT_WIDTH(%eax), %edi     /* edi = src_rect->width  */
   movl GFXRECT_HEIGHT(%eax), %ecx    /* ecx = src_rect->height */
   movl GFXRECT_PITCH(%eax), %esi     /* esi = src_rect->pitch  */
   movl GFXRECT_DATA(%eax), %eax      /* eax = src_rect->data   */
   movl %ecx, LOCAL1                  /* LOCAL1 = SCREEN_H      */
   subl %edi, %esi
   movl %esi, LOCAL2                  /* LOCAL2 = src_rect->pitch - SCREEN_W */

   movl ARG2, %ebx                    /* ebx = dest_rect        */
   shll $2, %edi                      /* edi = SCREEN_W * 4     */
   movl GFXRECT_PITCH(%ebx), %edx     /* edx = dest_rect->pitch */
   movl GFXRECT_DATA(%ebx), %ebx      /* ebx = dest_rect->data  */
   subl %edi, %edx
   movl %edx, LOCAL3                  /* LOCAL3 = (dest_rect->pitch) - (SCREEN_W * 4) */
   shrl $2, %edi                      /* edi = SCREEN_W                               */
   movl GLOBL(_colorconv_indexed_palette), %esi  /* esi = _colorconv_indexed_palette  */
   movl %edi, %ebp

   /* 8 bit to 32 bit conversion:
    we have:
    eax = src_rect->data
    ebx = dest_rect->data
    esi = _colorconv_indexed_palette
    edi = SCREEN_W
    LOCAL1 = SCREEN_H
    LOCAL2 = offset from the end of a line to the beginning of the next
    LOCAL3 = same as LOCAL2, but for the dest bitmap
   */

   _align_
   next_line_8_to_32:
      shrl $2, %edi             /* work with packs of 4 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_8_to_32  /* less than 4 pixels? Can't work with the main loop */
#endif

      _align_
      next_block_8_to_32:
         movl (%eax), %edx          /* edx = [4][3][2][1] */ 
         movzbl %dl, %ecx
         movd (%esi,%ecx,4), %mm0   /* mm0 = xxxxxxxxx [   1   ] */
         shrl $8, %edx
         movzbl %dl, %ecx
         movd (%esi,%ecx,4), %mm1   /* mm1 = xxxxxxxxx [   2   ] */
         punpckldq %mm1, %mm0       /* mm0 = [   2   ] [   1   ] */
         addl $4, %eax
         movq %mm0, (%ebx)
         shrl $8, %edx
         movzbl %dl, %ecx
         movd (%esi,%ecx,4), %mm0   /* mm0 = xxxxxxxxx [   3   ] */
         shrl $8, %edx
         movl %edx, %ecx
         movd (%esi,%ecx,4), %mm1   /* mm1 = xxxxxxxxx [   4   ] */
         punpckldq %mm1, %mm0       /* mm0 = [   4   ] [   3   ] */
         movq %mm0, 8(%ebx)
         addl $16, %ebx

         decl %edi
         jnz next_block_8_to_32

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_8_to_32:
         movl %ebp, %edi           /* restore width */
         andl $3, %edi
         jz end_of_line_8_to_32    /* nothing to do? */

         shrl $1, %edi
         jnc do_two_pixels_8_to_32

         movzbl (%eax), %edx       /* convert 1 pixel */
         movl (%esi,%edx,4), %edx
         incl %eax
         addl $4, %ebx
         movl %edx, -4(%ebx)

      do_two_pixels_8_to_32:
         shrl $1, %edi
         jnc end_of_line_8_to_32

         movzbl (%eax), %edx       /* convert 2 pixels */
         movzbl 1(%eax), %ecx
         movl (%esi,%edx,4), %edx
         movl (%esi,%ecx,4), %ecx
         addl $2, %eax
         movl %edx, (%ebx)
         movl %ecx, 4(%ebx)
         addl $8, %ebx

   _align_
   end_of_line_8_to_32:
#endif

      movl LOCAL2, %edx
      addl %edx, %eax
      movl LOCAL3, %ecx
      addl %ecx, %ebx
      movl LOCAL1, %edx
      movl %ebp, %edi          /* restore width */
      decl %edx
      movl %edx, LOCAL1
      jnz next_line_8_to_32

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret

#endif  /* ALLEGRO_COLOR8 */



#ifdef ALLEGRO_COLOR16

/* void _colorconv_blit_15_to_16 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_15_to_16)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_15_to_16_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG1, %eax                    /* eax = src_rect         */
   movl GFXRECT_WIDTH(%eax), %ecx     /* ecx = src_rect->width  */
   movl GFXRECT_HEIGHT(%eax), %edx    /* edx = src_rect->height */
   shll $1, %ecx
   movl GFXRECT_DATA(%eax), %esi      /* esi = src_rect->data   */
   movl GFXRECT_PITCH(%eax), %eax     /* eax = src_rect->pitch  */
   subl %ecx, %eax

   movl ARG2, %ebx                    /* ebx = dest_rect        */
   movl GFXRECT_DATA(%ebx), %edi      /* edi = dest_rect->data  */
   movl GFXRECT_PITCH(%ebx), %ebx     /* ebx = dest_rect->pitch */
   subl %ecx, %ebx
   shrl $1, %ecx

   /* 15 bit to 16 bit conversion:
    we have:
    ecx = SCREEN_W
    edx = SCREEN_H
    eax = offset from the end of a line to the beginning of the next
    ebx = same as eax, but for the dest bitmap
    esi = src_rect->data
    edi = dest_rect->data
   */

   movd %ecx, %mm7              /* save width for later */
   
   movl $0x7FE07FE0, %ecx
   movd %ecx, %mm6
   movl $0x00200020, %ecx       /* addition to green component */
   punpckldq %mm6, %mm6         /* mm6 = reg-green mask */
   movd %ecx, %mm4
   movl $0x001F001F, %ecx
   punpckldq %mm4, %mm4         /* mm4 = green add mask */
   movd %ecx, %mm5
   punpckldq %mm5, %mm5         /* mm5 = blue mask */

   movd %mm7, %ecx

   _align_
   next_line_15_to_16:
      shrl $3, %ecx             /* work with packs of 8 pixels */
      orl %ecx, %ecx
      jz do_one_pixel_15_to_16  /* less than 8 pixels? Can't work with the main loop */

      _align_
      next_block_15_to_16:
         movq (%esi), %mm0         /* read 8 pixels */
         movq 8(%esi), %mm1        /* mm1 = [rgb7][rgb6][rgb5][rgb4] */
         movq %mm0, %mm2           /* mm0 = [rgb3][rgb2][rgb1][rgb0] */
         movq %mm1, %mm3
         pand %mm6, %mm0           /* isolate red-green */
         pand %mm6, %mm1
         pand %mm5, %mm2           /* isolate blue */
         pand %mm5, %mm3
         psllq $1, %mm0            /* shift red-green by 1 bit to the left */
         addl $16, %esi
         psllq $1, %mm1
         addl $16, %edi
         por %mm4, %mm0            /* set missing bit to 1 */
         por %mm4, %mm1
         por %mm2, %mm0            /* recombine components */
         por %mm3, %mm1
         movq %mm0, -16(%edi)      /* write result */
         movq %mm1, -8(%edi)

         decl %ecx
         jnz next_block_15_to_16

      do_one_pixel_15_to_16:
         movd %mm7, %ecx          /* anything left to do? */
         andl $7, %ecx
         jz end_of_line_15_to_16

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
         shrl $1, %ecx            /* do one pixel */
         jnc do_two_pixels_15_to_16

         movzwl (%esi), %ecx      /* read one pixel */
         addl $2, %esi
         movd %ecx, %mm0
         movd %ecx, %mm2
         pand %mm6, %mm0
         pand %mm5, %mm2
         psllq $1, %mm0
         addl $2, %edi
         por %mm4, %mm0
         por %mm2, %mm0
         movd %mm0, %ecx
         movw %cx, -2(%edi)
         movd %mm7, %ecx
         shrl $1, %ecx

      do_two_pixels_15_to_16:
         shrl $1, %ecx
         jnc do_four_pixels_15_to_16

         movd (%esi), %mm0         /* read two pixels */
         addl $4, %esi
         movq %mm0, %mm2
         pand %mm6, %mm0
         pand %mm5, %mm2
         psllq $1, %mm0
         addl $4, %edi
         por %mm4, %mm0
         por %mm2, %mm0
         movd %mm0, -4(%edi)

      _align_
      do_four_pixels_15_to_16:
         shrl $1, %ecx
         jnc end_of_line_15_to_16
#endif

         movq (%esi), %mm0        /* read four pixels */
         addl $8, %esi
         movq %mm0, %mm2
         pand %mm6, %mm0
         pand %mm5, %mm2
         psllq $1, %mm0
         por %mm4, %mm0
         por %mm2, %mm0
         addl $8, %edi
         movq %mm0, -8(%edi)

   _align_
   end_of_line_15_to_16:
      addl %eax, %esi
      movd %mm7, %ecx           /* restore width */
      addl %ebx, %edi
      decl %edx
      jnz next_line_15_to_16

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



/* void _colorconv_blit_15_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_15_to_32)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_15_to_32_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   INIT_CONVERSION_2 ($0x7c00, $0x03e0, $0x001f);

   /* 15 bit to 32 bit conversion:
    we have:
    eax = src_rect->data
    ebx = dest_rect->data
    ecx = SCREEN_H
    edx = SCREEN_W
    esi = offset from the end of a line to the beginning of the next
    edi = same as esi, but for the dest bitmap
   */

   _align_
   next_line_15_to_32:
      shrl $1, %edx             /* work with packs of 2 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_15_to_32  /* 1 pixel? Can't use dual-pixel code */
#endif

      _align_
      next_block_15_to_32:
         movd (%eax), %mm0    /* mm0 = 0000 0000  [rgb1][rgb2] */
         punpcklwd %mm0, %mm0 /* mm0 = xxxx [rgb1] xxxx [rgb2]  (x don't matter) */
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         pslld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         pslld $6, %mm1
         por %mm1, %mm0
         addl $4, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         pslld $9, %mm2
         por %mm2, %mm0
         movq %mm0, (%ebx)
         addl $8, %ebx

         decl %edx
         jnz next_block_15_to_32

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_15_to_32:
         movl %ebp, %edx    /* restore width */
         shrl $1, %edx
         jnc end_of_line_15_to_32

         movd (%eax), %mm0
         punpcklwd %mm0, %mm0
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         pslld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         pslld $6, %mm1
         por %mm1, %mm0
         addl $2, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         pslld $9, %mm2
         por %mm2, %mm0
         movd %mm0, (%ebx)
         addl $4, %ebx

   _align_
   end_of_line_15_to_32:
#endif

      addl %esi, %eax
      movl %ebp, %edx         /* restore width */
      addl %edi, %ebx
      decl %ecx
      jnz next_line_15_to_32

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



/* void _colorconv_blit_16_to_15 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_16_to_15)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_16_to_15_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG1, %eax                    /* eax = src_rect         */
   movl GFXRECT_WIDTH(%eax), %ecx     /* ecx = src_rect->width  */
   movl GFXRECT_HEIGHT(%eax), %edx    /* edx = src_rect->height */
   shll $1, %ecx
   movl GFXRECT_DATA(%eax), %esi      /* esi = src_rect->data   */
   movl GFXRECT_PITCH(%eax), %eax     /* eax = src_rect->pitch  */
   subl %ecx, %eax

   movl ARG2, %ebx                    /* ebx = dest_rect        */
   movl GFXRECT_DATA(%ebx), %edi      /* edi = dest_rect->data  */
   movl GFXRECT_PITCH(%ebx), %ebx     /* ebx = dest_rect->pitch */
   subl %ecx, %ebx
   shrl $1, %ecx

   /* 16 bit to 15 bit conversion:
    we have:
    ecx = SCREEN_W
    edx = SCREEN_H
    eax = offset from the end of a line to the beginning of the next
    ebx = same as eax, but for the dest bitmap
    esi = src_rect->data
    edi = dest_rect->data
   */

   movd %ecx, %mm7              /* save width for later */

   movl $0xFFC0FFC0, %ecx
   movd %ecx, %mm6
   punpckldq %mm6, %mm6         /* mm6 = reg-green mask */
   movl $0x001F001F, %ecx
   movd %ecx, %mm5
   punpckldq %mm5, %mm5         /* mm4 = blue mask */
   
   movd %mm7, %ecx

   _align_
   next_line_16_to_15:
      shrl $3, %ecx             /* work with packs of 8 pixels */
      orl %ecx, %ecx
      jz do_one_pixel_16_to_15  /* less than 8 pixels? Can't work with the main loop */

      _align_
      next_block_16_to_15:
         movq (%esi), %mm0         /* read 8 pixels */
         movq 8(%esi), %mm1        /* mm1 = [rgb7][rgb6][rgb5][rgb4] */
         addl $16, %esi
         addl $16, %edi
         movq %mm0, %mm2           /* mm0 = [rgb3][rgb2][rgb1][rgb0] */
         movq %mm1, %mm3
         pand %mm6, %mm0           /* isolate red-green */
         pand %mm6, %mm1
         pand %mm5, %mm2           /* isolate blue */
         psrlq $1, %mm0            /* shift red-green by 1 bit to the right */
         pand %mm5, %mm3
         psrlq $1, %mm1
         por %mm2, %mm0            /* recombine components */
         por %mm3, %mm1
         movq %mm0, -16(%edi)      /* write result */
         movq %mm1, -8(%edi)

         decl %ecx
         jnz next_block_16_to_15

      do_one_pixel_16_to_15:
         movd %mm7, %ecx          /* anything left to do? */
         andl $7, %ecx
         jz end_of_line_16_to_15

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
         shrl $1, %ecx            /* do one pixel */
         jnc do_two_pixels_16_to_15

         movzwl (%esi), %ecx      /* read one pixel */
         addl $2, %esi
         movd %ecx, %mm0
         movd %ecx, %mm2
         pand %mm6, %mm0
         pand %mm5, %mm2
         psrlq $1, %mm0
         por %mm2, %mm0
         movd %mm0, %ecx
         addl $2, %edi
         movw %cx, -2(%edi)
         movd %mm7, %ecx
         shrl $1, %ecx

      do_two_pixels_16_to_15:
         shrl $1, %ecx
         jnc do_four_pixels_16_to_15

         movd (%esi), %mm0      /* read two pixels */
         addl $4, %esi
         movq %mm0, %mm2
         pand %mm6, %mm0
         pand %mm5, %mm2
         psrlq $1, %mm0
         por %mm2, %mm0
         addl $4, %edi
         movd %mm0, -4(%edi)

      _align_
      do_four_pixels_16_to_15:
         shrl $1, %ecx
         jnc end_of_line_16_to_15
#endif

         movq (%esi), %mm0      /* read four pixels */
         addl $8, %esi
         movq %mm0, %mm2
         pand %mm6, %mm0
         pand %mm5, %mm2
         psrlq $1, %mm0
         por %mm2, %mm0
         addl $8, %edi
         movd %mm0, -8(%edi)

   _align_
   end_of_line_16_to_15:
      addl %eax, %esi
      movd %mm7, %ecx           /* restore width */
      addl %ebx, %edi
      decl %edx
      jnz next_line_16_to_15

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



/* void _colorconv_blit_16_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_16_to_32)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_16_to_32_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   INIT_CONVERSION_2 ($0xf800, $0x07e0, $0x001f);

   /* 16 bit to 32 bit conversion:
    we have:
    eax = src_rect->data
    ebx = dest_rect->data
    ecx = SCREEN_H
    edx = SCREEN_W
    esi = offset from the end of a line to the beginning of the next
    edi = same as esi, but for the dest bitmap
   */

   _align_
   next_line_16_to_32:
      shrl $1, %edx             /* work with packs of 2 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_16_to_32  /* 1 pixel? Can't use dual-pixel code */
#endif

      _align_
      next_block_16_to_32:
         movd (%eax), %mm0    /* mm0 = 0000 0000  [rgb1][rgb2] */
         punpcklwd %mm0, %mm0 /* mm0 = xxxx [rgb1] xxxx [rgb2]  (x don't matter) */
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         pslld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         pslld $5, %mm1
         por %mm1, %mm0
         addl $4, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         pslld $8, %mm2
         por %mm2, %mm0
         movq %mm0, (%ebx)
         addl $8, %ebx

         decl %edx
         jnz next_block_16_to_32

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_16_to_32:
         movl %ebp, %edx    /* restore width */
         shrl $1, %edx
         jnc end_of_line_16_to_32

         movd (%eax), %mm0
         punpcklwd %mm0, %mm0
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         pslld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         pslld $5, %mm1
         por %mm1, %mm0
         addl $2, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         pslld $8, %mm2
         por %mm2, %mm0
         movd %mm0, (%ebx)
         addl $4, %ebx

   _align_
   end_of_line_16_to_32:
#endif

      addl %esi, %eax
      movl %ebp, %edx         /* restore width */
      addl %edi, %ebx
      decl %ecx
      jnz next_line_16_to_32

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret

#endif  /* ALLEGRO_COLOR16 */



#ifdef ALLEGRO_COLOR24

/* void _colorconv_blit_24_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_24_to_32)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_24_to_32_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG1, %eax                    /* eax = src_rect         */
   movl GFXRECT_WIDTH(%eax), %ecx     /* ecx = src_rect->width  */
   movl GFXRECT_HEIGHT(%eax), %edx    /* edx = src_rect->height */
   leal (%ecx, %ecx, 2), %ebx         /* ebx = SCREEN_W * 3     */
   movl GFXRECT_DATA(%eax), %esi      /* esi = src_rect->data   */
   movl GFXRECT_PITCH(%eax), %eax     /* eax = src_rect->pitch  */
   subl %ebx, %eax

   movl ARG2, %ebx                    /* ebx = dest_rect        */
   shll $2, %ecx                      /* ecx = SCREEN_W * 4     */
   movl GFXRECT_DATA(%ebx), %edi      /* edi = dest_rect->data  */
   movl GFXRECT_PITCH(%ebx), %ebx     /* ebx = dest_rect->pitch */
   subl %ecx, %ebx
   shrl $2, %ecx                      /* ecx = SCREEN_W         */
   movd %ecx, %mm7

   /* 24 bit to 32 bit conversion:
    we have:
    eax = offset from the end of a line to the beginning of the next
    ebx = same as eax, but for the dest bitmap
    ecx = SCREEN_W
    edx = SCREEN_H
    esi = src_rect->data
    edi = dest_rect->data
   */

   _align_
   next_line_24_to_32:
      shrl $2, %ecx             /* work with packs of 4 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_24_to_32  /* less than 4 pixels? Can't work with the main loop */
#endif

      _align_
      next_block_24_to_32:
         movq (%esi), %mm0         /* mm0 = [GB2][RGB1][RGB0] */
         movd 8(%esi), %mm1        /* mm1 = [..0..][RGB3][R2] */
         movq %mm0, %mm2
         movq %mm0, %mm3
         movq %mm1, %mm4
         psllq $16, %mm2
         psllq $40, %mm0
         psrlq $40, %mm2
         psrlq $40, %mm0           /* mm0 = [....0....][RGB0] */
         psllq $32, %mm2           /* mm2 = [..][RGB1][..0..] */
         psrlq $8, %mm1
         psrlq $48, %mm3           /* mm3 = [.....0....][GB2] */
         psllq $56, %mm4
         psllq $32, %mm1           /* mm1 = [.RGB3][....0...] */
         psrlq $40, %mm4           /* mm4 = [....0...][R2][0] */
         por %mm3, %mm1
         por %mm2, %mm0            /* mm0 = [.RGB1][.RGB0]    */
         por %mm4, %mm1            /* mm1 = [.RGB3][.RGB2]    */
         movq %mm0, (%edi)
         movq %mm1, 8(%edi)
         addl $12, %esi
         addl $16, %edi

         decl %ecx
         jnz next_block_24_to_32

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   do_one_pixel_24_to_32:
      movd %mm7, %ecx           /* restore width */
      andl $3, %ecx
      jz end_of_line_24_to_32   /* nothing to do? */

      shrl $1, %ecx
      jnc do_two_pixels_24_to_32

      xorl %ecx, %ecx           /* partial registar stalls ahead, 6 cycles penalty on the 686 */
      movzwl (%esi), %ebp
      movb  2(%esi), %cl
      movw  %bp, (%edi)
      movw  %cx, 2(%edi)
      addl $3, %esi
      addl $4, %edi
      movd %mm7, %ecx           /* restore width */
      shrl $1, %ecx

   do_two_pixels_24_to_32:
      shrl $1, %ecx
      jnc end_of_line_24_to_32

      movd (%esi), %mm0         /* read 2 pixels */
      movzwl 4(%esi), %ecx
      movd %ecx, %mm1
      movq %mm0, %mm2
      pslld $8, %mm1
      addl $6, %esi
      pslld $8, %mm0
      addl $8, %edi
      psrld $24, %mm2
      psrld $8, %mm0
      por %mm2, %mm1
      psllq $32, %mm1
      por %mm1, %mm0
      movq %mm0, -8(%edi)

   _align_
   end_of_line_24_to_32:
#endif

      addl %eax, %esi
      movd %mm7, %ecx           /* restore width */
      addl %ebx, %edi
      decl %edx
      jnz next_line_24_to_32

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret

#endif  /* ALLEGRO_COLOR24 */



#ifdef ALLEGRO_COLOR32

/* void _colorconv_blit_32_to_15 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_32_to_15)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_32_to_15_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   INIT_CONVERSION_1 ($0xf80000, $0x00f800, $0x0000f8);

   /* 32 bit to 15 bit conversion:
    we have:
    eax = src_rect->data
    ebx = dest_rect->data
    ecx = SCREEN_H
    edx = SCREEN_W / 2
    esi = offset from the end of a line to the beginning of the next
    edi = same as esi, but for the dest bitmap
   */

   _align_
   next_line_32_to_15:
      shrl $1, %edx             /* work with packs of 2 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_32_to_15  /* 1 pixel? Can't use dual-pixel code */
#endif

      _align_
      next_block_32_to_15:
         movq (%eax), %mm0
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         psrld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         psrld $6, %mm1
         por %mm1, %mm0
         addl $8, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         psrld $9, %mm2
         por %mm2, %mm0
         movq %mm0, %mm6
         psrlq $16, %mm0
         por %mm0, %mm6
         movd %mm6, (%ebx)
         addl $4, %ebx

         incl %ebp
         cmpl %edx, %ebp
         jb next_block_32_to_15

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_32_to_15:
         movl %ebp, %edx    /* restore width */
         shrl $1, %edx
         jnc end_of_line_32_to_15

         movd (%eax), %mm0
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         psrld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         psrld $6, %mm1
         por %mm1, %mm0
         addl $4, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         psrld $9, %mm2
         por %mm2, %mm0
         movd %mm0, %edx
         movw %dx, (%ebx)
         addl $2, %ebx

   _align_
   end_of_line_32_to_15:
#endif

      addl %esi, %eax
      movl %ebp, %edx         /* restore width */
      addl %edi, %ebx
      decl %ecx
      jnz next_line_32_to_15

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



/* void _colorconv_blit_32_to_16 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_32_to_16)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_32_to_16_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   INIT_CONVERSION_1 ($0xf80000, $0x00fc00, $0x0000f8);

   /* 32 bit to 16 bit conversion:
    we have:
    eax = src_rect->data
    ebx = dest_rect->data
    ecx = SCREEN_H
    edx = SCREEN_W
    esi = offset from the end of a line to the beginning of the next
    edi = same as esi, but for the dest bitmap
   */

   _align_
   next_line_32_to_16:
      shrl $1, %edx             /* work with packs of 2 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_32_to_16  /* 1 pixel? Can't use dual-pixel code */
#endif

      _align_
      next_block_32_to_16:
         movq (%eax), %mm0
         movq %mm0, %mm1
         nop
         movq %mm0, %mm2
         PAND (5, 0)        /* pand %mm5, %mm0 */
         psrld $3, %mm0
         PAND (3, 1)        /* pand %mm3, %mm1 */
         psrld $5, %mm1
         por %mm1, %mm0
         addl $8, %eax
         PAND (4, 2)        /* pand %mm4, %mm2 */
         psrld $8, %mm2
         nop
         nop
         por %mm2, %mm0
         movq %mm0, %mm6
         psrlq $16, %mm0
         por %mm0, %mm6
         movd %mm6, (%ebx)
         addl $4, %ebx

         decl %edx
         jnz next_block_32_to_16

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_32_to_16:
         movl %ebp, %edx      /* restore width */
         shrl $1, %edx
         jnc end_of_line_32_to_16

         movd (%eax), %mm0
         movq %mm0, %mm1
         movq %mm0, %mm2
         PAND (5, 0)          /* pand %mm5, %mm0 - get Blue component */
         PAND (3, 1)          /* pand %mm3, %mm1 - get Red component */
         psrld $3, %mm0       /* adjust Red, Green and Blue to correct positions */
         PAND (4, 2)          /* pand %mm4, %mm2 - get Green component */
         psrld $5, %mm1
         psrld $8, %mm2
         por %mm1, %mm0       /* combine Red and Blue */
         addl $4, %eax
         por %mm2, %mm0       /* and green */
         movq %mm0, %mm6      /* make the pixels fit in the first 32 bits */
         psrlq $16, %mm0
         por %mm0, %mm6
         movd %mm6, %edx
         addl $2, %ebx
         movw %dx, -2(%ebx)   /* write */

   _align_
   end_of_line_32_to_16:
#endif

      addl %esi, %eax
      movl %ebp, %edx         /* restore width */
      addl %edi, %ebx
      decl %ecx
      jnz next_line_32_to_16

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



/* void _colorconv_blit_32_to_24 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_32_to_24)
   movl GLOBL(cpu_mmx), %eax     /* if MMX is enabled (or not disabled :) */
   test %eax, %eax
   jz _colorconv_blit_32_to_24_no_mmx

   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG1, %eax                    /* eax = src_rect         */
   movl GFXRECT_WIDTH(%eax), %ecx     /* ecx = src_rect->width  */
   movl GFXRECT_HEIGHT(%eax), %edx    /* edx = src_rect->height */
   shll $2, %ecx                      /* ecx = SCREEN_W * 4     */
   movl GFXRECT_DATA(%eax), %esi      /* esi = src_rect->data   */
   movl GFXRECT_PITCH(%eax), %eax     /* eax = src_rect->pitch  */
   subl %ecx, %eax

   movl ARG2, %ebx                    /* ebx = dest_rect        */
   shrl $2, %ecx                      /* ecx = SCREEN_W         */
   leal (%ecx, %ecx, 2), %ebp         /* ebp = SCREEN_W * 3     */
   movl GFXRECT_DATA(%ebx), %edi      /* edi = dest_rect->data  */
   movl GFXRECT_PITCH(%ebx), %ebx     /* ebx = dest_rect->pitch */
   subl %ebp, %ebx
   movd %ecx, %mm7

   /* 32 bit to 24 bit conversion:
    we have:
    eax = offset from the end of a line to the beginning of the next
    ebx = same as eax, but for the dest bitmap
    ecx = SCREEN_W
    edx = SCREEN_H
    esi = src_rect->data
    edi = dest_rect->data
   */

   _align_
   next_line_32_to_24:
      shrl $2, %ecx             /* work with packs of 4 pixels */

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      jz do_one_pixel_32_to_24  /* less than 4 pixels? Can't work with the main loop */
#endif

      _align_
      next_block_32_to_24:
         movq (%esi), %mm0         /* mm0 = [.RGB1][.RGB0] */
         movq 8(%esi), %mm1        /* mm1 = [.RGB3][.RGB2] */
         movq %mm0, %mm2
         movq %mm1, %mm3
         movq %mm1, %mm4
         psllq $48, %mm3
         psllq $40, %mm0
         psrlq $32, %mm2
         psrlq $40, %mm0
         psllq $24, %mm2
         por %mm3, %mm0
         por %mm2, %mm0
         psllq $8, %mm4
         psllq $40, %mm1
         psrlq $32, %mm4
         psrlq $56, %mm1
         por %mm4, %mm1
         movq %mm0, (%edi)
         movd %mm1, 8(%edi)
         addl $16, %esi
         addl $12, %edi

         decl %ecx
         jnz next_block_32_to_24

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_32_to_24:
         movd %mm7, %ecx           /* restore width */
         andl $3, %ecx
         jz end_of_line_32_to_24   /* nothing to do? */

         shrl $1, %ecx
         jnc do_two_pixels_32_to_24

         movl (%esi), %ecx
         addl $4, %esi
         movw %cx, (%edi)
         shrl $16, %ecx
         addl $3, %edi
         movb %cl, -1(%edi)

         movd %mm7, %ecx
         shrl $1, %ecx             /* restore width */

      do_two_pixels_32_to_24:
         shrl $1, %ecx
         jnc end_of_line_32_to_24

         movq (%esi), %mm0         /* read 2 pixels */

         movq %mm0, %mm1

         psllq $40, %mm0
         psrlq $32, %mm1
         psrlq $40, %mm0
         psllq $24, %mm1

         por %mm1, %mm0

         movd %mm0, (%edi)
         psrlq $32, %mm0
         movd %mm0, %ecx
         movw %cx, 2(%edi)

         addl $8, %esi
         addl $6, %edi

   _align_
   end_of_line_32_to_24:
#endif

      addl %eax, %esi
      movd %mm7, %ecx           /* restore width */
      addl %ebx, %edi
      decl %edx
      jnz next_line_32_to_24

   emms
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret

#endif  /* ALLEGRO_COLOR32 */

#endif  /* ALLEGRO_MMX */



/********************************************************************************************/
/* pure 386 asm routines                                                                    */
/*  optimized for Intel Pentium                                                             */
/********************************************************************************************/

/* create the (pseudo - we need %ebp) stack frame */
#define CREATE_STACK_FRAME  \
   pushl %ebp             ; \
   movl %esp, %ebp        ; \
   pushl %ebx             ; \
   pushl %esi             ; \
   pushl %edi

#define DESTROY_STACK_FRAME \
   popl %edi              ; \
   popl %esi              ; \
   popl %ebx              ; \
   popl %ebp

/* reserve storage for ONE 32-bit push on the stack */
#define MYLOCAL1   -8(%esp)
#define MYLOCAL2  -12(%esp)
#define MYLOCAL3  -16(%esp)

/* initialize the registers */
#define SIZE_1
#define SIZE_2 addl %ebx, %ebx
#define SIZE_3 leal (%ebx,%ebx,2), %ebx
#define SIZE_4 shll $2, %ebx
#define LOOP_RATIO_1
#define LOOP_RATIO_2 shrl $1, %edi
#define LOOP_RATIO_4 shrl $2, %edi

#define INIT_REGISTERS_NO_MMX(src_mul_code, dest_mul_code, width_ratio_code)        \
   movl ARG1, %eax                  /* eax      = src_rect                    */  ; \
   movl GFXRECT_WIDTH(%eax), %ebx   /* ebx      = src_rect->width             */  ; \
   movl GFXRECT_HEIGHT(%eax), %ecx  /* ecx      = src_rect->height            */  ; \
   movl GFXRECT_PITCH(%eax), %edx   /* edx      = src_rect->pitch             */  ; \
   movl %ebx, %edi                  /* edi      = width                       */  ; \
   src_mul_code                     /* ebx      = width*x                     */  ; \
   movl GFXRECT_DATA(%eax), %esi    /* esi      = src_rect->data              */  ; \
   subl %ebx, %edx                                                                ; \
   movl %edi, %ebx                                                                ; \
   width_ratio_code                                                               ; \
   movl ARG2, %eax                  /* eax      = dest_rect                   */  ; \
   movl %edi, MYLOCAL1              /* MYLOCAL1 = width/y                     */  ; \
   movl %edx, MYLOCAL2              /* MYLOCAL2 = src_rect->pitch - width*x   */  ; \
   dest_mul_code                    /* ebx      = width*y                     */  ; \
   movl GFXRECT_PITCH(%eax), %edx   /* edx      = dest_rect->pitch            */  ; \
   subl %ebx, %edx                                                                ; \
   movl GFXRECT_DATA(%eax), %edi    /* edi      = dest_rect->data             */  ; \
   movl %edx, MYLOCAL3              /* MYLOCAL3 = dest_rect->pitch - width*y  */

  /* registers state after initialization:
    eax: free 
    ebx: free
    ecx: (int) height
    edx: free (for the inner loop counter)
    esi: (char *) source surface pointer
    edi: (char *) destination surface pointer
    ebp: free (for the lookup table base pointer)
    MYLOCAL1: (const int) width/ratio
    MYLOCAL2: (const int) offset from the end of a line to the beginning of next
    MYLOCAL3: (const int) same as MYLOCAL2, but for the dest bitmap
   */


#define CONV_TRUE_TO_8_NO_MMX(name, bytes_ppixel)                                 \
   _align_                                                                      ; \
   next_line_##name:                                                            ; \
      movl MYLOCAL1, %edx                                                       ; \
      pushl %ecx                                                                ; \
                                                                                ; \
      _align_                                                                   ; \
      next_block_##name:                                                        ; \
         movl $0, %ecx                                                          ; \
         movb (%esi), %al          /* read 1 pixel */                           ; \
         movb 1(%esi), %bl                                                      ; \
         movb 2(%esi), %cl                                                      ; \
         shrb $4, %al                                                           ; \
         addl $bytes_ppixel, %esi                                               ; \
         shll $4, %ecx                                                          ; \
         andb $0xf0, %bl                                                        ; \
         orb  %bl, %al             /* combine to get 4.4.4 */                   ; \
         incl %edi                                                              ; \
         movb %al, %cl                                                          ; \
         movb (%ebp, %ecx), %cl    /* look it up */                             ; \
         movb %cl, -1(%edi)        /* write 1 pixel */                          ; \
         decl %edx                                                              ; \
         jnz next_block_##name                                                  ; \
                                                                                ; \
      popl %ecx                                                                 ; \
      addl MYLOCAL2, %esi                                                       ; \
      addl MYLOCAL3, %edi                                                       ; \
      decl %ecx                                                                 ; \
      jnz next_line_##name


#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH

#define CONV_TRUE_TO_15_NO_MMX(name, bytes_ppixel)                                 \
   _align_                                                                       ; \
   next_line_##name:                                                             ; \
      movl MYLOCAL1, %edx                                                        ; \
      pushl %ecx                                                                 ; \
                                                                                 ; \
      _align_                                                                    ; \
      /* 100% Pentium pairable loop */                                           ; \
      /* 11 cycles = 10 cycles/2 pixels + 1 cycle loop */                        ; \
      next_block_##name:                                                         ; \
         movb bytes_ppixel(%esi), %al     /* al = b8 pixel2                  */  ; \
         addl $4, %edi                    /* 2 pixels written                */  ; \
         shrb $3, %al                     /* al = b5 pixel2                  */  ; \
         movb bytes_ppixel+1(%esi), %bh   /* ebx = g8 pixel2 << 8            */  ; \
         shll $16, %ebx                   /* ebx = g8 pixel2 << 24           */  ; \
         movb bytes_ppixel+2(%esi), %ah   /* eax = r8b5 pixel2               */  ; \
         shrb $1, %ah                     /* eax = r7b5 pixel2               */  ; \
         movb (%esi), %cl                 /* cl = b8 pixel1                  */  ; \
         shrb $3, %cl                     /* cl = b5 pixel1                  */  ; \
         movb 1(%esi), %bh                /* ebx = g8 pixel2 | g8 pixel1     */  ; \
         shll $16, %eax                   /* eax = r7b5 pixel2 << 16         */  ; \
         movb 2(%esi), %ch                /* ecx = r8b5 pixel1               */  ; \
         shrb $1, %ch                     /* ecx = r7b5 pixel1               */  ; \
         addl $bytes_ppixel*2, %esi       /* 2 pixels read                   */  ; \
         shrl $6, %ebx                    /* ebx = g5 pixel2 | g5 pixel1     */  ; \
         orl  %ecx, %eax                  /* eax = r7b5 pixel2 | r7b5 pixel1 */  ; \
         andl $0x7c1f7c1f, %eax           /* eax = r5b5 pixel2 | r5b5 pixel1 */  ; \
         andl $0x03e003e0, %ebx           /* clean g5 pixel2 | g5 pixel1     */  ; \
         orl  %ebx, %eax                  /* eax = pixel2 | pixel1           */  ; \
         decl %edx                                                               ; \
         movl %eax, -4(%edi)              /* write pixel1..pixel2            */  ; \
         jnz next_block_##name                                                   ; \
                                                                                 ; \
      popl %ecx                                                                  ; \
      addl MYLOCAL2, %esi                                                        ; \
      addl MYLOCAL3, %edi                                                        ; \
      decl %ecx                                                                  ; \
      jnz next_line_##name


#define CONV_TRUE_TO_16_NO_MMX(name, bytes_ppixel)                                 \
   _align_                                                                       ; \
   next_line_##name:                                                             ; \
      movl MYLOCAL1, %edx                                                        ; \
      pushl %ecx                                                                 ; \
                                                                                 ; \
      _align_                                                                    ; \
      /* 100% Pentium pairable loop */                                           ; \
      /* 10 cycles = 9 cycles/2 pixels + 1 cycle loop */                         ; \
      next_block_##name:                                                         ; \
         movb bytes_ppixel(%esi), %al     /* al = b8 pixel2                  */  ; \
         addl $4, %edi                    /* 2 pixels written                */  ; \
         shrb $3, %al                     /* al = b5 pixel2                  */  ; \
         movb bytes_ppixel+1(%esi), %bh   /* ebx = g8 pixel2 << 8            */  ; \
         shll $16, %ebx                   /* ebx = g8 pixel2 << 24           */  ; \
         movb (%esi), %cl                 /* cl = b8 pixel1                  */  ; \
         shrb $3, %cl                     /* cl = b5 pixel1                  */  ; \
         movb bytes_ppixel+2(%esi), %ah   /* eax = r8b5 pixel2               */  ; \
         shll $16, %eax                   /* eax = r8b5 pixel2 << 16         */  ; \
         movb 1(%esi), %bh                /* ebx = g8 pixel2 | g8 pixel1     */  ; \
         shrl $5, %ebx                    /* ebx = g6 pixel2 | g6 pixel1     */  ; \
         movb 2(%esi), %ch                /* ecx = r8b5 pixel1               */  ; \
         orl  %ecx, %eax                  /* eax = r8b5 pixel2 | r8b5 pixel1 */  ; \
         addl $bytes_ppixel*2, %esi       /* 2 pixels read                   */  ; \
         andl $0xf81ff81f, %eax           /* eax = r5b5 pixel2 | r5b5 pixel1 */  ; \
         andl $0x07e007e0, %ebx           /* clean g6 pixel2 | g6 pixel1     */  ; \
         orl  %ebx, %eax                  /* eax = pixel2 | pixel1           */  ; \
         decl %edx                                                               ; \
         movl %eax, -4(%edi)              /* write pixel1..pixel2            */  ; \
         jnz next_block_##name                                                   ; \
                                                                                 ; \
      popl %ecx                                                                  ; \
      addl MYLOCAL2, %esi                                                        ; \
      addl MYLOCAL3, %edi                                                        ; \
      decl %ecx                                                                  ; \
      jnz next_line_##name

#else

#define CONV_TRUE_TO_15_NO_MMX(name, bytes_ppixel)                                 \
   _align_                                                                       ; \
   next_line_##name:                                                             ; \
      movl MYLOCAL1, %edx                                                        ; \
                                                                                 ; \
      shrl $1, %edx                                                              ; \
      jz do_one_pixel_##name                                                     ; \
                                                                                 ; \
      pushl %ecx                                                                 ; \
                                                                                 ; \
      _align_                                                                    ; \
      /* 100% Pentium pairable loop */                                           ; \
      /* 11 cycles = 10 cycles/2 pixels + 1 cycle loop */                        ; \
      next_block_##name:                                                         ; \
         movb bytes_ppixel(%esi), %al     /* al = b8 pixel2                  */  ; \
         addl $4, %edi                    /* 2 pixels written                */  ; \
         shrb $3, %al                     /* al = b5 pixel2                  */  ; \
         movb bytes_ppixel+1(%esi), %bh   /* ebx = g8 pixel2 << 8            */  ; \
         shll $16, %ebx                   /* ebx = g8 pixel2 << 24           */  ; \
         movb bytes_ppixel+2(%esi), %ah   /* eax = r8b5 pixel2               */  ; \
         shrb $1, %ah                     /* eax = r7b5 pixel2               */  ; \
         movb (%esi), %cl                 /* cl = b8 pixel1                  */  ; \
         shrb $3, %cl                     /* cl = b5 pixel1                  */  ; \
         movb 1(%esi), %bh                /* ebx = g8 pixel2 | g8 pixel1     */  ; \
         shll $16, %eax                   /* eax = r7b5 pixel2 << 16         */  ; \
         movb 2(%esi), %ch                /* ecx = r8b5 pixel1               */  ; \
         shrb $1, %ch                     /* ecx = r7b5 pixel1               */  ; \
         addl $bytes_ppixel*2, %esi       /* 2 pixels read                   */  ; \
         shrl $6, %ebx                    /* ebx = g5 pixel2 | g5 pixel1     */  ; \
         orl  %ecx, %eax                  /* eax = r7b5 pixel2 | r7b5 pixel1 */  ; \
         andl $0x7c1f7c1f, %eax           /* eax = r5b5 pixel2 | r5b5 pixel1 */  ; \
         andl $0x03e003e0, %ebx           /* clean g5 pixel2 | g5 pixel1     */  ; \
         orl  %ebx, %eax                  /* eax = pixel2 | pixel1           */  ; \
         decl %edx                                                               ; \
         movl %eax, -4(%edi)              /* write pixel1..pixel2            */  ; \
         jnz next_block_##name                                                   ; \
                                                                                 ; \
      popl %ecx                                                                  ; \
                                                                                 ; \
      do_one_pixel_##name:                                                       ; \
         movl MYLOCAL1, %edx                                                     ; \
         shrl $1, %edx                                                           ; \
         jnc end_of_line_##name                                                  ; \
                                                                                 ; \
         movb (%esi), %dl                 /* dl = b8 pixel1                  */  ; \
         addl $2, %edi                                                           ; \
         shrb $3, %dl                     /* dl = b5 pixel1                  */  ; \
         movb 1(%esi), %bh                /* ebx = g8 pixel1                 */  ; \
         shrl $6, %ebx                    /* ebx = g5 pixel1                 */  ; \
         movb 2(%esi), %dh                /* edx = r8b5 pixel1               */  ; \
         shrb $1, %dh                     /* edx = r7b5 pixel1               */  ; \
         addl $bytes_ppixel, %esi         /* 1 pixel read                    */  ; \
         andl $0x7c1f, %edx               /* edx = r5b5 pixel1               */  ; \
         andl $0x03e0, %ebx               /* clean g5 pixel1                 */  ; \
         orl  %ebx, %edx                  /* ecx = pixel1                    */  ; \
         movw %dx, -2(%edi)               /* write pixel1                    */  ; \
                                                                                 ; \
   _align_                                                                       ; \
   end_of_line_##name:                                                           ; \
      addl MYLOCAL2, %esi                                                        ; \
      addl MYLOCAL3, %edi                                                        ; \
      decl %ecx                                                                  ; \
      jnz next_line_##name


#define CONV_TRUE_TO_16_NO_MMX(name, bytes_ppixel)                                 \
   _align_                                                                       ; \
   next_line_##name:                                                             ; \
      movl MYLOCAL1, %edx                                                        ; \
                                                                                 ; \
      shrl $1, %edx                                                              ; \
      jz do_one_pixel_##name                                                     ; \
                                                                                 ; \
      pushl %ecx                                                                 ; \
                                                                                 ; \
      _align_                                                                    ; \
      /* 100% Pentium pairable loop */                                           ; \
      /* 10 cycles = 9 cycles/2 pixels + 1 cycle loop */                         ; \
      next_block_##name:                                                         ; \
         movb bytes_ppixel(%esi), %al     /* al = b8 pixel2                  */  ; \
         addl $4, %edi                    /* 2 pixels written                */  ; \
         shrb $3, %al                     /* al = b5 pixel2                  */  ; \
         movb bytes_ppixel+1(%esi), %bh   /* ebx = g8 pixel2 << 8            */  ; \
         shll $16, %ebx                   /* ebx = g8 pixel2 << 24           */  ; \
         movb (%esi), %cl                 /* cl = b8 pixel1                  */  ; \
         shrb $3, %cl                     /* cl = b5 pixel1                  */  ; \
         movb bytes_ppixel+2(%esi), %ah   /* eax = r8b5 pixel2               */  ; \
         shll $16, %eax                   /* eax = r8b5 pixel2 << 16         */  ; \
         movb 1(%esi), %bh                /* ebx = g8 pixel2 | g8 pixel1     */  ; \
         shrl $5, %ebx                    /* ebx = g6 pixel2 | g6 pixel1     */  ; \
         movb 2(%esi), %ch                /* ecx = r8b5 pixel1               */  ; \
         orl  %ecx, %eax                  /* eax = r8b5 pixel2 | r8b5 pixel1 */  ; \
         addl $bytes_ppixel*2, %esi       /* 2 pixels read                   */  ; \
         andl $0xf81ff81f, %eax           /* eax = r5b5 pixel2 | r5b5 pixel1 */  ; \
         andl $0x07e007e0, %ebx           /* clean g6 pixel2 | g6 pixel1     */  ; \
         orl  %ebx, %eax                  /* eax = pixel2 | pixel1           */  ; \
         decl %edx                                                               ; \
         movl %eax, -4(%edi)              /* write pixel1..pixel2            */  ; \
         jnz next_block_##name                                                   ; \
                                                                                 ; \
      popl %ecx                                                                  ; \
                                                                                 ; \
      do_one_pixel_##name:                                                       ; \
         movl MYLOCAL1, %edx                                                     ; \
         shrl $1, %edx                                                           ; \
         jnc end_of_line_##name                                                  ; \
                                                                                 ; \
         movb (%esi), %dl                 /* dl = b8 pixel1                  */  ; \
         addl $2, %edi                                                           ; \
         shrb $3, %dl                     /* dl = b5 pixel1                  */  ; \
         movb 1(%esi), %bh                /* ebx = g8 pixel1                 */  ; \
         shrl $5, %ebx                    /* ebx = g6 pixel1                 */  ; \
         movb 2(%esi), %dh                /* edx = r8b5 pixel1               */  ; \
         addl $bytes_ppixel, %esi         /* 1 pixel read                    */  ; \
         andl $0xf81f, %edx               /* edx = r5b5 pixel1               */  ; \
         andl $0x07e0, %ebx               /* clean g6 pixel1                 */  ; \
         orl  %ebx, %edx                  /* ecx = pixel1                    */  ; \
         movw %dx, -2(%edi)               /* write pixel1                    */  ; \
                                                                                 ; \
   _align_                                                                       ; \
   end_of_line_##name:                                                           ; \
      addl MYLOCAL2, %esi                                                        ; \
      addl MYLOCAL3, %edi                                                        ; \
      decl %ecx                                                                  ; \
      jnz next_line_##name

#endif  /* ALLEGRO_COLORCONV_ALIGNED_WIDTH */



#ifdef ALLEGRO_COLOR8

/* void _colorconv_blit_8_to_8 (struct GRAPHICS_RECT *src_rect,
 *                              struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_8_to_8)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_1, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_1, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_rgb_map), %ebp

   _align_
   next_line_8_to_8_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx                /* work in packs of 4 pixels */
      jz do_one_pixel_8_to_8_no_mmx
#endif

      pushl %ecx

      _align_
      next_block_8_to_8_no_mmx:
         movl (%esi), %eax         /* read 4 pixels */
         movl $0, %ebx
         movl $0, %ecx
         addl $4, %esi
         addl $4, %edi
         movb %al, %bl             /* pick out 2x bottom 8 bits */
         movb %ah, %cl
         shrl $16, %eax
         movb (%ebp, %ebx), %bl    /* lookup the new palette entries */
         movb (%ebp, %ecx), %bh
         movl $0, %ecx
         movb %ah, %cl             /* repeat for the top 16 bits */
         andl $0xff, %eax
         movb (%ebp, %eax), %al
         movb (%ebp, %ecx), %ah
         shll $16, %eax
         orl %ebx, %eax            /* put everything together */
         movl %eax, -4(%edi)       /* write 4 pixels */
         decl %edx
         jnz next_block_8_to_8_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_8_to_8_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_8_to_8_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_8_to_8_no_mmx

         movl $0, %eax
         movb (%esi), %al          /* read 1 pixel */
         incl %edi
         incl %esi
         movb (%ebp, %eax), %al    /* lookup the new palette entry */
         movb %al, -1(%edi)        /* write 1 pixel */

      do_two_pixels_8_to_8_no_mmx:
         shrl $1, %edx
         jnc end_of_line_8_to_8_no_mmx

         movl $0, %eax
         movl $0, %ebx
         movb (%esi), %al          /* read 2 pixels */
         movb 1(%esi), %bl
         addl $2, %edi
         addl $2, %esi
         movb (%ebp, %eax), %al    /* lookup the new palette entry */
         movb (%ebp, %ebx), %bl
         movb %al, -2(%edi)        /* write 2 pixels */
         movb %bl, -1(%edi)

   _align_
   end_of_line_8_to_8_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_8_to_8_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_8_to_15 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
/* void _colorconv_blit_8_to_16 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_8_to_16_no_mmx:
#else
FUNC (_colorconv_blit_8_to_15)
FUNC (_colorconv_blit_8_to_16)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_2, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_2, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_indexed_palette), %ebp
   movl $0, %eax  /* init first line */

   _align_
   next_line_8_to_16_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_8_to_16_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 10 cycles = 9 cycles/4 pixels + 1 cycle loop */
      next_block_8_to_16_no_mmx:
         movl $0, %ebx
         movb (%esi), %al             /* al = pixel1            */
         movl $0, %ecx
         movb 1(%esi), %bl            /* bl = pixel2            */
         movb 2(%esi), %cl            /* cl = pixel3            */
         movl (%ebp,%eax,4), %eax     /* lookup: ax = pixel1    */
         movl 1024(%ebp,%ebx,4), %ebx /* lookup: bx = pixel2    */
         addl $4, %esi                /* 4 pixels read          */
         orl  %ebx, %eax              /* eax = pixel2..pixel1   */
         movl $0, %ebx
         movl %eax, (%edi)            /* write pixel1, pixel2   */
         movb -1(%esi), %bl           /* bl = pixel4            */
         movl (%ebp,%ecx,4), %ecx     /* lookup: cx = pixel3    */
         movl $0, %eax
         movl 1024(%ebp,%ebx,4), %ebx /* lookup: bx = pixel4    */
         addl $8, %edi                /* 4 pixels written       */
         orl  %ebx, %ecx              /* ecx = pixel4..pixel3   */
         decl %edx
         movl %ecx, -4(%edi)          /* write pixel3, pixel4   */
         jnz next_block_8_to_16_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_8_to_16_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_8_to_16_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_8_to_16_no_mmx

         movl $0, %eax
         incl %esi
         movb -1(%esi), %al
         movl (%ebp, %eax, 4), %ebx
         addl $2, %edi
         movl $0, %eax
         movw %bx, -2(%edi)

      do_two_pixels_8_to_16_no_mmx:
         shrl $1, %edx
         jnc end_of_line_8_to_16_no_mmx

         movl $0, %ebx
         movb (%esi), %al
         movb 1(%esi), %bl
         addl $2, %esi
         movl (%ebp, %eax, 4), %eax
         movl 1024(%ebp, %ebx, 4), %ebx
         addl $4, %edi
         orl %eax, %ebx
         movl $0, %eax
         movl %ebx, -4(%edi)

    _align_
    end_of_line_8_to_16_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_8_to_16_no_mmx
 
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_8_to_24 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_8_to_24)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_3, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_3, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_indexed_palette), %ebp
   movl $0, %eax  /* init first line */

   _align_
   next_line_8_to_24_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_8_to_24_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 12 cycles = 11 cycles/4 pixels + 1 cycle loop */
      next_block_8_to_24_no_mmx:
         movl $0, %ebx
         movb 3(%esi), %al               /* al = pixel4                     */
         movb 2(%esi), %bl               /* bl = pixel3                     */
         movl $0, %ecx
         movl 3072(%ebp,%eax,4), %eax    /* lookup: eax = pixel4 << 8       */
         movb 1(%esi), %cl               /* cl = pixel 2                    */
         movl 2048(%ebp,%ebx,4), %ebx    /* lookup: ebx = g8b800r8 pixel3   */
         addl $12, %edi                  /* 4 pixels written                */
         movl 1024(%ebp,%ecx,4), %ecx    /* lookup: ecx = b800r8g8 pixel2   */
         movb %bl, %al                   /* eax = pixel4 << 8 | r8 pixel3   */
         movl %eax, -4(%edi)             /* write r8 pixel3..pixel4         */
         movl $0, %eax
         movb %cl, %bl                   /* ebx = g8b8 pixel3 | 00g8 pixel2 */
         movb (%esi), %al                /* al = pixel1                     */
         movb %ch, %bh                   /* ebx = g8b8 pixel3 | r8g8 pixel2 */
         andl $0xff000000, %ecx          /* ecx = b8 pixel2 << 24           */
         movl %ebx, -8(%edi)             /* write g8r8 pixel2..b8g8 pixel3  */
         movl (%ebp,%eax,4), %eax        /* lookup: eax = pixel1            */
         orl  %eax, %ecx                 /* ecx = b8 pixel2 << 24 | pixel1  */
         movl $0, %eax
         movl %ecx, -12(%edi)            /* write pixel1..b8 pixel2         */
         addl $4, %esi                   /* 4 pixels read                   */
         decl %edx
         jnz next_block_8_to_24_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_8_to_24_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_8_to_24_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_8_to_24_no_mmx

         movl $0, %eax
         movb (%esi), %al                /* al = pixel1                     */
         incl %esi
         movl (%ebp,%eax,4), %eax        /* lookup: eax = pixel1            */
         movw %ax, (%edi)
         shrl $16, %eax
         addl $3, %edi
         movb %al, -1(%edi)
         movl $0, %eax

       do_two_pixels_8_to_24_no_mmx:
         shrl $1, %edx
         jnc end_of_line_8_to_24_no_mmx

         movl $0, %ebx
         movb (%esi), %al                /* al = pixel1                     */
         movb 1(%esi), %bl               /* bl = pixel2                     */
         addl $2, %esi
         movl (%ebp,%eax,4), %eax        /* lookup: eax = pixel1            */
         movl (%ebp,%ebx,4), %ebx        /* lookup: ebx = pixel2            */
         movl %eax, (%edi)               /* write pixel1                    */
         movw %bx, 3(%edi)
         shrl $16, %ebx
         addl $6, %edi
         movb %bl, -1(%edi)
         movl $0, %eax

   _align_
   end_of_line_8_to_24_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_8_to_24_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_8_to_32 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_8_to_32_no_mmx:
#else
FUNC (_colorconv_blit_8_to_32)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_4, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_1, SIZE_4, LOOP_RATIO_1)
#endif

   movl $0, %eax  /* init first line */
   movl GLOBL(_colorconv_indexed_palette), %ebp

   _align_
   next_line_8_to_32_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_8_to_32_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 10 cycles = 9 cycles/4 pixels + 1 cycle loop */
      next_block_8_to_32_no_mmx:
         movb (%esi), %al           /* al = pixel1          */
         movl $0, %ebx
         movb 1(%esi), %bl          /* bl = pixel2          */
         movl $0, %ecx
         movl (%ebp,%eax,4), %eax   /* lookup: eax = pixel1 */
         movb 2(%esi), %cl          /* cl = pixel3          */
         movl %eax, (%edi)          /* write pixel1         */
         movl (%ebp,%ebx,4), %ebx   /* lookup: ebx = pixel2 */
         movl $0, %eax
         movl (%ebp,%ecx,4), %ecx   /* lookup: ecx = pixel3 */
         movl %ebx, 4(%edi)         /* write pixel2         */
         movb 3(%esi), %al          /* al = pixel4          */
         movl %ecx, 8(%edi)         /* write pixel3         */
         addl $16, %edi             /* 4 pixels written     */
         movl (%ebp,%eax,4), %eax   /* lookup: eax = pixel4 */
         addl $4, %esi              /* 4 pixels read        */
         movl %eax, -4(%edi)        /* write pixel4         */
         movl $0, %eax
         decl %edx
         jnz next_block_8_to_32_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_8_to_32_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_8_to_32_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_8_to_32_no_mmx

         movb (%esi), %al           /* read one pixel */
         incl %esi
         movl (%ebp,%eax,4), %ebx   /* lookup: ebx = pixel */
         addl $4, %edi
         movl $0, %eax
         movl %ebx, -4(%edi)        /* write pixel */

      do_two_pixels_8_to_32_no_mmx:
         shrl $1, %edx
         jnc end_of_line_8_to_32_no_mmx

         movb (%esi), %al           /* read one pixel */
         movl $0, %ebx
         addl $2, %esi
         movb -1(%esi), %bl         /* read another pixel */         
         movl (%ebp,%eax,4), %edx   /* lookup: edx = pixel */
         movl (%ebp,%ebx,4), %ebx   /* lookup: ebx = pixel */
         addl $8, %edi
         movl $0, %eax
         movl %edx, -8(%edi)        /* write pixel */
         movl %ebx, -4(%edi)        /* write pixel */

   _align_
   end_of_line_8_to_32_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_8_to_32_no_mmx

   DESTROY_STACK_FRAME
   ret

#endif  /* ALLEGRO_COLOR8 */



#ifdef ALLEGRO_COLOR16

/* void _colorconv_blit_15_to_8 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_15_to_8)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_1, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_1, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_rgb_map), %ebp

   _align_
   next_line_15_to_8_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $1, %edx                /* work in packs of 2 pixels */
      jz do_one_pixel_15_to_8_no_mmx
#endif

      pushl %ecx

      _align_
      next_block_15_to_8_no_mmx:
         movl (%esi), %eax         /* read 2 pixels */
         addl $4, %esi
         addl $2, %edi
         movl %eax, %ebx           /* get bottom 16 bits */
         movl %eax, %ecx
         andl $0x781e, %ebx
         andl $0x03c0, %ecx
         shrb $1, %bl              /* shift to correct positions */
         shrb $3, %bh
         shrl $2, %ecx
         shrl $16, %eax
         orl %ecx, %ebx            /* combine to get a 4.4.4 number */
         movl %eax, %ecx
         movb (%ebp, %ebx), %bl    /* look it up */
         andl $0x781f, %eax
         andl $0x03c0, %ecx
         shrb $1, %al              /* shift to correct positions */
         shrb $3, %ah
         shrl $2, %ecx
         orl %ecx, %eax            /* combine to get a 4.4.4 number */
         movb (%ebp, %eax), %bh    /* look it up */
         movw %bx, -2(%edi)        /* write 2 pixels */
         decl %edx
         jnz next_block_15_to_8_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_15_to_8_no_mmx:
         movl MYLOCAL1, %edx
         shrl $1, %edx
         jnc end_of_line_15_to_8_no_mmx

         movl $0, %eax
         movw (%esi), %ax          /* read 1 pixel */
         addl $2, %esi
         incl %edi
         movl %eax, %ebx
         andl $0x781e, %ebx
         andl $0x03c0, %eax
         shrb $1, %bl              /* shift to correct positions */
         shrb $3, %bh
         shrl $2, %eax
         orl %eax, %ebx            /* combine to get a 4.4.4 number */
         movb (%ebp, %ebx), %bl    /* look it up */
         movb %bl, -1(%edi)        /* write 1 pixel */

   _align_
   end_of_line_15_to_8_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_15_to_8_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_15_to_16 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_15_to_16_no_mmx:
#else
FUNC (_colorconv_blit_15_to_16)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_2, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_2, LOOP_RATIO_1)
#endif

   _align_
   next_line_15_to_16_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_15_to_16_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 10 cycles = 9 cycles/4 pixels + 1 cycle loop */
      next_block_15_to_16_no_mmx:
         movl (%esi), %eax           /* eax = pixel2 | pixel1  */
         addl $8, %edi               /* 4 pixels written       */
         movl %eax, %ebx             /* ebx = pixel2 | pixel1  */
         andl $0x7fe07fe0, %eax      /* eax = r5g5b0 | r5g5b0  */
         shll $1, %eax               /* eax = r5g6b0 | r5g6b0  */
         andl $0x001f001f, %ebx      /* ebx = r0g0b5 | r0g0b5  */
         orl  %ebx, %eax             /* eax = r5g6b5 | r5g6b5  */
         movl 4(%esi), %ecx          /* ecx = pixel4 | pixel3  */
         movl %ecx, %ebx             /* ebx = pixel4 | pixel3  */
         andl $0x7fe07fe0, %ecx      /* ecx = r5g5b0 | r5g5b0  */
         shll $1, %ecx               /* ecx = r5g6b0 | r5g6b0  */
         andl $0x001f001f, %ebx      /* ebx = r0g0b5 | r0g0b5  */
         orl  %ebx, %ecx             /* ecx = r5g6b5 | r5g6b5  */
         orl  $0x00200020, %eax      /* green gamma correction */
         movl %eax, -8(%edi)         /* write pixel1..pixel2   */
         orl  $0x00200020, %ecx      /* green gamma correction */
         movl %ecx, -4(%edi)         /* write pixel3..pixel4   */
         addl $8, %esi               /* 4 pixels read          */
         decl %edx
         jnz next_block_15_to_16_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_15_to_16_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_15_to_16_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_15_to_16_no_mmx

         movl $0, %eax
         movw (%esi), %ax
         addl $2, %edi
         movl %eax, %ebx
         andl $0x7fe0, %eax
         andl $0x001f, %ebx
         shll $1, %eax
         addl $2, %esi
         orl $0x0020, %eax
         orl %ebx, %eax
         movw %ax, -2(%edi)

      do_two_pixels_15_to_16_no_mmx:
         shrl $1, %edx
         jnc end_of_line_15_to_16_no_mmx

         movl (%esi), %eax
         addl $4, %edi
         movl %eax, %ebx
         andl $0x7fe07fe0, %eax
         andl $0x001f001f, %ebx
         shll $1, %eax
         addl $4, %esi
         orl $0x00200020, %eax
         orl %ebx, %eax
         movl %eax, -4(%edi)

   _align_
   end_of_line_15_to_16_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_15_to_16_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_15_to_24 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
/* void _colorconv_blit_16_to_24 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_15_to_24)
FUNC (_colorconv_blit_16_to_24)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_3, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_3, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_rgb_scale_5x35), %ebp

   next_line_16_to_24_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_16_to_24_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 22 cycles = 20 cycles/4 pixels + 1 cycle stack + 1 cycle loop */
      next_block_16_to_24_no_mmx:
         movl %edx, -16(%esp)           /* fake pushl %edx                  */
         movl $0, %ebx
         movl $0, %eax
         movb 7(%esi), %bl              /* bl = high byte pixel4            */
         movl $0, %ecx
         movb 6(%esi), %al              /* al = low byte pixel4             */
         movl (%ebp,%ebx,4), %ebx       /* lookup: ebx = r8g8b0 pixel4      */
         movb 4(%esi), %cl              /* cl = low byte pixel3             */
         movl 1024(%ebp,%eax,4), %eax   /* lookup: eax = r0g8b8 pixel4      */
         movl $0, %edx
         addl %ebx, %eax                /* eax = r8g8b8 pixel4              */
         movb 5(%esi), %dl              /* dl = high byte pixel3            */
         shll $8, %eax                  /* eax = r8g8b8 pixel4 << 8         */
         movl 5120(%ebp,%ecx,4), %ecx   /* lookup: ecx = g8b800r0 pixel3    */
         movl 4096(%ebp,%edx,4), %edx   /* lookup: edx = g8b000r8 pixel3    */
         movl $0, %ebx
         addl %edx, %ecx                /* ecx = g8b800r8 pixel3            */
         movb %dl, %al                  /* eax = pixel4 << 8 | r8 pixel3    */
         movl %eax, 8(%edi)             /* write r8 pixel3..pixel4          */
         movb 3(%esi), %bl              /* bl = high byte pixel2            */
         movl $0, %eax
         movl $0, %edx
         movb 2(%esi), %al              /* al = low byte pixel2             */
         movl 2048(%ebp,%ebx,4), %ebx   /* lookup: ebx = b000r8g8 pixel2    */
         movb 1(%esi), %dl              /* dl = high byte pixel1            */
         addl $12, %edi                 /* 4 pixels written                 */
         movl 3072(%ebp,%eax,4), %eax   /* lookup: eax = b800r0g8 pixel2    */
         addl $8, %esi                  /* 4 pixels read                    */
         addl %ebx, %eax                /* eax = b800r8g8 pixel2            */
         movl (%ebp,%edx,4), %edx       /* lookup: edx = r8g8b0 pixel1      */
         movb %al, %cl                  /* ecx = g8b8 pixel3 | 00g8 pixel2  */
         movl $0, %ebx
         movb %ah, %ch                  /* ecx = g8b8 pixel3 | r8g8 pixel2  */
         movb -8(%esi), %bl             /* bl = low byte pixel1             */
         movl %ecx, -8(%edi)            /* write g8r8 pixel2..b8g8 pixel3   */
         andl $0xff000000, %eax         /* eax = b8 pixel2 << 24            */
         movl 1024(%ebp,%ebx,4), %ebx   /* lookup: ebx = r0g8b8 pixel1      */
         /* nop */
         addl %edx, %ebx                /* ebx = r8g8b8 pixel1              */
         movl -16(%esp), %edx           /* fake popl %edx                   */
         orl  %ebx, %eax                /* eax = b8 pixel2 << 24 | pixel1   */
         decl %edx
         movl %eax, -12(%edi)           /* write pixel1..b8 pixel2          */
         jnz next_block_16_to_24_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_16_to_24_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_16_to_24_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_16_to_24_no_mmx

         movl $0, %eax
         movl $0, %ebx
         movb 1(%esi), %al              /* al = high byte pixel1            */
         addl $3, %edi                  /* 1 pixel written                  */
         addl $2, %esi                  /* 1 pixel  read                    */
         movl (%ebp,%eax,4), %eax       /* lookup: eax = r8g8b0 pixel1      */
         movb -2(%esi), %bl             /* bl = low byte pixel1             */
         movl 1024(%ebp,%ebx,4), %ebx   /* lookup: ebx = r0g8b8 pixel1      */
         addl %eax, %ebx                /* ebx = r8g8b8 pixel1              */
         movw %bx, -3(%edi)
         shrl $16, %ebx
         movb %bl, -1(%edi)

       do_two_pixels_16_to_24_no_mmx:
         shrl $1, %edx
         jnc end_of_line_16_to_24_no_mmx

         movl $0, %eax
         movl $0, %ebx
         movb 1(%esi), %al              /* al = high byte pixel1            */
         addl $6, %edi                  /* 1 pixel written                  */
         addl $4, %esi                  /* 1 pixel  read                    */
         movl (%ebp,%eax,4), %eax       /* lookup: eax = r8g8b0 pixel1      */
         movb -4(%esi), %bl             /* bl = low byte pixel1             */
         movl 1024(%ebp,%ebx,4), %ebx   /* lookup: ebx = r0g8b8 pixel1      */
         addl %eax, %ebx                /* ebx = r8g8b8 pixel1              */
         movl $0, %eax
         movl %ebx, -6(%edi)            /* write pixel1                     */
         movb -1(%esi), %al             /* al = high byte pixel2            */
         movl $0, %ebx
         movl (%ebp,%eax,4), %eax       /* lookup: eax = r8g8b0 pixel2      */
         movb -2(%esi), %bl             /* bl = low byte pixel2             */
         movl 1024(%ebp,%ebx,4), %ebx   /* lookup: ebx = r0g8b8 pixel2      */
         addl %eax, %ebx                /* ebx = r8g8b8 pixel2              */
         movw %bx, -3(%edi)             /* write pixel2                     */
         shrl $16, %ebx
         movb %bl, -1(%edi)

   _align_
   end_of_line_16_to_24_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_16_to_24_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_15_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
/* void _colorconv_blit_16_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_15_to_32_no_mmx:
_colorconv_blit_16_to_32_no_mmx:
#else
FUNC (_colorconv_blit_15_to_32)
FUNC (_colorconv_blit_16_to_32)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_4, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_4, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_rgb_scale_5x35), %ebp
   movl $0, %eax  /* init first line */

   _align_
   next_line_16_to_32_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $1, %edx
      jz do_one_pixel_16_to_32_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 10 cycles = 9 cycles/2 pixels + 1 cycle loop */
      next_block_16_to_32_no_mmx:
         movl $0, %ebx
         movb (%esi), %al               /* al = low byte pixel1        */
         movl $0, %ecx
         movb 1(%esi), %bl              /* bl = high byte pixel1       */
         movl 1024(%ebp,%eax,4), %eax   /* lookup: eax = r0g8b8 pixel1 */
         movb 2(%esi), %cl              /* cl = low byte pixel2        */
         movl (%ebp,%ebx,4), %ebx       /* lookup: ebx = r8g8b0 pixel1 */
         addl $8, %edi                  /* 2 pixels written            */
         addl %ebx, %eax                /* eax = r8g8b8 pixel1         */
         movl $0, %ebx
         movl 1024(%ebp,%ecx,4), %ecx   /* lookup: ecx = r0g8b8 pixel2 */
         movb 3(%esi), %bl              /* bl = high byte pixel2       */
         movl %eax, -8(%edi)            /* write pixel1                */
         movl $0, %eax
         movl (%ebp,%ebx,4), %ebx       /* lookup: ebx = r8g8b0 pixel2 */
         addl $4, %esi                  /* 4 pixels read               */
         addl %ebx, %ecx                /* ecx = r8g8b8 pixel2         */
         decl %edx
         movl %ecx, -4(%edi)            /* write pixel2                */
         jnz next_block_16_to_32_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_16_to_32_no_mmx:
         movl MYLOCAL1, %edx            /* restore width */
         shrl $1, %edx
         jnc end_of_line_16_to_32_no_mmx

         movl $0, %ebx
         movb (%esi), %al               /* al = low byte pixel1        */
         addl $4, %edi                  /* 2 pixels written            */
         movb 1(%esi), %bl              /* bl = high byte pixel1       */
         movl 1024(%ebp,%eax,4), %eax   /* lookup: eax = r0g8b8 pixel1 */
         movl (%ebp,%ebx,4), %ebx       /* lookup: ebx = r8g8b0 pixel1 */
         addl $2, %esi
         addl %eax, %ebx                /* ebx = r8g8b8 pixel1         */
         movl $0, %eax
         movl %ebx, -4(%edi)            /* write pixel1                */

      _align_
      end_of_line_16_to_32_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_16_to_32_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_16_to_8 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_16_to_8)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_1, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_1, LOOP_RATIO_1)
#endif

   movl GLOBL(_colorconv_rgb_map), %ebp

   _align_
   next_line_16_to_8_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $1, %edx                /* work in packs of 2 pixels */
      jz do_one_pixel_16_to_8_no_mmx
#endif

      pushl %ecx

      _align_
      next_block_16_to_8_no_mmx:
         movl (%esi), %eax         /* read 2 pixels */
         addl $4, %esi
         addl $2, %edi
         movl %eax, %ebx           /* get bottom 16 bits */
         movl %eax, %ecx
         andl $0xf01e, %ebx
         andl $0x0780, %ecx
         shrb $1, %bl              /* shift to correct positions */
         shrb $4, %bh
         shrl $3, %ecx
         shrl $16, %eax
         orl %ecx, %ebx            /* combine to get a 4.4.4 number */
         movl %eax, %ecx
         movb (%ebp, %ebx), %bl    /* look it up */         
         andl $0xf01e, %eax
         andl $0x0780, %ecx
         shrb $1, %al              /* shift to correct positions */
         shrb $4, %ah
         shrl $3, %ecx
         orl %ecx, %eax            /* combine to get a 4.4.4 number */
         movb (%ebp, %eax), %bh    /* look it up */
         movw %bx, -2(%edi)        /* write 2 pixels */
         decl %edx
         jnz next_block_16_to_8_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_16_to_8_no_mmx:
         movl MYLOCAL1, %edx
         shrl $1, %edx
         jnc end_of_line_16_to_8_no_mmx

         movl $0, %eax
         movw (%esi), %ax          /* read 1 pixel */
         addl $2, %esi
         incl %edi
         movl %eax, %ebx
         andl $0xf01e, %ebx
         andl $0x0780, %eax
         shrb $1, %bl              /* shift to correct positions */
         shrb $4, %bh
         shrl $3, %eax
         orl %eax, %ebx            /* combine to get a 4.4.4 number */
         movb (%ebp, %ebx), %bl    /* look it up */
         movb %bl, -1(%edi)        /* write 1 pixel */

   _align_
   end_of_line_16_to_8_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_16_to_8_no_mmx

   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_16_to_15 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_16_to_15_no_mmx:
#else
FUNC (_colorconv_blit_16_to_15)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_2, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_2, SIZE_2, LOOP_RATIO_1)
#endif

   _align_
   next_line_16_to_15_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_16_to_15_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 9 cycles = 8 cycles/4 pixels + 1 cycle loop */
      next_block_16_to_15_no_mmx:
         movl (%esi), %eax         /* eax = pixel2 | pixel1 */
         addl $8, %edi             /* 4 pixels written      */
         movl %eax, %ebx           /* ebx = pixel2 | pixel1 */
         andl $0xffc0ffc0, %eax    /* eax = r5g6b0 | r5g6b0 */
         shrl $1, %eax             /* eax = r5g5b0 | r5g5b0 */
         andl $0x001f001f, %ebx    /* ebx = r0g0b5 | r0g0b5 */
         orl %ebx, %eax            /* eax = r5g5b5 | r5g5b5 */
         movl 4(%esi), %ecx        /* ecx = pixel4 | pixel3 */
         movl %ecx, %ebx           /* ebx = pixel4 | pixel3 */
         andl $0xffc0ffc0, %ecx    /* ecx = r5g6b0 | r5g6b0 */
         shrl $1, %ecx             /* ecx = r5g5b0 | r5g5b0 */
         andl $0x001f001f, %ebx    /* ebx = r0g0b5 | r0g0b5 */
         movl %eax, -8(%edi)       /* write pixel1..pixel2  */
         orl %ebx, %ecx            /* ecx = r5g5b5 | r5g5b5 */
         movl %ecx, -4(%edi)       /* write pixel3..pixel4  */
         addl $8, %esi             /* 4 pixels read         */
         decl %edx
         jnz next_block_16_to_15_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_16_to_15_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_16_to_15_no_mmx
         
         shrl $1, %edx
         jnc do_two_pixels_16_to_15_no_mmx

         movl $0, %eax
         movw (%esi), %ax
         addl $2, %edi
         movl %eax, %ebx
         andl $0xffc0ffc0, %eax
         andl $0x001f001f, %ebx
         shrl $1, %eax
         addl $2, %esi
         orl %ebx, %eax
         movw %ax, -2(%edi)

      do_two_pixels_16_to_15_no_mmx:
         shrl $1, %edx
         jnc end_of_line_16_to_15_no_mmx

         movl (%esi), %eax
         addl $4, %edi
         movl %eax, %ebx
         andl $0xffc0ffc0, %eax
         andl $0x001f001f, %ebx
         shrl $1, %eax
         addl $4, %esi
         orl %ebx, %eax
         movl %eax, -4(%edi)

   _align_
   end_of_line_16_to_15_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_16_to_15_no_mmx

   DESTROY_STACK_FRAME
   ret

#endif  /* ALLEGRO_COLOR16 */



#ifdef ALLEGRO_COLOR24

/* void _colorconv_blit_24_to_8 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_24_to_8)
   CREATE_STACK_FRAME
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_1, LOOP_RATIO_1)
   movl GLOBL(_colorconv_rgb_map), %ebp
   CONV_TRUE_TO_8_NO_MMX(24_to_8_no_mmx, 3)
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_24_to_15 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_24_to_15)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_2, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_2, LOOP_RATIO_1)
#endif

   CONV_TRUE_TO_15_NO_MMX(24_to_15_no_mmx, 3)
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_24_to_16 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_24_to_16)
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_2, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_2, LOOP_RATIO_1)
#endif

   CONV_TRUE_TO_16_NO_MMX(24_to_16_no_mmx, 3)
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_24_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_24_to_32_no_mmx:
#else
FUNC (_colorconv_blit_24_to_32)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_4, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_3, SIZE_4, LOOP_RATIO_1)
#endif

   _align_
   next_line_24_to_32_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_24_to_32_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 9 cycles = 8 cycles/4 pixels + 1 cycle loop */
      next_block_24_to_32_no_mmx:
         movl 4(%esi), %ebx        /* ebx = r8g8 pixel2         */
         movl (%esi), %eax         /* eax = pixel1              */
         shll $8, %ebx             /* ebx = r8g8b0 pixel2       */
         movl 8(%esi), %ecx        /* ecx = pixel4 | r8 pixel 3 */
         movl %eax, (%edi)         /* write pixel1              */
         movb 3(%esi), %bl         /* ebx = pixel2              */
         movl %ecx, %eax           /* eax = r8 pixel3           */
         movl %ebx, 4(%edi)        /* write pixel2              */
         shll $16, %eax            /* eax = r8g0b0 pixel3       */
         addl $16, %edi            /* 4 pixels written          */
         shrl $8, %ecx             /* ecx = pixel4              */
         movb 6(%esi), %al         /* eax = r8g0b8 pixel3       */
         movl %ecx, -4(%edi)       /* write pixel4              */
         movb 7(%esi), %ah         /* eax = r8g8b8 pixel3       */
         movl %eax, -8(%edi)       /* write pixel3              */
         addl $12, %esi            /* 4 pixels read             */
         decl %edx
         jnz next_block_24_to_32_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_24_to_32_no_mmx:
         movl MYLOCAL1, %edx      /* restore width */
         andl $3, %edx
         jz end_of_line_24_to_32_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_24_to_32_no_mmx

         movl $0, %eax
         movl $0, %ebx
         movw (%esi), %ax       /* read one pixel */
         movb 2(%esi), %bl
         addl $3, %esi
         shll $16, %ebx
         orl %ebx, %eax
         movl %eax, (%edi)         /* write */
         addl $4, %edi

      do_two_pixels_24_to_32_no_mmx:
         shrl $1, %edx
         jnc end_of_line_24_to_32_no_mmx

         movl $0, %ebx
         movl (%esi), %eax         /* read 2 pixels */
         movw 4(%esi), %bx
         movl %eax, %edx
         shll $8, %ebx
         shrl $24, %edx
         addl $6, %esi
         orl %edx, %ebx
         movl %eax, (%edi)         /* write */
         movl %ebx, 4(%edi)
         addl $8, %edi

   _align_
   end_of_line_24_to_32_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_24_to_32_no_mmx

   DESTROY_STACK_FRAME
   ret

#endif  /* ALLEGRO_COLOR24 */



#ifdef ALLEGRO_COLOR32

/* void _colorconv_blit_32_to_8 (struct GRAPHICS_RECT *src_rect,
 *                               struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorconv_blit_32_to_8)
   CREATE_STACK_FRAME
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_1, LOOP_RATIO_1)
   movl GLOBL(_colorconv_rgb_map), %ebp
   CONV_TRUE_TO_8_NO_MMX(32_to_8_no_mmx, 4)
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_32_to_15 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_32_to_15_no_mmx:
#else
FUNC (_colorconv_blit_32_to_15)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_2, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_2, LOOP_RATIO_1)
#endif

   CONV_TRUE_TO_15_NO_MMX(32_to_15_no_mmx, 4)
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_32_to_16 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_32_to_16_no_mmx:
#else
FUNC (_colorconv_blit_32_to_16)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_2, LOOP_RATIO_2)
#else
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_2, LOOP_RATIO_1)
#endif

   CONV_TRUE_TO_16_NO_MMX(32_to_16_no_mmx, 4)
   DESTROY_STACK_FRAME
   ret



/* void _colorconv_blit_32_to_24 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
#ifdef ALLEGRO_MMX
_align_
_colorconv_blit_32_to_24_no_mmx:
#else
FUNC (_colorconv_blit_32_to_24)
#endif
   CREATE_STACK_FRAME

#ifdef ALLEGRO_COLORCONV_ALIGNED_WIDTH
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_3, LOOP_RATIO_4)
#else
   INIT_REGISTERS_NO_MMX(SIZE_4, SIZE_3, LOOP_RATIO_1)
#endif

   _align_
   next_line_32_to_24_no_mmx:
      movl MYLOCAL1, %edx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      shrl $2, %edx
      jz do_one_pixel_32_to_24_no_mmx
#endif

      pushl %ecx

      _align_
      /* 100% Pentium pairable loop */
      /* 10 cycles = 9 cycles/4 pixels + 1 cycle loop */
      next_block_32_to_24_no_mmx:
         movl 4(%esi), %ebx     /* ebx = pixel2                    */
         addl $12, %edi         /* 4 pixels written                */
         movl %ebx, %ebp        /* ebp = pixel2                    */
         movl 12(%esi), %ecx    /* ecx = pixel4                    */
         shll $8, %ecx          /* ecx = pixel4 << 8               */
         movl (%esi), %eax      /* eax = pixel1                    */
         shll $24, %ebx         /* ebx = b8 pixel2 << 24           */
         movb 10(%esi), %cl     /* ecx = pixel4 | r8 pixel3        */
         orl  %eax, %ebx        /* ebx = b8 pixel2 | pixel1        */
         movl %ebp, %eax        /* eax = pixel2                    */
         shrl $8, %eax          /* eax = r8g8 pixel2               */
         movl %ebx, -12(%edi)   /* write pixel1..b8 pixel2         */
         movl 8(%esi), %ebx     /* ebx = pixel 3                   */
         movl %ecx, -4(%edi)    /* write r8 pixel3..pixel4         */
         shll $16, %ebx         /* ebx = g8b8 pixel3 << 16         */
         addl $16, %esi         /* 4 pixels read                   */
         orl  %ebx, %eax        /* eax = g8b8 pixel3 | r8g8 pixel2 */
         decl %edx
         movl %eax, -8(%edi)    /* write g8r8 pixel2..b8g8 pixel3  */
         jnz next_block_32_to_24_no_mmx

      popl %ecx

#ifndef ALLEGRO_COLORCONV_ALIGNED_WIDTH
      do_one_pixel_32_to_24_no_mmx:
         movl MYLOCAL1, %edx
         andl $3, %edx
         jz end_of_line_32_to_24_no_mmx

         shrl $1, %edx
         jnc do_two_pixels_32_to_24_no_mmx

         movl (%esi), %eax      /* read one pixel */
         addl $4, %esi
         movw %ax, (%edi)       /* write bottom 24 bits */
         shrl $16, %eax
         addl $3, %edi
         movb %al, -1(%edi)

      do_two_pixels_32_to_24_no_mmx:
         shrl $1, %edx
         jnc end_of_line_32_to_24_no_mmx

         movl (%esi), %eax      /* read two pixels */
         movl 4(%esi), %ebx
         addl $8, %esi
         movl %ebx, %edx
         andl $0xFFFFFF, %eax
         shll $24, %ebx
         orl %ebx, %eax
         shrl $8, %edx
         movl %eax, (%edi)      /* write bottom 48 bits */
         addl $6, %edi
         movw %dx, -2(%edi)

   _align_
   end_of_line_32_to_24_no_mmx:
#endif

      addl MYLOCAL2, %esi
      addl MYLOCAL3, %edi
      decl %ecx
      jnz next_line_32_to_24_no_mmx

   DESTROY_STACK_FRAME
   ret

#endif  /* ALLEGRO_COLOR32 */



#ifndef ALLEGRO_NO_COLORCOPY

/********************************************************************************************/
/* color copy routines                                                                      */
/*  386 and MMX support                                                                     */
/********************************************************************************************/


/* void _colorcopy (struct GRAPHICS_RECT *src_rect, struct GRAPHICS_RECT *dest_rect, int bpp)
 */
FUNC (_colorcopy)
   
   pushl %ebp
   movl %esp, %ebp
   pushl %ebx
   pushl %esi
   pushl %edi

   /* init register values */

   movl ARG3, %ebx
   movl ARG1, %eax                  /* eax = src_rect                 */
   movl GFXRECT_WIDTH(%eax), %eax
   mull %ebx

   movl %eax, %ecx                  /* ecx = src_rect->width * bpp    */
   movl ARG1, %eax
   movl GFXRECT_HEIGHT(%eax), %edx  /* edx = src_rect->height         */
   movl GFXRECT_DATA(%eax), %esi    /* esi = src_rect->data           */
   movl GFXRECT_PITCH(%eax), %eax   /* eax = src_rect->pitch          */
   subl %ecx, %eax                  /* eax = (src_rect->pitch) - ecx  */

   movl ARG2, %ebx                  /* ebx = dest_rect                */
   movl GFXRECT_DATA(%ebx), %edi    /* edi = dest_rect->data          */
   movl GFXRECT_PITCH(%ebx), %ebx   /* ebx = dest_rect->pitch         */
   subl %ecx, %ebx                  /* ebx = (dest_rect->pitch) - ecx */

   pushl %ecx

#ifdef ALLEGRO_MMX
   movl GLOBL(cpu_mmx), %ecx        /* if MMX is enabled (or not disabled :) */
   orl %ecx, %ecx
   jz next_line_no_mmx

   popl %ecx
   movd %ecx, %mm7                  /* save for later */
   shrl $5, %ecx                    /* we work with 32 pixels at a time */
   movd %ecx, %mm6

   _align_
   next_line:
      movd %mm6, %ecx
      orl %ecx, %ecx
      jz do_one_byte

      _align_
      next_block:
         movq (%esi), %mm0           /* read */
         movq 8(%esi), %mm1
         addl $32, %esi
         movq -16(%esi), %mm2
         movq -8(%esi), %mm3
         movq %mm0, (%edi)           /* write */
         movq %mm1, 8(%edi)
         addl $32, %edi
         movq %mm2, -16(%edi)
         movq %mm3, -8(%edi)
         decl %ecx
         jnz next_block

      do_one_byte:
         movd %mm7, %ecx
         andl $31, %ecx
         jz end_of_line

         shrl $1, %ecx
         jnc do_two_bytes

         movsb      

      do_two_bytes:
         shrl $1, %ecx
         jnc do_four_bytes

         movsb
         movsb

      _align_
      do_four_bytes:
         shrl $1, %ecx
         jnc do_eight_bytes

         movsl

      _align_
      do_eight_bytes:
         shrl $1, %ecx
         jnc do_sixteen_bytes

         movq (%esi), %mm0
         addl $8, %esi
         movq %mm0, (%edi)
         addl $8, %edi

      _align_
      do_sixteen_bytes:
         shrl $1, %ecx
         jnc end_of_line

         movq (%esi), %mm0
         movq 8(%esi), %mm1
         addl $16, %esi
         movq %mm0, (%edi)
         movq %mm1, 8(%edi)
         addl $16, %edi

   _align_
   end_of_line:
      addl %eax, %esi
      addl %ebx, %edi
      decl %edx
      jnz next_line

   emms
   jmp end_of_function
#endif

   _align_
   next_line_no_mmx:
      popl %ecx
      pushl %ecx
      shrl $2, %ecx
      orl %ecx, %ecx
      jz do_one_byte_no_mmx

      rep; movsl

      do_one_byte_no_mmx:
         popl %ecx
         pushl %ecx
         andl $3, %ecx
         jz end_of_line_no_mmx

         shrl $1, %ecx
         jnc do_two_bytes_no_mmx

         movsb

      do_two_bytes_no_mmx:
         shrl $1, %ecx
         jnc end_of_line_no_mmx

         movsb
         movsb

   _align_
   end_of_line_no_mmx:
      addl %eax, %esi
      addl %ebx, %edi
      decl %edx
      jnz next_line_no_mmx

      popl %ecx

end_of_function:
   popl %edi
   popl %esi
   popl %ebx
   popl %ebp

   ret



#ifdef ALLEGRO_COLOR16

/* void _colorcopy_blit_15_to_15 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
/* void _colorcopy_blit_16_to_16 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorcopy_blit_15_to_15)
FUNC (_colorcopy_blit_16_to_16)

   pushl %ebp
   movl %esp, %ebp

   pushl $2
   pushl ARG2
   pushl ARG1

   call GLOBL(_colorcopy)
   addl $12, %esp

   popl %ebp
   ret

#endif  /* ALLEGRO_COLOR16 */



#ifdef ALLEGRO_COLOR24

/* void _colorcopy_blit_24_to_24 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorcopy_blit_24_to_24)

   pushl %ebp
   movl %esp, %ebp

   pushl $3
   pushl ARG2
   pushl ARG1

   call GLOBL(_colorcopy)
   addl $12, %esp

   popl %ebp
   ret

#endif  /* ALLEGRO_COLOR24 */



#ifdef ALLEGRO_COLOR32

/* void _colorcopy_blit_32_to_32 (struct GRAPHICS_RECT *src_rect,
 *                                struct GRAPHICS_RECT *dest_rect)
 */
FUNC (_colorcopy_blit_32_to_32)

   pushl %ebp
   movl %esp, %ebp

   pushl $4
   pushl ARG2
   pushl ARG1

   call GLOBL(_colorcopy)
   addl $12, %esp

   popl %ebp
   ret

#endif  /* ALLEGRO_COLOR32 */

#endif  /* ALLEGRO_NO_COLORCOPY */

