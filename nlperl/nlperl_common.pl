#!/usr/bin/perl
#
# Utility script to build customized gstreamer distributions given an xml definition
# of the distribution. The distribution is defined in a gstbuildpars.xml file by default
#
use strict;
use File::Copy "cp";
use File::Path;
use Getopt::Long;
use Cwd 'fast_abs_path';
use XML::Simple;
use Data::Dumper;
use Switch;
use File::Basename;
use File::Spec;
use Digest::SHA;

my $cygwin = 0;

sub sha1file {
    my ($file) = @_;
    my $fh;

    open $fh, $file or die "couldn't open $file";
    my $sha1 = Digest::SHA->new(1); #using sha1
    $sha1->addfile($fh);
    my $digest = $sha1->hexdigest;
    close $fh;

    return $digest;
}

sub __system {
    my ($cmd, $echo, $dieonfail) = @_;
    print $cmd."\n" if defined($echo);
    if( system($cmd) != 0 and defined($dieonfail) ) {
        die "$cmd exit status not 0";
    }
}

sub __fileparse {
    my ($file) = @_;

    return fileparse ($file, qr/\.[^.]*/ );
}

sub __rtrim {
    my ($s) = @_;
    $s =~ s/\n|\r//g;
    return $s;
}

sub __abs_path {
    my ($path) = @_;
    $path = fast_abs_path($path);
	$path = `cygpath -mal $path` if $cygwin==1;
    $path = __rtrim($path);
    return $path;
}
sub get_dir_files {
    my ($dir,$noabspath,$filter) = @_;
    my @files = `ls $dir`;
    my @outfiles = ();

#    for (my $i=0; $i<=$#files; $i++ ) {
#        $files[$i] =~ s/\n|\r//g;
#        $files[$i] = __abs_path( $dir. "/" . $files[$i] ); 
#    }

    for my $file (@files) {
        $file =~ s/\n|\r//g;
        if( defined ($filter) && ($file !~ m/\Q$filter\E/ )) {
            next;
        }
        $file = __abs_path( $dir. "/" . $file ) if not defined($noabspath);
        next if -d $file;
        push (@outfiles, $file);
    }

    return @outfiles;
}

#finds the relative path from base to path
sub nl_abs2rel {
    my ($path, $base) = @_;
    my ($file, $volume);
    # canonicalize
    $path = __abs_path($path);
    $base = __abs_path($base);
    #print("path: $path\nbase:$base\n\n");       

    my $relpath = "";
    while( $path !~ m/\Q$base\E/ ) {
        #print "postbase:$base\n";
        ($volume, $base, $file) = File::Spec->splitpath( $base );
        $relpath .= "../";
        #remove trailing dir separator if any
        #print "prebase:$base\n";        
        $base =~ s/\/$//;
        #print("relpath:$relpath\nbase:$base\npath:$path\nmatched_string:$&\nbefore_matched:$`\nafter_matched:$'\n");
    }

    $path =~ s/\Q$base\E(.*)$/\1/;
    $relpath .= $path;
    return $relpath;
    #print("relpath: $relpath\n");   

}

# given an ELF binary, this will change
# the path to use relative paths containing $ORIGIN
#
# binary is the file from which to calculate the relative 
# path
#
# newbinary is the file that will receive the resulting
# rpath
sub relativize_rpath {
    my ($binary, $newbinary)=@_;
    if( not `which chrpath` =~ /chrpath/ ) {
        die "chrpath needed for relativize_rpath to work\n";
    }
    

    #getting RPATH from file using chrpath
    my $rpath = "";
    my $chrpath_out = `chrpath $binary`;
    if( $chrpath_out =~ m/RPATH=(.+)/ ) {
        $rpath = $1;
        print "found rpath = $1\n";
    } else {
        print "binary doesn't seem to have an RPATH entry. $chrpath_out\n";
        return;
    }

    my ($volume, $binarypath, $file) = File::Spec->splitpath( __abs_path( $binary ) );

    #normalize rpath
    #print "prerpath:$rpath\n";
    my $subs='$ORIGIN';
    $rpath =~ s|\Q$subs\E|$binarypath|;
    $rpath = __abs_path( $rpath );
    #print "postpath:$rpath\n";

    my $rel_path = nl_abs2rel( $rpath, $binarypath );
    $rel_path = '\$ORIGIN/' . $rel_path;

    #print "rpath $rpath\nbinarypath $binarypath\nrel_path $rel_path\n";
    #changing rpats
    __system( "chrpath -r $rel_path $newbinary", 1);

}

# writes a file with the contents passed in $contents
sub nl_write_textfile {
    my ($fname, $contents) = @_;
    open ( FILE, ">$fname") or die "couldn't open $fname for writing";
    print FILE $contents;
    close (FILE);
}

sub nl_read_textfile {
    my ($fname) = @_;
    open ( FILE, "$fname") or die "couldn't open $fname for reading";
    local $/; 
    my $ret = <FILE>;
    close (FILE);
    return $ret;
}


1;
