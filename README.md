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
Its type can be queried by the standard `Base` functions (`isfile`, `isdir`, `islink`, `isfifo`, `issocket`, `ischardev`, `isblockdev`). This will only call `stat` if  necessary -- which happens if the entry is a symlink and the type of the target needs to be determined. In this case, the link is followed from the path supplied to `scandir`, so the result may depend on the working directory if that path is relative.

```julia
julia> dir = mktempdir();
julia> cd(dir)
julia> mkdir("subdir");
julia> touch("file");
julia> symlink("subdir", "link")
julia> entries = scandir()
3-element Vector{DirEntry}:
 <file "./file">
 <link "./link">
 <directory "./subdir">

julia> isdir.(entries) # triggers `stat` call for "link" only
3-element BitArray{1}:
 0
 1
 1
 ```

`ScanDir.walkdir` is a faster implementation of `Base.walkdir` (https://docs.julialang.org/en/v1/base/file/#Base.Filesystem.walkdir), and has a compatible interface. Its interface differs from `Base.walkdir` in two ways:
 - it returns named tuples (root=..., dirs=..., file=...)
 - it supports a `prune` keyword argument to filter the returned contents.

```julia
julia> touch("subdir/file2");
julia> mkdir("subdir/skipme");
julia> touch("subdir/skipme/file3");
julia> collect(ScanDir.walkdir("."))
3-element Array{Any,1}:
 (root = ".", dirs = ["subdir"], files = ["file", "link"])
 (root = ".\\subdir", dirs = ["skipme"], files = ["file2"])
 (root = ".\\subdir\\skipme", dirs = String[], files = ["file3"])

julia> collect(ScanDir.walkdir(".", prune = e->startswith(e.name, "skip")))
2-element Array{Any,1}:
 (root = ".", dirs = ["subdir"], files = ["file", "link"])
 (root = ".\\subdir", dirs = String[], files = ["file2"])

```
 
 

