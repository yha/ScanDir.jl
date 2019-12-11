# ScanDir.jl

*Faster reading of directories*

This package provides two functions:
 - `scandir`, which returns a vector of `DirEntry` objects, each specifying a filename and a type (file, directory, link etc.).
 - `ScanDir.walkdir`, which is a faster version of `Base.walkdir`, using `scandir` to avoid unnecessary `stat` calls.

Julia's builtin `readdir` function returns filenames in a directory but discards the type information returned from the underlying `libuv` function call.
The `scandir` function exposes this information in the `DirEntry` struct. 
The name `scandir` was chosen to parallel python's `os.scandir`, which offers similar functionality.

Benchmarks of `ScanDir.walkdir` on one Windows machine have shown a speedup factor of 4\~4.5 on a local drive, and 30\~35 (!) on a network-mapped drive, compared to `Base.walkdir`.


## Usage
`scandir(path::AbstractString=".")` returns a vector of `DirEntry`. 
Each `DirEntry`'s filename is accessible via the `name` field. 
Its type can be queried by the standard `Base` functions (`isfile`, `isdir`, `islink`, `isfifo`, `issocket`, `ischardev`, `isblockdev`).

`ScanDir.walkdir` is a faster implementation of `Base.walkdir` (https://docs.julialang.org/en/v1/base/file/#Base.Filesystem.walkdir), and has the same interface.

