#!/usr/bin/perl

use strict;
use PirObject;

# This example does the SAME thing as "intro2.pl", except that
# it uses no external object definition files. The content
# of Book.pir and Character.pir are stored internally right
# here in this file, in the DATA section of the perl script,
# and put in a hash table that is provided as a fake
# search directory to DataModelPath(). The following piece
# of code contains all the perl statements that are new in this
# example: it implements the steps necessary to setup the fake
# search directory and configure PirObject to search it.

my %DIRECTORY_AS_HASH = ();  # Where we store two .pir files with their contents.
my $filename = "notsetyet";
while (my $line = <DATA>) {
    if ($line =~ m#^%%% (\S+)#) {   # Multiple files separated by "%%% filename"; see bottom of script.
        $filename = $1;
        next;
    }
    $DIRECTORY_AS_HASH{$filename} .= $line; # just append
}
# Next line is how we say to search the hash instead of a real directory.
PirObject->DataModelPath( \ %DIRECTORY_AS_HASH );




# AT THIS POINT, we resume with the exact same code as
# in "intro2.pl".

# Will load BOTH Book.pir and Character.pir!
PirObject->LoadDataModel("Book");

# Reload an object from a XML file... this file was created
# by the previous example script, intro1.pl.
my $book = PirObject::Book->FileToObject("pride.xml"); # from prev example

# Create three new PirObject::Character objects.
my $ebennet = new PirObject::Character (
    first => "Ilizabeth",   # misspelled on purpose
    last  => "Bennet",
    role  => "Heroine",   # not the drug!
);
my $jbennet = new PirObject::Character (
    first => "Jane",
    last  => "Bennet",
    role  => "Sister of Elizabeth",
);
my $collins = new PirObject::Character (
    first => "Mister",  # well, not really a first name...
    last  => "Collins",
    role  => "Idiot",
);

# Set a data field that happens to contain a single subobject
$book->set_maincharacter($ebennet);  # a single Char object

# Create an anonymous array of two Character objects
my $others = [ $jbennet, $collins, ];

# Set a data field that happens to be an array of subobjects
$book->set_othercharacters($others); # the array of two Char objects

# An example of access throught the data structure to
# get to an element deep in it. Normally, a programmer
# would not really do in this way, in case the top-level
# Character object is not defined.
$book->get_maincharacter()->set_first("Elizabeth"); # fix spelling

# Save the object. Have a look, and compare it to "pride.xml" !
$book->ObjectToFile("pride2.xml");


__END__
%%% Book.pir
# The example data object shown in the Introduction section
# of the file PirObjectManual.txt

- PerlClass     PirObject::Book

- InheritsFrom  PirObject

- FieldsTable

# Field name            Sing/Mult       Type            Comments
#---------------------- --------------- --------------- -----------------------
first                   single          string          Author's first name
last                    single          string          Author's last name
title                   single          string          Book title
year                    single          int4            Year of publication
keywords                array           string          List of keywords
maincharacter           single          <Character>     The main character
othercharacters         array           <Character>     Any other characters

- EndFieldsTable

- Methods

# None.
%%% Character.pir
# Another example data object shown in the documentation.

- PerlClass     PirObject::Character

- InheritsFrom  PirObject

- FieldsTable

# Field name            Sing/Mult       Type            Comments
#---------------------- --------------- --------------- -----------------------
first                   single          string          Character's first name
last                    single          string          Character's last name
role                    single          string          Character's role in book

- EndFieldsTable

- Methods

# None.
