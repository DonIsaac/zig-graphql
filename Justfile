alias b := build
alias t := test
alias w := watch

build:
    zig build --summary all 

# Continuously rebuild when files change.
watch:
    zig build -fincremental --watch --debounce 5

# Build and run tests.
test:
    zig build test --summary all

# Rebuild + run tests when files change.
test-watch *ARGS:
    zig build --summary all
