module ScanDir

export scandir

import Base.Filesystem: uv_dirent_t
import Base: eventloop

struct DirEntry
    name::String
    type::Int
end

for (i,s) in enumerate((:isfile, :isdir, :islink, :isfifo, :issocket, :ischardev, :isblockdev))
    @eval Base.Filesystem.$s(e::DirEntry) = e.type == $i
end

filename(e::DirEntry) = e.name

# Implementation copied from Base.readdir and modified to return DirEntry's
function scandir(path::AbstractString)
    # Allocate space for uv_fs_t struct
    uv_readdir_req = zeros(UInt8, ccall(:jl_sizeof_uv_fs_t, Int32, ()))

    # defined in sys.c, to call uv_fs_readdir, which sets errno on error.
    err = ccall(:uv_fs_scandir, Int32, (Ptr{Cvoid}, Ptr{UInt8}, Cstring, Cint, Ptr{Cvoid}),
                eventloop(), uv_readdir_req, path, 0, C_NULL)
    err < 0 && throw(SystemError("unable to read directory $path", -err))

    # iterate the listing into entries
    entries = DirEntry[]
    ent = Ref{uv_dirent_t}()
    while Base.UV_EOF != ccall(:uv_fs_scandir_next, Cint, (Ptr{Cvoid}, Ptr{uv_dirent_t}), uv_readdir_req, ent)
        push!(entries, DirEntry(unsafe_string(ent[].name), ent[].typ))
    end

    # Clean up the request string
    if VERSION >= v"1.3"
        ccall(:uv_fs_req_cleanup, Cvoid, (Ptr{UInt8},), uv_readdir_req)
    else
        ccall(:jl_uv_fs_req_cleanup, Cvoid, (Ptr{UInt8},), uv_readdir_req)
    end

    return entries
end

scandir() = scandir(".")

# Implementation copied from Base.walkdir and modified to use scandir,
# to avoid unnecessary stat()ing
function walkdir(root; topdown=true, follow_symlinks=false, onerror=throw)
    content = nothing
    try
        content = scandir(root)
    catch err
        isa(err, SystemError) || throw(err)
        onerror(err)
        # Need to return an empty closed channel to skip the current root folder
        chnl = Channel(0)
        close(chnl)
        return chnl
    end
    dirs = filter(isdir, content)
    files = filter(isfile, content)
    dirnames = map(filename, dirs)
    filenames = map(filename, files)

    function _it(chnl)
        if topdown
            put!(chnl, (root, dirnames, filenames))
        end
        for dir in dirs
            if follow_symlinks || !islink(dir)
                path = joinpath(root,dir.name)
                for (root_l, dirs_l, files_l) in walkdir(path, topdown=topdown, follow_symlinks=follow_symlinks, onerror=onerror)
                    put!(chnl, (root_l, dirs_l, files_l))
                end
            end
        end
        if !topdown
            put!(chnl, (root, dirnames, filenames))
        end
    end

    return Channel(_it)
end


end # module
