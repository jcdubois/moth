# Moth

The Moth Separation Kernel
==========================

The Moth Separation kernet is a pet project trying to define a very minimal
microkernel.

For now it is writen in C but the goal is to move to a formal langage that
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

Features
--------

Kernel
~~~~~~
The following list outlines the most-prominent features of the Moth kernel:

* Minimal SK for the Sparc architecture written in C
* Full availability of source code and documentation
* Static MMU table built at compile time
* Static Communication policy built at compile time
* Mbx mechanism for inter-partition synchronization
* Shared memory for inter-partition communication

Toolchain
~~~~~~~~~

Resources
---------

Documentation
~~~~~~~~~~~~~
The following detailed project documentation is available:

Mailing list
~~~~~~~~~~~~

Download
--------
The Moth sources are available through the following git repository:

  $ git clone https://github.com/jcdubois/moth.git

A browsable version of the repository is available here:

https://github.com/jcdubois/moth

A ZIP archive of the current Moth sources can be downloaded here:

https://github.com/jcdubois/moth/archive/master.zip

Build
-----
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

  $ sudo apt-get install

Deploy
------

References
----------

License
-------
--------------------------------------------------------------------------------
Copyright (C) 2017 Jean-Christophe Dubois <jcd@tribudubois.net>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version.
--------------------------------------------------------------------------------

Moth is a minimalist cooperative operating system where processes are separated through MMU.

The MMU table is static and build at compile time.

For now Moth is supported on Leon3.

Support for ARM processors is planned.
