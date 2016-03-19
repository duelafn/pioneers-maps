package Pioneers::Map;
use Moose;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 3.0011;# Created: 2013-02-09

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

method get_hex($i, $j) {
    my $a = $self->hex_map;
    return unless $#{$a} >= $i;
    return unless $#{$$a[$i]} >= $j;
    return $$a[$i][$j];
}

has config => (
    is         => 'rw',
    isa        => 'Pioneers::Config',
    predicate  => 'has_config',
    weak_ref   => 1,
);

method hexes() {
    return map @$_, @{$self->hex_map};
}

method nr_chits() {
    return scalar grep +($_ && $_->has_prop("consume_chit")), map @$_, @{$self->hex_map};
}


=head3 layout

0 or 1 depending on whether the layout is "Even" or "Odd" as defined at
http://www.redblobgames.com/grids/hexagons/. Namely:

Layout is 0 if the first hex of row 2 is the south-west neighbor of the
first hex of row 1,

Layout is 1 if the first hex of row 2 is the south-east neighbor of the
first hex of row 1,

The layout can be guessed from the hex_map.

=cut

has layout => (
    is         => 'rw',
    isa        => 'Int',
    lazy_build => 1,
);

sub _build_layout {
    my $self = shift;
    my $hmap = $self->hex_map;
    return @{$$hmap[0]} < @{$$hmap[1]} ? 0 : 1;
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
location to the callback: C<callback($hex, $i, $j)>. Applies callback to
hexes in the same order as they will be assigned by pioneers (matters if
you are managing the hex chits).

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

 $map->randomize_hexes(\%opt, @props);
 $map->randomize_hexes(@props);

Shuffles hexes which match ANY of the given properties.

 $map->randomize_hexes("resource");   # just 5 basic resources
 $map->randomize_hexes("production"); # resource or gold
 $map->randomize_hexes("land");       # include deserts
 $map->randomize_hexes("hex");        # ALL

=over 4

=item keep_sea_border

If true, any sea hexes adjacent to the edge or a table-top space will not
be moved. This preserves a border of sea if present.

=item allow_adjacent_goldmines

If true, will not check that no gold mines are adjacent.

=cut

method randomize_hexes(@props) {
    my $opt = (@props and 'HASH' eq ref($props[0])) ? shift @props : { };
    my $map = $self->hex_map;
    while (1) {
        my (@loc, @hex);
        $self->apply(sub {
            my ($hex, $i, $j) = @_;
            return if $$opt{keep_sea_border} and 's' eq $hex->type and 6 != grep { $_->[2] } $self->neighbors($i, $j);
            return unless $hex and $hex->has_any_props(@props);
            push @loc, [$i,$j];
            push @hex, $hex;
        });

        @loc = shuffle(@loc);
        for my $idx (0..$#loc) {
            my ($i, $j) = @{$loc[$idx]};
            $$map[$i][$j] = $hex[$idx];
        }

        my $all_ok = 1;
        unless ($$opt{allow_adjacent_goldmines}) {
            for my $idx (0..$#loc) {
                next unless $hex[$idx] and 'g' eq $hex[$idx]->type;
                my ($i, $j) = @{$loc[$idx]};
                $all_ok = 0 if grep { 'g' eq $$_[2]->type } $self->neighbors( $i, $j );
            }
        }

        return if $all_ok;
    }
}


=head3 randomize_ports

 $map->randomize_ports(\%opt);

Randomize ports, possibly moving them to different hexes. Ensures that
ports end up on water and point toward land.

=over 4

=item allow_crossings

When true, the "legs" of a port will be allowed to straddle a water hex as
long as each leg still touches a land.

=item allow_adjacent

When true, ports will be allowed to be adjacent to each other. Otherwise,
ports will never be adjacent which spreads them out a bit and also ensures
that no vertex will be able to make use of two ports simultaneously.

=back

=cut

method randomize_ports($opt) {
    $opt ||= {};
    my (@type, @hex);

    # Get all water hexes and all ports used.
    $self->apply(sub {
        my ($hex, @ij) = @_;
        return unless $hex and "s" eq $hex->type;
        push @hex, \@ij;
        return unless $hex->has_port;
        push @type, $hex->port;
        $hex->remove_port;
    });

    my @_type = shuffle(@type);
    my @_hex  = shuffle(@hex);

  HEX:
    while (@_type and @_hex) {
        my $pos = shift @_hex;
        # Looking for directions we can point so that both legs of the port
        # are touching land. For each direction, if there is actually a
        # land in that direction then all is well, both legs of the port
        # will be on land. However, if we are allow crossings, we need BOTH
        # adjacent hexes to be populated. Luckily, we can just have each
        # adjacent cound for 1 and the middle count for 2 and any direction
        # with a total of 2 or more counts will have the connections we
        # need (either the center or both sides -- or all three, of course).
        my %ok;
        for my $dir (0..5) {
            my $hex = $self->neighbor(@$pos, $dir);
            next unless $hex;
            next HEX if $hex->has_prop("sea") and $hex->port and not $$opt{allow_adjacent};
            next unless $hex->has_prop("land");
            $ok{$dir} += 2;
            next unless $$opt{allow_crossings};
            $ok{($dir + 1) % 6} += 1;
            $ok{($dir - 1) % 6} += 1;
        }

        my @ok = grep $ok{$_} > 1, keys %ok;
        redo unless @ok;
        my $hex = $self->get_hex(@$pos);
        $hex->port(shift @_type);
        $hex->port_orientation((shuffle(@ok))[0]);
    }

    warn "Failed to position all ports, some were lost\n" if @_type;
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


=head3 neighbor

 my ($i, $j, $hex) = $map->neighbor( $i, $j, $direction );

Returns the coordinates of the neighbor in the requested direction.
C<$direction> should be one of the following strings or numbers: e (0), ne
(1), nw (2), w (3), sw (4), se (5)

Returns an empty list if traveling in the requested direction takes you off
the edge of the map. However, C<(i, j, undef)> will be returned if the
requested direction is within the bounds of the map but is a point on the
table (thus stepping in that direction again may yield a valid hex).

Note: Oddness may occur if the hex map has any improperly short rows.

=cut

method neighbor($i, $j, $dir) {
    # the change in j (when going n or s) depends on layout and row parity.
    # If layout == row parity: the neighboring hexes are in same and right column of ourselves
    # If layout != row parity: the neighboring hexes are in same and left  column of ourselves
    state $DJ = [ [0, 1], [-1, 0] ];
    state $dir_map = {
        0 =>  "e",
        1 => "ne",
        2 => "nw",
        3 =>  "w",
        4 => "sw",
        5 => "se",
    };
    $dir = $$dir_map{$dir} if exists $$dir_map{$dir};

    my ($i1, $j1);

    # nw, ne, sw, se  (disregarding bad input)
    if (2 == length($dir)) {
        my $di = ($dir =~ /n/ ? -1 : 1);
        my $dj = $$DJ[($self->layout + $i) % 2][$dir =~ /w/ ? 0 : 1];
        ($i1, $j1) = ($i + $di, $j + $dj);
    }

    elsif ($dir eq 'w') {
        ($i1, $j1) = ($i, $j-1);
    }

    elsif ($dir eq 'e') {
        ($i1, $j1) = ($i, $j+1);
    }

    else { die }

    return if $i1 < 0 or $j1 < 0;
    my $hmap = $self->hex_map;
    return if $i1 > $#{$hmap};
    return if $j1 > $#{$$hmap[$i1]};
    return ($i1, $j1, $$hmap[$i1][$j1]);
}


=head3 neighbors

 my @neighbors = $map->neighbors( $i, $j );

Returns a lit of arrayrefs [ $i, $j, $hex ], one for each valid neighbor of
the given position (see L<neighbor> for definition of valid and
limitations).

=cut

method neighbors($i, $j) {
    # As with "neighbor", the changes in j (when going n or s) depend on
    # layout and row parity.
    state $DJ = [ [0, 1], [-1, 0] ];
    # _Could_ call neighbor a bunch of times, but what's the fun in that?

    my $hmap = $self->hex_map;

    my $djs = $$DJ[($self->layout + $i) % 2];
    my @n;
    for my $p ([$i-1, $j+$$djs[0]], [$i-1, $j+$$djs[1]],
               [$i,   $j-1],        [$i,   $j+1],
               [$i+1, $j+$$djs[0]], [$i+1, $j+$$djs[1]],
           ) {
        next if $$p[0] < 0 or $$p[1] < 0;
        next if $$p[0] > $#{$hmap} or $$p[1] > $#{$$hmap[$$p[0]]};
        $$p[2] = $$hmap[$$p[0]][$$p[1]];
        push @n, $p;
    }

    return @n;
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
