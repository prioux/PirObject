#!/usr/bin/perl

# This example assume you've already run intro1.pl and
# intro2.pl to create the files pride.xml and pride2.xml.

# It will access the two files as a single stream but ignore
# completely all the XML tags outside the <Character> subobjects.
# This demonstrate a way to selectively process just a subset
# of the input data, using an intelligent input file handle.
# As far as this program is concerned, it only sees Character objects.

use IO::File;
use PirObject;

# We don't even load the Book definition!
PirObject->LoadDataModel("Character");

# Note that of course, there are NO Character objects in pride.xml,
# (all three are in pride2.xml) but the subprocess does not know that.
my $infh = new IO::File "cat pride*.xml | perl -ne 'print if m#^\\s*<Character># .. m#^\\s*</Character>#' |"
   or die "Can't open read pipe to filtering subprocesses: $!\n";

while (my $character = PirObject::Character->FileHandleToObject($infh)) {
    my $first = $character->get_first();
    my $last  = $character->get_last();
    my $role  = $character->get_role();
    print "Got this character: $first $last, who plays the role of $role\n";
}

$infh-close();
