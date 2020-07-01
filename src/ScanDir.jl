module ScanDir

export scandir

import Base.Filesystem: uv_dirent_t
import Base: eventloop

struct DirEntry
    name::String
    path::String
    type::Int
end

_islink(e::DirEntry) = e.type == 3
for (i,s) in enumerate((:isfile, :isdir, :islink, :isfifo, :issocket, :ischardev, :isblockdev))
    @eval Base.Filesystem.$s(e::DirEntry) = e.type == $i || _islink(e) && $s(e.path)
end

filename(e::DirEntry) = e.name

# Implementation copied from Base.readdir and modified to return DirEntry's
function scandir(path::AbstractString=".")
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
        ent_name = unsafe_string(ent[].name)
        ent_path = joinpath(path, ent_name)
        push!(entries, DirEntry(ent_name, ent_path, ent[].typ))
    end

    # Clean up the request string
    if VERSION >= v"1.3"
        ccall(:uv_fs_req_cleanup, Cvoid, (Ptr{UInt8},), uv_readdir_req)
    else
        ccall(:jl_uv_fs_req_cleanup, Cvoid, (Ptr{UInt8},), uv_readdir_req)
    end

    return entries
end

_walkdir_entry(root, dirs, files) = (root = root, dirs = dirs, files = files)

# Implementation copied from Base.walkdir and modified to use scandir,
# to avoid unnecessary stat()ing
function walkdir(root; topdown=true, follow_symlinks=false, onerror=throw, prune=_->false)
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

    isfilelike(e) = (!follow_symlinks && islink(e)) || !isdir(e)
    filter!(!prune, content)
    dirs = filter(!isfilelike, content)
    files = filter(isfilelike, content)
    dirnames = map(filename, dirs)
    filenames = map(filename, files)

    function _it(chnl)
        if topdown
            put!(chnl, _walkdir_entry(root, dirnames, filenames))
        end
        for dir in dirs
            path = joinpath(root,dir.name)
            for (root_l, dirs_l, files_l) in walkdir(path,
                    topdown=topdown, follow_symlinks=follow_symlinks, onerror=onerror, prune=prune)
                put!(chnl, _walkdir_entry(root_l, dirs_l, files_l))
            end
        end
        if !topdown
            put!(chnl, _walkdir_entry(root, dirnames, filenames))
        end
    end

    return Channel(_it)
end


end # module
