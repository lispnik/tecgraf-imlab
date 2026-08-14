# Building ImLab with CMake

ImLab shipped with Tecgraf's `tecmake`, which resolves IUP, IM and CD through a shared
`TECTOOLS_HOME` tree and a matrix of `TEC_UNAME` platform names, and which has no macOS
support. `CMakeLists.txt` replaces it with an ordinary CMake build against libraries wherever
they actually are. The tecmake files (`tecmake.mak`, `src/config.mak`, `mak.*`) are left in
place; nothing reads them any more.

## Quick start (macOS)

    brew install lispnik/tecgraf/tecgraf-imlab

or, to build it yourself against installed libraries:

    brew install lispnik/tecgraf/tecgraf-{im,cd,iup} fftw
    cmake -S . -B build -DIMLAB_USE_SYSTEM_IUP=ON
    cmake --build build -j8
    ./build/imlab

IUP can arrive in either of two shapes and the build takes both:

- **installed** — a package such as Homebrew's `tecgraf-iup`, which carries `libiup_plot` and
  `libiupim` already built.
- **source tree** — pass `-DIUP_ROOT=/path/to/iup` (or set the `IUP` environment variable, or
  leave an IUP tree beside this one). IupPlot and IupIm are then compiled from it, since IUP
  ships them as source with no build of their own.

A source tree wins when one is found, so working on IUP and ImLab together does not mean
reinstalling IUP between builds; `-DIMLAB_USE_SYSTEM_IUP=ON` forces the installed one.

## The macOS application bundle

The build also produces `ImLab.app` beside the executable, with an icon generated from
`etc/ImLabLogo.png`, an `Info.plist` from `mak.macos/Info.plist.in`, and an ad-hoc signature --
without which a bundle copied from another machine is refused outright on Apple silicon.

    cmake --build build          # builds both build/imlab and build/ImLab.app
    open build/ImLab.app

It is assembled from the executable that was just built rather than compiled again as a
separate `MACOSX_BUNDLE` target: it is the same program, and a second target would double the
build for no difference in the result. `-DIMLAB_BUILD_APP_BUNDLE=OFF` skips it.

Nothing but the executable is in `Contents/MacOS`: `codesign` treats every other file there as
nested code and refuses to sign the bundle. So the images and kernels are in
`Contents/Resources`, and `load_image_imlab_logo` in `src/splash.cpp` now looks there too --
it previously searched only the executable's own directory and the one above it, which is
right for the plain executable and finds nothing in a bundle.

## Tests

    cmake -S . -B build -DIMLAB_BUILD_TESTS=ON && cmake --build build
    ctest --test-dir build              # or: test/run_tests.sh build/imlab

ImLab is a graphical application: what it does is put windows on screen and write files, so the
tests run the real program with a probe injected into it (`test/imlab_probe.m`,
`DYLD_INSERT_LIBRARIES`) and drive it through the callbacks its menus use. The windows are made
transparent and kept out of the Dock while they run, so a test run does not take over the
desktop.

| scenario | what it covers |
|---|---|
| `startup` | the main window comes up and the image named on the command line is opened |
| `saveas` | File > Save As all the way to a file on disk: the system save panel, then the format dialog, then the compression dialog |
| `save-edited` | an edit applied from the Process menu, then File > Save, which is deliberately a no-op on an unchanged document |

They need a window server, so they are opt-in rather than part of a default build.

## What it links against

| Dependency | Where it comes from |
|---|---|
| IM, `im_process`, `im_jp2` | Homebrew `tecgraf-im` |
| CD | Homebrew `tecgraf-cd` |
| IUP, IupControls, IupImageLib, IupCD, IupGL | frameworks in `$IUP_ROOT/BUILD-xcode/Release` |
| IupPlot, IupIm | compiled here from `$IUP_ROOT/srcplot` and `$IUP_ROOT/srcim` |
| FFTW (`im_fftw3`, `fftw3`, `fftw3f`) | Homebrew, optional — `-DIMLAB_ENABLE_FFTW=OFF` to skip |

The executable carries an rpath to the IUP framework directory, so it runs without
`DYLD_FRAMEWORK_PATH`. `etc/*.png` and `krn/` are copied beside the binary after each build,
because ImLab looks for its images next to the executable (see `load_image_imlab_logo` in
`src/splash.cpp`) and offers `krn/` as the convolution-kernel folder.

## What the old build wanted that this one does not

`src/config.mak` listed `cdpdf`, `pdflib`, `cdgl` and `cdcontextplus`. Nothing in `src/` calls
into any of them — they were link-time baggage:

- **`cdpdf` + `pdflib`** — PDF export goes through `CD_PDF`, which CD now implements natively on
  macOS (CGPDFContext); PDFlib is commercial and no longer distributed at all.
- **`cdcontextplus`** — CD's anti-aliased "Plus" contexts, not built on macOS. Quartz
  anti-aliases anyway.
- **`cdgl`** — CD-over-OpenGL. ImLab's 3D view drives OpenGL directly through IupGLCanvas.

## Platform differences that needed source changes

Two, both small and both guarded rather than rewritten:

- `src/windows/tridimwindow.cpp` included `<GL/gl.h>`. Apple ships the OpenGL headers in a
  framework, so that file now picks `<OpenGL/gl.h>` on `__APPLE__`.
- `src/windows/mainwindow_file.cpp` imported and exported Windows metafiles through
  `cdContextEMF` / `cdContextWMF`. CD provides those drivers only on Windows, so the four
  functions and their `IupSetFunction` registrations are now `#ifdef WIN32` — which is what
  they always effectively were. No menu item references them.

`src/plugin_capture.cpp` and `src/dialogs/imagecapture.cpp` are DirectShow video capture and
are Windows-only in this build too, exactly as in `config.mak`.

## Note on IUP

Starting ImLab used to crash immediately on macOS: it passes `IupGetGlobal("EXEFILENAME")`
straight to `strlen` when locating its images, and the Cocoa driver did not implement that
global. That is fixed in IUP itself (`src/cocoa/iupmac_globalattrib.m`), so an IUP tree from
before that change will still crash here.
