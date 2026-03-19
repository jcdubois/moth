The Moth Separation Kernel
==========================

The Moth Separation kernel is a pet project trying to define a very minimal
microkernel where tasks are isolated from each others by MMU. The goal is for
the kernel binary (not counting MMU tables) to fit in one or two memory pages
(4KB to 8KB). So the code needs to be very minimal with only mandatory
features.

Moth implements a cooperative scheduler and therefore tasks are not
preemptible. This means a task can keep the CPU as long as it needs and must
release it explicitly through a system call to allow other tasks to run.

Moth has only 5 system calls:

+ yield: to release the processor if another task is ready to run
+ wait: to wait for a mailbox from another task
+ mbx_send: to send a mailbox message to another task
+ mbx_receive: to retrieve a mailbox sent by another task
+ exit: to end a task

These are the only services provided by the Moth kernel. All other features
(drivers, interrupt handling, timer services) need to be provided by tasks
from user space.

All tasks are linked-in at proper memory location in the Moth binary during
the build process and therefore they are all created/present at start time
(there is no dynamic loading of tasks).

Moth is written in [SPARK](http://www.spark-2014.org/), C and assembly language.

[SPARK](http://www.spark-2014.org/) is a formal language that allows proving
that the code does not contain any runtime error.

**Separation Kernel definition borrowed from [MUEN](https://muen.codelabs.ch/)**

A Separation Kernel (SK) is a specialized microkernel that provides an
execution environment for components that exclusively communicate according to
a given security policy and are otherwise strictly isolated from each other.
The covert channel problem, largely ignored by other platforms, is addressed
explicitly by these kernels. SKs are generally more static and smaller than
dynamic microkernels, which minimizes the possibility of kernel failure,
enables the application of formal verification techniques and the mitigation of
covert channels.

Features
--------

**Kernel**

The following list outlines the most-prominent features of the Moth kernel:

+ Minimal SK for the Sparc architecture written in SPARK, C and assembly
+ Full availability of source code and documentation
+ Static MMU table built at compile time
+ Static Communication policy built at compile time
+ Mbx mechanism for inter-partition synchronization
+ Shared memory for inter-partition communication
+ Cooperative non-interruptible scheduling
+ Formally verified with GNATprove (SPARK proof)

**Tools**

+ XSL script to generate static MMU table from an XML description
+ XSL script to generate linker files from an XML description
+ XSL script to generate static/read-only task description from XML description

Resources
---------

**Documentation**

The following detailed project documentation is available:

**Mailing list**

TBD

Development Environment
-----------------------
The Moth SK has been developed and successfully tested using the development
environment listed in the following table.

| Software          | Version                                          |
|:----------------- |:------------------------------------------------ |
| Operating systems | Ubuntu 24.04 (Noble Numbat), x86_64              |
| GCC / GNAT        | 13 (sparc64-linux-gnu cross-compiler)            |

The following hardware is used for the development of Moth.

| Platform | Architecture | Processor |
|:---------|:------------ |:--------- |
| Qemu     | Sparc        | LEON3     |
| tsim     | Sparc        | LEON3     |

Required Tools
--------------
The first step to build Moth is to install the required packages:

**Development tools**
```bash
$ sudo apt-get install xsltproc gcc-sparc64-linux-gnu libncurses5 make \
    binutils gcc git gnat gnat-sparc64-linux-gnu
```

> **Note:** Any version of `gnat-sparc64-linux-gnu` from GCC 10 onwards is
> supported. Starting from GCC 12, the Ada runtime (`i-cexten.ads`) introduced
> 128-bit types incompatible with the sparc32 target (`-m32`). Moth works
> around this automatically by providing a local override in
> `kernel/core/ada_rts/i-cexten.ads` — no manual patching of the system
> runtime is required.

**Qemu**
```bash
$ sudo apt-get install qemu-system-sparc
```

**tsim**

You can also install the tsim LEON3 simulator from Gaisler.
You will find it at the following address: http://www.gaisler.com/index.php/downloads/simulators .
There is a free evaluation version you can use. It has some limitations such as
stopping the application after 2^32 clock cycles, but it is cycle-accurate and
more precise in the emulation (for example it emulates the cache).

**GNATprove (optional, for formal verification)**

To run the SPARK proof, install GNATprove 13 or later from the
[GNAT-FSF-builds releases](https://github.com/alire-project/GNAT-FSF-builds/releases)
(filter on `gnatprove-`). No system installation is required — just extract
and add to your `PATH`:

```bash
$ wget https://github.com/alire-project/GNAT-FSF-builds/releases/download/gnatprove-15.1.0-1/gnatprove-x86_64-linux-15.1.0-1.tar.gz
$ tar xzf gnatprove-x86_64-linux-15.1.0-1.tar.gz -C ~/opt/
$ export PATH=$HOME/opt/gnatprove-x86_64-linux-15.1.0-1/bin:$PATH
```

> **Note:** GNATprove does not need to match the GNAT compiler version used for
> building. Versions 13 and above are compatible with the Moth SPARK
> annotations.

Download
---------
The Moth sources are available through the following git repository:

```bash
$ git clone https://github.com/jcdubois/moth.git
```

A browsable version of the repository is available here:

https://github.com/jcdubois/moth

A ZIP archive of the current Moth sources can be downloaded here:

https://github.com/jcdubois/moth/archive/master.zip

Build
-----
Once done, you can build Moth:

```bash
$ cd /moth/install/directory/
$ export CROSS_COMPILE=sparc64-linux-gnu-
$ make ARCH=sparc leon3-qemu-defconfig
$ make
```

The build system automatically detects the installed GCC/GNAT version and
selects the appropriate compiler (`sparc64-linux-gnu-gcc-N`). The local
`kernel/core/ada_rts/` directory is searched first for Ada runtime files,
allowing the 128-bit type incompatibility to be resolved transparently on
GCC >= 12.

Formal Verification
--------------------
To run the SPARK proof (requires GNATprove, see above):

```bash
$ make proof
```

This runs `gnatprove` at level 4 with all provers enabled. The proof covers:

+ Absence of runtime errors (range checks, index checks, overflow)
+ Functional correctness of the scheduler (sorted ready list invariant,
  linked-list structural invariant)
+ Functional correctness of the mailbox subsystem
+ Data flow and information flow (Global contracts)

The proof completes without any `high` or `medium` unproved checks. A small
number of `pragma Assume` annotations are used where SMT solvers cannot
automatically instantiate universally quantified properties of doubly-linked
lists; these are documented inline and are mathematically obvious consequences
of the structural invariant.

Deploy
------
For now we only support Simulators. Real platforms should come later.

**Qemu**
```bash
$ qemu-system-sparc -M leon3_generic -display none -no-reboot -serial stdio -kernel build/moth.elf
```

**tsim**
```bash
$ tsim-leon3 -mmu build/moth.elf
tsim> go
```

References
----------
TBD

License
-------
***

Copyright (C) 2020 Jean-Christophe Dubois <jcd@tribudubois.net>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version.

***
