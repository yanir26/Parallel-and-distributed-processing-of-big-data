![M-R](https://user-images.githubusercontent.com/62119972/128590576-f5e8bb49-d291-4580-bd0d-bec1258d74a0.png)

# About

In this project we will use map reduce to analyze big data in parallel and distributed systems with erlang.

This program analyze big data from www.dblp.org and create tree of the partners for the author that the user chooses. In addition this program displays a table of the number of surnames beginning with the same letter at each level in the tree.

This program can handle with computers disconnect while processing. 

Link for Youtube video: www....


# How to run the program
**Installation**

Graphviz must be installed on the master computer:

```sudo apt install graphviz ```

**example**

In the master computer you need to write:

```
c(graphviz).
c(master).
master:start(NUMBER_OF_WORKER).
```

NUMBER_OF_WORKER - The code work with how many worker (computer) that the user want, this argument define the number of worker.

The progrem start after all the worker send keep-alive massage to the master computer. 

In the worker you need to write:

```
c(csv_reader). 
c(worker).
worker:start('master@NODE').
```

NODE - This is the address of the master computer. 

# Credit

For conversion xml to csv we used ```dblp-to-csv``` github.

For creating the tree we used ```erlang-graphviz``` github.
