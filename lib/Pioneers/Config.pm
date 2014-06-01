package Pioneers::Config;
use Carp;
use Moose;
use MooseX::UndefTolerant;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 1.0309;# Created: 2013-02-09
use Pioneers::Util qw/ subhash /;
use Pioneers::Types;
use Pioneers::Map;
use Pioneers::Config::Parser;

use MooseX::Types::Moose qw/ Str Bool ArrayRef /;
use MooseX::Types::Common::Numeric qw/ PositiveInt PositiveOrZeroInt /;

=pod

=head1 NAME

Pioneers::Config - Pioneers Config File

=head1 SYNOPSIS

 use strict;
 use Pioneers::Config;

=head1 DESCRIPTION

=head1 USAGE

=cut

our %parameters = (
    'title'                        => { isa => Str, required => 1 },
    'variant'                      => { isa => Str }, # Not used
    'desc'                         => { isa => Str },

    'num-players'                  => { isa => PositiveInt, required => 1 },
    'victory-points'               => { isa => PositiveInt, required => 1 },
    'sevens-rule'                  => { isa => "Pioneers::Types::SevensRule", default => 1 },
    'island-discovery-bonus'       => { isa => ArrayRef[PositiveOrZeroInt], parse_as => "ArrayOfNonNegInt" },

    'check-victory-at-end-of-turn' => { isa => Bool, default => 1 },
    'domestic-trade'               => { isa => Bool, default => 1 },
    'random-terrain'               => { isa => Bool, default => 0 },
    'use-pirate'                   => { isa => Bool, default => 1 },
    'strict-trade'                 => { isa => Bool, default => 0 },

    'num-bridges'                  => { isa => PositiveOrZeroInt, default =>  3 },
    'num-cities'                   => { isa => PositiveOrZeroInt, default =>  4 },
    'num-city-walls'               => { isa => PositiveOrZeroInt, default =>  3 },
    'num-roads'                    => { isa => PositiveOrZeroInt, default => 15 },
    'num-settlements'              => { isa => PositiveOrZeroInt, default =>  5 },
    'num-ships'                    => { isa => PositiveOrZeroInt, default => 15 },

    'resource-count'               => { isa => PositiveInt, default => 30 },

    'develop-chapel'               => { isa => PositiveOrZeroInt, default =>  1 },
    'develop-governor'             => { isa => PositiveOrZeroInt, default =>  1 },
    'develop-library'              => { isa => PositiveOrZeroInt, default =>  1 },
    'develop-market'               => { isa => PositiveOrZeroInt, default =>  1 },
    'develop-university'           => { isa => PositiveOrZeroInt, default =>  1 },
    'develop-monopoly'             => { isa => PositiveOrZeroInt, default =>  2 },
    'develop-plenty'               => { isa => PositiveOrZeroInt, default =>  2 },
    'develop-road'                 => { isa => PositiveOrZeroInt, default =>  2 },
    'develop-soldier'              => { isa => PositiveOrZeroInt, default => 13 },

    'chits'                        => { isa => "ArrayRef[Pioneers::Types::ChitValue]", parse_as => "ChitList" },
    'nosetup'                      => { isa => ArrayRef[ArrayRef[PositiveOrZeroInt]], parse_as => "NoSetupList" },
);

while (my ($param, $settings) = each %parameters) {
    (my $name = $param) =~ tr/-/_/;
    $$settings{name} = $name;
    has $name, is => "rw", subhash( $settings, qw/ isa required default / );
}

has map => (
    is         => 'rw',
    isa        => 'Pioneers::Map',
    handles    => {
        randomize_hexes => "randomize_hexes",
        shuffle_ports   => "shuffle_ports",
    },
);


sub load {
    my ($class, $file) = @_;
    return Pioneers::Config::Parser::parse_file($file);
}


=head3 shuffle_map

Shuffles the map - this is a weak randomization in that ports are not
moved. However is more randomization that "random-terrain" can provide and
will ensure that the chit assignment is valid.

Actions:

 - permutes ports (without moving any)
 - permutes land haxes (including gold or deserts)
 - permutes chits (enforces the no adjacent 6 or 8 rule)

=cut

method shuffle_map() {
    $self->shuffle_ports;
    $self->randomize_hexes("land");
    $self->randomize_chits;
}


=head3 randomize_chits

Randomizes the chits of a map while enforcing the rule that no 6's or 8's
may be adjacent.

NOTE: This method may die if there are no valid randomizations (or if it
has problems finding one).

=cut

sub randomize_chits {
    my ($self, $trials, $idx_trials) = @_;
    $trials     //= 10;
    $idx_trials //= 10;
    croak "Unable to randomize chits" unless $trials;

    my $map   = $self->map;
    my @chits = @{$self->chits};
    my (@coor, %val);

    $map->apply(sub {
        my ($hex, $i, $j) = @_;
        return unless $hex->has_prop("consume_chit");
        $val{"$i,$j"} = shift @chits;
        push @coor, [$i,$j];
    });


    # Basically, we are performing a Fisher-Yates shuffle but rejecting
    # (and redo-trying) any swaps which would make an invalid map. I'm
    # pretty sure that this produces a biased shuffle (the probable
    # legality of certain swaps will depend on the initial conditions of
    # the chits). However, I expect it will be good enough.
    my $idx = @coor;
    my $_idx_trials = $idx_trials;
  IDX:
    # Note: Need to enter block when $idx == 0 also so we check for two red
    #       numbers in upper right corner.
    while (--$idx >= 0) {
        my $swp = int rand($idx+1);
        my ($i, $j) = @{$coor[$idx]};# The coordinates we are fixing
        my ($a, $b) = @{$coor[$swp]};# Where we are stealing from

        # Do not want 2, 12, 6, or 8 on gold mines
        if ($val{"$a,$b"} =~ /^(?:2|12|6|8)$/) {
            redo IDX if 'g' eq $map->hex_map->[$i]->[$j]->type and $_idx_trials-- > 0;
        }

        # $i, $j may equal $a, $b or be neighbors or completely separated, however,
        #   - we are working backwards through the hexes (from bottom right)
        #   - thus, once the chit at (i,j) is placed, it will not be moved
        #   - thus, its neighbors below and right of it will never move

        # Need only check "forward" hexes if we ourselves are a 6 or 8
        if ($val{"$a,$b"} =~ /[68]/) {
            for (qw/ e sw se /) {
                next unless my ($x, $y) = $map->neighbor($i, $j, $_);
                if ($val{"$x,$y"} and $val{"$x,$y"} =~ /[68]/) {
                    # bad swap
                    if ($_idx_trials-- > 0) {
                        redo IDX;# try again
                    } else {
                        # Tried too many times (most likely got into the
                        # corner with a bunch of reds left over), start
                        # over from scratch
                        return $self->randomize_chits($trials-1, $idx_trials);
                    }
                }
            }
        }

        # Success, reset the local trial counter, perform the swap and move on
        $_idx_trials = $idx_trials;
        @val{"$i,$j", "$a,$b"} = @val{"$a,$b", "$i,$j"};
    }

    @chits = map $val{"$$_[0],$$_[1]"}, @coor;
    $self->chits(\@chits);

    return 1;
}


=head3 chits_ok

Return true if the chit arrangement is considered valid (that is, no
adjacent 6's or 8's).

=cut

method chits_ok() {
    my $map   = $self->map;
    my @chits = @{$self->chits};
    my @chit_matrix;

    $map->apply(sub {
        my ($hex, $i, $j) = @_;
        return unless $hex->has_prop("consume_chit");
        push @chit_matrix, [] if $i > $#chit_matrix;
        $chit_matrix[$i][$j] = shift @chits;

        next unless $chit_matrix[$i][$j] =~ /[68]/;

        # Need only check "backward" hexes:
        for (qw/ nw ne w /) {
            next unless my ($a, $b) = $map->neighbor($i, $j, $_);
            return 0 if $chit_matrix[$a][$b] and $chit_matrix[$a][$b] =~ /[68]/;
        }
    });

    return 1;
}


method to_map_string() {
    my $output = "";

    for my $param (sort keys %parameters) {
        next if $param eq 'variant';# Obsolete
        my $name = $parameters{$param}{name};
        my $val  = $self->$name;
        next unless defined($val);

        if ($parameters{$param}{isa} eq 'Bool') {
            $output .= "$param\n" if $val;
        }

        elsif ($param eq 'nosetup') {
            for my $vertex (@$val) {
                $output .= "$param @$vertex\n";
            }
        }

        else {
            my $str;
            given (ref($val)) {
                when ('')      { $str = $val }
                when ('ARRAY') { $str = join ",", @$val }
                default        { die "No stringification for object of reference $_" }
            }
            $str =~ s/\n/\n$param /mg;
            $output .= "$param $str\n";
        }
    }

    $output .= $self->map->to_map_string;

    return $output;
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
