package Pioneers::Config;
use Carp;
use Moose;
use MooseX::UndefTolerant;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 3.0110;# Created: 2013-02-09
use Pioneers::Util qw/ subhash /;
use Pioneers::Types;
use Pioneers::Map;
use Pioneers::Config::Parser;

use MooseX::Types::Moose qw/ Str Bool ArrayRef /;
use MooseX::Types::Common::Numeric qw/ PositiveInt PositiveOrZeroInt /;

use List::Util qw/ sum shuffle /;

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
    'use-dice-deck'                => { isa => Bool, default => 0 },

    'num-bridges'                  => { isa => PositiveOrZeroInt, default =>  3 },
    'num-cities'                   => { isa => PositiveOrZeroInt, default =>  4 },
    'num-city-walls'               => { isa => PositiveOrZeroInt, default =>  3 },
    'num-roads'                    => { isa => PositiveOrZeroInt, default => 15 },
    'num-settlements'              => { isa => PositiveOrZeroInt, default =>  5 },
    'num-ships'                    => { isa => PositiveOrZeroInt, default => 15 },
    'num-removed-dice-cards'       => { isa => PositiveOrZeroInt, default =>  5 },

    'resource-count'               => { isa => PositiveInt, default => 30 },
    'num-dice-decks'               => { isa => PositiveInt, default =>  2 },

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
        randomize_ports => "randomize_ports",
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

 $map->randomize_chits(\%opt);

Randomize chits, enforcing various rules. BEWARE: At this time, this method
will loop forever if there are no valid chit assignments and may loop for a
long time if it is really hard to find one (though most maps should be
either possible and fast or completely impossible).

=over 4

=item prevent_adjacent_68

Default true. When set, ensure that no "red" numbers (6's or 8's) are adjacent.

=item enforce_midnums_on_gold

Default true. When set, 6's, 8's, 2,'s and 12's will not be placed on gold mines.

=item allow_gold_adjacent_68

Default true. When false, gold mines will not be permitted adjacent to
"red" numbers (6'8 or 8's).

=back

=cut

sub randomize_chits {
    state $num_68 = { map +($_ => 1), 6, 8 };
    state $midnum = { map +($_ => 1), 3..5, 9..11 };
    state $default_opt = {
        prevent_adjacent_68     => 1,
        enforce_midnums_on_gold => 1,
        allow_gold_adjacent_68  => 1,
    };

    my ($self, $opt) = @_;
    for (keys %$default_opt) {
        $$opt{$_} = $$default_opt{$_} unless exists($$opt{$_});
    }

    my $map = $self->map;
    my (%chits, %val, @ordered_hex, @hex, %nonred, %nonred_init);

    $chits{$_}++ for @{$self->chits};
    $map->apply(sub {
        my ($hex, $i, $j) = @_;
        return unless $hex->has_prop("consume_chit");
        push @ordered_hex, [ $i, $j, $hex ];
        if (!$$opt{allow_gold_adjacent_68} and 'g' eq $hex->type) {
            $nonred_init{"$$_[0],$$_[1]"}++ for $map->neighbors($i, $j);
        }
    });

    die "Wrong number of chits, ".(sum(values(%chits)))." != ".(0+@ordered_hex).$/ unless sum(values(%chits)) == @ordered_hex;

  TRIAL:
    %nonred = %nonred_init;
    @hex = shuffle(@ordered_hex);

    # Place difficult numbers first so we don't nedlessly block ourselves out.
    for my $N (6, 8, 2, 12, 3..5, 9..11) {
        # Once a hex is rejectsd for $N, there is no point retrying it
        # untile we are at another $N, so reset $idx outside the next loop.
        my $idx = 0;
        for (1..($chits{$N}||0)) {
            goto TRIAL if $idx >= @hex;# What to do about infinite loop?
            my ($i, $j, $hex) = @{$hex[$idx]};

            # Perform various checks to see whether we accept placing
            # this number on this hex:
            my $invalid = 0;
            $invalid++ if $$opt{prevent_adjacent_68}     and $$num_68{$N}  and $nonred{"$i,$j"};
            $invalid++ if $$opt{enforce_midnums_on_gold} and !$$midnum{$N} and 'g' eq $hex->type;

            # If invalid, skip this hex and try the next in the randomization
            if ($invalid) { $idx++; redo; }

            # Have a valid hex for this number!
            splice @hex, $idx, 1;# Remove hex, thus we do not increment $idx
            $val{"$i,$j"} = $N;

            # Mark neighbors if we are 6 ot 8:
            if ($$opt{prevent_adjacent_68} and $$num_68{$N}) {
                $nonred{"$$_[0],$$_[1]"}++ for $map->neighbors($i, $j);
            }
        }
    }

    $self->chits([ map $val{"$$_[0],$$_[1]"}, @ordered_hex ]);
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
            for (ref($val)) {
                if ($_ eq '')         { $str = $val }
                elsif ($_ eq 'ARRAY') { $str = join ",", @$val }
                else                  { die "No stringification for object of reference $_" }
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
