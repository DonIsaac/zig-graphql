alias b := build
alias t := test

build:
    zig build --summary all --prominent-compile-errors

test:
    zig build --summary all test
