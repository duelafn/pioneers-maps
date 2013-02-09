package Pioneers::Util;
use strict; use warnings; use re 'taint';
our $VERSION = 0.0000;# Created: 2013-02-09
require Moose::Meta::TypeConstraint;

use parent "Exporter";
our %EXPORT_TAGS = (
    hash => [qw/ subhash /],
);
our @EXPORT_OK = map @$_, values %EXPORT_TAGS;
$EXPORT_TAGS{all} = \@EXPORT_OK;


=pod

=head1 NAME

Pioneers::Util - Utilities for Pioneers modules

=head1 USAGE

=head3 subhash

 my %shallow = subhash( \%orig, @keys );

Extract keys from a hash. Similar to:

 @shallow{@keys} = @orig{@keys};

But does not auto-vivify when key does not B<exist> in %orig (and does not
create key in %shallow).

=cut

#BEGIN: subhash
sub subhash {
  my $h = shift;
  map { exists($$h{$_}) ? ($_, $$h{$_}) : () } @_;
}
#END: subhash




1;

__END__

=head1 AUTHOR

 Dean Serenevy
 dean@serenevy.net
 http://dean.serenevy.net/

=head1 COPYRIGHT

This module is Copyright (c) 2013 Dean Serenevy. All rights reserved.

You may distribute under the terms of either the GNU General Public License
or the Artistic License, as specified in the Perl README file.
