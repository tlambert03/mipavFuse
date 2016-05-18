# mipavFuse
bash scripts to facilitate fusion of diSPIM datasets using MIPAV on a compute cluster


### mipavFuse.sh
This script  allows you to run the MIPAV fusion from the command line without using the GUI. Run it from a mac or linux terminal with something like this:
```bash
mipavFuse -z 0.5 /parent/directory/with/SPIM/data/
```
to get help on the function, use the "-h" flag (or just look through the script):
```bash
mipavFuse -h
```
this will give you a sense for the input parameters that are allowed.  The ones you will most likely need to change are Zstep size (-z) and base image (-b)... for my ASI diSPIM running on micromanager, that is typically "B" (transform SPIMA to SPIMB).
As a first step, before trying on the cluster, try to get that script to work locally, or manually on your login node on the computer cluster.
Note, you will need to use a MIPAV nightly build later than at least 03/23/2016 to get this to work (or at least, to be able to fuse a subset of time points, as needed for parallelization on the cluster).

Also, in order to get this to work on my cluster, I needed to wrap the call to MIPAV at the end of this script in an Xvfb session.  Xvfb is a virtual frame buffer that makes MIPAV think that it's working in a graphical environment (which is necessary, otherwise you'll get errors saying something about headless mode not working).  This may or may not be the case with your cluster... but if it is, you'll need to install Xvfb or something like it to make this work.  If you have a more elegant solution, that would be great... let me know!

###makeMIPAVjobs.sh
This script is the one I actually trigger on the cluster and it performs the task of splitting up the fusion process into many different jobs that can run in parallel on the cluster, and then it calls the mipavFuse script many times, each time just fusing a small subset of the entire time-lapse in parallel.  Again, use the -h flag to get help... But a typical usage would be to login to the compute cluster and submit a command like this:
```bash
makeMIPAVjobs -n 4 -f 1 -z 0.5 /parent/directory/with/SPIM/data/
```
where -n is the number of cores requested per job, and -f is the number of files processed per core.  So in the example above, each job would have 4 cores that each only need to process a single timepoint (this is because, on my cluster, starting a job with 4 cores is easier than 8 or more cores, but this still allows me to start less jobs and use some of the built in multi-threading capability of MIPAV... while still limiting any one core to a single timepoint with the -f 1 flag).  As you increase the number of files per core (the -f flag), then the total number of jobs will decrease, but the time until completion will increase.

*Note:* you will very likely need to change this file to reflect the syntax of your job scheduler.  We use LSF and I wrote this script around my sub command.  change the lines that start with ``` bsub ``` as needed for your job scheduler....
Also, this code may not be that robust, and if your file structure varies much from mine, it is likely to fail... this is something I want to improve and suggestions are welcome!

Don't forget that you will need to use a MIPAV nightly build later than at least 03/23/2016 to get this to work on the cluster

###remoteFuse.sh
This is just an example of a script that would allow you to run a one-line command on your local computer to perform the combined tasks of uploading the data to the server and sending a command to start the fusion on the cluster...

