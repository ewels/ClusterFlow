#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$FindBin::Bin/../source";
use CF::Constants;
use CF::Helpers;
use POSIX;

##########################################################################
# Copyright 2014, Philip Ewels (phil.ewels@scilifelab.se)                #
#                                                                        #
# This file is part of Cluster Flow.                                     #
#                                                                        #
# Cluster Flow is free software: you can redistribute it and/or modify   #
# it under the terms of the GNU General Public License as published by   #
# the Free Software Foundation, either version 3 of the License, or      #
# (at your option) any later version.                                    #
#                                                                        #
# Cluster Flow is distributed in the hope that it will be useful,        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of         #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          #
# GNU General Public License for more details.                           #
#                                                                        #
# You should have received a copy of the GNU General Public License      #
# along with Cluster Flow.  If not, see <http://www.gnu.org/licenses/>.  #
##########################################################################

# Get Options
my $required_cores;
my $required_mem;
my $required_modules;
my $run_fn;
my $help;
my $result = GetOptions ("cores=i" => \$required_cores, "mem=s" => \$required_mem, "modules" => \$required_modules, "runfn=s" => \$run_fn, "help" => \$help);
if($required_cores || $required_mem || $required_modules){
	exit;
}
if($help){
	die "\nThis is a core module which downloads files for Cluster Flow.\n";
}


# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($runfile, $job_id, $url, $dl_fn) = @ARGV;

# Strip number from download job ID so that these files are all read in the next module
$job_id =~ s/download_[\d]{3}$/download/;

warn "\n---------------------\nDownloading $dl_fn from $url\nStarted at ".strftime("%H:%M, %A - %d/%m/%Y", localtime)."\n";

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

my $command = "wget -nv --tries=10 --output-document=$dl_fn $url";
warn "\n###CFCMD $command\n\n";
if(!system ($command)){
	# Download worked - print resulting filename to results file
	print RUN "$job_id\t$dl_fn\n";
	my $duration =  CF::Helpers::parse_seconds(time - $timestart);
	warn "###CF Download worked - took $duration\n";
} else {
	# Download failed - don't print a filename so that child processes exit silently
	warn "###CF Error! Download '$dl_fn' failed: $? $!\n";
}

my $date = strftime "%H:%M %d-%m-%Y", localtime;
warn "\nDownload module finished at $date\n---------------------\n";

close (RUN);