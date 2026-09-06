nerdctl build -t bktest:latest .
nerdctl run --rm bktest:latest
nerdctl image list -a
nerdctl image remove bktest
nerdctl system prune
