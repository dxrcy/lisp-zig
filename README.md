# Lispcalc-Zig

Simple Lisp-like Calculator in Zig.
Every branch is lazy evaluated.

```sh
# Evaluate file
lispcalc example # Returns `1215`
cat example | lispcalc # (Equivalent)

# Evaluate standard input
echo '+ 2 3' | lispcalc # Returns `5`
lispcalc # Waits for user input
```

