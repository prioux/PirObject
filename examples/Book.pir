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
