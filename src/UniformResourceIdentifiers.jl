module UniformResourceIdentifiers

export URI

struct URI
    port::Int

    URI(uri::String) = new(if occursin("wss", uri) 443 else 80 end)
end

end