Instrumentation for the Rocq/Coq Compiler
=========================================

This collection of libraries and tools is meant to ease the collection of logs
and performance data while compiling Coq projects efficiently with dune. As it
is not currently possible to teach `dune` about custom data files (or any form
of additional file generated by compilation), we embed the generated data into
`.glob` files. With this approach, we both get:
1. fast CI using the dune cache to only recompiling files that need to be,
2. additional data for all files, including those that hit the cache.

Data Gathering
--------------

To set up data gathering, one must tell dune to use our `coqc-perf` wrapper in
the place of plain `coqc`. This is achieved by setting up an `env` stanza like
the following, assuming the package is installed.
```
(env
 (...
  (binaries
   (coqc-perf as coqc)
   (coqdep-werr as coqdep)
   ...)
  ...)
 ...)
```
If the package is not installed, but simply in the dune workspace, you need to
rely on relative paths to the executable instead.
```
(env
 (...
  (binaries
   (.../rocq-tools/bin/coqc_perf.exe as coqc)
   (.../rocq-tools/bin/coqdep_warn.exe as coqdep)
   ...)
  ...)
 ...)
```
In the above, we also set up `coqdep-warn` as a wrapper for `coqdep`, to allow
passing extra flags to `coqdep`, which is currently not possible with dune. In
the wrapper, we simply pass `-w +all` to make all warnings fatal.

With this setup, the compilation of your project will now additionally collect 
several pieces of data, which are all embedded into `.glob` files:
- Per-command performance data generated using Coq's profiling mechanism, with
  instruction counts, timing, and memory allocation data. A short summary with
  the performance numbers for the whole file is also included.
- A JSON log produced by our custom logger library if it was used (either from
  a plugin, or from our corresponding Ltac2 library). If the logger library is
  not in use, no lot is included.
- A copy of what the wrapped invocation of `coqc` printed on its `stderr`, and
  (separately) on its `stdout`. This is useful for, e.g., listing the warnings
  produced by the compilation of a given file, in case the cache hits.

Data Extraction
---------------

The embedding of data into `.glob` files is managed by the `Coqc_tools.Globfs`
library, and a `globfs` program is provided to inspect or extract the data. It
can be invoked as follows, for example.
```
$ dune build test-lib/test.vo
$ ls _build/default/test-lib/
test.glob
test.v
test.vo
$ globfs ls _build/default/test-lib/test.glob
_build/default/test-lib/test.glob:perf.json
_build/default/test-lib/test.glob:perf.csvline
_build/default/test-lib/test.glob:log.json
_build/default/test-lib/test.glob:stderr 
$ globfs extract _build/default/test-lib/test.glob:perf.json
$ ls _build/default/test-lib/
test.glob
test.glob.perf.json
test.v
test.vo
$ globfs extract _build/default/test-lib/test.glob
$ ls _build/default/test-lib/
test.glob
test.glob.perf.json
test.glob.perf.csvline
test.glob.log.json
test.glob.log.stderr
test.v
test.vo
```
For more details on the available commands, you can run `globfs help`.

Batch Data Extraction
---------------------

Since it is sometimes useful to extract **all** embedded data (e.g., in CI), a
script called `globfs.extract-all` is provided. It takes two arguments: first,
an integer indicating how many jobs it may run at once, and then the path to a
directory containing the `.glob` files to extract data from. For example, here
is what would be a typical invocation of the script (after having compiled the
project).
```
$ globfs.extract-all 8 _build/default
```

Analysing / Displaying the Data
-------------------------------

## Listing warnings

As the data we collect includes the standard and error output of `coqc`, it is
possible to work around [dune!7460](https://github.com/ocaml/dune/issues/7460)
and list all Coq warnings for the project, even when there are cache hits.

Once the relevant data has been extracted as described above, the warnings can
be listed using commands such as the following.
```
$ (cd _build/default && coqc-perf.report .) > full_warnings.log
$ (cd _build/default && coqc-perf.report dir1 dir2) > partial_warnings.log
```
The script also emits additional warnings to indicate whenever the compilation
of a Coq source file produced non-empty standard output. This is convenient to
detect, e.g., that a `Search` or `About` command has been forgotten somewhere.

## GitLab Code Quality Report

Using the following command, a warning list produced as explained above may be
turned into a GitLab code quality report.
```
$ cat full_warnings.log | coqc-perf.code-quality-report > code-quality.json
```

## Collecting Data Relevant for Performance Comparison

After having extracted data from `.glob` files, it still needs to be collected
so that it can then be used for performance comparison. running
```
$ coqc-perf.extract-all _build/default data
```
will extract all relevant data to a new folder named `data`.

To set up a performance comparison, one must produce two data folders: one for
the reference branch, and one for the target branch. These two folders may for
example be produced by separate CI stages, and then passed to another job that
is responsible for generating a performance report.

## Summary Performance Diff

Performance data folders produced as explained above include a CSV file with a
performance summary, including instruction counts for all processed Coq files.
Given two such CSV files, one can generate a comparison table as follows.
```
$ coqc-perf.summary-diff data_ref/perf_summary.csv data/perf_summary.csv
| Relative | Master   | MR       | Change   | Filename
|---------:|---------:|---------:|---------:|----------
|   +0.53% |    140.2 |    141.0 |     +0.7 | test1.v
|   +8.12% |    668.9 |    723.3 |    +54.3 | test2.v
|          |          |          |          |           
|    -nan% |      0.0 |      0.0 |     +0.0 | cpp2v-generated
|   +6.49% |    848.7 |    903.8 |    +55.1 | other
|   +6.20% |    889.7 |    944.9 |    +55.1 | total 
```
The first given CSV file is the reference data (e.g., from a master pipeline).

Use `coqc-perf.summary-diff --help` to learn more about the available options.
In particular, the program can also generate GitLab markdown format.

## Per-Sentence Instruction Diff

A collection of webpages with instruction diffs can also be generated.
```
$ coqc-perf.html-diff-alll data_ref data report
```
The script takes three directory paths as arguments: the path to the reference
data, the path to the data being compared, and an output target (`report`).