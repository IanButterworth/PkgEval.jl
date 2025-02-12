using LazyArtifacts: @artifact_str

lazy_artifact(x) = @artifact_str(x)

function _create_rootfs(config::Configuration)
    base = lazy_artifact(config.rootfs)

    # a bare rootfs isn't usable out-of-the-box
    derived = mktempdir()
    cp(base, derived; force=true)

    # add a user and group
    chmod(joinpath(derived, "etc/passwd"), 0o644)
    open(joinpath(derived, "etc/passwd"), "a") do io
        println(io, "$(config.user):x:$(config.uid):$(config.gid)::$(config.home):/bin/bash")
    end
    chmod(joinpath(derived, "etc/group"), 0o644)
    open(joinpath(derived, "etc/group"), "a") do io
        println(io, "$(config.group):x:$(config.gid):")
    end
    chmod(joinpath(derived, "etc/shadow"), 0o640)
    open(joinpath(derived, "etc/shadow"), "a") do io
        println(io, "$(config.user):*:::::::")
    end

    # replace resolv.conf
    rm(joinpath(derived, "etc/resolv.conf"); force=true)
    write(joinpath(derived, "etc/resolv.conf"), read("/etc/resolv.conf"))

    return derived
end

const rootfs_lock = ReentrantLock()
const rootfs_cache = Dict()
function create_rootfs(config::Configuration)
    lock(rootfs_lock) do
        key = (config.rootfs, config.uid, config.user, config.gid, config.group, config.home)
        dir = get(rootfs_cache, key, nothing)
        if dir === nothing || !isdir(dir)
            rootfs_cache[key] = _create_rootfs(config)
        end
        return rootfs_cache[key]
    end
end
