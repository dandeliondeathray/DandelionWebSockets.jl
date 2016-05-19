#!/usr/bin/env julia

using Coverage

run(`julia --code-coverage=all --inline=no test/runtests.jl`)
coverage = process_folder();

mkpath("coverage")
LCOV.writefile("coverage/cov.info", coverage);

run(`rm -rf coverage/src`)
run(`cp -r src coverage`)
run(`genhtml -o coverage coverage/cov.info`)

clean_folder("src")
clean_folder("test")
