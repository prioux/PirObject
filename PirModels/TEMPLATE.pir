#
# Prototype template for "PirObject" data objects descriptions.
#

# This file is called TEMPLATE.pir and provides the
# description for a sample object which has a XML
# main tag <TEMPLATE>; the name of the file (without
# the .pir extension) is what is used to select the name
# of the XML tag.

# Blank lines and lines beginning with a "#" are ignored.

# The format of this file is strict; there are sections that
# start with a "-" and a keyword, and they are expected to be
# found in the order shown here. More information about this
# file can be found in the file ProgrammingGuide.txt, in
# the section "The Data Object Definition File".



# ---- PerlClass ----
#
# The PerlClass is the name of the perl namespace that
# will be associated with the object. Typically, it has to
# be a subclass of PirObject::, as handled by PirObject.pm,
# and for consistency we suggest you call it the same as
# this file. You are free to build a class hierarchy as
# deep as you want.

- PerlClass	PirObject::TEMPLATE



# ---- InheritsFrom ----
#
# This is the name of an OPTIONAL superclass of the current
# object. When specified, it's the name of another PirObject 
# file: a .pir file other than the current one. The perlclass
# that handles the current object will become a subclass of the
# PerlClass specified in that other object file description.
# It will also automatically be configured to get a copy of
# all the fields specified in the FieldsTable of the other
# object description, to which the FieldsTable of the current
# file (just below) will be appended. See the documentation
# for an explanation on when this can be a useful thing to do.
# Typically, for simple data containers, there is NO NEED to
# specify anything in InheritsFrom, so the field can be left
# blank or the special placeholder keyword "PirObject" left
# there (it's the default, it means the same as a blank entry).

- InheritsFrom	PirObject



# ---- FieldsTable ----
#
# This is the list of data fields the object will contain.
# It's a table with four columns, separated by white spaces.
# Note that if InheritsFrom is set to something other than
# the default, above, then the object will contain other
# fields inserted BEFORE the fields in this list.

- FieldsTable

# Field name		Sing/Array/Hash	Type		Comments
#---------------------- ---------------	---------------	-----------------------
#name			single		string		A single string
#age			single		int4		A single number
#pet_names		array		string		An array of strings
#pet_ages		array	        int4		An array of numbers
#address		single          <Address>	A single subobject, found in Address.pir
#previous_addresses	array		<Address>	An array of subobjects

- EndFieldsTable



# ---- Methods ----
#
# You can insert arbitrary perl code here, but usually this is
# a place where you should insert only method definitions (subroutines)
# that will be added to the perl namespace identified above
# in section "PerlClass". You can override methods created automatically
# by PirObject.pm (e.g. methods created to access the fields
# of the object). In that case, the original automatic method can
# still be accessed as AUTO_{method_name} (e.g. if you override
# get_last() like in the example below, the original get_last()
# that was supposed to be created for you can be called as
# AUTO_get_last()).

- Methods

# (Commented out, this is just an example)
# # Override the default method: calls the original one unchanged.
# sub get_last {
#     my $self = shift;
#     $self->AUTO_get_last();
# }

