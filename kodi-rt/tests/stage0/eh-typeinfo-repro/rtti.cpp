#include <typeinfo>
struct B { virtual ~B(); };
struct D : B { ~D(); };
D* down(B* b) { return dynamic_cast<D*>(b); }
const char* name(B* b) { return typeid(*b).name(); }
B::~B() {}
D::~D() {}
B* make() { return new D; }
