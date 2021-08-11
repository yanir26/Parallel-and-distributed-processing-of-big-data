![M-R](https://user-images.githubusercontent.com/62119972/128590576-f5e8bb49-d291-4580-bd0d-bec1258d74a0.png)

# About

In this project we will use map reduce to analyze big data in parallel and distributed systems with erlang.

Link for Youtube video: www....


# How to run the program
**Installation**

Graphviz must be installed on the computers:

```sudo apt install graphviz ```

**example**

In the master computer you need to write:

```c(graphviz).
c(master).
master:start(NUMBER_OF_WORKER) .```

In the worker you need to write:

```c(worker).
worker:start('master@NODE'). ```

# Credit

For conversion xml to csv we used ```dblp-to-csv``` github.
