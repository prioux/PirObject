###########################################################
# PirObject.pm
#
# by Pierre Rioux, September 2004.
#
# Find more doc and information here:
#    http://sourceforge.net/projects/pirobject/
###########################################################

###########################################################
#    Copyright (C) 2004-2008 Pierre Rioux
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
# 
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
###########################################################

###########################################################
# This file provides the basic facilities to create dynamically
# perl classes for manipulating simple data containers that have
# XML I/O abilities.
###########################################################

###########################################################
#
# Revision history:
#
# $Log$
# Revision 1.15  2007/11/08 18:36:16  prioux
# Added the underscore character as an allowed character for a subobject
# name, in the fields table of the object definition file. Still, I
# recommend NOT to use such a character in object's name, if possible.
#
# Revision 1.14  2007/10/14 05:26:08  prioux
# The esthetic layout of the DTDs has been greatly improved. Also,
# they will show the comments that were supplied in the object
# definition file, if possible.
#
# Revision 1.13  2007/10/12 23:50:13  prioux
# Added ability to specify a field name that contains a '-' (dash);
# this is useful when trying to model external XML files that contain
# elements with such characters. However this also introduces an ambiguity,
# as method names to set the fields cannot have dashes, so the method
# names have a '_' (underscore) instead. It's unlikely that a XML document
# will have two fields that differ only in the usage of dashes and
# underscores!
#
# When PirObject loads an object description file, it records the actual
# path of the file in the %INC array of the main:: package, just like
# a "require" statement do. This is useful to figure out WHERE the
# files with .pir extensions were actually found after searching
# the DATAMODEL_PATH.
#
# Revision 1.12  2007/08/06 20:05:24  prioux
# Fixed tiny bug when calling FileHandleToObject() in a scalar
# context on a filehandle already at EOF: we now return undef
# instead of 0.
#
# Revision 1.11  2007/06/15 18:31:32  prioux
# Fixed a warning when calling XMLToObject().
#
# Revision 1.10  2007/02/19 18:47:25  prioux
# Improved error reporting when a datamodel file contains error in
# its 'method' section: instead of showing the full code listing
# of the internally-created package, only the 8 lines surrounding the
# first line in error are shown.
#
# Revision 1.9  2006/03/17 21:35:21  prioux
# Improved handling of truncated XML files in input; fixed bug
# when checking for already-defined methods in superclasses that
# prevented the "InheritsFrom" directive from working properly.
#
# Revision 1.8  2005/06/28 20:37:30  prioux
# Fixed bug when using InheritsFrom other than the typical "PirObject"
# keyword.
#
# Revision 1.7  2005/06/16 03:10:52  prioux
# Fixed warnings with DeepClone() method.
#
# Revision 1.6  2005/05/16 19:02:17  prioux
# Updated ObjectXMLDocumentHeader() so that in order to get
# a standalone document, you need to supply the keyword
# "standalone". The DTD is generated internally.
#
# Revision 1.5  2005/05/16 18:44:22  prioux
# Improved ObjectXMLDocumentHeader() so that when a proper DTD
# is passed in argument, the document becomes 'standalone'.
#
# Revision 1.4  2005/05/16 18:31:21  prioux
# Combined multiple ATTLIST declarations for single objects,
# arrays and hashes into a single ATTLIST declaration.
#
# Revision 1.3  2005/05/16 17:56:50  prioux
# Fixed DTD declarations for arrays and hashes;
# improved esthetic layout of hashes in XML dump;
# fixed problem of use of uninitialized var when
# accessing the HOME environment variable.
#
# Revision 1.2  2004/12/21 03:55:46  prioux
# Added support for object definition files that are supplied
# internally by the application (they no longer HAVE to be
# external files). See the doc for DataModelPath(). Added
# the GPL license file to the distribution (I forgot it in
# my first package...!)
#
# Revision 1.1.1.1  2004/10/23 01:04:39  prioux
# Initial import
#
#
###########################################################

use strict;
use IO::File;

package PirObject;

use vars qw(
             $RCS_VERSION
             $VERSION
             $DEBUG
           );

# Revision control strings
$RCS_VERSION='$Id$';
($VERSION) = ($RCS_VERSION =~ m#,v ([\w\.\-]+)#);

# Internal data structures; these exist ONLY in this top level class.
   $DEBUG               = 0;   # when true, prints traces.
my %PerlClassToXMLTag   = ();
my %XMLTagToPerlClass   = ();
my %XMLReaderSubCache   = ();
my $MODELFILE_EXTENSION = "pir";

my @DATAMODEL_PATH      = (
    ".",
    "./PirModels",
    ($ENV{"HOME"} || ".") . "/PirModels",
);
unshift(@DATAMODEL_PATH,split(/:/,$ENV{"PIR_DATAMODEL_PATH"}))
    if $ENV{"PIR_DATAMODEL_PATH"};

############################################################################
# Data Model Loading Section
############################################################################

# Use to set or get the data model path.
# This is a set of directories to search for ".pir" files
# when the LoadDataModel() method is called.

# New feature: any of the entries in the @DATAMODEL_PATH can
# now be a ref to a hash table instead of a directory name;
# in that case the hash table will be interpreted as a kind
# of in-memory file directory, where the key of the entries are
# filenames and the values their content.

sub DataModelPath {
    my $self = shift;
    die "Error: DataModelPath() can only be called as a class method of " . __PACKAGE__ . "\n"
        if $self ne __PACKAGE__;
    @DATAMODEL_PATH = @_ if @_;
    @DATAMODEL_PATH;
}

# This is the main method used to load a data model.
# The single required argument is the name of
# a top-level object description name, e.g. "XYZ",
# which will be used to load a description from
# a file called "XYZ.pir". If the object model described
# in this file refers to other subobjects, e.g. "ABC", then
# the method will automatically call itself to load these
# object description files too, recursively, until all
# needed descriptions are loaded. An added complexity
# is caused when the model description specifies the
# name of another object in its InheritsFrom; in that
# case before we can complete the process of defining the
# perl class for the model, we must load that other object
# definition first... which may trigger more load operations!  

sub LoadDataModel {
    my $self = shift;
    my $model = shift
       || die "Need to be supplied a datamodel name,\n" .
              "e.g.\"XYZ\" to search for \"XYZ.$MODELFILE_EXTENSION\".\n";
    my $being_loaded = shift || [];  # history load stack to check for infinite loops....

    die "Error: LoadDataModel() can only be called as a class method of " . __PACKAGE__ . "\n"
        if $self ne __PACKAGE__;

    die "Model name '$model' is not legal, it must be a bareword.\n"
        unless $model =~ m#^[a-zA-Z][\w\-]+$#;

    my $error_report = "";
    for (my $n=0;$n < @$being_loaded;$n+=2) {
        my $tag  = $being_loaded->[$n];
        my $path = $being_loaded->[$n+1];
        $error_report .= "$tag\t$path\n";  # not too serious to build this every time.
        next if $tag ne $model;
        # TODO: report better when cycle is caused by InheritsFrom
        die "Error: LoadDataModel() is given a set of files that refer to each other in an\n" .
            "infinite cycle! The model names and paths in the cycle are:\n" .
            $error_report;
    }

    my @to_load = ( $model );
    my $CurrentTagName       = "";
    my $CurrentPerlClass     = "";
    my $CurrentInheritsFrom  = "";
    my @CurrentUsedObjects   = ();
    LOAD: while (@to_load) {
        my $mod_to_load = shift(@to_load);
        next if exists $XMLTagToPerlClass{$mod_to_load}; # model name is also tag name
        foreach my $dir (@DATAMODEL_PATH) {
            my $file    = undef; # filename of external file
            my $content = undef; # content of file if internal file.
            if (ref($dir) ne "HASH") {  # Search a real directory
                $file = "$dir/$mod_to_load.$MODELFILE_EXTENSION";
                next unless -f $file;
            } else {  # Search an internal filesystem-in-a-hash. New feature.
                $file = "$mod_to_load.$MODELFILE_EXTENSION";
                $content = $dir->{"$mod_to_load.$MODELFILE_EXTENSION"} ||
                           $dir->{"$mod_to_load"};  # Internaly, we support "Object.pir" as well as "Object".
                next unless $content;
            }
            my ($TagName,$PerlClass,$InheritsFrom,@UsedObjects) =
                $self->_LoadDataModelFromFile($file,$being_loaded,$content);
            # For the next four scalars, the FIRST round through the loop has the
            # values we want to return in this method.
            @CurrentUsedObjects    = @UsedObjects unless $CurrentTagName;
            $CurrentPerlClass    ||= $PerlClass;
            $CurrentInheritsFrom ||= $InheritsFrom;
            $CurrentTagName      ||= $TagName;
            push(@to_load,@UsedObjects);
            next LOAD;
        }
        die "Error: can't find a datamodel file for '$mod_to_load' in datamodel search path.\n" .
            "Search path is:\n" . join("\n",@DATAMODEL_PATH,"");
    }
    # Actually, it's impossible for $CurrentTagName to be different from $model...
    if (! $CurrentTagName ) { # means we don't need to load anything, it was already loaded...
        $CurrentTagName      = $model;
        $CurrentPerlClass    = $XMLTagToPerlClass{$model};
        no strict;
        $CurrentInheritsFrom = ${"$CurrentPerlClass" . "::ISA"}[0]; # hopefully not changed by user...
        use strict;
        #@CurrentUsedObject ?!??
    }
    ($CurrentTagName,$CurrentPerlClass,$CurrentInheritsFrom,@CurrentUsedObjects);
}

# Internally used by LoadDataModel().
# Will actually call back LoadDataModel() sometimes.
sub _LoadDataModelFromFile {
    my $self = shift;
    my $filename = shift;
    my $being_loaded = shift || [];  # history load stack to check for infinite loops....
    my $filecontent = shift; # Optional: if file content is already supplied by application.

    print STDERR "DEBUG: Loading file: $filename\n"            if $DEBUG;

    my ($TagName) = ($filename =~ m#\b([a-zA-Z][\w\-]*)\.$MODELFILE_EXTENSION$#o);
    die "Error: can't figure out XML Tag name from datamodel file '$filename' ?!?\n"
        unless $TagName;

    my $class = ref($self) || $self;

    my @content = ();
    if (! $filecontent) {
        my $fh = new IO::File "<$filename"
            or die "Can't load datamodel file '$filename': $!\n";
        @content = <$fh>;
        $fh->close();
    } else {
        @content = split(/\n/,$filecontent); # yuk
        grep(($_ .= "\n") && 0, @content); # double yuk
    }

    # Values found in the datamodel file
    my $PerlClass    = "";
    my $InheritsFrom = "";
    my %Fields       = ();  # fieldname => [ sah , type, comment, hasobjects ]
    my @Fields       = ();  # Respect user's order.
    my $methods      = "";  # block of perlcode

    my $expect = "PerlClass";

    PARSEFILE:
    while (my $line = shift(@content)) {
        next if $line =~ m/^\s*$|^\s*#/;
        die "Unexpected line in datamodel file '$filename':\nLine: $line"
            unless $line =~ m#^\s*-\s*(\w+)\s*(\S*)\s*$#;
        my ($section,$value) = ($1,$2);
        die "Unexpected section '$section' in datamodel file '$filename'; expected section '$expect'.\nLine: $line"
            unless $section eq $expect;

        if ($section eq "PerlClass") {
            $PerlClass = $value;
            die "Incorrect PerlClass '$PerlClass' in datamodel file '$filename'.\n"
                unless $PerlClass =~ m#^[a-zA-Z]\w*(::[a-zA-Z]\w*)*$#;
            die "Error: PerlClass '$PerlClass' in datamodel file '$filename' conflicts with\n" .
                "a perl class already registered in " . __PACKAGE__ . "!\n"
                if exists $PerlClassToXMLTag{$PerlClass};
            $PerlClassToXMLTag{$PerlClass} = $TagName;
            $XMLTagToPerlClass{$TagName} = $PerlClass;
            $expect = "InheritsFrom";
            next;
        }

        if ($section eq "InheritsFrom") {
            $InheritsFrom = $value;
            $InheritsFrom = __PACKAGE__ if ! defined ($InheritsFrom) || $InheritsFrom eq "";
            die "Incorrect InheritsFrom '$InheritsFrom' in datamodel file '$filename'.\n"
                unless $InheritsFrom =~ m#^[a-zA-Z]\w*$#;
            $expect = "FieldsTable";
            next;
        }

        if ($section eq "FieldsTable") {
            $expect = "Methods";
            while ($line = shift(@content)) {
                next if $line =~ m/^\s*$|^\s*#/;
                last if $line =~ m#^\s*- EndFieldsTable#;
                die "Unparsable field definition line in datamodel file '$filename'.\nLine: $line"
                    unless $line =~ m!
                        ^\s*
                        ([a-zA-Z][\w\-]*)         # Field name
                        \s+
                        (single|array|hash)              # structure keyword
                        \s+
                        (int[1248]|string|<[a-zA-Z][a-zA-Z0-9_]*>)  # allowed types
                        \s*
                        (.*)                           # optional comment
                        !x;
                my ($name,$sah,$type,$comment) = ($1,$2,$3,$4);
                die "Error: redefinition of field '$name' in datamodel file '$filename'.\n"
                    if exists $Fields{$name};
                $comment =~ s/\s*$//;
                $Fields{$name} = [ $sah, $type, $comment ];
                push(@Fields,$name);
            }
            next;
        }  

        if ($section eq "Methods") {
            $methods = join("",@content);
            last PARSEFILE;
        }

        die "Unexpected section '$section' in datamodel file '$filename'.\nLine: $line";
    }

    # Before we proceed, we may need to call LoadDataModel() again if
    # the current object description inherits from the information in
    # another object description file.
    if ($InheritsFrom ne __PACKAGE__) {
        push(@$being_loaded, $TagName, $filename);  # to trap loops in files
        my ($tag,$perlclass,$inherits,@usedobj) =
            $self->LoadDataModel($InheritsFrom,$being_loaded);
        my $superfields      = $perlclass->_InfoFields();
        my $superfieldsorder = $perlclass->_InfoFieldsOrder();
        foreach my $name (reverse @$superfieldsorder) {
            next if $Fields{$name}; # current overrides super
            unshift(@Fields,$name);
            my ($sah,$type,$comment,$hasobjs) = @{$superfields->{$name}};
            $Fields{$name} = [ $sah, $type, $comment ];
        }
        $InheritsFrom = $perlclass;
    }

    # At this point, built the code for the methods and store the information
    # for the fields.

    my $eval = "
          # This is perl code internally generated and compiled ONCE.
          # It serves uniquely to add the (optional) custom methods
          # the user supplied in the datamodel file.

          use strict;
          package $PerlClass;
          use vars qw( \@ISA \$Fields \$FieldsOrder \$ArrayHashFields );

          \@ISA             = ( \"$InheritsFrom\" );
          \$Fields          = {};
          \$FieldsOrder     = [];
          \$ArrayHashFields = {};

          $methods
          ";

    eval $eval;
    if ($@) {
        my $message = $@;
        my ($linenum) = ($message =~ /line\s+(\d+)/);
        my $context = "";
        if ($linenum) {
            $linenum--;
            my @perlcode = split(/\n/,$eval);
            my $from = $linenum - 4; $from = 0          if $from < 0;
            my $to   = $linenum + 4; $to   = $#perlcode if $to   > $#perlcode;
            foreach my $n ( $from .. $to ) {
                $context .= sprintf("%4d: %s\n", $n+1, $perlcode[$n]);
            }
        }
        die "\n" . __PACKAGE__ . ": Error in evaluating the custom methods specified in datamodel file '$filename'.\n" .
            "The error message was:\n    $message\n" .
            ($context ? "The code surrounding the first line in error was:\n$context\n" : "");
        #    "The internal code generated from the datamodel file was:\n$eval\n";
    }

    # Add each field to the class.
    my @UsedObjects = ();
    foreach my $name (@Fields) {
        my $info = $Fields{$name} || die "Internal error!\n"; #impossible
        my ($sah,$type,$comment) = @$info;
        $PerlClass->_AddField($name,$sah,$type,$comment);
        push(@UsedObjects,substr($type,1,length($type)-2)) if substr($type,0,1) eq "<";
    }

    print STDERR "DEBUG: Finished with file: $filename\n" if $DEBUG > 0;
    $main::INC{"$TagName.$MODELFILE_EXTENSION"}=$filename;

    ($TagName,$PerlClass,$InheritsFrom,@UsedObjects);
}

# This is a method internally called by the LoadDataModel() methods
# to add a field to a perl class (including dynamically building the
# code for the methods that provide access to the field). It could
# be used by a user to add a field to a data model later on, although
# such a use should be rare indeed.

sub _AddField {
    my $self = shift;
    my $class = ref($self) || $self;

    my $name     = shift || die "_AddField() needs a field name!\n";
    my $sah      = shift || die "_AddField() needs a structure  'single', 'array' or 'hash'!\n";
    my $type     = shift || die "_AddField() needs a type!\n";
    my $comment  = shift || "";

    print STDERR "DEBUG: AddField(): Class=$class\tName=$name\tSAH=$sah\tType=$type\tComment=$comment\n" if $DEBUG > 1;

    die "Error in _AddField(): Field name '$name' is not correct.\n"
        unless $name =~ m#^[a-zA-Z][\w\-]*$#;
    die "Error in _AddField(): Field name '$name' cannot have two underscores and/or dashes side by side.\n"
        if $name =~ m#[_\-][_\-]#;
    die "Error in _AddField(): Keyword '$sah' is not 'single', 'array' or 'hash'.\n"
        unless $sah  eq "single" or $sah  eq "array" or $sah eq "hash";
    die "Error in _AddField(): Type '$type' is not legal.\n"
        unless $type =~ m!
                        (int[1248]|string|<[a-zA-Z][a-zA-Z0-9_]*>)  # allowed types
                        !x;

    (my $subname = $name) =~ tr/-/_/;
    die "Error in _AddField(): Field name '$name' is a reserved method name! (Method name of PirObject?)\n"
    #    if $class->can($subname) || defined &{__PACKAGE__ . "::" . $subname};
        if defined &{__PACKAGE__ . "::" . $subname};
    die "Error in _AddField(): Field name '$name' conflicts with a reserved XML tag!\n"
        if $name =~ m#^(key|null|int[1248]|string)$#;
    die "Error in _AddField(): Field name '$name' conflicts with the tag\n" .
        "name of the object <$name> (defined in file \"$name.$MODELFILE_EXTENSION\").\n"
        if $XMLTagToPerlClass{$name};
    
    # Get the data structures from the class that store the
    # info about the fields.
    my $fields = $self->_InfoFields();
    my $order  = $self->_InfoFieldsOrder();
    my $ah     = $self->_InfoArrayHashFields();

    die "Error: _AddField: trying to add a field '$name' that already exists?\n"
        if $fields->{$name};  # TODO: support updating (with warnings?)
    
    # Store the definition for the field.
    my $hasobjects = substr($type,0,1) eq "<" ? substr($type,1,length($type)-2) : "";
    $fields->{$name} = [ $sah, $type, $comment, $hasobjects ];
    push(@$order,$name);
    $ah->{$name}="A" if $sah eq "array";
    $ah->{$name}="H" if $sah eq "hash";

    # Code that adds the new access methods
    my $eval = '
        package _C_L_A_S_S;
        sub _AUTO__S_U_B_N_A_M_E {
            my $self = shift;
            $self->{"_N_A_M_E"}=$_[0] if @_;
            $self->{"_N_A_M_E"};
        }
        sub _AUTOGET_get__S_U_B_N_A_M_E {
            my $self = shift;
            $self->{"_N_A_M_E"};
        }
        sub _AUTOSET_set__S_U_B_N_A_M_E {
            my $self = shift;
            $self->{"_N_A_M_E"}=$_[0];
        }
        ';

    # Make sure we do not override user's own methods.
    my $AUTO    = "";
    my $AUTOGET = "";
    my $AUTOSET = "";
    $AUTO       = "AUTO_" if defined &{$class . "::" . "$subname"};
    $AUTOGET    = "AUTO_" if defined &{$class . "::" . "get_$subname"};
    $AUTOSET    = "AUTO_" if defined &{$class . "::" . "set_$subname"};
    $eval =~ s/_AUTO_/$AUTO/g;
    $eval =~ s/_AUTOGET_/$AUTOGET/g;
    $eval =~ s/_AUTOSET_/$AUTOSET/g;

    # Substitude the package name and the field name
    $eval =~ s/_C_L_A_S_S/$class/g;
    $eval =~ s/_S_U_B_N_A_M_E/$subname/g;
    $eval =~ s/_N_A_M_E/$name/g;

    # Add the subroutines
    eval $eval;
    if ($@) {
        die "_AddField: Internal error adding access methods for field '$name'.\n" .
            "Error message: $@\n" .
            "Code to compile:\n$eval\n";
    }
}

# This allows a user to load a data model right from the line
# where the "use PirObject" statement is executed. E.g.
#     use PirObject qw( Person Address Book );
sub import {
    my $self = shift;
    my $class = ref($self) || $self;  # always an instance method anyway
    my @models = @_;
    foreach my $mod_to_load (@models) {
        $class->LoadDataModel($mod_to_load);
    }
}

############################################################################
# Internal methods to access bookkeeping data structures
############################################################################

sub _InfoFields {
    my $self = shift;
    my $class = ref($self) || $self;
    no strict;
    ${$class . "::"}{"Fields"} ||= {};
}

sub _InfoFieldsOrder {
    my $self = shift;
    my $class = ref($self) || $self;
    no strict;
    ${$class . "::"}{"FieldsOrder"} ||= [];
}

sub _InfoArrayHashFields {
    my $self = shift;
    my $class = ref($self) || $self;
    no strict;
    ${$class . "::"}{"ArrayHashFields"} ||= {};
}

############################################################################
# Methods commonly accessed by users
############################################################################

# This is the main object creator. It creates a blank
# data object. If arguments are given to the method, then
# the arguments are assumed to be assignments to fields
# of the object, to be performed right away. E.g.
# $obj = $class->new( id => 1, name => "pierre" );

sub new {
    my $self  = shift;
    my $class = ref($self) || $self;

    die "Error: new() is method that needs to be called on a subclass\n" .
        "       of " . __PACKAGE__ . ", not on " . __PACKAGE__ . " itself!\n"
        if $class eq __PACKAGE__;

    my $new   = {};
    bless($new,$class);
    
    my $ah  = $self->_InfoArrayHashFields();
    foreach my $field (keys %$ah) {
        my $what = $ah->{$field};
        $new->{$field} = [] if $what eq "A";
        $new->{$field} = {} if $what eq "H";
    }
    $new->SetMultipleFields(@_) if @_;
    $new;
}

# This method can be used to set multiple fields of
# an object in a single call. An even number of
# arguments must be given; even numbered args are
# field names, and odd numbered args are their
# corresponding values. E.g.
# $obj->SetMutipleFields( id => 1, name => "pierre" );

sub SetMultipleFields {
    my $self = shift;
    my $class = ref($self) || $self;
    my @args = @_;
    die "SetMultipleFields: odd number of elements for field/value pairs?!?\n"
        if (scalar(@args) & 1) == 1;
    my $Fields = $self->_InfoFields();
    while (@args) {
        my $field = shift @args;
        my $val   = shift @args;
        die "SetMultipleFields: Error: field '$field' is not defined for object.\n"
            unless $Fields->{$field};
        $self->{$field}=$val;
    }
    $self;
}

############################################################################
# Input/Output Section
############################################################################

sub ObjectToFile {
    my $self    = shift;
    my $filename= shift || die "ObjectToFile() needs a filename!\n";
    my $options = shift || "";

    my $class = ref($self)
        || die "ObjectToFile() must be called on an instance, not a class like '$self'.\n";

    my $fh = new IO::File ">$filename"
        or die "Can't write to filename '$filename': $!\n";

    $self->ObjectToXML($options,$fh);
}

sub FileToObject {
    my $self    = shift;
    my $filename= shift || die "FileToObject() needs a filename!\n";

    my $fh = new IO::File "<$filename"
        or die "Can't read from filename '$filename': $!\n";

    $self->FileHandleToObject($fh);
}

sub ObjectToFileHandle {
    my $self    = shift;
    my $fh      = shift || die "ObjectToFileHandle() needs a fh!\n";
    my $options = shift || "";

    my $class = ref($self)
        || die "ObjectToFileHandle() must be called on an instance, not a class like '$self'.\n";

    $self->ObjectToXML($options,$fh);
}

sub FileHandleToObject {
    my $self    = shift;
    my $fh      = shift || die "FileHandleToObject() needs a fh!\n";
    
    my $class = ref($self) || $self;

    my @objects = ();
    for (;;) {
        my ($tag,$line) = &_FindFirstTag($fh);
        last if ! defined $tag;
        my $XMLreaderSub = &_GenerateXMLReaderSub($tag); # it caches the code too
        my $txt = $line . &{$XMLreaderSub}($fh);
        my $objclass = $XMLTagToPerlClass{$tag}
            || die "Can't figure out which PerlClass handles XML tag <$tag> ?!? Maybe the datamodel has not been loaded?\n";
        my $obj = $objclass->XMLToObject(\ $txt, "ZAP" ); # ref is more efficient
        return $obj unless wantarray;
        push(@objects,$obj);
    }
    return @objects if wantarray; # can be empty
    return undef; # single objects are returned in loop above; here we have reached EOF in scalar ctx
}

# Internal use; reads lines from a filehandle until the
# first XML tag which (normally always) specifies the
# type of object we're trying to load. Note that it
# expects the tag to be near the beginning of the line,
# just like the XML dumper creates them here.
sub _FindFirstTag {
    my $fh = shift;
    my $tag = undef;
    for (;;) {
        my $line = <$fh>;
        return (undef,undef) unless defined $line;
        next if $line =~ m#^\s*$|^\s*<[!?]#;
        die "Unexpected XML line: $line"
            unless $line =~ m#^\s*<([\w\-]+)>#;
        $tag=$1;
        return ($tag,$line);
    }
}

# For efficiency, a custom input subroutine is compiled
# and cached the first time it is used; there is one such
# subroutine per data object. It reads until the XML end tag
# of the data object, e.g. </XYZ>.

sub _GenerateXMLReaderSub {
    my $tag = shift;
    return $XMLReaderSubCache{$tag} if $XMLReaderSubCache{$tag};
    my $subeval = '
        sub {    # the backslash create a ref to the sub!
            my $fh = shift;
            my @lines = ();
            for (;;) {
                my $line = <$fh>;
                last if ! defined $line;
                push(@lines,$line);
                last if $line =~ m#^\s*</T_A_G>#;
            }
            join("",@lines);
        }
    ';
    $subeval =~ s/T_A_G/$tag/;
    my $subref = eval $subeval;
    die "Error compiling subroutine to read XML objects <$tag>:\n$@\n===CODE:\n$subeval\n===\n"
        if $@;
    $XMLReaderSubCache{$tag} = $subref;
    $subref;
}

# Typically used to convert an object to its flat XML
# representation; if a filehandle $fh is supplied, the
# XML text is dumped to the filehandle as it is being
# created and nothing is returned. Otherwise, a single
# large string with the whole of the XML document is
# returned.
# The keyword "showempty" in the $option string causes the
# XML document to contain empty tags for undefined fields.
# The document has the same meaning, as far as PirObject
# is concerned, so it's just  an esthetic/debugging feature.
sub ObjectToXML {
    my $self    = shift;
    my $options = shift || "";  # not used yet
    my $fh      = shift || undef;  # optional, internal
    my $level   = shift || 0; # internal

    my $class = ref($self) ||
        die "Error: this method is an instance method, not a class method!\n";

    my $maintag = $PerlClassToXMLTag{$class}
       || die "Can't find XML Tag name registered for objects of class '$class' ?!?\n";

    my $fields = $class->_InfoFields();
    my $order  = $class->_InfoFieldsOrder();

    my $opt_showempty = ($options =~ /showempty/i);

    my $indent0 = "  " x $level;
    my $indent1 = $indent0 . "  ";
    my $indent2 = $indent0 . "    ";

    my $txt = ""; # where we store the XML text;

    $txt .= "$indent0<$maintag>\n";

    foreach my $field (@$order) {
        my $val = $self->{$field};
        my $info = $fields->{$field};
        my ($sah,$type,$desc,$hasobjects) = @$info;
        my $baretype = $hasobjects || $type;

        if ($sah eq "single") {
            if (! $hasobjects) {
                if (! defined $val) {
                    $txt .= "$indent1<$field/>\n" if $opt_showempty;
                    next;
                }
                $txt .= "$indent1<$field>". &_StringEncodeEntities($val) . "</$field>\n";
            } else {
                if (! defined $val) {
                    $txt .= "$indent1<$field struct=\"single\" type=\"$baretype\"/>\n" if $opt_showempty;
                    next;
                }
                $txt .= "$indent1<$field struct=\"single\" type=\"$baretype\">\n";
                $fh and print $fh $txt and $txt = "";
                $txt .= $val->ObjectToXML($options,$fh,$level+2);
                $txt .= "$indent1</$field>\n";
            }
            next;
        }

        if ($sah eq "array") {
            if (! defined($val) || @$val == 0) {
                $txt .= "$indent1<$field struct=\"array\" type=\"$baretype\"/>\n" if $opt_showempty;
                next;
            }
            $txt .= "$indent1<$field struct=\"array\" type=\"$baretype\">\n";
            foreach my $elem (@$val) {
                if (! defined $elem) {
                    $txt .= "$indent2<null/>\n";
                    next;
                }
                if (! $hasobjects) {
                    $txt .= "$indent2<$type>" . &_StringEncodeEntities($elem) . "</$type>\n";
                } else {
                    $fh and print $fh $txt and $txt = "";
                    $txt .= $elem->ObjectToXML($options,$fh,$level+2);
                }
            }
            $txt .= "$indent1</$field>\n";
            $fh and print $fh $txt and $txt = "";
            next;
        }

        if ($sah eq "hash") {
            if (! defined($val) || scalar(keys %$val) == 0) {
                $txt .= "$indent1<$field struct=\"hash\" type=\"$baretype\"/>\n" if $opt_showempty;
                next;
            }
            $txt .= "$indent1<$field struct=\"hash\" type=\"$baretype\">\n";
            foreach my $key (sort keys %$val) {
                my $elem = $val->{$key};
                $txt .= "$indent2<key>". &_StringEncodeEntities($key) . "</key>";
                if (!defined($elem)) {
                    $txt .= "\t<null/>\n";
                    next;
                }
                if (! $hasobjects) {
                    $txt .= "\t<$type>" . &_StringEncodeEntities($elem) . "</$type>\n";
                } else {
                    $txt .= "\n";
                    $fh and print $fh $txt and $txt = "";
                    $txt .= $elem->ObjectToXML($options,$fh,$level+2);
                }
            }
            $txt .= "$indent1</$field>\n";
            $fh and print $fh $txt and $txt = "";
            next;
        }

        die "Internal error: single/array/hash keyword is '$sah' ?!?\n";

    }

    $txt .= "$indent0</$maintag>\n";
    $fh and print $fh $txt and $txt = "";
    return $txt if !$fh;
    "";
}

sub ObjectXMLDocumentHeader {
    my $self = shift;
    my $dtd  = shift || "";
    my $class = ref($self) || $self;
    # funny, we'll make this work with both real objects and just the class.

    my $maintag = $PerlClassToXMLTag{$class}
       || die "Error: can't find which XML tag is associated with class '$class' ?!?\n";

    my $standalone = $dtd eq "standalone" ? "yes" : "no"; # special keyword

    my $headdtd = $dtd ? "SYSTEM \"$dtd\"" : "SYSTEM \"$maintag.dtd\"";
    $headdtd = "[\n\n" . $self->WholeModelDTD() . "\n\n]"
        if $standalone eq "yes";

    my $header =
       qq#<?xml version="1.0" encoding="UTF-8" standalone="$standalone"?>\n# .
       qq#<!DOCTYPE $maintag $headdtd>\n#;

    $header;
}

# This is the main entry point to the methods that convert
# a XML document stored in a single string back into
# an in-memory object. For efficiency reasons when parsing
# very large XMl documents, we suggest that you pass a REF
# to the XML string, and also provide the "ZAP" keyword
# in $options, which will zap the refered string back to
# undef (to free memory early before reconstruction starts).
sub XMLToObject {
    my $self    = shift;
    my $xml     = shift        # the string, or better, a ref to the string. Either works.
        || die "No XML text supplied?\n";
    my $options = shift || ""; # 'ZAP' saves memory when string passed as ref.

    my $class = ref($self) || $self;

    my $xmlref = ref($xml) ? $xml : \$xml;

    my @tokens = split(m#(<[^>]*>)#,$$xmlref);
    $$xml=undef if $options =~ /ZAP/;
    
    my $position = 0;
    $self->XMLTokenArrayToObject(\@tokens,\$position)
}

# Internal; parse the tokenized XML document.
sub XMLTokenArrayToObject {
    my $self    = shift;
    my $tokens  = shift; # array ref of all tokens
    my $posref  = shift;
    
    my $class = ref($self) || $self;
    my $maintag = $PerlClassToXMLTag{$class}
        || die "Error: can't figure out XML tag associated with class '$class' ?!?\n";
    my $fields = $self->_InfoFields();

    # Clear past tokens from memory. There is a reason why it's
    # worth it to do this.
    for (my $zap=$$posref-1;$zap >= 0; $zap--) {
        last if ! defined $tokens->[$zap];
        $tokens->[$zap]=undef;
    }

    $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
    $tokens->[$$posref++] eq "<$maintag>"
        or &FatalXML($tokens,$$posref,"Expected main tag <$maintag> of object");

    my $obj = $self->new();

    for (;;) {
        $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
        last if $tokens->[$$posref] eq "</$maintag>";
        $tokens->[$$posref++] =~ m#^<([\w\-]+)(?: struct="(\w+)" type="([\w\-]+)")?(/?)>$#
            or &FatalXML($tokens,$$posref-1,"Expected field tag of object <$maintag>");
        my ($field,$struct,$type,$empty) = ($1,$2,$3,$4);

        next if $empty;  # just ignore empty tags... this leaves no entry in the hash of the obj.

        my $info = $fields->{$field}
           || FatalXML($tokens,$$posref-1,"Can't find field definition for tag <$field> of object <$maintag>");
        my ($defstruct,$deftype,$hasobjects) = @$info[0,1,3];
        &FatalXML($tokens,$$posref-1,"Inconsistency between XML text and field definition of datamodel file.\n" .
                                    "Datamodel says: struct=$defstruct and type=$deftype")
            if ($struct && $struct ne $defstruct) || ($type && ($hasobjects ? $type ne $hasobjects : $type ne $deftype));

        if ($defstruct eq "single") {
            if (!$hasobjects) {
                $obj->{$field} = &_StringDecodeEntities($tokens->[$$posref++]);
                $tokens->[$$posref++] eq "</$field>"
                    or &FatalXML($tokens,$$posref,"Expected to find end tag (scalar field) </$field>")
             } else { # single subobject
                $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
                if ($tokens->[$$posref] eq "</$field>") { # empty array
                    $$posref++;
                    next;
                }
                $tokens->[$$posref++] =~ m#^<([\w\-]+)>$#
                    or &FatalXML($tokens,$$posref,"Expect tag for subobject for field <$field>");
                my $subtag = $1;
                next if $subtag eq "null";  # <null> is a for a null object. Not important here.
                my $subclass = $XMLTagToPerlClass{$subtag}
                    or FatalXML($tokens,$$posref, "Can't find class associated with subobject tag <$subtag>");
                $$posref--;
                my $subobject = $subclass->XMLTokenArrayToObject($tokens,$posref);
                $obj->{$field} = $subobject;
                $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
                $tokens->[$$posref++] eq "</$field>"
                    or &FatalXML($tokens,$$posref-1,"Expected to find end tag (single subobject) </$field>")
             }
             next;
        }

        if ($defstruct eq "array") {
            my $array = [];
            my $expect = $hasobjects ? "<$hasobjects>" : "<$deftype>";
            my $subclass = $XMLTagToPerlClass{$hasobjects}; # undef is OK if not an array of subobjects
            &FatalXML($tokens,$$posref,"Can't find subclass associated with expected tag <$hasobjects>?")
                if $hasobjects && ! defined $subclass;
            for (;;) {
                $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
                if ($tokens->[$$posref] eq "</$field>") {
                    $$posref++;
                    last;
                }
                if ($tokens->[$$posref] eq "<null/>") {
                    $$posref++;
                    push(@$array,undef);
                    next;
                }
                $tokens->[$$posref++] eq $expect
                    or &FatalXML($tokens,$$posref-1,"Expected array element tag $expect");
                if ($hasobjects) {
                    $$posref--;
                    my $subobj = $subclass->XMLTokenArrayToObject($tokens,$posref);
                    push(@$array,$subobj);
                    next;
                }
                push(@$array,&_StringDecodeEntities($tokens->[$$posref++]));
                $tokens->[$$posref++] eq "</$deftype>"
                    or &FatalXML($tokens,$$posref-1,"Expected array element end tag </$deftype>")
            }
            $obj->{$field}=$array;
            next;
        }

        if ($defstruct eq "hash") {
            my $hash = {};
            my $expect = $hasobjects ? "<$hasobjects>" : "<$deftype>";
            my $subclass = $XMLTagToPerlClass{$hasobjects}; # undef is OK if not a hash of subobjects
            &FatalXML($tokens,$$posref,"Can't find subclass associated with expected tag <$hasobjects>?")
                if $hasobjects && ! defined $subclass;
            for (;;) {
                $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
                if ($tokens->[$$posref] eq "</$field>") {
                    $$posref++;
                    last;
                }
                $tokens->[$$posref++] eq "<key>"
                    or &FatalXML($tokens,$$posref-1,"Expected hash tag <key>");
                my $key = &_StringDecodeEntities($tokens->[$$posref++]);
                $tokens->[$$posref++] eq "</key>"
                    or &FatalXML($tokens,$$posref-1,"Expected hash tag </key>");
                $$posref++ while $$posref < @$tokens && $tokens->[$$posref] =~ m#^\s*$|^<[!?]#;
                if ($tokens->[$$posref] eq "<null/>") {
                    $$posref++;
                    $hash->{$key}=undef;  # creates entry that EXISTS, at least.
                    next;
                }
                $tokens->[$$posref++] eq $expect
                    or &FatalXML($tokens,$$posref-1,"Expected hash value element tag $expect");
                if ($hasobjects) {
                    $$posref--;
                    my $subobj = $subclass->XMLTokenArrayToObject($tokens,$posref);
                    $hash->{$key}=$subobj;
                    next;
                }
                $hash->{$key}=&_StringDecodeEntities($tokens->[$$posref++]);
                $tokens->[$$posref++] eq "</$deftype>"
                    or &FatalXML($tokens,$$posref-1,"Expected hash value element end tag </$deftype>")
            }
            $obj->{$field}=$hash;
            next;
        }

        &FatalXML($tokens,$$posref,"Not supported yet");
    }
    $$posref++;

    $obj;
}

sub FatalXML { # not a method
    my $tokens = shift;
    my $pos    = shift;
    my $mess   = shift; # what a mess

    $mess =~ s/\s*$//;

    my @fifteen = ();
    my $cnt = 0;
    while ($pos > 0 && $pos < @$tokens && $cnt < 15) {  # show 15 tokens
        my $tok = $tokens->[$pos++];
        $cnt++;
        $tok = substr($tok,0,50) . "..." if length($tok) > 50;
        push(@fifteen,$tok);
    }
    my $prettyxml = join("",@fifteen);
    
    die "XML Parser error: $mess\nXML text:\n$prettyxml\n";
}

sub _StringEncodeEntities { # not a method
    my $string = shift;
    $string =~ s/&/&amp;/g;
    $string =~ s/</&lt;/g;
    $string =~ s/>/&gt;/g;
    $string;
}

sub _StringDecodeEntities { # not a method
    my $string = shift;
    $string =~ s/&gt;/>/g;
    $string =~ s/&lt;/</g;
    $string =~ s/&amp;/&/g;
    $string;
}

############################################################################
# Clone Methods Section
############################################################################

sub ShallowClone {
    my $self  = shift;
    my $class = ref($self) || die "Error: ShallowClone() is an instance method, not a class method.\n";

    my $clone = { %$self };
    bless($clone,$class);
    $clone;
}

sub DeepClone {
    my $self  = shift;
    my $class = ref($self) || die "Error: DeepClone() is an instance method, not a class method.\n";

    my $clone  = $self->ShallowClone();
    my $fields = $self->_InfoFields();
    my $ah     = $self->_InfoArrayHashFields();

    # Check each field
    foreach my $field (keys %$fields) {
        my $info = $fields->{$field}; # [ defstruct, deftype, comment, hasobjects ]
        my $hasobjects = $info->[3];
        my $what = $ah->{$field};  # undef, "A" or "H".
        next if ! exists  $clone->{$field};  # nothing to do, clone is already OK
        next if ! defined $clone->{$field};  # nothing to do, clone is already OK

        # Clone single subobjects
        if (!defined($what) && $hasobjects) {  # means the field is a single subobject
            $clone->{$field}=$clone->{$field}->DeepClone(); # wow
        }

        # Clone array fields
        if (defined($what) && $what eq "A") {
            my $array = $clone->{$field};
            if (! $hasobjects) {
                $clone->{$field} = [ @$array ];  # copies all elements
            } else {
                my $newarray = [];
                foreach my $elem (@$array) {
                    if (!defined($elem)) {
                        push(@$newarray,undef);
                    } else {
                        push(@$newarray,$elem->DeepClone());
                    }
                }
                $clone->{$field} = $newarray;
            }
        }

        # Clone hash fields
        if (defined($what) && $what eq "H") {
            my $hash = $clone->{$field};
            if (! $hasobjects) {
                $clone->{$field} = { %$hash };  # copies all keyvals
            } else {
                my $newhash = {};
                foreach my $key (keys %$hash) {
                    if (!defined($hash->{$key})) {
                        $newhash->{$key}=undef;  # makes sure key exists even if no value
                    } else {
                        $newhash->{$key}=$hash->{$key}->DeepClone();
                    }
                }
                $clone->{$field} = $newhash;
            }
        }

    }

    $clone;
}

############################################################################
# DTD Generation Section
############################################################################

sub LocalObjectDTD {
    my $self = shift;
    my $globelemlist = shift || {}; # internal helps WholeModelDTD() warn about inconsistencies

    my $class = ref($self) || $self;

    my $tag = $PerlClassToXMLTag{$class}
        || die "Can't figure out which tag corresponds to perl class '$class' ?!?\n";

    my $fields      = $class->_InfoFields();
    my $fieldsorder = $class->_InfoFieldsOrder();

    my $maxlen = 0; # used for formatted printing with sprintf
    $maxlen = length($_) > $maxlen ? length($_) : $maxlen foreach @$fieldsorder;

    my $numspaces = 60 - length($tag);
    my $numspaces1 = int($numspaces/2);
    my $numspaces2 = $numspaces - $numspaces1;
    my $dtd = "<!-- ************************************************************ -->\n" .
              "<!-- " . (" " x $numspaces1) . $tag . (" " x $numspaces2) . " -->\n" .
              "<!-- ************************************************************ -->\n\n";

    $dtd .= "<!ELEMENT $tag (\n";
    my $maxlenP1 = $maxlen+1; # used for formatted printing with sprintf
    for (my $i=0;$i<@$fieldsorder;$i++) {
        my $field = $fieldsorder->[$i];
        $dtd .= sprintf("    \%-${maxlenP1}s","$field?");
        $dtd .= " ," if $i < @$fieldsorder-1; # commas after each except the last
        $dtd .= "\n";
    }
    $dtd .= "    )>\n\n";

    my $att = "";
    my $elemlist = {};

    foreach my $field (@$fieldsorder) {
        my $info = $fields->{$field};
        my ($sah, $type, $comment, $hasobjects) = @$info;
        my $baretype = $hasobjects || $type;
        $comment =~ s/--+/- -/g;
        $comment = " <!-- $comment -->" if $comment ne "";
        if ($sah eq "single") {
            if ($hasobjects) {
                my $elemdtd = sprintf("<!ELEMENT \%-${maxlen}s ( \%s? )>",$field,$baretype);
                $elemlist->{$field} = $elemdtd;
                $elemdtd =~ s/!ELE/!-- / if $globelemlist->{$field};
                $elemdtd =~ s/>$/ -->/   if $globelemlist->{$field};
                $dtd .= "$elemdtd$comment\n";
                next if $globelemlist->{$field};
                $att .= sprintf("<!ATTLIST \%-${maxlen}s struct CDATA #FIXED \"single\"\n",$field);
                $att .= sprintf("          \%-${maxlen}s type   CDATA #FIXED \"\%s\">\n","",$baretype);
            } else {
                my $elemdtd = sprintf("<!ELEMENT \%-${maxlen}s ( #PCDATA )>",$field);
                $elemlist->{$field} = $elemdtd;
                $elemdtd =~ s/!ELE/!-- / if $globelemlist->{$field};
                $elemdtd =~ s/>$/ -->/   if $globelemlist->{$field};
                $dtd .= "$elemdtd$comment\n";
            }
            next;
        }
        if ($sah eq "array") {
            my $elemdtd = sprintf("<!ELEMENT \%-${maxlen}s ( (\%s | null)* )>",$field,$baretype);
            $elemlist->{$field} = $elemdtd;
            $elemdtd =~ s/!ELE/!-- / if $globelemlist->{$field};
            $elemdtd =~ s/>$/ -->/   if $globelemlist->{$field};
            $dtd .= "$elemdtd$comment\n";
            next if $globelemlist->{$field};
            $att .= sprintf("<!ATTLIST \%-${maxlen}s struct CDATA #FIXED \"array\"\n",$field);
            $att .= sprintf("          \%-${maxlen}s type   CDATA #FIXED \"\%s\">\n","",$baretype);
            next;
        }
        if ($sah eq "hash") {
            my $elemdtd = sprintf("<!ELEMENT \%-${maxlen}s ( (key , (\%s | null))* )>",$field,$baretype);
            $elemlist->{$field} = $elemdtd;
            $elemdtd =~ s/!ELE/!-- / if $globelemlist->{$field};
            $elemdtd =~ s/>$/ -->/   if $globelemlist->{$field};
            $dtd .= "$elemdtd$comment\n";
            next if $globelemlist->{$field};
            $att .= sprintf("<!ATTLIST \%-${maxlen}s struct CDATA #FIXED \"hash\"\n",$field);
            $att .= sprintf("          \%-${maxlen}s type   CDATA #FIXED \"\%s\">\n","",$baretype);
            next;
        }
    }

    &_ReportDTDInconsistencies($tag,$globelemlist,$elemlist);

    $dtd .= "\n" . $att if $att ne "";

    $dtd;
}

sub WholeModelDTD {
    my $self = shift;
    my $class = ref($self) || $self;

    my $tag = $PerlClassToXMLTag{$class}
        || die "Can't figure out which tag corresponds to perl class '$class' ?!?\n";

    my $globelemlist = {};

    my @dtd_to_gen = ( $tag );
    my %dtd_generated = ( );

    my $dtd = "";

    while (@dtd_to_gen) {
        my $todo = shift(@dtd_to_gen);  # name of object, e.g. "Person"
        next if $dtd_generated{$todo};
        my $todoclass = $XMLTagToPerlClass{$todo};
        $dtd .= "\n\n" if $dtd;
        $dtd .= $todoclass->LocalObjectDTD($globelemlist);
        my $fields      = $todoclass->_InfoFields();
        my $fieldsorder = $todoclass->_InfoFieldsOrder();
        $dtd_generated{$todo}=1;
        foreach my $field (@$fieldsorder) {
            my $info = $fields->{$field};
            my $hasobjects = $info->[3]; # will be object name if field has objects
            next unless $hasobjects;
            push(@dtd_to_gen,$hasobjects);
        }
    }

    $dtd .= ( "\n" . $self->ReservedElementsDTD() );

    $dtd;
}

sub ReservedElementsDTD {
    my $self = shift;
    my $class = ref($self) || $self;

    my $dtd = "<!-- ************************************************************ -->\n" .
              "<!--                       Reserved Tags                          -->\n" .
              "<!-- ************************************************************ -->\n\n" .
              "<!ELEMENT int1   ( #PCDATA )>\n" .
              "<!ELEMENT int2   ( #PCDATA )>\n" .
              "<!ELEMENT int4   ( #PCDATA )>\n" .
              "<!ELEMENT int8   ( #PCDATA )>\n" .
              "<!ELEMENT string ( #PCDATA )>\n" .
              "<!ELEMENT key    ( #PCDATA )>\n" .
              "<!ELEMENT null      EMPTY   >\n"
              ;
    $dtd;
}

sub _ReportDTDInconsistencies { # not a method
    my $localtag     = shift;
    my $globelemlist = shift;
    my $elemlist     = shift;

    foreach my $field (keys %$elemlist) {
        my $def = $elemlist->{$field};
        $def =~ s/\s+/ /g; # need to make sure spacing is not significant
        $globelemlist->{$field} ||= [];
        my $previnfo = $globelemlist->{$field};
        for (my $n=0;$n < @$previnfo;$n += 2) {
            my $otherobj = $previnfo->[$n];
            my $otherdef = $previnfo->[$n+1];
            next if $def eq $otherdef;
            warn "Warning: DTD definition for element <$field> of object <$localtag> conflicts with\n" .
                 "     the DTD definition for the same element of object <$otherobj>.\n";
        }
        push(@$previnfo, $localtag, $def );  # record it
    }

}


1;
