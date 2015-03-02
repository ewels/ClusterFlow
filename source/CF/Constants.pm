#!/usr/bin/env perl
use warnings;
use strict;
use FindBin qw($Bin);
use File::Find;
use File::Basename;
use Cwd;
use Exporter;

package CF::Constants;

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

our $CF_VERSION = "0.4 devel";

our $homedir = $ENV{"HOME"};

# Old config hash. Delete soon.
our %config;

# Empty config vars
our $EMAIL;
our $CL_COLOURS = 0;
our $CHECK_UPDATES;
our @NOTIFICATIONS;
our $SPLIT_FILES = 1;
our $PRIORITY;
our $TOTAL_CORES = 64;
our $TOTAL_MEM = '4G';
our $MAX_RUNS = 12;
our $CLUSTER_ENVIRONMENT = '';
our $CUSTOM_JOB_SUBMIT_COMMAND;
our $CF_MODULES = 1;
our %ENV_MODULE_ALIASES;
our @LOG_HIGHLIGHT_STRINGS;
our @LOG_WARNING_STRINGS;

# Empty references hash
our %REFERENCES;

# Update checking variables
our $AVAILABLE_VERSION;
our $UPDATES_LAST_CHECKED = 0;

parse_conf_file ();
parse_genomes_file();
parse_updates_file();

sub parse_conf_file {
    # Read global config variables in. Do in order so that local prefs overwrite.
    # Look in current directory and parent, as this module can be called
    # by /cf and by /modules/module.cfmod
    
    my $num_configs = 0;
    my @config_files = ("$FindBin::Bin/clusterflow.config", "$FindBin::Bin/../clusterflow.config", "$homedir/clusterflow/clusterflow.config", './clusterflow.config');
    foreach my $config_file (@config_files){
        if(-e $config_file){
            $num_configs++;
            open (CONFIG, $config_file) or die "Can't read $config_file: $!";
            my $comment_block = 0;
            while (<CONFIG>) {
                chomp;
                s/\n//;
                s/\r//;
                
                if($_ =~ /^\/\*.*\*\/$/){    # one line comments
                    $comment_block = 0;
                    next;
                } elsif($_ =~ /^\/\*/){        # multiline comments start
                    $comment_block = 1;
                    next;
                } elsif($_ =~ /\*\//){        # multiline comments end
                    $comment_block = 0;
                    next;
                }
                
                if($_ =~ /^\@/ && !$comment_block){
                    my @sections = split(/\s+/, $_, 2);
                    $config{substr($sections[0], 1)} = $sections[1];
                    my $name = substr($sections[0], 1);
                    my $val = $sections[1];
                    
                    if($name eq 'email'){
                        $EMAIL = $val;
                    } elsif($name eq 'colourful' or $name eq 'colorful'){
                        $CL_COLOURS = $val;
                    } elsif($name eq 'check_updates'){
                        $CHECK_UPDATES = $val;
                    } elsif($name eq 'available_version'){
                        $AVAILABLE_VERSION = $val;
                    } elsif($name eq 'updates_last_checked'){
                        $UPDATES_LAST_CHECKED = $val;
                    } elsif($name eq 'notification'){
                        push @NOTIFICATIONS, $val;
                    } elsif($name eq 'split_files'){
                        $SPLIT_FILES = $val;
                    } elsif($name eq 'priority'){
                        $PRIORITY = $val;
                    } elsif($name eq 'max_runs'){
                        $MAX_RUNS = $val;
                    } elsif($name eq 'total_cores'){
                        $TOTAL_CORES = $val;
                    } elsif($name eq 'total_mem'){
                        $TOTAL_MEM = $val;
                    } elsif($name eq 'cluster_environment'){
                        $CLUSTER_ENVIRONMENT = $val;
                    } elsif($name eq 'custom_job_submit_command'){
                        $CUSTOM_JOB_SUBMIT_COMMAND = $val;
                    } elsif($name eq 'ignore_modules'){
                        $CF_MODULES = 0;
                    } elsif($name eq 'environment_module_alias'){
                        my ($search, $replace) = split(/\s+/, $val, 2);
                        $ENV_MODULE_ALIASES{$search} = $replace;
                    } elsif($name eq 'log_highlight_string'){
                        push @LOG_HIGHLIGHT_STRINGS, $val;
                    } elsif($name eq 'log_warning_string'){
                        push @LOG_WARNING_STRINGS, $val;
                    }
                }
            }
            close(CONFIG);
        }
    }
    
    # Remove duplicate Notifications
    my @unique_notifications;
    my %seen_notification;
    foreach my $value (@NOTIFICATIONS) {
        if (!$seen_notification{$value}) {
            push @unique_notifications, $value;
            $seen_notification{$value} = 1;
        }
    }
    @NOTIFICATIONS = @unique_notifications;
    
    if($num_configs == 0){
        print ("Cluster Flow Error - no config files found. See clusterflow.config.example for an example.\n\n");
        exit;
    }
}

sub parse_genomes_file {
    
    # Read genomes config variables in. Do in order so that local prefs overwrite.
    
    my @genome_files = ("$FindBin::Bin/genomes.config", "$homedir/clusterflow/genomes.config", './genomes.config');
    foreach my $genome_file (@genome_files){
        if(-e $genome_file){
            open (GCONFIG, $genome_file) or die "Can't read $genome_file: $!";
            my $comment_block = 0;
            while (<GCONFIG>) {
                chomp;
                s/\n//;
                s/\r//;
                
                if($_ =~ /^\/\*.*\*\/$/){    # one line comments
                    $comment_block = 0;
                    next;
                } elsif($_ =~ /^\/\*/){        # multiline comments start
                    $comment_block = 1;
                    next;
                } elsif($_ =~ /^\*\//){        # multiline comments start
                    $comment_block = 0;
                    next;
                }
                if($_ =~ /^\@reference/ && !$comment_block){
                    my @sections = split(/\s+/, $_);
                    my $ref_type = $sections[1];
                    my $key = $sections[2];
                    $REFERENCES{$ref_type}{$key}{path} = $sections[3];
                    $REFERENCES{$ref_type}{$key}{species} = $sections[4] if defined $sections[4];
                    $REFERENCES{$ref_type}{$key}{assembly} = $sections[5] if defined $sections[5];
                    $REFERENCES{$ref_type}{$key}{config_file} = $genome_file
                }
            }
            close(GCONFIG);
        }
    }
}


sub parse_updates_file {
    my $updates_file = $ENV{"HOME"}."/clusterflow/.cfupdates";
    if(-e $updates_file){
        open (UPDATES, $updates_file) or die "Can't read $updates_file: $!";
        $AVAILABLE_VERSION = <UPDATES>;
        $AVAILABLE_VERSION =~ s/[\n\r]//;
        $UPDATES_LAST_CHECKED = <UPDATES>;
        $UPDATES_LAST_CHECKED =~ s/[\n\r]//;
        close (UPDATES);
    }
}





####################################
# Lists available genomes
####################################
sub list_clusterflow_genomes {
    
    my $returnstring = "";
    
    my @config_files = ("$FindBin::Bin/genomes.config", "$homedir/clusterflow/genomes.config", './genomes.config');
    
    foreach my $config_file (@config_files){
        
        my $conf_count = 0;
        my $conf_file_string .= "\n".('-' x 50)."\n $config_file\n".('-' x 50)."\n";
        foreach my $ref_type ( keys %REFERENCES){
            my $type_count = 0;
            my $type_string = "\n== $ref_type Paths ==\n";
            foreach my $genome_key ( keys %{$REFERENCES{$ref_type}}){
                if(defined($REFERENCES{$ref_type}{$genome_key}{config_file}) && $REFERENCES{$ref_type}{$genome_key}{config_file} eq $config_file){
                    my $this_key = $genome_key." " x (20 - length($genome_key));
                    my $this_species = " " x 20;
                    if(defined($REFERENCES{$ref_type}{$genome_key}{species})){
                        $this_species = $REFERENCES{$ref_type}{$genome_key}{species}." " x (20 - length($REFERENCES{$ref_type}{$genome_key}{species}));
                    }
                    my $this_assembly = " " x 15;
                    if(defined($REFERENCES{$ref_type}{$genome_key}{assembly})){
                        $this_assembly = $REFERENCES{$ref_type}{$genome_key}{assembly}." " x (15 - length($REFERENCES{$ref_type}{$genome_key}{assembly}));
                    }
                    my $this_path = $REFERENCES{$ref_type}{$genome_key}{path};
                    $type_string .= " ".$this_key.$this_species.$this_assembly.$this_path."\n";
                    $conf_count++;
                    $type_count++;
                }
            }
            if($type_count > 0){
                $conf_file_string .= $type_string;
            }
        }
        if($conf_count > 0){
            $returnstring .= $conf_file_string;
        }
    }
    $returnstring .= "\n";
    
    return $returnstring;
}






####################################
# Prints help for a specific module or pipeline
####################################
sub clusterflow_pipeline_help {
    
    my ($pipeline) = @_;
    
    my $help = "";
    
    my @pipelines = ("./$pipeline.config", "$homedir/clusterflow/pipelines/$pipeline.config", "$FindBin::Bin/pipelines/$pipeline.config");
    my @modules = ("./$pipeline.cfmod", "$homedir/clusterflow/modules/$pipeline.cfmod", "$FindBin::Bin/modules/$pipeline.cfmod");
    foreach my $pipeline (@pipelines){
        if(-e $pipeline){
            open (PIPELINE, $pipeline) or die "Can't read $pipeline: $!";
            my $comment_block = 0;
            while (<PIPELINE>) {
                chomp;
                s/\n//;
                s/\r//;
                next if($_ =~ /^\/\*/); # multiline comments start
                if($_ =~ /^\*\//){        # multiline comments end
                    $help .= "\n".("-" x 20)."\n Pipeline:\n".("-" x 20)."\n";
                    next;
                }
                $help .= $_."\n";
            }
            close(PIPELINE);
        }
        if($help){
            return ($help);
        }
    }
    
    foreach my $module (@modules){
        if(-e $module){
            $help = `$module --help`;
            return ($help);
        }
    }
    
    if($help eq ""){
        $help = "\nSorry, no help found for this pipeline.\n\n";
    }
    
    return ($help);
    
}




####################################
# Prints main cluster flow help
####################################
sub clusterflow_help {

    my $help;
    
    $help = <<"EOT";

Cluster Flow Help
=================
Running Cluster Flow version $CF_VERSION

SYNTAX
    cf [flags] pipeline_name file_1 file_2..
    
    Note that the name of a single module can be used instead of a
    pipeline name.

EXAMPLE
    cf --genome NCBIM37 sra_bismark *.sra

SPECIFIC PIPELINE / MODULE HELP
    To see specific help about a pipeline or module, use
    cf --help followed by a pipeline or module name.

INTRODUCTION
    Cluster Flow is simple package to run pipelines in a cluster environment.
    
    Cluster Flow will set off multiple queued jobs on the cluster with queue 
    dependencies as defined in the pipeline.

COMMON FLAGS
    These are flags that are commonly used in day to day Cluster Flow use.
    For a full description of the avilable flags and how to use them, see
    the Cluster Flow documentation.
	
    --setup
        Interactive prompt to generate required CF config files
	
    --genome <ID>
        ID of a genome referred to in clusterflow.config
        This genome ID is used to specify genome paths, bowtie
        index basenames and GTF file paths.
        Use --list_genomes to show available IDs
    
    --file_list
        Text file containing input files or download URLs
        
    --params
        Specify extra module parameters. These will be applied to every
        module if a pipeline name is specified.
        
    --list_pipelines
        Print available pipelines
        
    --list_modules
        Print available modules
        
    --list_genomes
        Print available genomes
    
    --qstat
        Parses the output from qstat in a visually attractive and intuitive manner
        
    --qstatall
        Same as --qstat, but for all jobs submitted by all users
    
    --qdel
        Delete all jobs running in a particular Cluster Flow pipeline. Follow
        with a pipeline ID, printed when running --qstat
        
    --add_genome
        Interactive wizard to add new genomes to your genomes.config files
        
    --dry_run
        Prints jobs to terminal instead of submitting them to the cluster
        
    --version
        Print version of Cluster Flow installed
        
    --check_updates
        Look for available Cluster Flow updates
        
    --help
        Print this help message.
        If specified with a pipeline or module name afterwards, the help for that
        pipeline or module will be displayed. eg. cf --help sra_bismark

RARE FLAGS
    These flags are used to override Cluster Flow defaults for a single run.
    For a full description of the avilable flags and how to use them, see
    the Cluster Flow documentation.

    --cores <num>
        Set the maximum number of cores to use for all runs
    
    --email <email>
        Set the e-mail address for notifications
    
    --max_runs <num>
        Divide input files into <num> runs. Overrides --split_files
        Setting this will override the default value set in
        clusterflow.config. Set to 0 to disable max_runs.
       
    --mem <string>
        Set the maximum memory to use for all runs

    --notifications <cresa>
        Specify desired notifications
        c = pipeline complete, r = run complete, e = qsub job ends
        s = qsub job suspended, a = qsub job aborted
   
    --no_fn_check
        Disable input file type checking
        
    --ref <type>=<path>
        Path to a reference to be used for alignment. Overrides --genome
        Possible values for type: fasta / bowtie / bowtie2 / star / gtf
        eg: --ref fasta=/path/to/fasta/files
    
    --single
        Force single-end mode
        
    --split_files <num>
        Create one run per <num> files

    --paired
        Force paired-end mode
    
    --priority <num>
        Set the queue priority for cluster jobs
    
    --runfile_prefix
        Prefix for run file filename. Avoids potential clashes if
        running multiple instances of Cluster Flow with the same
        input file.

AUTHOR
    Written by Phil Ewels (GitHub: \@ewels). Initial work done at the
    Babraham Institute, Cambridge. Continued at SciLifeLab, Stockholm.
    
SEE ALSO
    There is a full Cluster Flow manual available at
    http://ewels.github.io/clusterflow/

EOT
    
    return ($help);

}







####################################
# Function to run interactive shell prompt to add new genomes
####################################

sub clusterflow_add_genome {

    print "\n\nCluster Flow Genomes Config Generator\n======================================\nRunning Cluster Flow version $CF_VERSION\n";
    print "\nThis wizard will add a new reference paths to your genomes.config files\n\n";
    
    my %new_refs;

    # Determine which config file to append to
    my $cwd = Cwd::getcwd();
    print "First off, which config file would you like to add these references to?\n\n".
          "1 - Cluster Flow Installation directory, will be visible for all users\n".
          "       $FindBin::Bin/genomes.config\n\n".
          "2 - Your home directory, will be visible for you whenever you run Cluster Flow\n".
          "       $homedir/clusterflow/genomes.config\n\n".
          "3 - This directory, will only be visible when running Cluster Flow here\n".
          "       $cwd/genomes.config\n\n".
          "Please enter 1-3 to select one of the file paths..\n";

    my $fn;
    while ($fn = <STDIN>){
        chomp ($fn);
        if ($fn =~ /^1$/){
            $fn = "$FindBin::Bin/genomes.config";
            last;
        } elsif ($fn =~ /^2$/){
            $fn = "$homedir/clusterflow/genomes.config";
            last;
        } elsif ($fn =~ /^3$/){
            $fn = "./genomes.config";
            last;
        } else {
            print "\nSorry, I didn't understand that.\nPlease enter a number, 1-3..\n\n";
        }
    }
    print "Great - we'll use $fn\n\n";
    unless (-e $fn) {
        print "This file doesn't yet exist, and will be created..\n\n";
    }
    
    # Open straight away - if permission errors will die before any further faff
    open (OUT,'>>',$fn) or die "Can't write to $fn: $!";

    # Get Species and assembly
    print "To help identify genomes when using cf --list_genomes, you can specify\n".
          "a species and an assembly.This are both optional - just\n".
          "leave blank and press enter to ignore.\n";

    print "Please enter the species name (eg. Human):\n";
    my $species = <STDIN>;
    chomp ($species);
    $species =~ s/\s+/_/g;

    print "\nPlease enter the assembly name (eg. GRCh37):\n";
    my $assembly = <STDIN>;
    chomp ($assembly);

    # Get genome ID
    print "\nNext, we need a unique ID for the genome. This is what\n".
           "you will specify when you run jobs with --genome.\n".
           "We often just use the assembly name. Alphanumeric with _ and - only.\n";
    my $genomeID;
    GENOMEIDWHILE: while ($genomeID = <STDIN>){
        chomp ($genomeID);
        $genomeID =~ s/[^\w-]//g;
        if(length($genomeID) == 0){
            print "Sorry, this ID is required. Please enter a value:\n";
            next;
        }
        my $confirm = 0;
        foreach my $ref_type ( keys %REFERENCES){
            if(defined($REFERENCES{$ref_type}{$genomeID})){
                print " # A $ref_type reference with this ID already exists in $REFERENCES{$ref_type}{$genomeID}{config_file}:\n".
                      "    $REFERENCES{$ref_type}{$genomeID}{path}"."\n\n";
                $confirm = 1;
            }
        }
        if($confirm){
            print "You can still use this ID, but be aware that it may overwrite previous path definitions..\nDo you want to continue?\n\n";
            while (my $continue = <STDIN>){
                chomp ($continue);
                if ($continue =~ /^n(o)?/i){
                    print "\nOk, please enter a new ID:\n\n";
                    last;
                } elsif($continue =~ /^y(es)?/i){
                    print "\nOk, we'll continue with $genomeID then..\n\n";
                    last GENOMEIDWHILE;
                } else {
                    print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
                }
            }
        } else {
            print "\nGreat - we'll continue with $genomeID\n\n";
            last;
        }
    }
    
    # Search for references
    print "The wizard will now search a set of directories for known reference files\n".
          "(eg. GTF files).\n".
          "What path would you like to search (recursively)?\n".
          "Leave blank to skip this step and add paths manually..\n\n";
    
    my $do_search = 1;
    while($do_search){
        $do_search = 0; # Default to doing this loop only once.
        my $search_path;
        SEARCHPATHWHILE: while ($search_path = <STDIN>){
            chomp ($search_path);
            if(length($search_path) == 0){
                print "Ok, we can skip this step..\n\n";
                last;
            } elsif (-d $search_path) {
                last;
            } elsif (-e $search_path) {
                $search_path = dirname($search_path);
                if (-d $search_path) {
                    print "This looks like a file rather than a directory..\n".
                          "I'll trim off the filename and search this directory:\n  $search_path\n\n";
                    last;
                } else {
                    print "Hmm, this looks like a file but I can't find the\n".
                          "base directory. Please try again..\n\n";
                }
            } else {
                print "Oops! This directory doesn't exist!\n\n";
            }
        }
        if(length($search_path) > 0){
            my $found_files = 0;
            my $added_refs = 0;
            my %search_files;
            $search_files{fasta} = ();
            $search_files{bowtie} = ();
            $search_files{bowtie2} = ();
            $search_files{star} = ();
            $search_files{gtf} = ();
            $search_files{bwa} = ();
            &File::Find::find(sub {push(@{$search_files{fasta}}, $File::Find::name) if /\.fa(sta)?$/i}, $search_path);
            &File::Find::find(sub {push(@{$search_files{bowtie}}, $File::Find::name) if /\.ebwt$/i}, $search_path);
            &File::Find::find(sub {push(@{$search_files{bowtie2}}, $File::Find::name) if /\.bt2$/i}, $search_path);
            &File::Find::find(sub {push(@{$search_files{star}}, $File::Find::name) if /SAindex$/i}, $search_path);
            &File::Find::find(sub {push(@{$search_files{gtf}}, $File::Find::name) if /\.gtf$/i}, $search_path);
            &File::Find::find(sub {push(@{$search_files{bwa}}, $File::Find::name) if /\.bwt$/i}, $search_path);
            
            foreach my $type (keys %search_files){
                SFILES_FOREACH: foreach my $fn (@{$search_files{$type}}){
                    $found_files++;
                    my $ref;
                    if($type eq 'fasta'){ $ref = &File::Basename::dirname($fn); }
                    if($type eq 'bowtie'){ $ref = substr($fn, 0, -7); }
                    if($type eq 'bowtie2'){ $ref = substr($fn, 0, -6); }
                    if($type eq 'star'){ $ref = &File::Basename::dirname($fn); }
                    if($type eq 'gtf'){ $ref = $fn; }
                    if($type eq 'bwa'){ $ref = substr($fn, 0, -4); }
                    print "Found a $type file: $fn\nDo you want to add the following reference?\n   $ref\n\n".
                          "Enter y(es) / n(o) / a(ll) ('all' to ignore all $type files)\n";
                    while (my $continue = <STDIN>){
                        chomp ($continue);
                        if ($continue =~ /^n(o)?/i){
                            print "\nOk, I'll ignore this one. Continuing search..\n\n";
                            last;
                        } elsif($continue =~ /^y(es)?/i){
                            $added_refs++;
                            print "\nGreat! Adding that path..\n\n";
                            $new_refs{$type}{$genomeID}{path} = $ref;
                            last SFILES_FOREACH;
                        } elsif($continue =~ /^a(ll)?/i){
                            print "\nOk, ignoring all $type files..\n\n";
                            last SFILES_FOREACH;
                        } else {
                            print "\nSorry, I didn't understand that.\nCould you try again please? (y/n/a)\n\n";
                        }
                    } # Save ref y/n/a
                } # foreach found file
            } # foreach ref type
            print "\nReference file search finished..\n\n";
        
            if($added_refs == 0){
                if($found_files == 0){
                    print "\nOh dear, I couldn't find any files matching my search extensions\n".
                          "under that path.\n".
                          "I'm looking for *.fa, *.fasta, *.ebwt, *.bt2, SA, *.gtf and *.bwt files.\n\n";
                } else {
                    print "\nOops, we didn't add any new references.\n\n";
                }
                print "Do you want to try a different path for the search (y) or continue\n".
                      "on to manually enter reference paths? (n)\n\n";
                      
                while (my $continue = <STDIN>){
                    chomp ($continue);
                    if ($continue =~ /^n(o)?/i){
                        print "\nOk, let's get on with the manual addition..\n\n";
                        last;
                    } elsif($continue =~ /^y(es)?/i){
                        print "\nOk, let's try again..\n\n";
                        $do_search = 1;
                    } else {
                        print "\nSorry, I didn't understand that.\nCould you try again please? (y/n/a)\n\n";
                    }
                } # Repeat search y/n input
            } # if $added_refs == 0
        } # if search path > 0
    } # while $do_search

    
    # Manually add paths
    print "Now we can add any reference paths manually if you'd like.\n\n".
          "First, enter the type of reference that this is - Cluster Flow\n".
          "currently uses fasta, bowtie, bowtie2, star and gtf but you can\n".
          "extend it to use any that you like. Lower case letters, numbers, underscores\n".
          "and hyphens only.\n\n".
          "If you don't want to add any manual reference paths, just leave\n".
          "this blank and press enter...\n\n";
    
    my $man_ref_type;
    MANREF: while($man_ref_type = <STDIN>){
        chomp($man_ref_type);
        $man_ref_type = lc($man_ref_type);
        $man_ref_type =~ s/[^a-z0-9_-]//g;
        if(length($man_ref_type) == 0){
            print "Ok, we'll continue..\n\n";
            last MANREF;
        } else {
            print "Great - using reference type \"$man_ref_type\"..\n\n";
            print "Now please enter the full path for this reference:\n";
            my $man_ref_path;
            MANREFPATH: while ($man_ref_path = <STDIN>){
                chomp ($man_ref_path);
                if(length($man_ref_path) == 0){
                    print "You need to add a path..\n\n";
                } else {
                    $new_refs{$man_ref_type}{$genomeID}{path} = $man_ref_path;
                    print "\nGreat, Looks good. Note that as this is the manual addition I'm not checking\n".
                          "that this path actually exists..\n\n";
                    last MANREFPATH;
                }
            }
        }
        print "If you want to add another path for this genome ($genomeID) just\n".
              "add another reference type. Leave blank to continue..\n\n";
    }
    
    # Write the new paths to the file
    foreach my $type (keys %new_refs){
        foreach my $genomeID (keys %{$new_refs{$type}}){
            my $path = $new_refs{$type}{$genomeID}{path};
            print OUT "\@reference\t$type\t$genomeID\t$path\t$species\t$assembly\n";
            print "Added a $type reference: $genomeID = $path\n";
        }
    }
    close (OUT);
    
    print "\nThese new references were appended to the end of $fn\n".
          "If a genome key has more than one of the same reference\n".
          "type, only the last will be used by Cluster Flow.\n\n".
          "To check that this wizard has worked, you can run cf --list_genomes\n\n";
          
    print "All done! Exiting..\n\n";
}









####################################
# Function to run interactive shell prompt
# to generate a config file for first run
####################################
sub clusterflow_setup {
    
    # First of all - check we have a global config file
    my $global_fn = "$FindBin::Bin/clusterflow.config";
    unless(-e $global_fn){
        print "\n\nCluster Flow Global Config Generator\n".('='x37)."\nRunning Cluster Flow version $CF_VERSION\n\n";
        print "There is no global config file for Cluster Flow:\n$global_fn\n\n";
        print "This wizard can create one based on \n$global_fn.example\nbefore configuring a personal config file.\n\n";
        print "Would you like to create a global config file?\n\n";
        my $do_global = 0;
        while (my $continue = <STDIN>){
            chomp ($continue);
            if ($continue =~ /^n(o)?/i){
                print "\nOk. Bear in mind that certain configuration variables\nsuch as \@cluster_environment) must be set\nfor *all* Cluster Flow users.\n\n";
				sleep(1);
				last;
            } elsif($continue =~ /^y(es)?/i){
                print "\nBrilliant - we'll make a copy of\n$global_fn.example\nand customise a couple of key variables.\n\n";
                $do_global = 1;
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
        if($do_global){
            # Load the example config file
            open(GLOBAL_CONFIG_EXAMPLE, "<", $global_fn.".example") or die "Can't open global config example file: $!\n\n";
        	my @config_file = <GLOBAL_CONFIG_EXAMPLE>;
        	close(GLOBAL_CONFIG_EXAMPLE);
            
            # Get environment
            print "First - Cluster Flow is compatible with several HPC cluster managers,\nbut it needs to know which one you're using..\n\n";
            print "Are you using local, GRIDEngine, SLURM or LSF?\n(if you're just using this on your laptop, use local)\n\n";
            my $env;
            while ($env = <STDIN>){
                chomp ($env);
                if ($env =~ /(local|GRID( )?Engine|SGE|SLURM|LSF)/i){
					# I'm pedantic when it comes to capitalisation, sorry.
					$env = 'local' if $env =~ /local/i;
					$env = 'GRIDEngine' if $env =~ /GRID( )?Engine/i;
					$env = 'GRIDEngine' if $env =~ /SGE/i;
					$env = 'SLURM' if $env =~ /SLURM/i;
					$env = 'LSF' if $env =~ /LSF/i;
					$CLUSTER_ENVIRONMENT = $env;
                    print "\nGreat, going with $env\n\n";
                    my $inserted = 0;
                    for my $i (0 .. $#config_file) {
                        if($config_file[$i] =~ /\@cluster_environment/){
                            if(!$inserted){
                                $config_file[$i] = "\@cluster_environment\t$env\n";
                                $inserted = 1;
                            } else {
                                $config_file[$i] = '';
                            }
                        }
                    }
					last;
                } else {
                    print "\nSorry, I didn't understand that.\nCould you try again please?\n\n";
                }
            }
            
            # Environment modules?
            print "Next, do you use environment modules?\nThese use commands such as 'module load bowtie' to\n";
            print "load tools into your namespace. If you don't\nunderstand what this means, the answer is probably no.\n\n";
            print "Do you want to use environment modules? (y/n)\n\n";
            while (my $envmods = <STDIN>){
                chomp ($envmods);
                if ($envmods =~ /^y(es)?/i){
		            my $inserted = 0;
		            for my $i (0 .. $#config_file) {
		                if($config_file[$i] =~ /\@ignore_modules/){
		                    if(!$inserted){
		                        $config_file[$i] = "/* \@ignore_modules\ttrue */\n";
		                        $inserted = 1;
		                    } else {
		                        $config_file[$i] = '';
		                    }
		                }
		            }
                    last;
                } elsif($envmods =~ /^n(o)?/i){
                    print "\nOk, I'll add \@ignore_modules to the config file..\n\n";
		            my $inserted = 0;
		            for my $i (0 .. $#config_file) {
		                if($config_file[$i] =~ /\@ignore_modules/){
		                    if(!$inserted){
		                        $config_file[$i] = "\@ignore_modules\ttrue\n";
		                        $inserted = 1;
								$CF_MODULES = 0;
		                    } else {
		                        $config_file[$i] = '';
		                    }
		                }
		            }
                    last;
                } else {
                    print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
                }
            }

            
            print "Ok, all done - writing to $global_fn\n\nMoving on to personal configs..\n\n";
            open(GLOBAL_CONFIG, ">", $global_fn) or die "Can't open global config file for writing: $!\n\n";
        	print GLOBAL_CONFIG @config_file;
        	close(GLOBAL_CONFIG);
			sleep(1);
        }
    }
    
    # Ok, go on to personal config files
    my $fn = $homedir."/clusterflow/clusterflow.config";
    
    print "\n\nCluster Flow User Config Generator\n".('='x34)."\nRunning Cluster Flow version $CF_VERSION\n\n";
    print "This mode will generate a personalised Cluster Flow config file for you \nin your home directory: ~/clusterflow/clusterflow.config\n\n";
    
	my $make_personal_config = 1;
    if(-e $fn){
        print "### WARNING ###\n$fn already exists!\nThis script will overwrite that file. Do you want to continue? (y/n)\n\n";
        while (my $continue = <STDIN>){
            chomp ($continue);
            if ($continue =~ /^n(o)?/i){
				$make_personal_config = 0;
                print "\nProbably wise.. See the manual for more information about how the config file works.\n\n";
				last;
            } elsif($continue =~ /^y(es)?/i){
                print "\nOk, no problem.. I'll wipe it when we get to the end.\n\n";
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
    }
    
if($make_personal_config){
    my $config = "/*
Clusterflow Config
-------------------
Default static variables for clusterflow.
Syntax - \@key:value
These will overwrite any with the same name in the centralised config file
-------------------
*/\n\n";
    
    my $cl_cols;
    print "Right, let's get started!\nFirst off - Cluster Flow can make nice coloured status messages for you.\n";
    print "They help to scan quickly, but can look a bit nasty with some colour schemes.\n";
    print "Would you like to have coloured status messages? (y/n)\n\n";
    while ($cl_cols = <STDIN>){
        chomp ($cl_cols);
        if($cl_cols =~ /^y(es)?/i){
            print "\nYeah! Top tip: they look great with the dark solarized colour scheme.\n\n";
            $cl_cols = 1;
            sleep(2);
            last;
        } elsif ($cl_cols =~ /^n(o)?/i){
            print "\nFair enough. You can change you mind later if you fancy a little colour in your life ;)\n\n";
            $cl_cols = 0;
            last;
        } else {
            print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
        }
    }
    $config .= "\@colourful    $cl_cols\n";


    my $email;
    print "Next up - what is your e-mail address?\nThis will be used for sending notifications.\n\n";
    while ($email = <STDIN>){
        chomp ($email);
        if($email =~ /^\w[\w\.\-]*\w\@\w[\w\.\-]*\w(\.\w{2,4})$/){
            print "\nGreat! That looks good..\n\n";
            last;
        } else {
            print "\nHmm, that e-mail address looked a little odd.\nAre you sure you typed it in correctly? (y/n)\n\n";
            my $invalidemail = <STDIN>;
            chomp($invalidemail);
            if($invalidemail =~ /^y(es)?/i){
                print "\nFair enough!\n\n";
                last;
            } else {
                print "\nNo problem.. Please try it again..\n\n";
            }
        }
    }
    $config .= "\@email    $email\n";
    
    my $use_defaults;
    my $use_defaults_stdin;
    print "Ok, the rest of this wizard is about which notification e-mails that
you'd like to receive. We can skip this and use default settings if you
prefer. Use defaults? (y/n)\n\n";
    while ($use_defaults_stdin = <STDIN>){
        chomp ($use_defaults_stdin);
        if($use_defaults_stdin =~ /^y(es)?/i){
            print "\nGood choice. You can always edit these later anyway, just see the manual..\n\n";
            $use_defaults = 1;
            sleep(2);
            last;
        } elsif ($use_defaults_stdin =~ /^n(o)?/i){
            print "\nOk, let's delve a little deeper..\n\n";
            last;
        } else {
            print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
        }
    }
    if($use_defaults){
        $config .= "\@notification    complete\n";
        $config .= "\@notification    suspend\n";
        $config .= "\@notification    abort\n";
    } else {
        
        my ($notify_complete, $notify_run, $notify_success, $notify_error, $notify_abort);
        
        print "Would you like to receive a notification when a pipeline is completed?
The e-mail tells you the pipeline that has finished, the working directory
for that pipeline, a list of Cluster Flow highlight notifications (typically
whether each step in the pipeline ran successfully for each file) and then the
log file output for each file. These notifications are recommended (y/n)\n\n";
        while ($notify_complete = <STDIN>){
            chomp ($notify_complete);
            if($notify_complete =~ /^y(es)?/i){
                print "\nGreat!\n\n";
                $config .= "\@notification    complete\n";
                last;
            } elsif ($notify_complete =~ /^n(o)?/i){
                print "\nOk, fair enough..\n\n";
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
        
        print "Would you like to receive a notification when each run is completed?
Usually a run is the processing of one input file. The e-mail tells you the
name of the run that has finished, its pipeline and the working directory.
It includes a list of Cluster Flow highlight notifications (typically
whether each step in the pipeline ran successfully) and then the log file output.
These notifications are recommended for those who like to keep a close eye on
their processing (y/n)\n\n";
        while ($notify_run = <STDIN>){
            chomp ($notify_run);
            if($notify_run =~ /^y(es)?/i){
                print "\nGreat!\n\n";
                $config .= "\@notification    run\n";
                last;
            } elsif ($notify_run =~ /^n(o)?/i){
                print "\nOk, sounds good..\n\n";
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
        
        print "Would you like to receive a notification when step of each run ends?
This will be a GRID Engine notice for every qsub job. These notifications
are not recommended as a typicaly Cluster Flow run can flood your inbox with hundreds
of such e-mails. Would you like to receive them? (y/n)\n\n";
        while ($notify_success = <STDIN>){
            chomp ($notify_success);
            if($notify_success =~ /^y(es)?/i){
                print "\nFair enough, you were warned!\n\n";
                $config .= "\@notification    end\n";
                last;
            } elsif ($notify_success =~ /^n(o)?/i){
                print "\nProbably sensible..\n\n";
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
        
        print "Would you like to receive a notification when a GRID Engine
job is suspended? You're unlikely to get many if any, so they're recommended.
Would you like to receive these notifications? (y/n)\n\n";
        while ($notify_error = <STDIN>){
            chomp ($notify_error);
            if($notify_error =~ /^y(es)?/i){
                print "\nSounds good!\n\n";
                $config .= "\@notification    suspend\n";
                last;
            } elsif ($notify_error =~ /^n(o)?/i){
                print "\nFair enough..\n\n";
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
        
        print "Ok, last one. Would you like to receive a notification 
when a GRID Engine job exits in an abort state? This typically only
happens when you or an administrator kills your cluster jobs using
qdel. You're unlikely to get many of these, so they're recommended.
Would you like to receive these notifications? (y/n)\n\n";
        while ($notify_abort = <STDIN>){
            chomp ($notify_abort);
            if($notify_abort =~ /^y(es)?/i){
                print "\nSounds good!\n\n";
                $config .= "\@notification    abort\n";
                last;
            } elsif ($notify_abort =~ /^n(o)?/i){
                print "\nFair enough..\n\n";
                last;
            } else {
                print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
            }
        }
        $config .= "\n\n\n";
    
    } # end of defaults check
    
    print "\n\nGreat, that's it! The following config file will be created:\n\n$config\n";
    
    print "\nRemember that you can add further settings to your
personalised config file - see the Cluster Flow manual
for further information.\n\n\n";
    
    unless(-e $homedir."/clusterflow/" && -d $homedir."/clusterflow/"){
        mkdir ($homedir."/clusterflow/") or die "Can't create clusterflow directory: $!";
    }
    open (OUT, '>', $fn) or die "Can't write to $fn: $!";
    print OUT $config;
    close OUT;
	
} # if($make_personal_config){

	# Final section - bash aliases
	my $alias = "\n\n# Aliases added by Cluster Flow setup wizard\n";
	my $bashrc = '';
	$bashrc = "$homedir/.bashrc" if(-e "$homedir/.bashrc");
	$bashrc = "$homedir/.bash_profile" if(-e "$homedir/.bash_profile");
	if(length($bashrc) > 0){
		my $has_qs = 0;
		my $has_qsa = 0;
		open (BASHRC, '<', $bashrc) or die "Couldn't open $bashrc for appending: $!";
		while(<BASHRC>){
			$has_qs = 1 if(/alias qs='cf --qstat'/);
			$has_qsa = 1 if(/alias qsa='cf --qstatall'/);
		}
		close(BASHRC);
		
		if(!$has_qs && system("type qs > /dev/null 2>&1")){
		    print "\n\nCluster Flow Bash Alias Generator\n".('='x34)."\nRunning Cluster Flow version $CF_VERSION\n\n";
			print "A common command when using Cluster Flow is 'cf --qstat'\n".
				  "This shows currently running jobs. This is a bit of a mouthful to type,\n".
				  "so most users set up a bash alias so that you can type 'qs' instead.\n\n".
				  "It doesn't look like 'qs' does anything for you at the moment, would\n".
				  "you like the wizard to add this alias to $bashrc ?\n\n";
			while (my $add_qs = <STDIN>){
			    chomp ($add_qs);
			    if($add_qs =~ /^y(es)?/i){
					$alias .= "alias qs='cf --qstat'\n";
			        print "\nOk, added..\n\n";
			        last;
			    } elsif ($add_qs =~ /^n(o)?/i){
			        print "\nNo problem..\n\n";
			        last;
			    } else {
			        print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
			    }
			}
		}
		if(!$has_qsa && $CLUSTER_ENVIRONMENT eq 'GRIDEngine' && system("type qsa > /dev/null 2>&1")){
			print "The same goes for 'cf --qstatall', would you like to bind this to 'qsa'?\n\n";
			while (my $add_qsa = <STDIN>){
			    chomp ($add_qsa);
			    if($add_qsa =~ /^y(es)?/i){
					$alias .= "alias qsa='cf --qstatall'\n";
			        print "\nOk, added..\n\n";
			        last;
			    } elsif ($add_qsa =~ /^n(o)?/i){
			        print "\nNo problem..\n\n";
			        last;
			    } else {
			        print "\nSorry, I didn't understand that.\nCould you try again please? (y/n)\n\n";
			    }
			}
		}
		if(length($alias) > 47){
			open (BASHRC, '>>', $bashrc) or die "Couldn't open $bashrc for appending: $!";
			print BASHRC $alias."\n\n";
			close(BASHRC);
		}
		
		print "\n\nNote about the cf command\n".('='x25)."\n";
		print "As a small final note, be aware that Cluster flow is only really useful\n".
			  "if the main cf executable is available as a command in the terminal.\n".
			  "How you do this depends heavily on your setup, so this wizard doesn't\n".
			  "attempt to do it for you. Bear in mind that you may want to add one\n".
			  "of the following lines to $bashrc :\n\n".
			  "module load cf\n".
			  'export PATH="'.$FindBin::Bin.'":$PATH"'."\n\n";
	}
}


1;
