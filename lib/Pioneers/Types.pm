package Pioneers::Types;
use strict; use warnings; use re 'taint';
use Moose::Util::TypeConstraints;

=pod

=head1 NAME

Pioneers::Types - Types for Pioneers modules

=head1 SYNOPSIS

 use Pioneers::Types;

=head1 TYPES

=cut

subtype "Pioneers::Types::PosInt" => (
    as "Int",
    where { $_ > 0 },
    message { 'Int is not larger than 0' }
);

subtype "Pioneers::Types::NonNegInt" => (
    as "Int",
    where { $_ >= 0 },
    message { 'Int must be nonnegative' }
);


enum "Pioneers::Types::SevensRule"      => [ 0, 1, 2 ];

enum "Pioneers::Types::ChitValue"       => [ 2..6, 8..12 ];

enum "Pioneers::Types::LandHexType"       => [qw/ d g p m f h t /];
enum "Pioneers::Types::SeaHexType"        => [qw/ s /];

enum "Pioneers::Types::PortType"        => [qw/ ? b g o w l /];
enum "Pioneers::Types::PortOrientation" => [ 0..5 ];







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
