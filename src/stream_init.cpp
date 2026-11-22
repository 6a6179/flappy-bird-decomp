// Each of the view, engine and game translation units initialized libstdc++
// streams before main. Naming their guards separately preserves that lifetime
// and gives the linker three distinct addresses for the registered destructors.
#include <ios>

namespace {
std::ios_base::Init FLAP_STREAM_GUARD;
}
