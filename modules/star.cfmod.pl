#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use FindBin qw($Bin);
use lib "$FindBin::Bin/../source";
use CF::Constants;
use CF::Helpers;

##########################################################################
# Copyright 2014, Stuart Archer                                          #
# Derivative of: bowtie2.cfmod (Copyright 2014, Philip Ewels)            #
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

# QSUB SETUP
# --cores i = offered cores. Return number of required cores.
if($required_cores){
	print CF::Helpers::allocate_cores($required_cores, 4, 8);
	exit;
}
# --mem. Return the required memory allocation.
if($required_mem){
    if(!$run_fn){
        print '32000000000';
        exit;
    } else {
        # Parse the run file
        my ($starting_files, $config) = CF::Helpers::parse_runfile($run_fn);
    	# estimate memory based on genome size
        my $minmem = 32000000000;
    	if (exists($$config{references}{star})) {
    		my $star_path = $$config{references}{star}."/SA";
    		if (-e $star_path){
    			$minmem = int(1.2 * -s $star_path);
    			$minmem =    8000000000 if $minmem <    8000000000; #Minmem floor: 8Gb
			$minmem = 1024000000000 if $minmem > 1024000000000; #Minmem ceiling: 1Tb
    		}	
    	}
    	my $maxmem = int($minmem * 1.8);	#Maxmem ceiling: 1.8Tb
    	print CF::Helpers::allocate_memory($required_mem, $minmem, $maxmem);
    	exit;
    }
}
# --modules. Return csv names of any modules which should be loaded.
if($required_modules){
	print 'STAR'; # may need zcat too
	exit;
}
# --help. Print help.
if($help){
	print "".("-"x17)."\n STAR Module\n".("-"x17)."\n
STAR aligner. Requires a minimum of ~30GB RAM for human genome.\n
For further information, please run STAR --help\n\n";
	exit;
}

# MODULE
my $timestart = time;

# Read in the input files from the run file
my ($files, $runfile, $job_id, $prev_job_id, $cores, $mem, $parameters, $config_ref) = CF::Helpers::load_runfile_params(@ARGV);
my %config = %$config_ref;

# Check that we have a genome defined
if(!defined($config{references}{star})){
	warn "\n\n###CF Error: No star path found in run file $runfile for job $job_id. Exiting.. ###";
	exit;
} else {
	warn "\nAligning against ".$config{references}{star}."\n\n";
}

if(!defined($cores) || $cores < 1){
	$cores = 1;
}

open (RUN,'>>',$runfile) or die "###CF Error: Can't write to $runfile: $!";

# Print version information about the module.
warn "---------- STAR version information ----------\n";
warn `STAR --version`;
warn "\n------- End of STAR version information ------\n";	

# Load parameters
my $genomeLoad = 'NoSharedMemory';
my $sam_attributes = '--outSAMattributes Standard';
foreach my $parameter (@$parameters){
	if($parameter =~ /LoadAndRemove/){
		$genomeLoad='LoadAndRemove';
	}
	if ($parameter =~ /LoadAndKeep/) {
		$genomeLoad='LoadAndKeep';
	}
	if ($parameter =~ /outSAMattributes=All/) {
		$sam_attributes = '--outSAMattributes All';
	}
	
}


# Separate file names into single end and paired end
my ($se_files, $pe_files) = CF::Helpers::is_paired_end(\%config, @$files);

# FastQ encoding type. Once found on one file will assume all others are the same
my $encoding = 0;

# Go through each single end file and run STAR
if($se_files && scalar(@$se_files) > 0){
	foreach my $file (@$se_files){
		
		# Figure out the encoding if we don't already know
		if(!$encoding){
			($encoding) = CF::Helpers::fastq_encoding_type($file);
		}
		my $enc = "";
		my %convert_enc = ('phred33' => '0', 'phred64' => '-31', 'solexa' => '-31');  # I *think* this is correct
		if($encoding eq 'phred33' or $encoding eq 'phred64' or $encoding eq 'solexa'){
			$enc = '--outQSconversionAdd '.$convert_enc{$encoding};
		}
		
		my $prefix = $file;
		$prefix =~ s/\.gz$//;
		$prefix =~ s/\.fastq$//;
		$prefix =~ s/\.fq$//;
	
		my $output_fn = $prefix."Aligned.out.sam";
		
		my $command = "STAR --runThreadN $cores $enc $sam_attributes --genomeLoad $genomeLoad";  
		if ($file =~ /\.gz$/) {
			$command .= " --readFilesCommand zcat";	#code
		}
		
		$command .= " --genomeDir ".$config{references}{star}." --readFilesIn $file --outFileNamePrefix $prefix";
		warn "\n###CFCMD $command\n\n";
		
		if(!system ($command)){
			# STAR worked - print out resulting filenames
			my $duration =  CF::Helpers::parse_seconds(time - $timestart);
			warn "###CF STAR (SE mode) successfully exited, took $duration..\n";
			if(-e $output_fn){
				print RUN "$job_id\t$output_fn\n"; 
			} else {
				warn "\n###CF Error! star output file $output_fn not found..\n";
			}
		} else {
			warn "\n###CF Error! star (SE mode) failed exited in an error state for input file '$file': $? $!\n\n";
		}
	}
}

# Go through the paired end files and run STAR
if($pe_files && scalar(@$pe_files) > 0){
	foreach my $files_ref (@$pe_files){
		my @files = @$files_ref;
		if(scalar(@files) == 2){
			
			# Figure out the encoding if we don't already know
			if(!$encoding){
				($encoding) = CF::Helpers::fastq_encoding_type($files[0]);
			}
			my $enc = "";
			my %convert_enc = ('phred33' => '0', 'phred64' => '-31', 'solexa' => '-31');  # I think this is correct
			if($encoding eq 'phred33' || $encoding eq 'phred64' || $encoding eq 'solexa'){
				$enc = '--outQSconversionAdd '.$convert_enc{$encoding};
			}
			
			my $prefix = $files[0];
			$prefix =~ s/\.gz$//;
			$prefix =~ s/\.fastq$//;
			$prefix =~ s/\.fq$//;
			$prefix =~ s/\_R1_001$//;
		
			my $output_fn = $prefix."Aligned.out.sam";
			
			my $command = "STAR --runThreadN $cores $enc $sam_attributes --genomeLoad $genomeLoad";
			if ($files[0] =~ /\.gz$/) {
				$command .= " --readFilesCommand zcat";	#code
			}
			
			$command .= " --genomeDir ".$config{references}{star}." --readFilesIn $files[0] $files[1] --outFileNamePrefix $prefix";
			warn "\n###CFCMD $command\n\n";
			
			if(!system ($command)){
				# STAR worked - print out resulting filenames
				my $duration =  CF::Helpers::parse_seconds(time - $timestart);
				warn "###CF STAR (PE mode) successfully exited, took $duration..\n";
				if(-e $output_fn){
					print RUN "$job_id\t$output_fn\n"; 
				} else {
					warn "\n###CF Error! STAR output file $output_fn not found..\n";
				}	
			} else {
				warn "\n###CF Error! STAR (PE mode) exited in an error state for input file '".$files[0]."': $? $!\n\n";
			}
			
		} else {
			warn "\n###CF Error! STAR paired end files had ".scalar(@files)." input files instead of 2\n";
		}
	}
}


close (RUN);
