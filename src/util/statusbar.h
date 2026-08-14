/** \file
 * \brief Status Bar for IUP Dialogs
 * \note Must create a IupCanvas with the attributes:
 * RASTERSIZE=1x26  EXPAND=HORIZONTAL  BORDER=NO */

#ifndef __STATBAR_H
#define __STATBAR_H

#if	defined(__cplusplus)
extern "C" {
#endif
        
/** Status Bar */
typedef struct _sbStatusBar
{
  cdCanvas* sbCanvas;
  int xy_pos, rgb_pos, rgb_size, height;
  char str[512];
  /* What each of the three areas currently shows. The bar is drawn imperatively -- a caller
     writes a value and it appears -- but the canvas can be repainted at any time by the window
     system, and a repaint used to redraw only the empty boxes, so the text vanished. Keeping
     the strings lets sbRepaint put them back. */
  char zoom_str[64];
  char xy_str[64];
  char msg_str[512];
  long background;
  long foreground;
}sbStatusBar;


/** Creates the status bar */
sbStatusBar* sbCreate(Ihandle* iupCanvas);

/** Destroys the status bar */
void sbKill(sbStatusBar* sb);

/** Draws zoom information */
void sbDrawZoom(sbStatusBar* sb, int z1, int z2);

/** Draws a text */
void sbDrawMessage(sbStatusBar* sb, const char* Msg);

/** Draws a percentage */
void sbDrawPercent(sbStatusBar* sb, int p);

/** Draws position information */
char* sbDrawXY(sbStatusBar* sb, int x, int y);

/** Draws position information */
char* sbDrawX(sbStatusBar* sb, int x);

/** Draws 2 component color information */
char* sbDrawAB(sbStatusBar* sb, void* a, void* b, int data_type);

/** Draws 3 component color information */
char* sbDrawABC(sbStatusBar* sb, void* a, void* b, void* c, int data_type);

/** Draws 4 component color information */
char* sbDrawABCD(sbStatusBar* sb, void* a, void* b, void* c, void* d, int data_type);

/** Draws gray information */
char* sbDrawA(sbStatusBar* sb, void* a, int data_type);

/** Draws indexed color information */
char* sbDrawMap(sbStatusBar* sb, long color, unsigned char i);

/** Clears all the areas */
void sbClear(sbStatusBar* sb);

#if defined(__cplusplus)
}
#endif

#endif  /* __STATBAR_H */
