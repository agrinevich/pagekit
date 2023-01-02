#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Compile;
use FindBin qw($Bin);
use lib "$Bin/../lib";

our $VERSION = '0.2';

my $test = Test::Compile->new();

$test->all_files_ok();
$test->done_testing();

1;
