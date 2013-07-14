#!/usr/bin/perl
use strict; use warnings; use 5.010;
use Test::More 0.88;

use lib 'lib';
use Pioneers::Config;

my $config = Pioneers::Config->load("t/test.game");
ok($config, "parsed OK");

my $map = $config->map;

is($map->nr_chits, 28, "nr_chits");
is($map->layout,    1, "layout");

# neighbor
{
    my ($i, $j, $hex);
    ($i, $j, $hex) = $map->neighbor(3, 2, "nw");
    is($i, 2, "nw i = 2");
    is($j, 2, "nw j = 2");
    is($hex->type, "f", "nw type = f");

    ($i, $j, $hex) = $map->neighbor(0, 5, "e");
    is($i, undef, "e i = undef");
    is($j, undef, "e j = undef");
    is($hex, undef, "e type = -");

    ($i, $j, $hex) = $map->neighbor(1, 4, "e");
    is($i, 1, "e i = 1");
    is($j, 5, "e j = 5");
    is($hex->type, "s", "e type = s");
}


done_testing;
