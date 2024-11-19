## UniApp

### Description

Some misc applications for various purposes.

### Compilation

```{julia}
using PackageCompiler

apps = ["gim" => "gim", "rmi" => "rmi"]

create_app("UniApp", "UniAppCompiled"; executables=apps, force=true)
# or
# this will make the compiled apps smaller
# because it only includes those standard libraries that the project needs
# instead of all standard libraries
# but this may cause unexpected errors
# if some dependent standard libraries without being reflected in the Project file
create_app("UniApp", "UniAppCompiled"; executables=apps, force=true, filter_stdlibs=true)
```

### Life

Still in development.