package Pioneers::Map;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09

use Pioneers::Types;
use Pioneers::Map::LandHex;
use Pioneers::Map::SeaHex;

use List::Util qw/ shuffle /;

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
);

method hexes() {
    return map @$_, @{$self->hex_map};
}

method nr_chits() {
    return scalar grep +($_ && $_->has_prop("consume_chit")), map @$_, @{$self->hex_map};
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

=head3 apply

 $map->apply(sub { ... });

Executes the subroutine for each hex in the map. Passes the hex and its
location to the callback: callback($hex, $i, $j)

=cut

method apply($cb) {
    my $map = $self->hex_map;
    for my $i (0..$#{$map}) {
        for my $j (0..$#{$$map[$i]}) {
            local $_ = $$map[$i][$j];
            next unless $_;
            $cb->($_, $i, $j);
        }
    }
}


=head3 randomize_hexes

 $map->randomize_hexes(@props);

Shuffles hexes which match ANY of the given properties.

 $map->randomize_hexes("resource");   # just 5 basic resources
 $map->randomize_hexes("production"); # resource or gold
 $map->randomize_hexes("land");       # include deserts
 $map->randomize_hexes("hex");        # ALL

=cut

method randomize_hexes(@props) {
    my $map = $self->hex_map;
    my (@loc, @hex);
    $self->apply(sub {
        my ($hex, $i, $j) = @_;
        return unless $hex and $hex->has_any_props(@props);
        push @loc, [$i,$j];
        push @hex, $hex;
    });

    @loc = shuffle(@loc);
    for my $idx (0..$#loc) {
        my ($i, $j) = @{$loc[$idx]};
        $$map[$i][$j] = $hex[$idx];
    }
}

=head3 shuffle_ports

 $map->shuffle_ports;

Shuffles ports (shuffles types without moving any ports or changing their
orientation.

=cut

method shuffle_ports() {
    my (@type, @hex);
    $self->apply(sub {
        my ($hex, $i, $j) = @_;
        return unless $hex and "s" eq $hex->type and $hex->has_port;
        push @type, $hex->port;
        push @hex, $hex;
    });

    @type = shuffle(@type);
    for my $idx (0..$#type) {
        $hex[$idx]->port($type[$idx]);
    }
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
