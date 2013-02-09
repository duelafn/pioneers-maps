package Pioneers::Map;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09

use Pioneers::Types;
use Pioneers::Map::LandHex;
use Pioneers::Map::SeaHex;

=pod

=head1 NAME

Pioneers::Map - Pioneers Map Object

=head1 SYNOPSIS

 use strict;
 use Pioneers::Map;

=head1 DESCRIPTION

=head1 USAGE

=cut

has hex_map => (
    is         => 'rw',
    isa        => 'ArrayRef[ArrayRef[Maybe[Pioneers::Map::Hex]]]',
    default    => sub { [] },
);

method hexes() {
    return map @$_, @{$self->hex_map};
}

method nr_chits() {
    return scalar grep +($_ && $_->consumes_chit), map @$_, @{$self->hex_map};
}



has _chit_index => (
    is         => 'rw',
    isa        => 'Int',
    traits     => ['Counter'],
    default    => -1,
    handles    => {
        _reset_chit_index => "reset",
        _step_chit_index  => "inc",
    },
);

method to_map_string() {
    my $str = "map\n";
    for my $row (@{$self->hex_map}) {
        $str .= join ",", map +($_ ? $_->to_map_string($self) : '-'), @$row;
        $str .= "\n";
    }
    $str .= ".";
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
