# Unit tests, from the repo root: Rscript tests/testthat.R
# One file: Rscript -e 'testthat::test_file("tests/testthat/test-metrics.R")'
# tests/testthat/helper-app.R loads the app's code first.

testthat::test_dir("tests/testthat", reporter = c("summary", "fail"), stop_on_failure = TRUE)
