#include <iup.h>
#include <iupcontrols.h>
#include <iupgl.h>
#include <iupim.h>
#include <iup_plot.h>

#include <im_binfile.h>

#include <im_format_jp2.h>
#ifdef USE_AVI
#include <im_format_avi.h>
#endif
#ifdef USE_WMV
#include <im_format_wmv.h>
#endif

#include "imlab.h"
#include "imagedocument.h"
#include "mainwindow.h"

#include <stdlib.h>
#include <stdio.h>
#include <memory.h>
#include <string.h>
#include <locale.h>

#if _MSC_VER > 1900 /* Visual Studio 2017 and newer */
#define USE_UTF8_VC
#endif  


void imlabShowSplash(const char* exe_filename);


/***************************************/
/* Where everything begin and end...   */
/***************************************/

int main(int argc, char* argv[])
{
#ifdef USE_UTF8_VC
  imBinFileSetCurrentModule(IM_STREAM);  /* To use fopen instead of CreateFile/open in Windows/Linux by IM */
#endif

  imFormatRegisterJP2();
#ifdef USE_AVI
  imFormatRegisterAVI();
#endif
#ifdef USE_WMV
  imFormatRegisterWMV();
#endif

  /* Initialize the interface library */
  if (IupOpen(&argc, &argv) == IUP_ERROR)
    return 0;

#ifdef USE_UTF8_VC
  IupSetGlobal("UTF8MODE", "Yes");
  IupSetGlobal("UTF8MODE_FILE", "Yes");
  setlocale(LC_ALL, ".UTF8");
#endif

  IupSetLanguage("ENGLISH");

  setlocale(LC_NUMERIC, "C");
  IupSetGlobal("DEFAULTPRECISION", "4");

#ifdef _DEBUG
  IupSetGlobal("GLOBALLAYOUTDLGKEY", "Yes");
#endif

  IupControlsOpen();
  IupGLCanvasOpen();
  IupPlotOpen();
  IupImageLibOpen();
  IupImOpen();

  imlabShowSplash(IupGetGlobal("EXEFILENAME"));

  /* create the main window */
  imlabCreateMainWindow();

  /* process command line arguments */
  while (argc > 1)
  {
    imlabImageDocumentCreateFromFileName(argv[argc-1]);
    argc--;
  }

  /* Start the interface message loop */
  IupMainLoop();

  /* destroy the main window */
  imlabKillMainWindow();

  /* Terminates the interface library */
  IupClose();

  return EXIT_SUCCESS;
}
