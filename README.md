##The Moth Separation Kernel

The Moth Separation kernet is a pet project trying to define a very minimal
microkernel. The goal is for the kernel binary to fit in one or two
memory pages (4KB to 8KB). So the code need to be very minimal with only
required features.

Moth has only 4 system calls:

* yield: to release the processor if another task is ready to run
* wait: to wait for a mailbox from another task
* mbx_send: to send a mailbox message to another task
* mbx_receive: to retreive a mailbox sent by another task

These are the services provided by the Moth kernel. All other features 
(drivers, interrupt handling, timer services) need to be provided by tasks
from user space.

Moth is writen in C but the goal is to move to a formal langage that
would allow to prove that it does not contain any runtime error. Frama-C and
Spark are candidate languages for this future phase.

A Separation Kernel (SK) is a specialized microkernel that provides an
execution environment for components that exclusively communicate according to
a given security policy and are otherwise strictly isolated from each other.
The covert channel problem, largely ignored by other platforms, is addressed
explicitly by these kernels. SKs are generally more static and smaller than
dynamic microkernels, which minimizes the possibility of kernel failure,
enables the application of formal verification techniques and the mitigation of
covert channels.

##Features

###Kernel
The following list outlines the most-prominent features of the Moth kernel:

* Minimal SK for the Sparc architecture written in C
* Full availability of source code and documentation
* Static MMU table built at compile time
* Static Communication policy built at compile time
* Mbx mechanism for inter-partition synchronization
* Shared memory for inter-partition communication
* cooperative non interruptible scheduling

###Toolchain
* XSL script to generate static MMU table from an XML description
* XSL script to generate linker files fron an XML description
* XSL script to generate static/read-only task description from XML description

##Resources

###Documentation
The following detailed project documentation is available:

###Mailing list
TBD

##Download
The Moth sources are available through the following git repository:

	$ git clone https://github.com/jcdubois/moth.git

A browsable version of the repository is available here:

https://github.com/jcdubois/moth

A ZIP archive of the current Moth sources can be downloaded here:

https://github.com/jcdubois/moth/archive/master.zip

##Build
The Moth SK has been developed and successfully tested using the development
environment listed in the following table.

|===================================================================
| Operating systems      | Ubuntu 17.10 (Artful Aardvark), x86_64
| GCC version            | 7.2.0
|===================================================================

The following hardware is used for the development of Moth.

|===================================================================
| Qemu                           | Sparc      | LEON3
|===================================================================

The first step to build Moth is to install the required packages:

	$ sudo apt-get install xsltproc gcc-sparc64-linux-gnu libncurses5 make binutils gcc git qemu-system-sparc

Once done, you can build Moth:

	$ cd /moth/install/directory/
	$ make ARCH=sparc leon3-qemu-defconfig
	$ make

##Deploy

	$ qemu-system-sparc -M leon3_generic -display none -no-reboot -serial stdio -kernel build/moth.elf

##References

TBD

##License

***

Copyright (C) 2017 Jean-Christophe Dubois <jcd@tribudubois.net>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version.

***
