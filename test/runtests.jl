using Test
using ScanDir

# Tests copied and modified from julia's test/file.jl
dirwalk = mktempdir()
cd(dirwalk) do
    for i=1:2
        mkdir("sub_dir$i")
        open("file$i", "w") do f end

        mkdir(joinpath("sub_dir1", "subsub_dir$i"))
        touch(joinpath("sub_dir1", "file$i"))
    end
    touch(joinpath("sub_dir2", "file_dir2"))
    has_symlinks = !Sys.iswindows() || (Sys.windows_version() >= Sys.WINDOWS_VISTA_VER)
    follow_symlink_vec = has_symlinks ? [true, false] : [false]
    has_symlinks && symlink(abspath("sub_dir2"), joinpath("sub_dir1", "link"))
    for prune_subsub in [false, true]
        prune = prune_subsub ? e->startswith(e.name,"subsub") : _->false
        subsubs = prune_subsub ? [] : ["subsub_dir1", "subsub_dir2"]

        for follow_symlinks in follow_symlink_vec
            chnl = ScanDir.walkdir(".", follow_symlinks=follow_symlinks, prune=prune)

            root, dirs, files = take!(chnl)
            @test root == "."
            @test dirs == ["sub_dir1", "sub_dir2"]
            @test files == ["file1", "file2"]

            root, dirs, files = take!(chnl)
            @test root == joinpath(".", "sub_dir1")
            if has_symlinks
                if follow_symlinks
                    @test dirs ==  ["link"; subsubs]
                    @test files == ["file1", "file2"]
                else
                    @test dirs ==  subsubs
                    @test files == ["file1", "file2", "link"]
                end
            else
                @test dirs ==  subsubs
                @test files == ["file1", "file2"]
            end

            root, dirs, files = take!(chnl)
            if follow_symlinks
                @test root == joinpath(".", "sub_dir1", "link")
                @test dirs == []
                @test files == ["file_dir2"]
                root, dirs, files = take!(chnl)
            end
            if !prune_subsub
                for i=1:2
                    @test root == joinpath(".", "sub_dir1", "subsub_dir$i")
                    @test dirs == []
                    @test files == []
                    root, dirs, files = take!(chnl)
                end
            end

            @test root == joinpath(".", "sub_dir2")
            @test dirs == []
            @test files == ["file_dir2"]

            @test !isready(chnl)
        end

        for follow_symlinks in follow_symlink_vec
            chnl = ScanDir.walkdir(".", follow_symlinks=follow_symlinks, topdown=false, prune=prune)
            root, dirs, files = take!(chnl)
            if follow_symlinks
                @test root == joinpath(".", "sub_dir1", "link")
                @test dirs == []
                @test files == ["file_dir2"]
                root, dirs, files = take!(chnl)
            end
            if !prune_subsub
                for i=1:2
                    @test root == joinpath(".", "sub_dir1", "subsub_dir$i")
                    @test dirs == []
                    @test files == []
                    root, dirs, files = take!(chnl)
                end
            end
            @test root == joinpath(".", "sub_dir1")
            if has_symlinks
                if follow_symlinks
                    @test dirs ==  ["link"; subsubs]
                    @test files == ["file1", "file2"]
                else
                    @test dirs ==  subsubs
                    @test files == ["file1", "file2", "link"]
                end
            else
                @test dirs ==  subsubs
                @test files == ["file1", "file2"]
            end

            root, dirs, files = take!(chnl)
            @test root == joinpath(".", "sub_dir2")
            @test dirs == []
            @test files == ["file_dir2"]

            root, dirs, files = take!(chnl)
            @test root == "."
            @test dirs == ["sub_dir1", "sub_dir2"]
            @test files == ["file1", "file2"]

            @test !isready(chnl)
        end
    end

    # These subtly depend on timing, so removed for now
    # TODO need better way to test onerror
    # #test of error handling
    # chnl_error = ScanDir.walkdir(".")
    # chnl_noerror = ScanDir.walkdir(".", onerror=x->x)

    # root, dirs, files = take!(chnl_error)
    # #@show root
    # @test root == "."
    # @test dirs == ["sub_dir1", "sub_dir2"]
    # @test files == ["file1", "file2"]

    # rm(joinpath("sub_dir1"), recursive=true)
    # @test_throws Base.IOError take!(chnl_error) # throws an error because sub_dir1 do not exist

    # root, dirs, files = take!(chnl_noerror)
    # @test root == "."
    # @test dirs == ["sub_dir1", "sub_dir2"]
    # @test files == ["file1", "file2"]

    # root, dirs, files = take!(chnl_noerror) # skips sub_dir1 as it no longer exist
    # @test root == joinpath(".", "sub_dir2")
    # @test dirs == []
    # @test files == ["file_dir2"]

    # Test that symlink loops don't cause errors
    if has_symlinks
        mkdir(joinpath(".", "sub_dir3"))
        # this symlink requires admin privileges on Windows:
        symlink_err = false
        try
            symlink("foo", joinpath(".", "sub_dir3", "foo"))
        catch e
            symlink_err = true
            showerror(stderr, e); println(stderr)
            @warn "Could not create symlink. Symlink loop tests skipped."
        end

        if !symlink_err
            @test_throws Base.IOError ScanDir.walkdir(joinpath(".", "sub_dir3"); follow_symlinks=true)
            root, dirs, files = take!(ScanDir.walkdir(joinpath(".", "sub_dir3"); follow_symlinks=false))
            @test root == joinpath(".", "sub_dir3")
            @test dirs == []
            @test files == ["foo"]
        end
    end
end
rm(dirwalk, recursive=true)
