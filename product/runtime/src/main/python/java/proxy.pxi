global_class("java.lang.ClassLoader")
global_class("java.lang.reflect.Proxy")
global_class("com.chaquo.python.PyInvocationHandler")
global_class("com.chaquo.python.PyProxy")


PROXY_BASE_NAME = "_chaquopy_proxy"


def dynamic_proxy(*interfaces):
    """Use this function in the bases of a class declaration, and that class will become a dynamic
    proxy. All parameters must be Java interface classes.
    """
    return DynamicProxyClass(PROXY_BASE_NAME, tuple(interfaces), {})

class DynamicProxyClass(JavaClass):
    def __new__(metacls, cls_name, bases, cls_dict):
        if cls_name == PROXY_BASE_NAME:
            for b in bases:
                if not (isinstance(b, type) and issubclass(b, JavaObject) and
                        b.getClass().isInterface()):
                    raise TypeError(f"{b!r} is not a Java interface")
            return type.__new__(metacls, cls_name, bases, cls_dict)

        else:
            global ClassLoader, Proxy, PyInvocationHandler, PyProxy
            if not (bases and bases[0].__name__ == PROXY_BASE_NAME):
                raise TypeError("dynamic_proxy must be used first in class bases")
            if any([b.__name__ == PROXY_BASE_NAME for b in bases[1:]]):
                raise TypeError("dynamic_proxy can only be used once in class bases")
            interfaces = (PyProxy,) + bases[0].__bases__
            klass = Proxy.getProxyClass(ClassLoader.getSystemClassLoader(), interfaces)
            cls_dict["_chaquopy_j_klass"] = klass._chaquopy_this
            # TODO: Python proxy objects should also be isinstance(java.lang.reflect.Proxy).
            cls = type.__new__(metacls, cls_name,
                               (DynamicProxy,) + interfaces + bases[1:],
                               cls_dict)
            add_member(cls, "<init>", JavaMethod("(Ljava/lang/reflect/InvocationHandler;)V"))
            add_member(cls, "_chaquopyGetDict", JavaMethod("()Lcom/chaquo/python/PyObject;"))
            add_member(cls, "_chaquopySetDict", JavaMethod("(Lcom/chaquo/python/PyObject;)V"))
            jclass_cache[klass.getName()] = cls
            return cls


class DynamicProxy(object):
    def __init__(self):
        JavaObject.__init__(self, PyInvocationHandler())

    def __getattr__(self, name):
        if name.startswith("_chaquopy"):
            error = "object's superclass __init__ must be called before using it as a Java object"
        else:
            # Exception type and wording are based on Python 2.7.
            error = f"object has no attribute '{name}'"
        raise AttributeError(f"'{type(self).__name__}' {error}")

    # Proxy objects can have user-defined Python attributes, so remove the restrictions imposed
    # by JavaObject.__setattr__.
    __setattr__ = object.__setattr__
