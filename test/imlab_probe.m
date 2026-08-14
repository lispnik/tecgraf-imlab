/* A test harness for ImLab, injected with DYLD_INSERT_LIBRARIES.
 *
 * ImLab is a graphical application: what it does is put windows on screen and write files, and
 * neither can be checked by calling a function. So the test runs the real program and drives it
 * from inside, through the callbacks it registers with IupSetFunction and the buttons it
 * registers with IupSetHandle -- the same entry points its menus use.
 *
 * What each scenario does is chosen by IMLAB_TEST in the environment. Results go to stdout as
 * "ok" / "FAIL" lines, and the exit status is the number of failures, so the runner can simply
 * check it.
 *
 * Timing is driven by run-loop timers rather than dispatch blocks: several of these paths spin
 * their own nested loop (a modal panel, a sheet with IupLoopStep, IupPopup), and the main
 * dispatch queue is not drained inside those, while run-loop timers still fire.
 */
#import <Cocoa/Cocoa.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#include <iup.h>
#include "iup_object.h"

static int g_failures = 0;

static void chk(int condition, const char* what, const char* detail)
{
  printf("%-4s %-52s %s\n", condition ? "ok" : "FAIL", what, detail ? detail : "");
  fflush(stdout);
  if (!condition)
    g_failures++;
}

static void finish(void)
{
  printf("%d failure(s)\n", g_failures);
  fflush(stdout);
  exit(g_failures);
}

/* Schedules work on the main run loop, in the modes the nested loops run in. */
static void after(double seconds, void (^block)(void))
{
  NSTimer* timer = [NSTimer timerWithTimeInterval:seconds
                                          repeats:NO
                                            block:^(NSTimer* t) { (void)t; block(); }];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
}

/* Polls until the block reports it has done its work, or the attempts run out. */
static void poll_until(double interval, int attempts, int (^block)(void))
{
  __block int tries = 0;
  NSTimer* timer = [NSTimer timerWithTimeInterval:interval repeats:YES block:^(NSTimer* t) {
    if (block() || ++tries >= attempts)
      [t invalidate];
  }];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
  [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
}

/* Accepts the file panel on screen. -[NSSavePanel ok:] is not implemented on modern AppKit, so
   finish its run the way the Save button does: end the modal session, or the sheet, depending
   on how it was opened -- a PARENTDIALOG makes IUP run it as a sheet. */
static int accept_file_panel(void)
{
  for (NSWindow* window in [NSApp windows])
  {
    if (![window isKindOfClass:[NSSavePanel class]])
      continue;

    if ([window sheetParent])
      [[window sheetParent] endSheet:window returnCode:NSModalResponseOK];
    else
      [NSApp stopModalWithCode:NSModalResponseOK];

    return 1;
  }
  return 0;
}

/* Presses a button ImLab registered by name, and closes its dialog if the callback asks for it.
   Invoking the callback directly bypasses IupPopup's handling of IUP_CLOSE, so do it here. */
static int press_named_button(const char* handle_name)
{
  Ihandle* button = IupGetHandle(handle_name);
  Ihandle* dialog = button ? IupGetDialog(button) : NULL;
  Icallback callback;
  int result;

  if (!button || !dialog || !IupGetInt(dialog, "VISIBLE"))
    return 0;

  callback = IupGetCallback(button, "ACTION");
  result = callback ? callback(button) : IUP_DEFAULT;

  if (result == IUP_CLOSE)
    IupHide(dialog);

  return 1;
}

/* Presses the default button of any visible dialog other than the main window. IupGetParam --
   which is what ImLab's compression options dialog is -- marks its OK button as the dialog's
   DEFAULTENTER, so this presses OK without having to know anything about the dialog. */
extern Ihandle* iupDlgListFirst(void);
extern Ihandle* iupDlgListNext(void);

static int press_default_button(void)
{
  Ihandle* main_window = IupGetHandle("imlabMainWindow");
  Ihandle* dialog;

  for (dialog = iupDlgListFirst(); dialog; dialog = iupDlgListNext())
  {
    Ihandle* button;
    Icallback callback;
    int result;

    if (dialog == main_window || !IupGetInt(dialog, "VISIBLE"))
      continue;

    button = IupGetAttributeHandle(dialog, "DEFAULTENTER");
    if (!button)
      continue;

    callback = IupGetCallback(button, "ACTION");
    result = callback ? callback(button) : IUP_DEFAULT;

    if (result == IUP_CLOSE)
      IupHide(dialog);

    return 1;
  }

  return 0;
}

/* Finds a menu item by its title, anywhere under the application's menu, and invokes it -- the
   same callback the menu would fire. This is how an edit gets applied without a mouse. */
static Ihandle* find_menu_item(Ihandle* menu, const char* title)
{
  Ihandle* child;

  if (!menu)
    return NULL;

  for (child = IupGetNextChild(menu, NULL); child; child = IupGetNextChild(menu, child))
  {
    const char* class_name = IupGetClassName(child);
    char* child_title = IupGetAttribute(child, "TITLE");

    if (0 == strcmp(class_name, "item") && child_title && 0 == strcmp(child_title, title))
      return child;

    {
      Ihandle* found = find_menu_item(child, title);   /* submenus hold a menu of their own */
      if (found)
        return found;
    }
  }

  return NULL;
}

static int invoke_menu_item(const char* title)
{
  Ihandle* item = find_menu_item(IupGetHandle("mnMainMenu"), title);
  Icallback callback = item ? IupGetCallback(item, "ACTION") : NULL;

  if (!callback)
    return 0;

  callback(item);
  return 1;
}

static long file_mtime(const char* path)
{
  struct stat st;
  return stat(path, &st) == 0 ? (long)st.st_mtime : 0;
}

static int file_exists(const char* path)
{
  struct stat st;
  return stat(path, &st) == 0 && st.st_size > 0;
}

/* ------------------------------------------------------------------ scenarios ---- */

/* The application starts, shows its main window, and opens the image named on the command
   line. Everything else here depends on that much working. */
static void test_startup(void)
{
  Ihandle* main_window = IupGetHandle("imlabMainWindow");
  int documents = 0;

  chk(main_window != NULL, "the main window exists", NULL);

  /* the image passed on the command line becomes a document window */
  for (NSWindow* window in [NSApp windows])
    if ([[window title] hasPrefix:@"Bitmap of"])
      documents++;

  {
    char detail[128];
    snprintf(detail, sizeof detail, "%d document window(s)", documents);
    chk(documents > 0, "the image named on the command line was opened", detail);
  }

  finish();
}

/* File > Save As, all the way to a file on disk: the system save panel, then ImLab's format
   dialog, then its compression dialog. Each is a separate nested loop. */
static void test_save_as(void)
{
  const char* output = getenv("IMLAB_TEST_OUTPUT");
  Icallback save_as = IupGetFunction("imlabSaveAs");

  chk(save_as != NULL, "the Save As callback is registered", NULL);
  if (!save_as || !output)
    finish();

  /* Accept each dialog as it appears. The panel is first; the two IUP dialogs follow, and
     ImLab names their OK buttons, so they can be pressed by name. */
  poll_until(0.4, 40, ^int {
    if (accept_file_panel())
      return 0;                                   /* keep going: the dialogs come next */
    if (press_named_button("btSaveOK"))
      return 0;
    if (press_default_button())
      return 0;
    return file_exists(output);                   /* done once the file is there */
  });

  after(18.0, ^{
    char detail[1024];
    snprintf(detail, sizeof detail, "%s", output);
    chk(file_exists(output), "Save As wrote the file", detail);
    finish();
  });

  save_as(NULL);   /* this blocks until the whole chain of dialogs is finished */
}

/* File > Save on a document that has been edited. Save is deliberately a no-op on an unchanged
   document -- iImgDocSaveCheck only writes when ImageFile->changed is set -- so the test edits
   the image first, through the Process menu, exactly as a user would. */
static void test_save_edited(void)
{
  const char* output = getenv("IMLAB_TEST_OUTPUT");
  long before = output ? file_mtime(output) : 0;

  chk(invoke_menu_item("Negative"), "an edit can be applied from the Process menu", "Negative");

  after(2.0, ^{
    Icallback save = IupGetFunction("imlabSave");
    chk(save != NULL, "the Save callback is registered", NULL);

    /* Save may still put up format or compression dialogs, and for an image that is part of a
       sequence it asks a question first; accept whatever appears. */
    poll_until(0.4, 40, ^int {
      if (accept_file_panel())  return 0;
      if (press_named_button("btSaveOK")) return 0;
      if (press_default_button()) return 0;
      return file_mtime(output) > before;
    });

    after(16.0, ^{
      char detail[1024];
      snprintf(detail, sizeof detail, "%s, mtime %ld -> %ld", output, before, file_mtime(output));
      chk(file_mtime(output) > before, "Save rewrote the edited file", detail);
      finish();
    });

    if (save)
      save(NULL);
  });
}

__attribute__((constructor)) static void imlab_probe_init(void)
{
  const char* scenario = getenv("IMLAB_TEST");

  if (!scenario)
    return;

  /* Let ImLab finish starting: it shows a splash, builds its main window, and opens whatever
     was named on the command line. */
  after(4.0, ^{
    if (0 == strcmp(scenario, "startup"))
      test_startup();
    else if (0 == strcmp(scenario, "saveas"))
      test_save_as();
    else if (0 == strcmp(scenario, "save-edited"))
      test_save_edited();
    else
    {
      printf("unknown IMLAB_TEST scenario: %s\n", scenario);
      exit(2);
    }
  });
}
