libstdc++-tracker
=================


WARNING: This thing is as debian-specific as it gets. Don't use it unless
the words "gcc transition" mean something to you : )

ANOTHER WARNING: This is my first ever perl script. Expect it to be as
low quality as noob scripts go. Read it first, and only execute it if
you think it's sane.


Why is it there?
----------------

Short answer: **False positives.**

-----

Long answer:

The official [transition tracker] qualifies a package as good or bad based
on the `libstdc++6` version it links against.

[transition tracker]: https://release.debian.org/transitions/html/libstdc++6.html

However, this generates a lot of false positives in case a package does
not use any new symbols from `libstdc++6-5.x` (the most notable will
be `std::string`, which is now a shorthand for
`std::__cxx11::basic_string`.

Example: The very first package, [7kaa] is marked as "bad", because it doesn't
use anything from `libstdc++6 >= 5`.

Inspecting the build log, it was compiled with `g++-5_5.2.1-14` and
`libstdc++6_5.2.1-14`, so if it had used any symbols from that, it should have
linked against them and `shlibdeps` would have picked up the dependency.



What does it do?
----------------

1. It runs `ben` in order to generate the same list as the tracker
   (limited to amd64 architecture for now, since I only have access to that)
2. For every package "ben" marks as bad, it downloads a build log
   and inspects the `Toolchain package versions:` line to check if it was
   a compile with *both* `g++-5_5` *and* `libstdc++6_5`. If it was (and if
   the compile was successful) it is considered a false positive.
3. After fetching the files for one package from the server,
   it sleeps for 5 seconds to limit server load.


When its done, you'll get a list of packages that actually need attention
in the output/directory



How do I run it?
----------------

Simply run `make` and wait.

After its done, there'll be result files in the `output/` directory.

They contain package name, arch, version and status text based on which
the result was decided.
False-positive means that this compile had `g++-5` and `libstdc++6_5` in
the toolchain, fails-to-build-from-source should be obvious, and
needs-rebuild means it was tried with an older g++ and/or libstdc++
version.
