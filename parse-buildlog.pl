#!/usr/bin/perl
use strict;
use warnings;
use LWP 5.6.4;
use HTML::Entities;
use experimental 'smartmatch';
use URI::Escape;

my $arch = 'amd64';

my $filename = 'output/ben_deps';
open my $fh, '<', $filename or die $!;

my $level = 0;
my @packages;
while(my $row = <$fh> ) {
	my $newlevel = 0;
	my $package;
	my $sign;
	if ( ($newlevel) = ( $row =~ /^=*> Dependency level\s+(\d+)\s+<=*$/ ) )
	{
		print("New level: $newlevel\n");
		$level = $newlevel;
		if ( $newlevel >= 1 ) {
			print ("Done parsing ben output\n");
			last;
		}
	}
	elsif ( ($package, $sign ) = ( $row =~ /^\s*([a-zA-Z0-9._+-]+): ([\(\[])$arch/ ) )
	{
		if ( $sign eq '[' )
		{
			print("Package $package b0rken\n");
			push @packages, $package;
		} elsif ( $sign eq '(' )
		{
			print("Package $package good\n");
		} else {
			die ("Unknown sign $sign");
		}
	}
	elsif ( $row =~ /^\s*$/ )
	{
		print ("Blank line\n");
	}
	else
	{
		die ("Not understood: $row");
	}
}

my $packages_dir = "cache/packages";
if ( not -d "$packages_dir" ) {
	mkdir ($packages_dir);
}

my @falsepositives;
my @needrebuild;
my @buildfailed;

my $done =0;

my %sourcename;

foreach my $package (@packages) {
	my $directory = "$packages_dir/$package";
	my $overviewfile = "$directory/overview.html";
	my $logfile = "$directory/log.txt";
	my $fetch = 0;
	my $text;

	if ( not -d "$directory" ) {
		print ("Don't have package $package, fetching\n");
		mkdir ( $directory );
	}

	if ( not -f "$overviewfile" ) {
		print ("Don't have file $overviewfile, fetching\n");
		$fetch = 1;
		fetch_overview($overviewfile, $package);
	}

	print ("Checking status for $package\n");

	if ( not -f "$logfile" ) {
		print ("Don't have logfile $logfile, fetching\n");
		$fetch=1;
		parse_overviewfile($logfile, $overviewfile, $package);
	}

	if ( not -f $logfile ) {
		die "Logfile not there\n";
	}

	open my $logfh, '<', $logfile or die "Can't open logfile";

	# Search for toolchain package versions
	while ( my $row = <$logfh> ) {
		if ( $row =~ /^Toolchain package versions/ ) {
			print ($row);
			if ( $row =~ /g\+\+-5/ and $row =~ /libstdc\+\+6_5/ ) {
				# Check if the build failed
				if ( $package ~~ @buildfailed ) {
					print("Serious problem: FTBFS with gcc-5: $package\n");
				} else {
					print ("False positive: $package, compiled with g++-5 and libstdc++6_5\n");
					push @falsepositives, $package;
				}
			} else {
				print "Package $package needs recompile\n";
				push @needrebuild, $package;
			}
			last; # cancel reading logfile
		}
	}

	$done+=1;

	print "Completed $done of ".scalar(@packages)." Packages\n";

	if ( $fetch ) {
		my $sleep=5;
		print "Sleeping $sleep seconds to reduce load on buildd status server\n";
		sleep($sleep);
	}
}

my $pkg;
my $fpfile = "output/false-positives.txt";
my $rpfile = "output/real-problems.txt";


print ("\n\n\n ===== SUMMARY ===== \n\n\n");

foreach $pkg (@falsepositives) {
	print "False positive: $pkg\n";
}

foreach $pkg (@buildfailed) {
	print "FTBFS, please check: $pkg\n";
}

print ("\n\n\n ===== Built with old gcc ===== \n\n\n");

foreach $pkg (@needrebuild) {
	print "Please try to rebuild $pkg\n";
}

### subroutines



# parameter 1 outputfile
# parameter 2 package name
# returns: whole http page
# sideeffect: write http page to outputfile
sub fetch_overview {
	my ( $outputfile, $package ) = @_;
	my $url_overview = "https://buildd.debian.org/status/package.php?p=".uri_escape($package);

	print( "Fetching $package overview to $outputfile...\n");


	my $browser = LWP::UserAgent->new;
	my $response = $browser->get($url_overview);
	die "Error at $url_overview\n ", $response->status_line, "\n Aborting"
		unless $response->is_success;

	open my $outfh, '>', $outputfile;
	print $outfh $response->content;
	close $outfh;

	return $response->content;
}

# parameter 1 outputfile for log
# parameter 2 filename to parse (overviewfile)
# parameter 3 package name
# returns: uri of log file
# sideeffect: writes to logfile
sub parse_overviewfile {
	my ( $logfile, $overviewfile, $package ) = @_;
	open my $infh, '<', $overviewfile;

	# Archs to check for a logfile, in order
	my @archs = ("amd64", "i386", "arm64" );

	while (my $row = <$infh> ) {
		foreach my $arch (@archs) {
			if ( (my $url, my $source, my $text) = ( $row =~ /<a href="(fetch.php\?pkg=([^&]+)&amp;arch=$arch&amp;ver=[^&]+&amp;stamp=\d*)">([^<]+)<\/a>/ ) ) {
				$url = decode_entities($url);
				print ("Source of $package is $source\n" );
				$sourcename{$package} = $source;
				print ("Found text $text, url $url\n");
				if ( not $text eq "Installed" ) {
					push @buildfailed, $package;
					print ("Text $text suggests something went wrong with the build\n");
				}
				if ( not -f "$logfile" ) {
					print ("Fetching log for $package from arch $arch\n");
					my $browser = LWP::UserAgent->new;
					my $response = $browser->get("https://buildd.debian.org/status/$url");
					die "Error at $url\n", $response->status_line, "\n Aborting"
						unless $response->is_success;
					open my $outfh, '>', $logfile;
					print $outfh $response->content;
					close $outfh;
				}
				return $url;
			}
		}
	}
	die ("I did not find any log file for $logfile");
}
