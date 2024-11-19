function gim_parse_args()
    s = ArgParseSettings(prog="gim",
        description="Call 'git commit -m MESSAGE' together with updating the version field in Project.toml if needed.",
        version="0.1.0",
        add_version=true)

    @add_arg_table s begin
        "--message", "-m"
        help = "Use the given MESSAGE as the commit message."
        arg_type = String

        "--class", "-c"
        help = """Which CLASS this commit belongs to.
        Valid values:
        0: skip version control;
        3: feature modifications, bug fixing, etc.;
        2: new features;
        1. conprehensive upgrade."""
        arg_type = UInt8
        default = 0

        "--force", "-f"
        help = "Whether show version control prompt again when '-c -1' is given. If this flag is given, no prompt will be shown again."
        action = :store_true
    end

    return parse_args(s)
end

# call `git commit -m MESSAGE` together with updating the version field in Project.toml if needed
function gim()::Cint
    parsed_args = gim_parse_args()

    @info string("the current working directory: ", pwd())

    if isempty(parsed_args["message"])
        @error "message is empty"
    end
    if parsed_args["class"] ∉ (0, 3, 2, 1)
        @error "class number is invalid"
    end
    if !parsed_args["force"] && parsed_args["class"] == 0
        print("You can change the class number passed before again if needed: ")
        parsed_args["class"] = parse(Int64, readline(stdin))
        while parsed_args["class"] ∉ (0, 3, 2, 1)
            @warn "invalid class number, please enter a valid one again"
            print("Enter a valid class number: ")
            parsed_args["class"] = parse(Int64, readline(stdin))
        end
    end

    if parsed_args["class"] != 0
        proj_toml_file = joinpath(pwd(), "Project.toml")
        if !isfile(proj_toml_file)
            @error string("NOT found the Project.toml file in the current working directory: ", pwd())
        end

        proj_toml_dict = open(proj_toml_file, "r") do io
            TOML.parse(io)
        end
        old_version = proj_toml_dict["version"]
        version_vec = parse.(UInt, split(old_version, "."))
        version_vec[parsed_args["class"]] += 1
        proj_toml_dict["version"] = join(version_vec, ".")
        open(proj_toml_file, "w") do io
            TOML.print(io, proj_toml_dict)
        end

        @info string("modify the version field (", old_version, " => ", proj_toml_dict["version"], ") in ", proj_toml_file, " successfully")
    else
        @info "won't modify the Project.toml file"
    end

    add_cmd = Cmd(string.(["git", "add", "-A"]))
    @info string("running ", add_cmd, " ...")
    run(add_cmd; wait=true)

    commit_cmd = Cmd(string.(["git", "commit", "-m", parsed_args["message"]]))
    @info string("running ", commit_cmd, " ...")
    run(commit_cmd; wait=true)

    return 0
end