#if (!defined(__llvm__) && !defined(__INTEL_COMPILER) && defined(__GNUC__) && __GNUC__ < 5) || \
    (defined(__GLIBCXX__) && __GLIBCXX__ < 20160805)
#error "gcc with no or only partial c++11 support"
#endif

int main() {}
