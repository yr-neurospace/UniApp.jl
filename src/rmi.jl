const RM_BLACKLIST_FILE = "~/.rm_blacklist"

function rmi_parse_args()
    s = ArgParseSettings(prog="rm",
        description="A wrapper of `rm -rf`, which is developed to avoid mistakenly delete important files/directories.",
        version="0.1.0",
        add_version=true)

    @add_arg_table s begin
        "args"
        nargs = 'R'
        help = "Files and/or Directories"
    end

    return parse_args(s)
end

function rmi()::Cint
    if isfile(abspath(expanduser(RM_BLACKLIST_FILE)))
        rm_blacklist = open(abspath(expanduser(RM_BLACKLIST_FILE)), "r") do io
            pathes = strip.(readlines(io))
            pathes = pathes[.!isempty.(pathes)]
            pathes = map(pathes) do x
                if x != "/"
                    rstrip(x, '/')
                else
                    x
                end
            end
            [
                pathes;
                map(pathes[isdir.(pathes)]) do x
                    if x != "/" && isdir(x)
                        string(x, "/*")
                    elseif x == "/"
                        string(x, "*")
                    else
                        @error string(x, " is not a directory")
                    end
                end
            ]
        end
    else
        @error "~/.rm_blacklist does NOT exist, for the sake of file security, please add file and/or directory pathes (one per line) you don't want to remove at all to it before using this command"
    end

    parsed_args = rmi_parse_args()
    if isempty(parsed_args["args"])
        @error "NO files and/or directories provided"
    end

    @info string("the current working directory: ", pwd())

    all_args = map(parsed_args["args"]) do x
        x = abspath(expanduser(x))
        if x != "/"
            rstrip(x, '/')
        else
            x
        end
    end

    rm_blacklist_dirs = String[]
    rm_blacklist_files = String[]

    uni_parent_dirs = unique(dirname.(all_args))
    uni_parent_dir_files = Dict(k => readdir(k) for k in uni_parent_dirs)
    uni_parent_dir_passed_files = Dict(k => String[] for k in uni_parent_dirs)
    for v in all_args
        push!(uni_parent_dir_passed_files[dirname(v)], basename(v))
    end
    for k in uni_parent_dirs
        if issetequal(uni_parent_dir_files[k], uni_parent_dir_passed_files[k])
            @warn string("\033[1m\033[38;2;255;0;0mbe careful! You want to empty the directory: ", joinpath(k, "*"), "\033[0m\033[0m")
            if joinpath(k, "*") in rm_blacklist
                rm_blacklist_files = [rm_blacklist_files; all_args[in.(all_args, Ref(joinpath.(k, uni_parent_dir_passed_files[k])))]]
                push!(rm_blacklist_dirs, joinpath(k, "*"))
                all_args = all_args[.!in.(all_args, Ref(joinpath.(k, uni_parent_dir_passed_files[k])))]
            end
        end
    end

    all_files = all_args[isfile.(all_args)]
    all_dirs = all_args[isdir.(all_args)]

    rm_blacklist_files = [rm_blacklist_files; all_files[in.(all_files, Ref(rm_blacklist))]]
    rm_blacklist_dirs = [rm_blacklist_dirs; all_dirs[in.(all_dirs, Ref(rm_blacklist))]]

    valid_files = all_files[all_files.∉Ref(rm_blacklist)]
    valid_dirs = all_dirs[all_dirs.∉Ref(rm_blacklist)]

    if !isempty(rm_blacklist_files)
        @warn string("\033[1m\033[38;2;255;0;0mthese files will NOT be deleted: \033[0m\033[0m\n\n", join(string.("\033[1m\033[38;2;255;0;0m", 1:length(rm_blacklist_files), ". ", rm_blacklist_files, "\033[0m\033[0m"), "\n"), "\n\n")
    end
    if !isempty(rm_blacklist_dirs)
        @warn string("\033[1m\033[38;2;255;0;0mthese directories will NOT be deleted: \033[0m\033[0m\n\n", join(string.("\033[1m\033[38;2;255;0;0m", 1:length(rm_blacklist_dirs), ". ", rm_blacklist_dirs, "\033[0m\033[0m"), "\n"), "\n\n")
    end
    if !isempty(valid_files)
        @warn string("\033[1m\033[38;2;0;255;0mthese files WILL be deleted permanently: \033[0m\033[0m\n\n", join(string.("\033[1m\033[38;2;0;255;0m", 1:length(valid_files), ". ", valid_files, "\033[0m\033[0m"), "\n"), "\n\n")
    end
    if !isempty(valid_dirs)
        @warn string("\033[1m\033[38;2;0;255;0mthese directories WILL be deleted permanently: \033[0m\033[0m\n\n", join(string.("\033[1m\033[38;2;0;255;0m", 1:length(valid_dirs), ". ", valid_dirs, "\033[0m\033[0m"), "\n"), "\n\n")
    end

    if !isempty([valid_files; valid_dirs])
        @warn "\033[1m\033[38;2;255;0;0mif you are certainly sure of what you are doing, just enter 'YES' to continue or enter 'NO' (any other characters are equivalent to) to exit\033[0m\033[0m"
        print("Enter '\033[1m\033[38;2;255;0;0mYES\033[0m\033[0m' to continue or '\033[1m\033[38;2;0;255;0mNO\033[0m\033[0m' to exit here: ")
        confirm_flag = readline(stdin)
        if confirm_flag == "YES"
            del_cmd = Cmd(string.(["rm"; "-rf"; valid_files; valid_dirs]))
            println("\033[1m\033[38;2;255;0;0mGood luck, boy! Deletion task will start soon ...\033[0m\033[0m")
            @info string("\nrunning ", del_cmd, " ...")
            run(del_cmd; wait=true)
            println("\033[1m\033[38;2;0;255;0mCalm down, all are tidy and clean now!\033[0m\033[0m")
        else
            println("\033[1m\033[38;2;0;255;0mYou seem to have made the right decision. Nothing will be deleted! Everything is as before!\033[0m\033[0m")
        end
    else
        @info "\033[1m\033[38;2;0;255;0mNo valid files or directories need to be deleted after excluding protected files and/or directories\033[0m\033[0m"
    end

    return 0
end