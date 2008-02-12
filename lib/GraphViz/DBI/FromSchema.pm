package GraphViz::DBI::FromSchema;

=head1 NAME

GraphViz::DBI::FromSchema - Create a diagram of database tables, using the
foreign key information in the schema

=head1 SYNOPSIS

  use DBI;
  use GraphViz::DBI::FromSchema;

  my $db = DBI->connect(@dsn_etc);

  my $filename = 'DB_diagram.ps';
  open my $file, '>', $filename or die "Opening $filename failed: $!\n";
  print $file GraphViz::DBI::FromSchema->new($db)->graph_tables->as_ps;

=cut


use warnings;
use strict;


use base qw<GraphViz::DBI>;

our $VERSION = 0.01;


=head1 DESCRIPTION

This module creates a diagram of the tables in a database, listing the fields
in each table and with arrows indicating foreign keys between tables.

L<GraphViz::DBI> provides functionality for doing this.  By default it
identifies foreign keys based on fields being named in a particular way, and
suggests subclassing it to implement different heuristics.  This module is a
subclass which uses the L<DBI> to interrogate the database about the foreign
keys defined for each table -- which, for databases which support referential
integrity, should work irrespective of your naming scheme.

The interface is identical to L<GraphViz::DBI>'s, so see its documentation for
details.

=cut


sub is_foreign_key {
  my ($self, $table, $field) = @_;

  # Grab all the foreign keys for this table (unless we've already done so):
  unless ($self->{foreign_key}{$table})
  {
    my $keys_query = $self->get_dbh->foreign_key_info(undef, undef, undef,
        undef, undef, $table);
    while (local $_ = $keys_query->fetchrow_hashref)
    {

      # foreign_key_info should just return foreign keys(!), but with MySQL it
      # seems also to include all primary and unique keys; skip these by only
      # saving keys which are actually pointing to a table:
      $self->{foreign_key}{$table}{$_->{FKCOLUMN_NAME}} = $_->{PKTABLE_NAME}
          if $_->{PKTABLE_NAME};
    }
  }

  $self->{foreign_key}{$table}{$field};
}


=head2 Printing Large Diagrams

For reasonably sized databases, the diagrams generated by this module can be
too large to fit on to paper that fits in your printer.  Unix has a C<poster>
command which can help with this, splitting a large diagram up into 'tiles'
printed on separate sheets, complete with crop marks for trimming and
assembling into a giant poster.  Sample usage:

  $ poster -m A4 -s 0.45 DB_diagram_big.ps > DB_diagram_A4.ps

=head2 Fixing Table Names

The table names retrieved by C<GraphViz::DBI> appear to suffer from a couple of
problems:

=over 2

=item *

They are prefixed by the database name (and a dot).

=item *

They are surrounded by the appropriate quote marks used for identifiers in that
sort of database.  There are several reports of this in the C<GraphViz::DBI> RT
queue.

=back

Both of these get in the way of matching up foreign keys with the tables they
reference, so this module overrides fetching the list of table names to remove
them.

=cut


sub get_tables
{
  my ($self) = @_;

  $self->{tables} ||= [map
  {
    s/ .* \. //x;
    tr/`//d; # XXX
    $_;
  } $self->SUPER::get_tables];

  @{$self->{tables}};
}

=head1 FUTURE PLANS

In the common case where you have a C<DBI> object and you want a diagram (like
in the L</SYNOPSIS>) it's irritating to have deal with the
C<GraphViz::DBI::FromSchema> object, which is really an implementation detail.
So it may be worth creating a functional interface to hide this.

It may further make sense to have a function which saves the diagram to a file
as well, since that's likely to be what people want to do with it.

=head1 CAVEATS

This has been developed using MySQL.  There isn't anything MySQL-specific in
it, and it should work with other database software, but that hasn't been
tried.  The only thing required is that the C<DBI> driver implements the
L<foreign_key_info|DBI/foreign_key_info> method.

The L<table-name 'fixing'|/Fixing Table Names> described above may be a bad
idea, or not work in some circumstances.  Arguably this should be done in
C<GraphViz::DBI> rather than here.

This module is lacking substantive tests, because of the difficulty of
automatically testing something which needs a database and generates graphical
output.  Suggestions on what to do about this welcome.

=head1 SEE ALSO

=over 2

=item *

L<GraphViz::DBI>, which provides most of the functionality

=back

=head1 CREDITS

Written by Ovid and Smylers at Pipex Communications UK Ltd trading as Donhost,
L<http://www.donhost.co.uk>.

Maintained by Smylers <smylers@cpan.org>

Thanks to Marcel GrE<uuml>nauer for writing C<GraphViz::DBI>.

=head1 COPYRIGHT & LICENCE

Copyright 2007-2008 by Pipex Communications UK Ltd

This library is software libre; you may redistribute it and modify it under the
terms of any of these licences:

=over 2

=item *

L<The GNU General Public License, version 2|perlgpl>

=item *

The GNU General Public License, version 3

=item *

L<The Artistic License|perlartistic>

=item *

The Artistic License 2.0

=back

=cut


1;
