# Building ImLab with CMake

ImLab shipped with Tecgraf's `tecmake`, which resolves IUP, IM and CD through a shared
`TECTOOLS_HOME` tree and a matrix of `TEC_UNAME` platform names, and which has no macOS
support. `CMakeLists.txt` replaces it with an ordinary CMake build against libraries wherever
they actually are. The tecmake files (`tecmake.mak`, `src/config.mak`, `mak.*`) are left in
place; nothing reads them any more.

## Quick start (macOS)

    brew install tecgraf-im tecgraf-cd fftw
    cmake -S . -B build -DIUP_ROOT=/path/to/iup
    cmake --build build -j8
    ./build/imlab

`IUP_ROOT` can be omitted if the `IUP` environment variable is set, or if an IUP tree sits
beside this one. It must be a **source** tree — IupPlot and IupIm are compiled from it, since
IUP does not ship them as libraries.

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
