package Pioneers::Config::Parser;
use strict; use warnings; use re 'taint'; use 5.010;
our $VERSION = 0.0000;# Created: 2013-02-09
use Regexp::Assemble;
use Pioneers::Config;
use Marpa::R2;
use Path::Class;
require Pioneers::Config::Parser::Actions;

use parent "Exporter";
our %EXPORT_TAGS = (
    parsers => [qw/ parse_file parse_string /],
);
our @EXPORT_OK = map @$_, values %EXPORT_TAGS;
$EXPORT_TAGS{all} = \@EXPORT_OK;

our $GRAMMAR;


=pod

=head1 NAME

Pioneers::Config::Parser - Marpa-based config parser

=head1 SYNOPSIS

 use strict;
 use Pioneers::Config::Parser;

=head1 DESCRIPTION



=head1 USAGE

=cut


sub rule {
    my ($lhs, $rhs, @rest) = @_;
    $rhs = [ ref($rhs) ? @$rhs : $rhs ];
    return ( lhs => $lhs, rhs => $rhs, @rest );
}

my %tokens = (
    RESOURCE_HEX_TYPE => [ qr/\G([gpmfht])/ ],
    SEA_HEX_TYPE      => [ qr/\G(s)/ ],
    DESERT_HEX_TYPE   => [ qr/\G(d)/ ],
    TABLE_HEX_TYPE    => [ qr/\G(\-)/ ],
    CHIT_INDEX        => [ qr/\G(\d+)/ ],
    PORT_TYPE         => [ qr/\G([\?bgowl])/ ],
    PIRATE            => [ qr/\G(R)/ ],
    NO_SHUFFLE        => [ qr/\G(\+)/ ],
    PORT_DIRECTION    => [ qr/\G([0-5])/ ],

    CHIT_VALUE        => [ qr/\G([2-68-9]|1[0-2])/ ],# Valid dice rolls

    COMMENT           => [ qr/\G(#.*)/ ],
    COMMA             => [ qr/\G,/ ],

    BEGIN_MAP         => [ qr/\Gmap/ ],
    END_MAP           => [ qr/\G\./ ],

    NO_SETUP_X        => [ qr/\G(\d+)/ ],
    NO_SETUP_Y        => [ qr/\G(\d+)/ ],
    NO_SETUP_D        => [ qr/\G([0-5])/ ],
    SEVENS_RULE       => [ qr/\G([0-2])/ ],

    Bool              => [ qr/\G/, 1 ],

    BEGIN_LINE        => [ qr/\G^/m ],
    LINE              => [ qr/\G(.*)/ ],
    OPT_SPACE         => [ qr/\G([ \t]*)/ ],
    SPACE             => [ qr/\G([ \t]+)/ ],
    NonNegInt         => [ qr/\G(\d+)/, sub { 0 + $1 } ],
    PosInt            => [ qr/\G([1-9][0-9]*)/, sub { 0 + $1 } ],
    EOL               => [ qr/\G(?:\n|\r\n)/ ],
    EOF               => [ qr/\G\z/ ],
);


sub build_parameter_rules {
    my (@rules, %types);

    while (my ($param, $settings) = each %Pioneers::Config::parameters) {
        my $type = $$settings{parse_as} || $$settings{isa};
        $type =~ s/^Pioneers::Types:://;
        $types{$type} //= Regexp::Assemble->new;
        $types{$type}->add(quotemeta($param));
    }

    while (my ($type, $re) = each %types) {
        my $pat = $re->as_string;
        $tokens{"parameter:$type"} = [ qr/\G($pat)/ ];
        if ($type eq 'Bool') {
            push @rules, { rule parameter => [ "parameter:$type", "OPT_SPACE", $type ], action => "set_parameter" };
        } else {
            push @rules, { rule parameter => [ "parameter:$type", "SPACE", $type ], action => "set_parameter" };
        }
    }

    return @rules;
}

sub build_grammar {
    return if $GRAMMAR;
    my @parameter_rules = build_parameter_rules();

    $GRAMMAR = Marpa::R2::Grammar->new({
        start => "config",
        actions => "Pioneers::Config::Parser::Actions",
        default_action => '_1',
        terminals => [keys %tokens],

        rules => [
            { rule config => "command", min => 0, action => "build_config" },
            { rule command => [qw/ BEGIN_LINE OPT_SPACE directive OPT_SPACE EOL /] },
            { rule command => [qw/ BEGIN_LINE OPT_SPACE directive OPT_SPACE EOF /] },
            { rule command => [qw/ BEGIN_LINE OPT_SPACE EOL /] },
            { rule command => [qw/ BEGIN_LINE OPT_SPACE EOF /] },

            { rule directive => "parameter" },
            { rule directive => "COMMENT" },
            { rule directive => "map", action => "build_map" },

            @parameter_rules,

            { rule map => [qw/ BEGIN_MAP EOL map_data END_MAP /] },

            { rule map_data => "map_line", min => 1, separator => "EOL" },
            { rule map_line => [qw/ BEGIN_LINE OPT_SPACE map_list /],           action => "step_map_row" },
            { rule map_list => "hex_spec", min => 1, separator => "list_sep" },

            { rule hex_spec => [qw/ RESOURCE_HEX_TYPE CHIT_INDEX /],            action => "add_resource_hex" },
            { rule hex_spec => [qw/ RESOURCE_HEX_TYPE CHIT_INDEX NO_SHUFFLE /], action => "add_resource_hex" },
            { rule hex_spec => [qw/ SEA_HEX_TYPE /],                            action => "add_sea_hex" },
            { rule hex_spec => [qw/ SEA_HEX_TYPE PORT_TYPE PORT_DIRECTION /],   action => "add_sea_hex" },
            { rule hex_spec => [qw/ SEA_HEX_TYPE PIRATE /],                     action => "add_sea_hex" },
            { rule hex_spec => [qw/ DESERT_HEX_TYPE CHIT_INDEX /],              action => "add_desert_hex" },
            { rule hex_spec => [qw/ DESERT_HEX_TYPE CHIT_INDEX NO_SHUFFLE /],   action => "add_desert_hex" },
            { rule hex_spec => "TABLE_HEX_TYPE",                                action => "add_empty_hex" },

            { rule list_sep => [qw/ OPT_SPACE COMMA OPT_SPACE /] },

            { rule Str => "LINE" },
            { rule SevensRule => "SEVENS_RULE" },
            { rule ArrayOfNonNegInt => "NonNegInt", min => 1, separator => "list_sep",  action => "gather_list" },
            { rule ChitList => "CHIT_VALUE", min => 1, separator => "list_sep",         action => "gather_list" },
            { rule NoSetupList => [qw/ NO_SETUP_X SPACE NO_SETUP_Y SPACE NO_SETUP_D /], action => "gather_nosetup" },
        ],
    });

    $GRAMMAR->precompute;
}




sub parse_file {
    my $file = file(shift);
    parse_string(scalar $file->slurp);
}

sub parse_string {
    build_grammar();
    my $input = shift;
    my $rec = Marpa::R2::Recognizer->new({
        grammar         => $GRAMMAR,
        ranking_method  => 'rule',
    });

    my $pos = 0;
  TOKEN:
    while ($pos < length($input)) {
        my $expected = $rec->terminals_expected;

        if (@$expected) {
            # [ TOKEN, value, length ]
            for my $tok (lex(\$input, $pos, $expected)) {
                if (defined($rec->read(@$tok[0,1]))) {
                    $pos += $$tok[2];
                    next TOKEN
                }
            }

            PARSE_ERROR($input, $pos, $expected);
        }

        else {
            PARSE_ERROR($input, $pos);
        }
    }

    return ${$rec->value};
}


sub lex {
    my ($input, $pos, $expected) = @_;
    my @matches;

  TOKEN:
    for my $token_name (@$expected) {
        my $token = $tokens{$token_name};
        die "Unknown token $token_name" unless defined $token;
        my $rule = $token->[0];
        pos($$input) = $pos;
        next TOKEN unless $$input =~ $rule;

        my $matched_len = $+[0] - $-[0];
        my $matched_value = undef;

        if (defined( my $val = $token->[1] )) {
            if (ref $val eq 'CODE') {
                $matched_value = $val->();
            } else {
                $matched_value = $val;
            }
        } elsif ($#- > 0) { # Captured a value
            $matched_value = $1;
        }

        push @matches, [ $token_name, $matched_value, $matched_len ];
    }

    return sort { $$b[2] <=> $$a[2] } @matches;
}



sub PARSE_ERROR {
    my ($input, $pos, $expected) = @_;

    my $line = 1+(substr($input,0,$pos) =~ tr/\n/\n/);
    my $eol  = index($input,"\n",$pos);

    my $at;
    if ($eol == $pos) {
        $at = "end of line";
    } else {
        $at = "'" . substr($input, $pos, $eol - $pos) . "'";
    }

    if ($expected and @$expected) {
        die "Parse error on line $line at $at, expecting: @$expected\n";
    } else {
        die "Parse error on line $line at $at.\n";
    }
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
