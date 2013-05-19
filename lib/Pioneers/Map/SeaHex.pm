package Pioneers::Map::SeaHex;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09

extends 'Pioneers::Map::Hex';

=pod

=head1 NAME

Pioneers::Map::SeaHex - Pioneers SeaHex object

=head1 SYNOPSIS

 use strict;
 use Pioneers::Map::SeaHex;

=head1 DESCRIPTION

=head1 USAGE

=over 4

=item type

Hex type (default "s")

=item pin

Pinning. Has no effect, but is default true for classification purposes.

=item port

One of the port symbols (?, g, o, l, b, w)

=item port_orientation

Orientation: 0..5 where 0 puts port pointing east (usable by the eastern
hex), then proceeds counter-clockwise.

=back

=cut

has "+type" => (
    isa        => 'Pioneers::Types::SeaHexType',
    default    => "s",
);

has "+pin" => (
    default    => 1,
);

has port => (
    is         => 'rw',
    isa        => 'Pioneers::Types::PortType',
    predicate  => 'has_port',
    clearer    => 'remove_port',
);

has port_orientation => (
    is         => 'rw',
    isa        => 'Pioneers::Types::PortOrientation',
    default    => 0,
);




method to_map_string() {
    my $str = "s";
    $str .= $self->port() . $self->port_orientation() if $self->has_port;
    return $str;
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
