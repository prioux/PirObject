#!/usr/bin/perl

use strict;
use PirObject;

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
