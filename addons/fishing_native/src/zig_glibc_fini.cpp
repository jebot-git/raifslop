// Zig 0.13's glibc shared-library CRT registers C++ destructors but does not
// install crtbeginS's __cxa_finalize hook. Finalize this DSO on dlclose, while
// its code is still mapped. Enabled only for our optional Zig/Linux toolchain.
extern "C" void *__dso_handle;
extern "C" void __cxa_finalize(void *);
__attribute__((destructor)) static void fishing_finalize_dso() {
 __cxa_finalize(&__dso_handle);
}
