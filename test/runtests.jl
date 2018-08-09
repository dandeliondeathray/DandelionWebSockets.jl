using DandelionWebSockets

# As part of improving the tests in this package, I feel the need to differentiate between the
# different types of tests I have here.
#
# For want of better terms, I'll categorize the tests into one of the following:
#
# - Small
# - Medium
# - Large
#
# Below is a table of the different aspects of a test that are used to categorize them. The most
# important aspects are speed, scope, and determinism. It's important that most tests are
# entirely deterministic, that is, the test will either succeed 100% of the time, or fail 100% of
# the time. It should not succeed 99% of the time, and fail 1% of the time. Because of this,
# testing concurrent code is forbidden in small tests. Medium tests may be concurrent, but care
# should be taken to make the test deterministic. Large tests may be written against code that fails
# due to external factors, but care should be taken to minimize the influence of those external
# factors.
#
# ====================================================================
# Aspect      | Small          | Medium                 | Large      |
# ====================================================================
# Speed       | < 10s          | < 10s                  | < 1 minute |
# --------------------------------------------------------------------
# Concurrency | None           | Yes, but deterministic | Yes        |
# --------------------------------------------------------------------
# Scope       | Type or method | Type or method         | Package    |
# ====================================================================
#
# NOTE: Speed applies to _all_ tests in that category, not a single test case.

# TODO Remove dependency on FactCheck
#include("mock_test.jl")

include("utilities.jl")

# include("network_test.jl")
# TODO Remove dependency on FactCheck
#include("ping_test.jl")
# TODO Remove dependency on FactCheck
#include("handshake_test.jl")
# TODO Remove dependency on FactCheck
#include("reconnect_test.jl")
# TODO Remove dependency on FactCheck
#include("integration_test.jl")

include("runsmalltests.jl")
include("runmediumtests.jl")