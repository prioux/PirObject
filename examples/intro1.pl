#!/usr/bin/perl

use strict;
use PirObject;

# Load the data model for the Book objects
PirObject->LoadDataModel("Book"); # will parse the file "Book.pir"

# Create a new object with a few data fields already
# filled in
my $book = new PirObject::Book (
   title    => "Pride And Prejudice",
   first    => "Jane",
   last     => "Austen",
   keywords => [ "drama", "romance", ],
);

# Set the value of a field
$book->set_year(1805);   # not sure of the real year btw!

# Get the value of a field
print "Title is: ", $book->get_title(), "\n";

# Save the object to a XML file
$book->ObjectToFile("pride.xml");

# Reload the object
my $reloaded_book = PirObject::Book->FileToObject("pride.xml");

# Dumps the DTD for the book object. Note
# that this can be done with the class or with a real object.
print "The DTD follows:\n", PirObject::Book->WholeModelDTD();

