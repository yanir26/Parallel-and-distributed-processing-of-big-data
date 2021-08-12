![M-R](https://user-images.githubusercontent.com/62119972/128590576-f5e8bb49-d291-4580-bd0d-bec1258d74a0.png)

# About

In this project we will use map reduce to analyze big data in parallel and distributed systems with Erlang programming language.

This program analyze big data from www.dblp.org and create tree of the partners for the author that the user chooses. In addition this program displays a table of the number of surnames beginning with the same letter at each level in the tree.

This program can handle with computers disconnect while processing. 

Link for Youtube video: https://www.youtube.com/watch?v=7HWlEaO4jUk


# How to run the program
**For the work with more then one computer we need to write in all the computers:**
```
erl -name NAME@ADDRESS -setcookie dblp
```

ADDRESS - the ip of computer.

NAME - set name for this computer.

**In the master computer you need to write:**

```
c(graphviz).
c(master_statem).
c(master).
master:start(NUMBER_OF_WORKER).
```

NUMBER_OF_WORKER - The code work with how many worker (computer) that the user want, this argument define the number of worker.

The progrem start after all the worker send keep-alive massage to the master computer. 

**In the worker you need to write:**

```
c(csv_reader). 
c(worker).
worker:start('NODE').
```

NODE - This is the address of the master computer. 

# Credit

For conversion xml to csv we used ```dblp-to-csv``` github.

For creating the tree we used ```erlang-graphviz``` github.
