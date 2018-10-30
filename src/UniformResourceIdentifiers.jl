module UniformResourceIdentifiers

export URI

struct URI
    scheme::String
    host::String
    port::Int
    abs_path::String

    function URI(uri::String)
        defaultports = Dict{String, Int}(
            "http" => 80,
            "https" => 443,
            "ws" => 80,
            "wss" => 443)
        m = match(r"(?<scheme>[^:]+)://(?<host>[^:]+)(?::(?<port>\d*))?(?<abs_path>/.*)?", uri)
        if m == nothing
            throw(RuntimeException())
        end
        scheme = m[:scheme]
        host = m[:host]
        port = if m[:port] != nothing && m[:port] != ""
            parse(Int, m[:port])
        else
            defaultports[scheme]
        end
        abs_path = if m[:abs_path] != nothing
            m[:abs_path]
        else
            "/"
        end
        new(scheme, host, port, abs_path)
    end
end

end