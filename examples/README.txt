============================
Running The Example Programs
============================

This document explains how to run the four example programs supplied
with the PirObject distribution.



Prerequisites:

    1- The file PirObject.pm should already be installed
       some place where the perl executable can find it.
       See the INSTALLATION.txt manual for more info. However,
       for a VERY quick test of the examples, you can simply
       copy PirObject.pm right into the examples subdirectory.

    2- Change your current directory to the examples subdirectory.
       The subdirectory not only contains the perl code for the
       three examples (the three .pl files) but it also contains
       two object definition files (the .pir files) that will be
       accessed by these scripts. Since "." is a default search
       directory used by PirObject for the object definition file,
       running the sample scripts from here will allow them to
       find the .pir files.



Running the examples:

     1- Run the first example:

           perl intro1.pl

       This should produce the two lines

          Title is: Pride And Prejudice
          The DTD follows:

       followed by a bunch of XML lines (the DTD of the book object).
       The script will also create the file "pride.xml" in the current
       directory.

     2- Run the second example:

            perl intro2.pl

        This one doesn't produce ANY output at all, but it does
        create a file called "pride2.xml". Have a look.

     3- Run the third example:

            perl get_characters.pl

        This script should produce only three lines of output:
  
            Got this character: Elizabeth Bennet, who plays the role of Heroine
            Got this character: Jane Bennet, who plays the role of Sister of Elizabeth
            Got this character: Mister Collins, who plays the role of Idiot

     4- Run the fourth example:

            perl intro2Internal.pl

        This script does exactly the same as intro2.pl, but it demonstrates
        how to package a data model INSIDE the perl program itself, instead
        of using external .pir files. "intro2.pl" required "Book.pir" and
        "Character.pir" to be in the current directory, but
        "intro2Internal.pl" does not (it contains the two files embedded
        as strings).


Final notes:

Of course, since PirObject is a programming module, the whole point
of the examples is not to just run them, but to actually LOOK at
the sample code. They are relatively well documented, so have a
look.
