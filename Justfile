alias b := build
alias t := test
alias w := watch

build:
    zig build --summary all --prominent-compile-errors

# Continuously rebuild when files change.
watch:
    zig build --prominent-compile-errors -fincremental --watch --debounce 5

# Build and run tests.
test:
    zig build --summary all --prominent-compile-errors test

# Rebuild + run tests when files change.
test-watch *ARGS:
    zig build --summary all --prominent-compile-errors test --watch --debounce 5 -- {{ARGS}}
