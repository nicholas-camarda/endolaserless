test_files <- sort(list.files(
    "tests",
    pattern = "^test_.*[.]R$",
    full.names = TRUE
))

stopifnot(length(test_files) >= 2L)

for (test_file in test_files) {
    sys.source(test_file, envir = new.env(parent = globalenv()))
    message("PASS ", test_file)
}

message("PASS all R tests")
