#!/usr/bin/perl
use strict;

################################################################################
# CONSTANTS
################################################################################

$ENV{'TERM'}        = "vt100";
$ENV{'PATH'}        = "/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin";

my $SUCCESS         = 0;
my $ERROR           = 1;

my $USAGE           = "$0 < alternate input file for debugging >";

################################################################################
# VARIABLES
################################################################################

my $exit_code       = $SUCCESS;
my $err_msg         = "";

my $counter         = 0;
my $config_flag     = 0;
my $end_flag        = 0;
my $indent          = "    ";
my $indent_level    = 1;
my $old_space_count = 0;
my $new_space_count = 0;

my $my_zpool        = "";

################################################################################
# SUBROUTINES
################################################################################

# NAME: Function f__indent
# WHAT: Print out precise indentation
#
sub f__indent {
    my $return_code = $SUCCESS;
    my $indent_lvl  = $_[0];
    my $one_indent  = $_[1];

    for ( my $i=0 ; $i < $indent_lvl ; $i++ ) {
        print "$one_indent";
    }
    
}

################################################################################
# MAIN
################################################################################

# WHAT: Make sure we have a zpool command
# WHY:  Cannot proceed otherwise
#
if ( $exit_code == $SUCCESS ) {
    my $command = "which zpool 2> /dev/null";
    open( COMMAND, "$command |" );
    chomp( $my_zpool = <COMMAND> );
    close( COMMAND);

    if ( $my_zpool eq "" ) {
        $err_msg   = "Could not locate the zpool command";
        $exit_code = $ERROR;
    }

}

# WHAT: Gather data
# WHY:  Asked to
#
if ( $exit_code == $SUCCESS ) {

    if ( $ARGV[0] ne "" ) {
        my $fh          = $ARGV[0];
        open( FH, "<", $fh );
    } else {
        my $command = "$my_zpool status -T d";
        open( FH, "$command |" );
    }
    
    while ( <FH> ) {
        chomp;
        my $input_line = $_;
    
        if ( $input_line =~ /^config:/ ) {
            $config_flag = 1;
        }
    
        if ( $input_line =~ /^errors:/ ) {
            $config_flag = 0;
        }

        if (( $end_flag == 1 ) && ( $input_line =~ /pool: / )) {
            print "\}\n\{\n";
            $config_flag = 0;
            $end_flag = 0;
        }
    
        if ( $config_flag == 1 ) {
    
            if ( $input_line =~ /config/ ) {
                &f__indent( $indent_level, $indent );
                print "\"config\" : \{\n";
    
                # Set the amount of leading spaces
                # This will be used later on to determine indentation level changes
                my $str = $input_line;
                $str =~ /^(\s*)/;
                $old_space_count = length( $1 ); 
            } else {
    
                if (( $input_line !~ /NAME/ ) && ( $input_line ne "" )) {
    
                    # Check the amount of leading spaces
                    # This will be used to determine any indentation level changes
                    my $str = $input_line;
                    $str =~ /^(\s*)/;
                    $new_space_count = length( $1 ); 
    
                    if ( $new_space_count > $old_space_count ) {
    
                        if ( $old_space_count > 0 ) {
                            print ",\n";
                        }
    
                        $indent_level++;
                    } elsif ( $new_space_count < $old_space_count ) {
                        print "\n";
                        $indent_level--;
                        &f__indent( $indent_level, $indent );
                        print "\},\n";
                    } else {
                        print "\n";
                        &f__indent( $indent_level, $indent );
                        print "\},\n";
                    }
    
                    # Now that we think we are clear on indentation, it is
                    # time to clear out those leading spaces before printing
                    $input_line =~ s/^\s*//g;
    
                    # To get here, we are processing information about the elements
                    # within a ZFS pool.  This data is a quintuple, so let's collapse
                    # the spaces so it can be split into meaninful pieces
                    $input_line =~ s/\s+/\?/g;
                    ( my $name, my $state, my $read, my $write, my $cksum ) = split(/\?/,$input_line);
                    &f__indent( $indent_level, $indent );
    
                    # We now print out the pieces
                    print "\"$name\" : {\n";
                    $indent_level++;
                    &f__indent( $indent_level, $indent );
                    print "\"state\" : \"$state\",\n";
                    &f__indent( $indent_level, $indent );
                    print "\"read\" : \"$read\",\n";
                    &f__indent( $indent_level, $indent );
                    print "\"write\" : \"$write\",\n";
                    &f__indent( $indent_level, $indent );
                    print "\"cksum\" : \"$cksum\"";
                    $indent_level--;
    
                    # Reset the leading space counter
                    $old_space_count = $new_space_count;
                }
    
            }
    
        } else {
    
            if ( $input_line ne "" ) {
    
                # The first line is the date!
                if ( $counter == 0 ) {
                    print "{\n";
                    &f__indent( $indent_level, $indent );
                    print "\"date\" : \"$input_line\",\n";
                } else {
                    $input_line =~ s/:\ /:/g;
                    ( my $key, my $value ) = split(/:/,$input_line);
                    $key =~ s/[^a-zA-Z0-9]//g;
    
                    if ( $key eq "errors" ) {
                        $end_flag = 1;
                        print "\n";
    
                        if ( $indent_level > 2 ) {
    
                            while ( $indent_level > 2 ) {
                                &f__indent( $indent_level, $indent );
                                print "\}\n";
                                $indent_level--;
                            }
    
                        }
    
                        # We should be at an indent of 2 right here
                        &f__indent( $indent_level, $indent );
                        print "\}\n";
                        $indent_level--;
                        # ... and now indent of 1 right here
                        &f__indent( $indent_level, $indent );
                        print "\},\n";
                        &f__indent( $indent_level, $indent );
                        print "\"$key\" : \"$value\"\n";
    
                    } else {
                        &f__indent( $indent_level, $indent );
                        print "\"$key\" : \"$value\",\n";
                    }
    
                }
    
            }
    
        }
    
        $counter++;
    }
    
    close( FH );
    print "\}\n";
}

# WHAT: Complain if necessary and exit
# WHY:  Success or failure, either way we are through!
#
if ( $exit_code != $SUCCESS ) {

    if ( $err_msg ne "" ) {
        print "\n";
        print "    ERROR:  $err_msg ... processing halted\n";
        print "\n";
        print "    Usage:  $USAGE\n";
    }

}

exit $exit_code;
