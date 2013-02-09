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
    'title'                        => { isa => "Str", required => 1 },
    'variant'                      => { isa => "Str" }, # Not used
    'desc'                         => { isa => "Str" },

    'num-players'                  => { isa => "Pioneers::Types::PosInt", required => 1 },
    'victory-points'               => { isa => "Pioneers::Types::PosInt", required => 1 },
    'sevens-rule'                  => { isa => "Pioneers::Types::SevensRule", default => 1 },
    'island-discovery-bonus'       => { isa => "ArrayRef[Pioneers::Types::NonNegInt]", parse_as => "ArrayOfNonNegInt" },

    'check-victory-at-end-of-turn' => { isa => "Bool", default => 1 },
    'domestic-trade'               => { isa => "Bool", default => 1 },
    'random-terrain'               => { isa => "Bool", default => 0 },
    'use-pirate'                   => { isa => "Bool", default => 1 },
    'strict-trade'                 => { isa => "Bool", default => 0 },

    'num-bridges'                  => { isa => "Pioneers::Types::NonNegInt", default =>  3 },
    'num-cities'                   => { isa => "Pioneers::Types::NonNegInt", default =>  4 },
    'num-city-walls'               => { isa => "Pioneers::Types::NonNegInt", default =>  3 },
    'num-roads'                    => { isa => "Pioneers::Types::NonNegInt", default => 15 },
    'num-settlements'              => { isa => "Pioneers::Types::NonNegInt", default =>  5 },
    'num-ships'                    => { isa => "Pioneers::Types::NonNegInt", default => 15 },

    'resource-count'               => { isa => "Pioneers::Types::PosInt", default => 30 },

    'develop-chapel'               => { isa => "Pioneers::Types::NonNegInt", default =>  1 },
    'develop-governor'             => { isa => "Pioneers::Types::NonNegInt", default =>  1 },
    'develop-library'              => { isa => "Pioneers::Types::NonNegInt", default =>  1 },
    'develop-market'               => { isa => "Pioneers::Types::NonNegInt", default =>  1 },
    'develop-university'           => { isa => "Pioneers::Types::NonNegInt", default =>  1 },
    'develop-monopoly'             => { isa => "Pioneers::Types::NonNegInt", default =>  2 },
    'develop-plenty'               => { isa => "Pioneers::Types::NonNegInt", default =>  2 },
    'develop-road'                 => { isa => "Pioneers::Types::NonNegInt", default =>  2 },
    'develop-soldier'              => { isa => "Pioneers::Types::NonNegInt", default => 13 },

    'chits'                        => { isa => "ArrayRef[Pioneers::Types::ChitValue]", parse_as => "ChitList" },
    'nosetup'                      => { isa => "ArrayRef[ArrayRef[Pioneers::Types::NonNegInt]]", parse_as => "NoSetupList" },
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
