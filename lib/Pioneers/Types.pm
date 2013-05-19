package Pioneers::Types;
use strict; use warnings; use re 'taint';
use Moose::Util::TypeConstraints;
use YAML::Any;

=pod

=head1 NAME

Pioneers::Types - Types for Pioneers modules

=head1 SYNOPSIS

 use Pioneers::Types;

=head1 TYPES

=cut


our %TYPE_INFO = munge_types(Load(<<'TYPES'));
plain:
  symbol: p
  production: grain
  production_symbol: g
  properties: [ land, resource, production, consume_chit, increment_chit ]

mountain:
  symbol: m
  production: ore
  production_symbol: o
  properties: [ land, resource, production, consume_chit, increment_chit ]

field:
  symbol: f
  production: wool
  production_symbol: l
  properties: [ land, resource, production, consume_chit, increment_chit ]

hill:
  symbol: h
  production: brick
  production_symbol: b
  properties: [ land, resource, production, consume_chit, increment_chit ]

forest:
  symbol: t
  production: wood
  production_symbol: w
  properties: [ land, resource, production, consume_chit, increment_chit ]

desert:
  symbol: d
  properties: [ land, increment_chit ]

gold:
  symbol: g
  production: gold
  properties: [ land, production, consume_chit, increment_chit ]

sea:
  symbol: s
  properties: [ sea ]
TYPES


enum "Pioneers::Types::SevensRule"      => [ 0, 1, 2 ];

enum "Pioneers::Types::ChitValue"       => [ 2..6, 8..12 ];

enum "Pioneers::Types::LandHexType"     => [ map $$_{symbol}, grep $$_{properties}{land}, values %{$TYPE_INFO{by_name}} ];
enum "Pioneers::Types::SeaHexType"      => [ map $$_{symbol}, grep $$_{properties}{sea},  values %{$TYPE_INFO{by_name}} ];

enum "Pioneers::Types::PortType"        => [ '?', map $$_{production_symbol}, grep $$_{properties}{resource}, values %{$TYPE_INFO{by_name}} ];
enum "Pioneers::Types::PortOrientation" => [ 0..5 ];




sub munge_types {
    my $data = shift;
    my %type = (
        raw => $data,
        by_name => {},
        by_symbol => {},
        by_production_symbol => {},
    );

    while (my ($name, $info) = each %$data) {
        my %fixed = (
            name => $name,
            %$info,
            properties => { map +($_ => 1), 'hex', @{$$info{properties}||[]} },
        );

        $type{by_name}{$name} = \%fixed;

        die "Resource $name is missing production symbol" if $$_{properties}{resource} and !$fixed{production_symbol};
        if (exists $fixed{production_symbol}) {
            my $sym = $fixed{production_symbol};
            my $set = $type{by_production_symbol};
            die "Symbol $sym already defined ($$set{$sym}{name}) in hex type $name" if exists $$set{$sym};
            $$set{$sym} = \%fixed;
        }

        die "Missing symbol for hex type $name" unless $fixed{symbol};
        do {
            my $sym = $fixed{symbol};
            my $set = $type{by_symbol};
            die "Symbol $sym already defined ($$set{$sym}{name}) in hex type $name" if exists $$set{$sym};
            $$set{$sym} = \%fixed;
        };
    }

    return %type;
}


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
