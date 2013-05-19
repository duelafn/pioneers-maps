package Pioneers::Map::Hex;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09

use Pioneers::Types;

=pod

=head1 NAME

Pioneers::Map::Hex - Pioneers Hex object

=head1 SYNOPSIS

 use strict;
 use Pioneers::Map::Hex;

=head1 DESCRIPTION

=head1 USAGE

=over 4

=item type

Hex symbol (p, m, f, h, t, d, g, s)

=item pin

If true, the land hex will not be randomized even if "randomize terrain" is
selected.

=item map

A reference to a map object containing the hex.

=back

=cut

has type => (
    is         => 'rw',
    required   => 1,
);

has pin => (
    is         => 'rw',
    isa        => 'Bool',
);

has map => (
    is         => 'rw',
    isa        => 'Pioneers::Map',
);


=head3 has_prop

=head3 has_all_props

=head3 has_any_props

Check whether the hex has the given properties (land, resource, production,
... see Pioneers::Types for the complete list).

=cut

my $info = $Pioneers::Types::TYPE_INFO{by_symbol};
method has_prop($prop) {
    $$info{$self->type}{properties}{$prop} ? 1 : 0;
}

method has_all_props(@prop) {
    my $symbol = $self->type;
    for my $prop (@prop) {
        return 0 unless $$info{$symbol}{properties}{$prop};
    }
    return 1;
}

method has_any_props(@prop) {
    my $symbol = $self->type;
    for my $prop (@prop) {
        return 1 if $$info{$symbol}{properties}{$prop};
    }
    return 0;
}








no Moose;
__PACKAGE__->meta->make_immutable;

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
