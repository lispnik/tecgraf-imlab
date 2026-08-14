#include <iup.h>
#include <stdlib.h>
#include <stdio.h>

#include "imlab.h"
#include "imlab_images.h"


#ifndef WIN32
static void CreateCursorImage(int w, int h, unsigned char* bits, char* colors[], char* name)
{
  Ihandle* iup_image = IupImage(w, h, bits);
  IupSetHandle(name, iup_image); 

  int i = 0;
  while (colors[i] != NULL)
  {
    IupStoreAttributeId(iup_image, "", i, colors[i]); 
    i++;
  }
}
#endif

void imlabCreateButtonImages(void)
{
  IupSetHandle("imlabProgressCancel", load_image_cancel());
  IupSetHandle("imlabHistogramButton", create_image_histo());
  IupSetHandle("imlab3DButton", create_image_3d());
  IupSetHandle("imlabBitmapButton", create_image_bitmap());
  IupSetHandle("imlabMatrixButton", create_image_matrix());
  IupSetHandle("imlabLogo", create_image_imlab_logo());

#ifndef WIN32
  {
    unsigned char cross_bits[23 * 23] =
    {
     0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,2,2,2,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,2,2
    ,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1
    ,2,2,2,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,2,2
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    ,0,0,0,0,0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0,0,0,0
    };
    char* cross_colors[] =
    {
      "BGCOLOR",
      "255 255 255",
      "0 0 0",
      NULL
    };

    CreateCursorImage(23, 23, cross_bits, cross_colors, "CrossCursor");
    IupSetAttribute(IupGetHandle("CrossCursor"), "HOTSPOT", "11:11");  // From RC in Windows

    IupSetHandle("IMLAB", IupGetHandle("imlabLogo"));  // From RC in Windows
}
#endif
}
