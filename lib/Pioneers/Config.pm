package Pioneers::Config;
use Moose;
use MooseX::UndefTolerant;
use MooseX::StrictConstructor;
use Method::Signatures::Simple;
use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09
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
);


sub load {
    my ($class, $file) = @_;
    return Pioneers::Config::Parser::parse_file($file);
}



method to_map_string() {
    my $output = "";

    for my $param (sort keys %parameters) {
        next if $param eq 'variant';# Obsolete
        my $name = $parameters{$param}{name};
        my $val  = $self->$name;
        next unless defined($val);

        if ($parameters{$param}{isa} eq 'Bool') {
            $output .= "$param\n";
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
