export BEN_CACHE_DIR=cache

# Add packages to be skipped here.
SKIP=soapdenovo2 swarm-cluster

all: output/needs-rebuild.txt

cache/libstdc++6.ben:
	mkdir -p cache
	wget https://release.debian.org/transitions/config/ongoing/libstdc++6.ben -O $@
	echo 'architectures= ["amd64"];' >> $@

cache/Packages_amd64:
	mkdir -p cache
	ben download --config ben.config --areas main --mirror http://ftp.de.debian.org/debian

output/ben_deps: output cache/Packages_amd64 cache/libstdc++6.ben
	mkdir -p output
	ben monitor --text cache/libstdc++6.ben > $@

output/needs-rebuild.txt: output/ben_deps
	./parse-buildlog.pl ${SKIP}
